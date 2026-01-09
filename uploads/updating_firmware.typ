#import "@local/rpi-style:0.0.1": * 

#import "../../globalvars.typ": *

#show: rpi_whitepaper.with(
    title: "Updating Raspberry Pi Firmware",
    version_string: [Version 1.1],
    version_history: (
        "1.0", "24 May 2021", "Initial release", 
        "1.1", "27 April 2022", "Copy edit, public release",
    ),
    platforms: ("AllSBC", "AllCM", "Pi400", "Pi500")
)


= Introduction

In some circumstances it may be necessary to update the VideoCore firmware in a #pi-prefix operating system (OS) image without going through the normal upgrade process. This whitepaper documents how to use the normal upgrade process, and also gives information on how to bypass the standard update process if it is not suitable.

= Why you might need new firmware

The firmware on #pi-prefix devices is upgraded over time. Possible reasons for an upgrade might be:

- Bug fixes
- Support for new processors (e.g. moving from #pi-prefix 3 to #pi-prefix 4)
- Support for new memory chips
- Support for new revisions of the printed circuit board (PCB)

It is not possible to make the firmware forward compatible, i.e. to be able to cope with future changes in hardware; however, every effort is made to make the firmware backward compatible, in that the latest firmware should always work on older products without causing any regressions.

For example, there are various revisions of the #pi-prefix 4 PCB. The latest versions require the latest firmware to work correctly, in part due to changes in the power management chips on the PCB, which require a different startup sequence. If you use #pi-prefix 4s in a third-party product, you could find that when you take delivery of a new batch of #pi-prefix 4 devices they are a newer revision, and your standard distribution, with older firmware, no longer works correctly.


= The standard upgrade process

There are standard commands you can use in the #pios (and many third-party OS distributions) that will upgrade the system and any firmware. #trading recommends using these processes wherever possible.

To upgrade the Linux kernel and all #pi-prefix specific firmware to the latest release version, the following commands should be used:

```
sudo apt update
sudo apt full-upgrade
```

Note that this process will not upgrade between major OS versions. While it is possible to implement a full upgrade between major versions in place, #trading does not recommend this -- it is not a tested procedure due to the huge number of changes involved. In this case we recommend starting afresh, installing the OS from scratch on a new Secure Digital (SD) card using #pi-prefix Imager. You will need to reinstall all the required software in a new installation.


= Updating only the firmware

Sometimes, going through the standard upgrade procedure may not be possible. For example, you may have a customised distribution with no update facilities, or that cannot be upgraded without causing further issues.
In these circumstances, and possibly others, you will need to update the firmware files in the distribution manually.

You can download the firmware files from the following location:

#link("https://github.com/raspberrypi/firmware/archive/refs/heads/stable.zip")

This zip file contains a number of items, but the ones we are interested in at this stage are in the boot folder.
The firmware files have names of the form `start.elf`, and their associated support files are `fixup.dat`.

The basic principle is to copy the required start and fixup files from this zip file to replace the same named files in the destination OS image. The exact process will depend on how the OS has been set up, but this is an example of how it would be done for a #pios image:

- Extract or open the zip file so you can access the required files.
- Open up the `boot` folder in the destination OS image (this could be on an SD card, or a disk-based copy).
- Determine which `start.elf` and `fixup.dat` files are present in the destination OS image.
- Copy those files from the zip archive to the destination image.

The image should now be ready for use on the latest #trading hardware.

