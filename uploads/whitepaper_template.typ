#import "@local/rpi-style:0.1.0": * 
#import "../../globalvars.typ": *

#show: rpi_external_whitepaper.with(
    title: "Raspberry Pi whitepapers: a customer template",
    description: "Raspberry Pi Ltd, in association with ACME",
    release: [1],
    version_history: (
    [1], [21 Aug 2025], [Initial release],
    ),
    watermark: ([Draft]),
    cover_image: scale(image("diagrams/cm5io-hero.png"), x: 200%, y: 200%),
)

// cspell:ignore Ahrefs

= Introduction

#pi whitepapers are documents, predominantly published by #pi, that provide in-depth information and best practices for using Raspberry Pi computers in specific applications, such as industrial automation, IIoT (industrial Internet of Things), or home automation. These documents offer technical details, design guidance, and troubleshooting advice for developers and industrial users, helping them build complex solutions on the #pi platform.

#pi is expanding its whitepaper range to include contributions from third parties. This whitepaper outlines the information that external contributors must provide in order to have their document published under the #pi whitepaper banner. It also serves as a reference for the overall format used in #pi whitepapers.

Whitepapers are published on #pi’s Product Information Portal (PIP): #link("https://pip.raspberrypi.com/categories/685-whitepapers-app-notes").

== Typesetting

This whitepaper illustrates how #pi whitepapers are formatted. Third-party whitepapers should follow this scheme.

All #pi whitepapers are written using the `Typst` markup. Typst is a typesetting tool designed for the sciences, and it provides all the standard features you may expect, including tables, images, equations, etc. It is a much easier markup to use than LaTeX. #link("https://typst.app/docs/")

Whitepapers produced by third parties should ideally use the `Typst` markup, though this is not essential. Please avoid word-processor-style documents or similar formats containing inline images, as converting these to `Typst` can be time-consuming.

When using `Typst`, images should be stored in a subfolder named `diagrams` to match #pi’s internal repository structure. 

The source `Typst` markup for this whitepaper is available on request from #trading. Please contact #link("applications@raspberrypi.com").

= Whitepaper template: #pi in your application/market

== Whitepaper title

_A compelling and clear title. Example: ‘Pioneering the future of industrial automation with Raspberry Pi Compute Module 4’._

The title should be concise and immediately convey the whitepaper's topic. Include key search terms related to your industry.

== Executive summary

_A brief, high-level overview of the whitepaper's contents. Approximately 150–250 words._

This section should serve as a standalone summary that can be read in about a minute. State the problem you faced, your solution using Raspberry Pi, and the key results or benefits achieved. Specify which Raspberry Pi product was used and explain why it was chosen. This section is critical for busy readers and for search engine optimisation (SEO).

 == The challenge

_Define the problem or market need that your company is addressing. What are the current limitations or inefficiencies?_

Describe the pain points in your industry. For example, "The demand for more cost-effective and scalable edge computing solutions in [your industry] has outpaced traditional hardware offerings, which are often expensive and inflexible." Use statistics or market trends to support your claims.

== The solution: harnessing the power of Raspberry Pi

_Detail your company's solution and how Raspberry Pi products are integral to it._

Explain how the features and capabilities of your Raspberry Pi device directly address the challenges you outlined. Be specific. Why did you choose Raspberry Pi 5, Compute Module 4, or Zero W? Highlight key attributes, such as:

- Cost-effectiveness: How does the price point allow for wider deployment or new business models?
- Performance: How does the processor, the RAM, or any other specification meet the application's needs?
- Ecosystem and community support: How have you benefited from Raspberry Pi’s extensive documentation and community support, as well as the availability of third-party accessories?
- Size and form factor: Is the compact size of a Compute Module or a Zero W crucial to your design?
- Flexibility and I/O: How do the GPIO pins, cameras, or other interfaces enable your specific functionality?
- Long-term availability: To what extent was Raspberry Pi’s long-term product support a key selling point for your industrial application? 

== Case studies

_Case study title. Example: ‘A case study in [your application]’. This should be a detailed, real-world example of your solution in action._

This is the core of the whitepaper. Walk the reader through a specific project or product. Structure it like a narrative:

- Background: Introduce the customer, their problem, and the project scope.
- Implementation: Describe the technical architecture. Use diagrams or block schematics if possible. Explain the software stack, including the operating system (Raspberry Pi OS), frameworks, and any custom code.
- Results and impact: Quantify the benefits. This is crucial for demonstrating value. Use metrics like:
 - Cost savings: "X% reduction in hardware costs."
 - Performance improvements: "X% increase in processing speed."
 - Time to market: "Reduced development time by X weeks/months."
 - Scalability: "Able to deploy thousands of units."
 - Testimonial: Include a quote from the customer to add credibility.

== Technical deep dive: architecture and design considerations

_Provide a more in-depth look at the technical aspects of your solution._

This section is for the engineers and technical decision-makers. It can be more detailed and may include:

- Component selection: Justify your choice of specific Raspberry Pi models and other supporting hardware (e.g. power management, I/O boards).
- Software stack: List the key software components and their roles (e.g. Python scripts, containerisation with Docker, data logging with InfluxDB).
- Power management: Discuss how you handle power efficiency and reliability.
- Security: Explain how you secured the device and its data.
- Challenges: Detail any specific technical hurdles you faced and how you solved them. This demonstrates your expertise.

== The future of [your application] with Raspberry Pi

_Look ahead to future trends and how your solution is positioned for growth._

Discuss the scalability of your solution and its future possibilities. How can using Raspberry Pi enable new features or business models? Mention emerging technologies like AI/ML at the edge, connectivity (5G, LoRaWAN), or advanced sensor integration.

== Conclusion

_Summarise the key takeaways and reiterate your value proposition._

Reinforce the main arguments: Raspberry Pi is not just an enthusiast/hobbyist board but a robust, cost-effective, and powerful platform for professional embedded solutions. End with a strong call to action, prompting the reader to contact your firm for consultation or more information.

== About [your company name]

_A brief description of your company._

Include your company's mission, expertise, and contact information. This is an important branding opportunity.

== SEO best practices and content strategy

- Keyword research: Identify keywords your target audience is searching for. Tools like Google Keyword Planner or Ahrefs can help. Examples include: ‘Raspberry Pi industrial’, ‘embedded Linux solutions’, ‘edge computing’, ‘[your market segment] automation’.
- Optimised titles and headings: Place primary keywords in the title and subheadings.
- Internal and external links: Link to relevant pages on your website (e.g. product pages, case studies) and to reputable external sources (e.g. Raspberry Pi's official documentation).
- Distribution strategy: Once published, promote the whitepaper on your website, social media channels (LinkedIn is a must), and industry-specific forums. Consider guest posting on blogs that serve your market segment.
- Gated content: Ask readers to provide their email address to download the whitepaper. This generates valuable leads for your sales and marketing teams.

By following this template, your firm can produce a professional, informative, and highly effective whitepaper that not only showcases your technical expertise but also drives business results.
