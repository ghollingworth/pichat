"""
Citation Renderer Module

Handles rendering of markdown text with citations in multiple output formats.
Supports HTML, Markdown, Plain Text, and PHPBB formats.
"""
import re
from bisect import bisect_right


class CitationRenderer:
    """
    Handles rendering of markdown text with citations in multiple output formats.
    Supports HTML, Markdown, Plain Text, and PHPBB formats.
    """
    
    @staticmethod
    def _build_line_index(text):
        """Return list of (start_offset, end_offset) for each line."""
        lines = text.splitlines(keepends=True)
        line_ranges = []
        offset = 0
        for line in lines:
            start = offset
            offset += len(line)
            line_ranges.append((start, offset))
        if not lines:
            line_ranges.append((0, 0))
        return line_ranges

    @staticmethod
    def _offset_to_line(line_ranges, offset):
        """Map a character offset to a 1-based line number."""
        if not line_ranges:
            return 1
        starts = [start for start, _ in line_ranges]
        index = bisect_right(starts, max(0, offset)) - 1
        if index < 0:
            return 1
        if index >= len(line_ranges):
            return len(line_ranges)
        return index + 1

    def extract_markdown_blocks(self, markdown_text):
        """Extract contiguous non-empty line blocks with line ranges."""
        if markdown_text is None:
            markdown_text = ""
        lines = markdown_text.splitlines()
        blocks = []
        block_start = None
        for idx, line in enumerate(lines, start=1):
            if line.strip():
                if block_start is None:
                    block_start = idx
            else:
                if block_start is not None:
                    blocks.append({"start_line": block_start, "end_line": idx - 1})
                    block_start = None
        if block_start is not None:
            blocks.append({"start_line": block_start, "end_line": len(lines)})
        return blocks

    def map_supports_to_lines(self, markdown_text, grounding_supports):
        """Add start_line/end_line for each grounding support using offsets.
        Merges consecutive supports that reference the same chunks."""
        if markdown_text is None:
            markdown_text = ""
        line_ranges = self._build_line_index(markdown_text)
        supports_with_lines = []
        for support in grounding_supports or []:
            if isinstance(support, dict):
                segment = support.get("segment") or {}
                start_offset = segment.get("start_index", 0)
                end_offset = segment.get("end_index", len(markdown_text))
            else:
                segment = getattr(support, "segment", None)
                if segment and getattr(segment, "start_index", None) is not None:
                    start_offset = segment.start_index
                else:
                    start_offset = 0
                if segment and getattr(segment, "end_index", None) is not None:
                    end_offset = segment.end_index
                else:
                    end_offset = len(markdown_text)
            supports_with_lines.append({
                "support": support,
                "start_offset": start_offset,
                "end_offset": end_offset,
                "start_line": self._offset_to_line(line_ranges, start_offset),
                "end_line": self._offset_to_line(line_ranges, end_offset),
            })
        
        # Merge consecutive supports that reference the same chunks
        if len(supports_with_lines) < 2:
            return supports_with_lines
        
        # Sort by start_line, then by end_line
        supports_with_lines.sort(key=lambda x: (x["start_line"], x["end_line"]))
        
        merged = []
        i = 0
        while i < len(supports_with_lines):
            current = supports_with_lines[i]
            current_support = current["support"]
            
            # Get chunk indices for current support
            current_chunks = set()
            if isinstance(current_support, dict):
                current_chunks = set(current_support.get("grounding_chunk_indices", []))
            elif hasattr(current_support, "grounding_chunk_indices"):
                current_chunks = set(current_support.grounding_chunk_indices or [])
            
            # Try to merge with subsequent supports
            merged_support = current
            j = i + 1
            while j < len(supports_with_lines):
                next_item = supports_with_lines[j]
                next_support = next_item["support"]
                
                # Get chunk indices for next support
                next_chunks = set()
                if isinstance(next_support, dict):
                    next_chunks = set(next_support.get("grounding_chunk_indices", []))
                elif hasattr(next_support, "grounding_chunk_indices"):
                    next_chunks = set(next_support.grounding_chunk_indices or [])
                
                # Check if they reference the same chunks and are consecutive
                same_chunks = current_chunks == next_chunks and len(current_chunks) > 0
                consecutive = (merged_support["end_line"] + 1 >= next_item["start_line"] and
                              merged_support["start_line"] <= next_item["end_line"] + 1)
                
                if same_chunks and consecutive:
                    # Merge: extend the range and combine citation URLs
                    # Update the merged support's line/offset info
                    merged_support["start_offset"] = min(merged_support["start_offset"], next_item["start_offset"])
                    merged_support["end_offset"] = max(merged_support["end_offset"], next_item["end_offset"])
                    merged_support["start_line"] = min(merged_support["start_line"], next_item["start_line"])
                    merged_support["end_line"] = max(merged_support["end_line"], next_item["end_line"])
                    
                    # Merge citation URLs (avoid duplicates by chunk_idx)
                    if isinstance(merged_support["support"], dict):
                        current_urls = merged_support["support"].get("citation_urls", [])
                        next_urls = next_support.get("citation_urls", [])
                        seen_chunk_indices = {c.get("chunk_idx") for c in current_urls if c.get("chunk_idx") is not None}
                        for citation in next_urls:
                            chunk_idx = citation.get("chunk_idx")
                            if chunk_idx is None or chunk_idx not in seen_chunk_indices:
                                current_urls.append(citation)
                                if chunk_idx is not None:
                                    seen_chunk_indices.add(chunk_idx)
                        merged_support["support"]["citation_urls"] = current_urls
                        # Update segment to reflect merged range
                        if "segment" in merged_support["support"]:
                            merged_support["support"]["segment"]["start_index"] = merged_support["start_offset"]
                            merged_support["support"]["segment"]["end_index"] = merged_support["end_offset"]
                    j += 1
                else:
                    break
            
            merged.append(merged_support)
            i = j
        
        return merged

    def insert_citations_into_text(self, text, supports_with_lines, chunk_to_citation, output_mode):
        """
        Insert citation links directly into text based on output mode.
        Returns the text with citations inserted.
        """
        if output_mode == 'html':
            # HTML mode doesn't insert citations into text - uses clickable regions
            return text
        
        lines = text.splitlines(keepends=True)
        if not lines:
            return text
        
        # Build line_citations mapping
        line_citations = {}
        for item in supports_with_lines:
            support = item["support"]
            line_no = item["end_line"]
            citation_urls = []
            
            if isinstance(support, dict):
                citation_urls = support.get("citation_urls", [])
            elif hasattr(support, "citation_urls"):
                citation_urls = support.citation_urls or []
            
            if citation_urls:
                for citation in citation_urls:
                    chunk_idx = None
                    url = None
                    title = None
                    
                    if isinstance(citation, dict):
                        chunk_idx = citation.get("chunk_idx")
                        url = citation.get("url")
                        title = citation.get("title")
                    else:
                        chunk_idx = getattr(citation, "chunk_idx", None)
                        url = getattr(citation, "url", None)
                        title = getattr(citation, "title", None)
                    
                    if not url and title:
                        url = f"localhost://{title}"
                    
                    if url and chunk_idx is not None and chunk_idx in chunk_to_citation:
                        citation_num = chunk_to_citation[chunk_idx]
                        line_citations.setdefault(line_no, []).append({
                            "url": url,
                            "title": title,
                            "citation_num": citation_num,
                            "chunk_idx": chunk_idx,
                        })
        
        # Insert citations into lines
        result_lines = []
        for line_idx, line in enumerate(lines, start=1):
            result_lines.append(line.rstrip('\n\r'))
            
            if line_idx in line_citations:
                citations = line_citations[line_idx]
                # Remove duplicates by citation_num
                seen_nums = set()
                unique_citations = []
                for cit in citations:
                    if cit["citation_num"] not in seen_nums:
                        unique_citations.append(cit)
                        seen_nums.add(cit["citation_num"])
                
                # Sort by citation number
                unique_citations.sort(key=lambda x: x["citation_num"])
                
                # Format citations based on output mode
                citation_parts = []
                for cit in unique_citations:
                    num = cit["citation_num"]
                    url = cit["url"]
                    title = cit.get("title", "")
                    
                    if output_mode == 'markdown':
                        # Markdown: [1](url) or [1: title](url)
                        if title:
                            citation_parts.append(f"[{num}: {title}]({url})")
                        else:
                            citation_parts.append(f"[{num}]({url})")
                    elif output_mode == 'raw':
                        # Raw mode: [1] url (text format for citations)
                        citation_parts.append(f"[{num}] {url}")
                    elif output_mode == 'phpbb':
                        # PHPBB: [url=url]1[/url]
                        citation_parts.append(f"[url={url}]{num}[/url]")
                
                if citation_parts:
                    if output_mode == 'raw':
                        # For raw, add citations on same line with space
                        result_lines[-1] += " " + " ".join(citation_parts)
                    else:
                        # For markdown and phpbb, add citations on same line
                        result_lines[-1] += " " + " ".join(citation_parts)
            
            # Add back newline if original had one
            if line.endswith('\n'):
                result_lines[-1] += '\n'
        
        return ''.join(result_lines)

    def render(self, markdown_text, grounding_supports, output_mode='html'):
        """
        Convert markdown to HTML and append citation links at the end of the line
        corresponding to each grounding support's end offset.
        Citation numbers are based on unique chunk indices.
        
        output_mode: 'html', 'markdown', 'raw', or 'phpbb'
        """
        if markdown_text is None:
            markdown_text = ""
        blocks = self.extract_markdown_blocks(markdown_text)
        supports_with_lines = self.map_supports_to_lines(markdown_text, grounding_supports)

        # Build a global mapping of chunk_idx -> citation_number
        # This ensures each unique chunk gets a consistent citation number
        chunk_to_citation = {}
        citation_number = 1
        
        # First pass: collect all unique chunks and assign citation numbers
        for item in supports_with_lines:
            support = item["support"]
            citation_urls = None
            chunk_indices = []
            
            if isinstance(support, dict):
                citation_urls = support.get("citation_urls", [])
                chunk_indices = support.get("grounding_chunk_indices", [])
            elif hasattr(support, "citation_urls"):
                citation_urls = support.citation_urls or []
                chunk_indices = getattr(support, "grounding_chunk_indices", [])
            
            # Map each chunk index to a citation number
            for citation in citation_urls:
                chunk_idx = None
                if isinstance(citation, dict):
                    chunk_idx = citation.get("chunk_idx")
                elif hasattr(citation, "chunk_idx"):
                    chunk_idx = getattr(citation, "chunk_idx", None)
                
                if chunk_idx is not None and chunk_idx not in chunk_to_citation:
                    chunk_to_citation[chunk_idx] = citation_number
                    citation_number += 1

        lines = markdown_text.splitlines()
        line_citations = {}
        
        # Second pass: collect citations per line, using chunk-based citation numbers
        for item in supports_with_lines:
            support = item["support"]
            line_no = item["end_line"]
            citation_urls = None
            
            if isinstance(support, dict):
                citation_urls = support.get("citation_urls", [])
            elif hasattr(support, "citation_urls"):
                citation_urls = support.citation_urls or []
            
            if citation_urls:
                for citation in citation_urls:
                    chunk_idx = None
                    url = None
                    title = None
                    
                    if isinstance(citation, dict):
                        chunk_idx = citation.get("chunk_idx")
                        url = citation.get("url")
                        title = citation.get("title")
                    else:
                        chunk_idx = getattr(citation, "chunk_idx", None)
                        url = getattr(citation, "url", None)
                        title = getattr(citation, "title", None)
                    
                    # If no URL but we have a title, create a localhost:// link
                    if not url and title:
                        url = f"localhost://{title}"
                    
                    if url and chunk_idx is not None and chunk_idx in chunk_to_citation:
                        citation_num = chunk_to_citation[chunk_idx]
                        line_citations.setdefault(line_no, []).append({
                            "url": url,
                            "title": title,
                            "citation_num": citation_num,
                            "chunk_idx": chunk_idx,
                        })

        # Build chunks map: chunk_idx -> {title, url, citation_num}
        # This will be sent to frontend for the citation sidebar
        chunks_map = {}
        for item in supports_with_lines:
            support = item["support"]
            citation_urls = None
            
            if isinstance(support, dict):
                citation_urls = support.get("citation_urls", [])
            elif hasattr(support, "citation_urls"):
                citation_urls = support.citation_urls or []
            
            if citation_urls:
                for citation in citation_urls:
                    chunk_idx = None
                    url = None
                    title = None
                    
                    if isinstance(citation, dict):
                        chunk_idx = citation.get("chunk_idx")
                        url = citation.get("url")
                        title = citation.get("title")
                    else:
                        chunk_idx = getattr(citation, "chunk_idx", None)
                        url = getattr(citation, "url", None)
                        title = getattr(citation, "title", None)
                    
                    if not url and title:
                        url = f"localhost://{title}"
                    
                    if chunk_idx is not None and chunk_idx not in chunks_map:
                        citation_num = chunk_to_citation.get(chunk_idx)
                        chunks_map[chunk_idx] = {
                            "title": title,
                            "url": url,
                            "citation_num": citation_num,
                        }

        # Insert citations into text based on output mode
        if output_mode == 'html':
            # HTML mode: don't insert citations into text - they'll be shown in sidebar
            annotated_markdown = "\n".join(lines)
        elif output_mode == 'raw':
            # Raw mode: return original text unchanged, citations will be appended at end
            annotated_markdown = markdown_text
        else:
            # Other modes: insert citations directly into text
            annotated_markdown = self.insert_citations_into_text(
                markdown_text, supports_with_lines, chunk_to_citation, output_mode
            )
            # For non-HTML modes, we still need to split into lines for blocks
            lines = annotated_markdown.splitlines()
        
        # Generate HTML only for HTML mode
        html = None
        if output_mode == 'html':
            try:
                import importlib
                markdown_it = importlib.import_module("markdown_it")
                markdown_it_class = getattr(markdown_it, "MarkdownIt")
                renderer_module = importlib.import_module("markdown_it.renderer")
                renderer_html = getattr(renderer_module, "RendererHTML")
                
                # Create custom renderer that adds data-sourcepos attributes
                # This must be inside the try block so renderer_html is in scope
                class SourcePosRenderer(renderer_html):
                    def renderAttrs(self, token):
                        """Override to add data-sourcepos for block-level tokens."""
                        result = super().renderAttrs(token)
                        # Add data-sourcepos for block-level tokens that have map info
                        # token.map is [start_line, end_line] where both are 0-based
                        # end_line is exclusive (the line number after the token ends)
                        # So map=[0, 1] means the token is on line 0 only (0-based) = line 1 (1-based)
                        # The last line of the token is (end_line_exclusive - 1) in 0-based
                        # Convert to 1-based: (end_line_exclusive - 1) + 1 = end_line_exclusive_0based
                        if token.map and len(token.map) == 2 and token.tag and token.nesting != -1:
                            start_line_0based = token.map[0]
                            end_line_exclusive_0based = token.map[1]
                            # Convert start to 1-based
                            start_line = start_line_0based + 1
                            # Last line of token is (end_line_exclusive_0based - 1) in 0-based
                            # Convert to 1-based: (end_line_exclusive_0based - 1) + 1 = end_line_exclusive_0based
                            end_line = end_line_exclusive_0based
                            result += f' data-sourcepos="{start_line}:0-{end_line}:0"'
                        return result
                
                md = markdown_it_class("commonmark", {"sourcepos": True}, renderer_cls=SourcePosRenderer)
                html = md.render(annotated_markdown)
                html = self._wrap_html_with_supports(html, supports_with_lines)
            except Exception as exc:
                raise ImportError("markdown-it-py is required to render markdown to HTML") from exc

        # Build supports with URLs (using the same chunk_to_citation mapping)
        supports_with_urls = []
        for item in supports_with_lines:
            support = item["support"]
            citation_urls = []
            if isinstance(support, dict):
                citation_urls = support.get("citation_urls", [])
            elif hasattr(support, "citation_urls"):
                citation_urls = support.citation_urls or []
            
            # Extract URLs and titles with citation numbers
            urls = []
            for citation in citation_urls:
                chunk_idx = None
                if isinstance(citation, dict):
                    url = citation.get("url")
                    title = citation.get("title")
                    chunk_idx = citation.get("chunk_idx")
                else:
                    url = getattr(citation, "url", None)
                    title = getattr(citation, "title", None)
                    chunk_idx = getattr(citation, "chunk_idx", None)
                # If no URL but we have a title, create a localhost:// link
                if not url and title:
                    url = f"localhost://{title}"
                if url:
                    citation_num = chunk_to_citation.get(chunk_idx) if chunk_idx is not None else None
                    urls.append({
                        "url": url,
                        "title": title,
                        "chunk_idx": chunk_idx,
                        "citation_num": citation_num,
                    })
            
            supports_with_urls.append({
                "start_line": item["start_line"],
                "end_line": item["end_line"],
                "start_offset": item["start_offset"],
                "end_offset": item["end_offset"],
                "urls": urls,
            })
        
        result = {
            "markdown": annotated_markdown,
            "blocks": blocks,
            "supports": supports_with_urls,
            "chunks": chunks_map,  # Map of chunk_idx -> {title, url, citation_num}
        }
        
        # Add HTML only for HTML mode
        if output_mode == 'html':
            result["html"] = html
        else:
            # For other modes, return the formatted text
            if output_mode == 'raw':
                # For raw mode, return original text and generate citations list
                result["raw"] = annotated_markdown
                # Generate citations list to append at the end
                citations_list = []
                # Collect all unique citations sorted by citation number
                seen_citations = set()
                # Sort chunks by citation number (handle None values)
                sorted_chunks = sorted(
                    chunks_map.items(),
                    key=lambda x: x[1].get("citation_num") if x[1].get("citation_num") is not None else 999999
                )
                for chunk_idx, chunk_info in sorted_chunks:
                    citation_num = chunk_info.get("citation_num")
                    if citation_num is not None and citation_num not in seen_citations:
                        seen_citations.add(citation_num)
                        url = chunk_info.get("url", "")
                        title = chunk_info.get("title", "")
                        citations_list.append(f"[{citation_num}] {url}")
                result["raw_citations"] = "\n".join(citations_list) if citations_list else ""
            elif output_mode == 'markdown':
                result["markdown_formatted"] = annotated_markdown
            elif output_mode == 'phpbb':
                result["phpbb"] = annotated_markdown
        
        return result

    def _wrap_html_with_supports(self, html, supports_with_lines):
        """Wrap HTML elements whose sourcepos overlaps support line ranges."""
        try:
            import importlib
            bs4 = importlib.import_module("bs4")
        except Exception as exc:
            raise ImportError("beautifulsoup4 is required for HTML post-processing") from exc

        soup = bs4.BeautifulSoup(html, "html.parser")

        def parse_sourcepos(value):
            match = re.match(r"^(\d+):\d+-(\d+):\d+$", value or "")
            if not match:
                return None, None
            return int(match.group(1)), int(match.group(2))

        for idx, item in enumerate(supports_with_lines, start=1):
            start_line = item["start_line"]
            end_line = item["end_line"]
            matched = []
            # Find all elements that overlap with this support range
            # Only consider elements that are NOT already inside a citation-range div
            for el in soup.find_all(attrs={"data-sourcepos": True}):
                # Skip if already inside a citation-range div
                if el.find_parent("div", class_="citation-range"):
                    continue
                sourcepos = el.get("data-sourcepos")
                el_start, el_end = parse_sourcepos(sourcepos)
                if el_start is None or el_end is None:
                    continue
                overlaps = not (el_end < start_line or el_start > end_line)
                if overlaps:
                    matched.append(el)
            
            if not matched:
                continue
            
            # Filter to only wrap leaf elements (elements that are not ancestors of other matched elements)
            # This ensures we wrap the most specific elements, not parent containers
            to_wrap = []
            for el in matched:
                # Check if this element is an ancestor of any other matched element
                is_ancestor = False
                for other_el in matched:
                    if el is not other_el:
                        # Check if el is an ancestor of other_el
                        parent = other_el.parent
                        while parent and parent != soup and parent.name:
                            if parent == el:
                                is_ancestor = True
                                break
                            parent = parent.parent
                        if is_ancestor:
                            break
                # Only wrap if it's not an ancestor (i.e., it's a leaf in the matched set)
                if not is_ancestor:
                    to_wrap.append(el)
            
            if not to_wrap:
                continue
            
            # Extract chunk indices from this support
            support = item["support"]
            chunk_indices = []
            if isinstance(support, dict):
                citation_urls = support.get("citation_urls", [])
                for citation in citation_urls:
                    chunk_idx = citation.get("chunk_idx") if isinstance(citation, dict) else getattr(citation, "chunk_idx", None)
                    if chunk_idx is not None and chunk_idx not in chunk_indices:
                        chunk_indices.append(chunk_idx)
            elif hasattr(support, "citation_urls"):
                for citation in (support.citation_urls or []):
                    chunk_idx = citation.get("chunk_idx") if isinstance(citation, dict) else getattr(citation, "chunk_idx", None)
                    if chunk_idx is not None and chunk_idx not in chunk_indices:
                        chunk_indices.append(chunk_idx)
            
            # Create wrapper and insert before first element
            wrapper = soup.new_tag("div")
            wrapper["class"] = f"citation-range citation-range-{idx}"
            wrapper["data-cite-id"] = str(idx)
            if chunk_indices:
                wrapper["data-chunk-indices"] = ",".join(str(ci) for ci in sorted(chunk_indices))
            wrapper["style"] = "cursor: pointer;"
            to_wrap[0].insert_before(wrapper)
            # Move all elements to wrap into the wrapper
            for el in to_wrap:
                wrapper.append(el.extract())

        return str(soup)
