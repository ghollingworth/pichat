#import "@local/rpi-style:0.0.1": * 

#import "../../globalvars.typ": *

#show: rpi_whitepaper.with(
    title: "Configuring the Compute Module 4",
    version_string: [Version 1.2],
    version_history: (
    [1.0], [7 September 2021], [Initial release],
    [1.1], [27 April 2022], [Copy edit, public release],
    [1.2], [17 December 2022], [Clarification on HDMI blanking],
    ),
    platforms: ("CM4")
)

= Introduction

The #pi-prefix Compute Module 4 (CM 4) is available in a number of different hardware configurations. Sometimes it may be necessary to disable some of these features when they are not required. For example, if a particular configuration of the module is not available, you may have been supplied with one with extra features that must be disabled for your use case.

Disabling features also results in power saving, which can be important when CM 4 devices are used in battery environments or similar.

At the time of writing the #pi-prefix CM 4 is available with or without wireless/Bluetooth; with 1, 2, 4, or 8GB of random-access memory (RAM); and with 0, 8, 16, or 32GB of on-board embedded Multi-Media Card (eMMC) flash storage, which means there are a total of 32 different combinations available.

This document describes how to disable various hardware interfaces, in both hardware and software, and how to reduce the amount of memory used by the Linux operating system (OS).

== Usage chart

This chart shows which variants can be used to replace other variants using the appropriate modifications as described below. To read the chart, select the device you have from the top axis, and read down to determine which other devices this one can replace.

#note[It is not possible to use a #pi-prefix CM 4 with eMMC on a carrier that is designed for use with off-board eMMC or a Secure Digital (SD) card. This is because the SD input/output pins used to connect to any SD card slot are used to connect the on-board eMMC.]

#table(
    columns: 9,
    stroke: (x: 0.4pt, y: 0.4pt),
    align: left,
    fill: (x, y) => if y == 0 or x == 0{ luma(85%) },
    table.header(
    [CM4 variant], [1GB], [2GB], [4GB], [8GB], [1GB+WLAN], [2GB+WLAN], [4GB+WLAN], [8GB+WLAN]
    ),
    [1GB], [#sym.checkmark], [#sym.checkmark], [#sym.checkmark], [#sym.checkmark], [#sym.checkmark], [#sym.checkmark], [#sym.checkmark], [#sym.checkmark],
    [2GB], [], [#sym.checkmark], [#sym.checkmark], [#sym.checkmark], [], [#sym.checkmark], [#sym.checkmark], [#sym.checkmark],
    [4GB], [], [#sym.checkmark], [#sym.checkmark], [#sym.checkmark], [], [], [#sym.checkmark], [#sym.checkmark],
    [8GB], [], [], [], [#sym.checkmark], [], [], [], [#sym.checkmark],
    [1GB+WLAN], [], [], [], [], [#sym.checkmark], [#sym.checkmark], [#sym.checkmark], [#sym.checkmark],
    [2GB+WLAN], [], [], [], [], [], [#sym.checkmark], [#sym.checkmark], [#sym.checkmark],
    [4GB+WLAN], [], [], [], [], [], [], [#sym.checkmark], [#sym.checkmark],
    [8GB+WLAN], [], [], [], [], [], [], [], [#sym.checkmark]
)


= Configuration

== Disabling wireless and Bluetooth

=== Disabling at the hardware level

If you are developing your own #pi-prefix CM 4 carrier board then this configuration can be done at the hardware level by pulling certain pins to ground. This is the best approach, and also allows for switching the devices on and off via a mechanical switch, e.g. a key switch.

Full details of all the pins can be found in Chapter 4 of the #pi-prefix CM 4 datasheet, but in brief:

#table(
    columns: 3,
    stroke: (x: 0.4pt, y: 0.4pt),
    align: left,
    table.header(
    [Pin], [Signal], [Description],
    ),
    [89], [WL_nDisable], [Can be left floating; if driven low the wireless interface will be disabled. Internally pulled up via 1.8K to CM4_3.3V],
    [91], [BT_nDisable], [Can be left floating; if driven low the Bluetooth interface will be disabled. Internally pulled up via 1.8K to CM4_3.3V]
)


#note[Disabling the wireless and Bluetooth interfaces will save a small amount of power, so can be useful in low-power situations.]

=== Disabling using software overlays

You can also disable the wireless and Bluetooth interfaces at the software level. There are number of options here.

There are two device tree overlays that control Bluetooth and wireless. These are documented in full in the `/boot/overlays/README` file on any #pi-prefix, but the important information is reproduced here. Add the appropriate `dtoverlay` options to the `config.txt` file in the boot folder.

#table(
    columns: (auto, auto, auto),
    stroke: (x: 0.4pt, y: 0.4pt),
    align: (left, left, left),
    table.header(
    [Name], [config.txt], [Description],
    ),
    [disable-wifi], [dtoverlay=disable-wifi], [Disable on-board wireless on #pi-prefix 3B, 3B+, 3A+, 4B, Zero W, and CM 4],
    [disable-bt], [dtoverlay=disable-bt], [Disable on-board Bluetooth on #pi-prefix 3B, 3B+, 3A+, 4B, Zero W, and CM 4],
)


=== Extra security for disabling in software

Although the wireless or Bluetooth interface will be turned off on boot when using the device tree overlay mechanism, in some circumstances, with the right access to the device (e.g. root access), it would be possible to turn these back on again.

One robust way to prevent any use of the wireless and Bluetooth interfaces is to remove from the system the firmware that is loaded to the wireless/Bluetooth combo chip. Without this firmware, the wireless and Bluetooth interfaces are entirely unable to start up.

The firmware for the #pi-prefix CM 4 can be found in `/lib/firmware/brcm/brcmfmac43455-sdio`. Simply deleting this file will prevent the wireless/Bluetooth chip from starting up.


== Reducing the memory available to the OS

Although unlikely, there may be situations where you need to reduce the amount of RAM available to the OS, i.e. to make a 4GB device look like a 1GB device. This can be done by altering the Linux command line as follows:

- Edit the `cmdline.txt` file in the `boot` folder with an appropriate text editor
- Add `mem=nn[KMG]` to the end of the command line, where K=kilobytes, M=megabytes, and G=gigabytes

So, to set the maximum amount of memory available to the Linux kernel to 1GB, add `mem=1G` to the command line.

#note[The kernel requires the command line to be one single line of text, so ensure you do not inadvertently add any carriage returns.]

== Disabling the High-Definition Multimedia Interface (HDMI)

Although the CM 4's power requirements are automatically reduced by simply not having anything attached to the HDMI ports, a very small additional saving can be made by ensuring that the HDMI PHY (physical layer) is not turned on.

Add the following to the `config.txt` file: `hdmi_blanking=2`

#note[This option is only available when using the legacy or FKMS graphics stack. It is not available when using the KMS graphics driver.]


== Disabling the Universal Serial Bus (USB) interface

Depending on the software version, the USB interface can be enabled or disabled by default. To force the USB interface to off, add the following to the `config.txt` file: `otg_mode=0`

