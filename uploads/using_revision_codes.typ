#import "@local/rpi-style:0.0.1": * 

#import "../../globalvars.typ": *

#show: rpi_whitepaper.with(
    title: "How to use Raspberry Pi Model Revision Codes",
    version_string: [Version 1.0],
    version_history: (
    [1.0], [1 Feb 2022], [Initial release],
    ), 
    platforms: ("AllSBC", "AllCM", "Pi400", "Pi500")
)

= Introduction

Each Raspberry Pi Model (excluding the Pico series) contains a revision code that identifies the model, board revision, processor type, installed memory, manufacturing location, plus some other bits of information.

This revision information can be used to identify boards accurately, and vary program operation accordingly. This whitepaper describes how to analyse the revision code, and introduces some best practices to use when using revision information.

This whitepaper assumes that the #pi is running #pios, and is fully up to date with the latest firmware and kernels.

= The Revision Code

There have been two versions of revision code format since the #pi was original released. The older style revision code contains a lot less information, and only applies to the original Model A, B, A+, B+ and CM1. All later boards now have the new style revision codes. This whitepaper will only cover use of the new style revision codes. For details on the older codes, see our online documentation. #link("https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#old-style-revision-codes")

The new style revision codes are a bit pattern contained in a 32-bit value. From the command line you can interrogate the operating system for the revision code using:

```
cat /proc/cpuinfo
```

This displays quite a lot of information, but the revision code can be found three lines from the end. Adding a `grep` to the command will pull out just the revision code.

```
$cat /proc/cpuinfo | grep Revision
Revision      : c03111
```

The bit pattern represents the following:

#let bit_table(..cells) = {

    // Header row text is bold
    show table.cell: set text(size: 7pt, weight: "light")
    show table: set par(justify: false)

    table(
        stroke: (x: 0.1pt, y: 0.1pt),
        columns:2,
        row-gutter: 1pt,
        fill: (x, y) => { luma(100%) },
        ..cells
    )
}

#table(
    columns: 3, 
    table.header([Bits], [Represents], [Options]),
    [31], [Overvoltage], 
        [#bit_table([0], [Overvoltage allowed ], [1], [Overvoltage disallowed])],
    [30], [OTP Program], 
        [#bit_table([0], [OTP programming allowed ], [1], [OTP programming disallowed])],
    [29], [OTP Read], 
        [#bit_table([0], [OTP reading allowed ], [1], [OTP reading disallowed])],
    [26-28], [Unused], [], 
    [25], [Warranty bit], 
        [#bit_table([0], [Warranty is intact], [1], [Warranty has been voided by overclocking])],
    [24], [Unused], [],
    [23], [New flag], 
        [#bit_table([0], [Old style revision code], [1], [New style revision code])],
    [20-22], [Memory size],
        [#bit_table(
        [0], [256MB],
        [1], [512MB],
        [2], [1GB],
        [3], [2GB],
        [4], [4GB],
        [5], [8GB])],
    [16-19], [Manufacturer], 
        [#bit_table(
        [0], [Sony UK], 
        [1], [Egoman],
        [2], [Embest],
        [3], [Sony Japan],
        [4], [Embest],
        [5], [Stadium])
         ],

    [12-15], [Processor], 
        [#bit_table(
        [0], [BCM2835],
        [1], [BCM2836],
        [2], [BCM2837],
        [3], [BCM2711])
        ],
    [4-11], [Type], 
        [#bit_table(
        [0], [A], 
        [1], [B],
        [2], [A+],
        [3], [B+],
        [4], [2 B],
        [5], [Alpha (early prototype)],
        [6], [CM 1],
        [8], [3B],
        [9], [Zero],
        [a], [CM3],
        [c], [Zero W],
        [d], [3B+],
        [e], [3A+],
        [f], [Internal use only],
        [10], [CM 3+],
        [11], [4B],
        [12], [Zero 2 W],
        [13], [400],
        [14], [CM 4],
        [15], [CM 4s])
        ],
    [0-3], [Revision], [0, 1, 2, etc.],
)


In our example above, we have a hexadecimal revision code of `c03111`. Converting this to binary we get `1 100 0000 0011 00010001 0001`. Spaces have been inserted to show the borders between each section of the revision code, according to the above table.

So, starting from the lowest order bits, the bottom four (0-3) are the board revision number, so this board has a revision of 1.1.  The next four bits (4-11) are the board type, in this case binary `b10001`, hex `0x11`, so this is a #pi 4B. Using the same process, we can determine that the processor is the BCM2711, the board was manufactured by Sony UK, and it has 4GB of RAM.


== Getting the revision code in your program

Obviously there are so many programming languages out there that it's not possible to give examples for all of them, but here are two quick examples for `C` and `Python`. Both these examples use a system call to run a bash command that gets the `cpuinfo` and pipes the result to `awk` to recover the required revision code. They then use bit operations to extract the `New`, `Model`, and `Memory` fields from the code.


````
#include <stdio.h>
#include <stdlib.h>

int main( int argc, char *argv[] )
{
  FILE *fp;
  char revcode[32];

  fp = popen("cat /proc/cpuinfo | awk '/Revision/ {print $3}'", "r");
  if (fp == NULL)
    exit(1);
  fgets(revcode, sizeof(revcode), fp);
  pclose(fp);

  int code = strtol(revcode, NULL, 16);
  int new = (code >> 23) & 0x1;
  int model = (code >> 4) & 0xff;
  int mem = (code >> 20) & 0x7;

  if (new && model == 0x11 && mem >= 3)  // Note, 3 in the mem field is 2GB
     printf("We are a 4B with at least 2GB of RAM!\n" );

  return 0;
}
````

And the same in Python:

```
import subprocess

cmd = "cat /proc/cpuinfo | awk '/Revision/ {print $3}'"
revcode = subprocess.check_output(cmd, shell=True)

code = int(revcode, 16)
new = (code >> 23) & 0x1
model = (code >> 4) & 0xff
mem = (code >> 20) & 0x7

if new and model == 0x11 and mem >= 3 : # Note, 3 in the mem field is 2GB
    print("We are a 4B with at least 2GB RAM!")
```

== Using the revision code

#trading advise against using the revision code as a whole (`c03111`). For example, one scheme for device identification might be to have a list of all possible revision codes in a program, and compare the detected code with this list to determine if features are enabled. However, this mechanism will break when a new board revision comes out, or if the production location changes. #trading occasionally silently release newer version of the #pi 4B and these new boards get new board revision numbers. This changes the overall revision code and this new revision code will not be in the programmed list. The program will now reject the unrecognised code, and perhaps abort, even though revisions of the same board type are always backwards compatible. A new version of the software would need to be released with the new revision code added to the list, which can be a maintenance issue.

Another example might be if a program is only intended to work on devices with 2GB or RAM or more. The naive approach is to look at the list of revision codes for models that have 2GB of RAM or more, and build that list in to the code. But of course, this breaks as soon as a new board revision is released, or the boards are manufactured at a different location.

A better mechanism is to use the individual fields from the revision code e.g. board type or memory, for any required identification. If a program is only be supported on a #pi 4B's, only the board type field needs to be checked. Alternatively, it may be necessary to restrict code to 4B devices with 2GB of RAM or more, so simply look at those two fields to determine whether to allow code to run.

In short, the advice is to ignore those fields that are not relevant to determining whether code will run, which ultimately means do not use a list of complete revision codes for identification.

The examples in the previous section use the recommended approach. They pull out the board type and memory size from the revision code, and use them to determine whether or not they are a 4B with 2GB or more of RAM.

One further thing to note, always check bit 23, the 'New' flag, to ensure that the revision code is the new version before checking any other fields. The examples also do this.