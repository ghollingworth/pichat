#import "@local/rpi-style:0.0.1": * 

#import "../../globalvars.typ": *

#show: rpi_whitepaper.with(
    title: "Extra PMIC features: Raspberry Pi 4, Raspberry Pi 5, and Compute Module 4",
    version_string: [Version 1.1],
    version_history: (
    [1.0], [16 Dec 2022], [Initial release],
    [1.1], [7 Jul 2024], [Fix typo in vcgencmd commands, added #pi-prefix 5 detail.],
    ), 
    platforms: ("Pi4", "Pi5", "CM4")
)

= Introduction

#pi-prefix 4/5 and #pi-prefix Compute Module 4 devices use a Power Management Integrated Circuit (PMIC) to supply the various voltages required by the various components on the PCB. They also sequence power-ups to ensure the devices are started in the correct order.

Over the duration of production of these models, a number of different PMIC devices have been used. All the PMICs have provided extra functionality over and above that of voltage supply:

- Two ADC channels that can be used on CM4.
 - On later revisions of #pi-prefix 4 and #pi-prefix 400, and all models of the #pi-prefix 5, the ADCs are wired up to the USB-C power connector on CC1 and CC2.
- An on-chip sensor that can be used to monitor the PMIC's temperature, available on #pi-prefix 4 and 5, and CM4.

This document describes how to access these features in software.

#warning[There is no guarantee that this functionality will be maintained in future versions of the PMIC, so it should be used with caution.]

You may wish to also refer to the following documents:

- #pi-prefix CM4 datasheet: #link("https://datasheets.raspberrypi.com/cm4/cm4-datasheet.pdf")
- #pi-prefix 4 reduced schematics: #link("https://datasheets.raspberrypi.com/rpi4/raspberry-pi-4-reduced-schematics.pdf")



This white paper assumes that the #pi is running #pios, and is fully up to date with the latest firmware and kernels.



= Using the features

Originally these features were only available by directly reading registers on the PMIC itself. However, the register addresses vary depending on the PMIC used (and therefore on the board revision), so #trading has provided a revision-agnostic way of getting this information.

This involves using the command line tool `vcgencmd`, which is a program that allows user space applications to access information stored in or accessed from the #trading device's firmware.

The available `vcgencmd` commands are as follows:

#table(
    columns: 2, 
    table.header([Command], [Description]),
    [`vcgencmd measure_volts usb_pd`], [Measures the voltage on the pin marked usb_pd (See CM4 IO schematic). CM4 only.],
    [`vcgencmd measure_volts ain1`], [Measures the voltage on the pin marked ain1 (See CM 4 IO schematic). CM4 only.],
    [`vcgencmd measure_temp pmic`], [Measures the temperature of the PMIC die. CM4 and #pi-prefix 4 and 5.],
)


All of these commands are run from the Linux command line.

== Using the features from program code

It is possible to use these `vcgencmd` commands programmatically if you need the information inside an application. In both Python and C, an OS call can be used to run the command and return the result as a string.

Here is some example Python code that can be used to call the `vcgencmd` command:

```python
import subprocess

# call vcgencmd and pass in a command
output = subprocess.check_output(['vcgencmd', 'measure_temp', 'pmic'])

# print the output of the command
print(output)
```

This code uses the Python `subprocess` module to call the `vcgencmd` command and pass in the `measure_temp` command targetting the `pmic`, which will measure the temperature of the PMIC die. The output of the command will be printed to the console.

Here is a similar example in C:

```c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main() {
  char *cmd = "vcgencmd measure_temp pmic";
  char buffer[128];
  FILE *pipe = popen(cmd, "r");

  if (!pipe)
  {
    perror("popen");
    return 1;
  }

  while (!feof(pipe))
  {
    if (fgets(buffer, 128, pipe) != NULL)
    {
      printf("%s", buffer);
    }
  }

  pclose(pipe);
  return 0;
}
```

The C code uses `popen` (rather than `system()`, which would also be an option), and is probably a little more verbose than it needs to be because it can handle multiple line results from the call, whereas `vcgencmd` returns only a single line of text.

#note[These code extracts are supplied only as examples, and you may need to modify them depending on your specific needs. For example, you may want to parse the output of the `vcgencmd` command to extract the temperature value for later use.]
