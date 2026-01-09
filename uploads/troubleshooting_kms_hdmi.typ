#import "@local/rpi-style:0.0.1": * 

#import "../../globalvars.typ": *

#show: rpi_whitepaper.with(
    title: "Troubleshooting KMS HDMI output",
    version_string: [Version 1.1],
    version_history: (
    [1.0], [3 Jan 2023], [Initial release],
    [1.1], [2 Oct 2023], [Update to include #pi-prefix 5 information],
    ), 
    platforms: ("AllSBC", "AllCM", "Pi400", "Pi500")
)

= Introduction

With the introduction of the KMS (Kernel Mode Setting) graphics driver, #trading is moving away from legacy firmware control of the video output system and towards a more open source graphics system. However, this has come with its own set of challenges. This document is intended to help with any issues that might arise when moving to the new system.

This whitepaper assumes that #pi is running #pios, and is fully up to date with the latest firmware and kernels.

== Terminology

*DRM:* Direct Rendering Manager, a subsystem of the Linux kernel used to communicate with graphics processing units (GPUs). Used in partnership with FKMS and KMS.

*DVI:* A predecessor to HDMI, but without the audio capabilities. HDMI to DVI cables and adapters are available to connect a #pi-prefix device to a DVI-equipped display.

*EDID:*  Extended Display Identification Data. A metadata format for display devices to describe their capabilities to a video source. The EDID data structure includes the manufacturer name and serial number, product type, physical display size, and the timings supported by the display, along with some less useful data. Some displays can have defective EDID blocks, which can cause problems if those defects are not handled by the display system.

*FKMS (vc4-fkms-v3d):* Fake Kernel Mode Setting. While the firmware still controls the low-level hardware (for example, the High-Definition Multimedia Interface (HDMI) ports, the Display Serial Interface (DSI), etc), standard Linux libraries are used in the kernel itself. FKMS is used by default in Buster, but is now deprecated in favour of KMS in Bullseye. Bookworm does not support Legacy or FKMS graphics stacks.

*HDMI:* High-Definition Multimedia Interface is a proprietary audio/video interface for transmitting uncompressed video data and compressed or uncompressed digital audio data.

*HPD:* Hotplug detect. A physical wire that is asserted by a connected display device to show it is present.

*KMS:* Kernel Mode Setting; see #link("https://www.kernel.org/doc/html/latest/gpu/drm-kms.html") for more details. On #pi, `vc4-kms-v3d` is a driver that implements KMS, and is often referred to as "the KMS driver".

*Legacy graphics stack:* A graphics stack wholly implemented in the VideoCore firmware blob exposed by a Linux framebuffer driver. Until recently, the legacy graphics stack has been used in the majority of #trading devices; it has now been replaced by KMS/DRM.

= The HDMI system and the graphics drivers

#pi-prefix devices use the HDMI standard, which is very common on modern LCD monitors and televisions, for video output. #pi-prefix 3 (including #pi-prefix 3B+) and earlier devices have a single HDMI port, which is capable of 1920 × 1200 \@60Hz output using a full-size HDMI connector. #pi-prefix 4 and 5 have two micro HDMI ports and are capable of 4K output on both ports. Depending on setup, the HDMI 0 port on #pi-prefix 4 is capable of up to 4Kp60, but when using two 4K output devices you are limited to p30 on both devices. #pi-prefix 5 is capable of 4Kp60 on both ports simultaneously.

The graphics software stack, irrespective of version, is responsible for interrogating attached HDMI devices for their properties and setting up the HDMI system appropriately. Legacy and FKMS stacks both use the firmware in the VideoCore graphics processor to check for HDMI presence and properties. By contrast, KMS uses an entirely open source, ARM-side implementation. This means the code bases for the two systems are entirely different, and in some circumstances this can result in different behaviour between the two approaches.

HDMI and DVI devices identify themselves to the source device using a piece of metadata called an EDID block. This is read by the source device from the display device via an I2C connection, and it is entirely transparent to the end user as it is done by the graphics stack. The EDID block contains a great deal of information, but it is primarily used to specify which resolutions the display supports, so #pi-prefix can be set up to output an appropriate resolution.

== How HDMI is dealt with during booting

When first powered on, #pi goes through several processing stages, known as boot stages:

- The first stage, the ROM-based bootloader, starts up the VideoCore GPU.
- The second-stage bootloader (this is `bootcode.bin` on the SD card on devices before #pi-prefix 4, and in SPI EEPROM on #pi-prefix 4 and 5):
 - On #pi-prefix 4 and 5, the second-stage bootloader will start up the HDMI system, interrogate the display for possible modes, and then set up the display appropriately. At this point, the display is used to provide basic diagnostic data.
 - The bootloader diagnostic display (07 Dec 2022 onwards) will display the status of any attached displays (whether Hotplug Detect (HPD) is present, and whether an EDID block was recovered from the display).
- The VideoCore firmware (`start.elf`) is loaded and run. This will take over control of the HDMI system, read the EDID block from any attached displays, and show the rainbow screen on those displays.
- The Linux kernel boots
 - During kernel boot, KMS will take over control of the HDMI system from the firmware. Once again the EDID block is read from any attached displays, and this information is used to set up the Linux console and desktop.

= Possible problems and symptoms

The most common failure symptom experienced when moving to KMS is an initially good boot, with the bootloader screen and then the rainbow screen appearing, followed after a few seconds by the display going black and not coming back on. The point at which the display goes black is the point during the kernel booting process when the KMS driver takes over running the display from the firmware. The #pi is currently running in all respects except for the HDMI output, so if SSH is enabled then you should be able to log in to the device by that route. The green SD card access LED will usually flicker occasionally.

It is also possible that you will see no HDMI output at all: no bootloader display, and no rainbow screen. This can usually be attributed to a hardware fault.

= Diagnosing the fault

== No HDMI output at all

It is possible that the device has not booted at all, but this is outside of the remit of this white paper.

Assuming that the observed behaviour is a display problem, the lack of HDMI output during any part of the booting process is usually due to a hardware fault. There are several possible options:

- Defective HDMI cable
 - Try a new cable. Some cables, especially very cheap ones, may not contain all the required communication lines (e.g. hotplug) for #pi to detect the display successfully.
- Defective HDMI port on #pi
 - If you are using a #pi-prefix 4 or 5, try the other HDMI port.
- Defective HDMI port on the monitor
 - Sometimes the HDMI port on a monitor or TV can wear out. Try a different port if the device has one.
 - Rarely, a display device may only provide EDID data when turned on, or when the correct port is selected. To check, make sure that the device is on and that the correct input port is selected.
- Display device is not asserting the hotplug detect line

== Initial output, then the screen goes black

If the display comes up but then goes off during Linux kernel boot, there are several possible causes, and these are usually related to a problem reading the EDID from the display device.

As can be seen from the section above dealing with the boot sequence, the EDID is read at several different points during the boot process, and each of these reads is done by a different piece of software. The final read, when KMS takes over, is carried out by unaltered upstream Linux kernel code, and this does not handle defective EDID formats as well as the earlier firmware software. This is why the display can stop working correctly once KMS takes over.

There are several ways to confirm whether KMS is failing to read the EDID, and two of these are as follows.

=== Check the bootloader diagnostic screen (#pi-prefix 4 and 5 only)

#note[Bootloader diagnostics require a recent bootloader. You can upgrade to the latest version using these instructions: #link("https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#updating-the-bootloader]")]

Remove the SD card and reboot the #pi. Press ESC on the `Install OS` screen, and the diagnostic screen should appear on the display device. There should be a line on the display that starts with `display:` — for example:

```
display: DISP0: HDMI HPD=1 EDID=ok #2 DISP1:   HPD=0 EDID=none #0
```

This output from a #pi-prefix 4 shows that the system detected an HDMI display on HDMI port 0, the hotplug detect is asserted, and the EDID was read OK. Nothing was found on HDMI port 1.

=== Check whether the KMS system detected an EDID

To check this you will need to log in to the #pi-prefix device over SSH from a different computer. SSH can be enabled when creating an SD card image with Raspberry Pi Imager, using the Advanced Settings options. Enabling SSH on an SD card that has already been imaged is a little more complicated: you will need to use another computer to add a file named `ssh` to the boot partition. Replace the SD card in the original #pi and power it up. This should enable SSH, with an IP address allocated by DHCP.

Once logged in, type the following at the terminal prompt to display the contents of any EDID detected (you may need to change `HDMI-A-1` to `HDMI-A-2` depending on which HDMI port on the #pi the display device is connected to):

```
cat /sys/class/drm/card?-HDMI-A-1/edid
```

If there are no folders named `card?-HDMI-A-1` or similar, then is likely that no EDID could be read from the display device.

#note[In the case where the EDID is read successfully, there is a useful virtual file in the same folder, called `modes`, which when displayed shows all the possible modes the EDID claims the device supports.]


= Mitigations

== Hotplug detect failure

If both the firmware and KMS fail to find an attached monitor, it could be a hotplug detection failure — i.e., the #pi does not know a device has been plugged in, so it doesn't check for an EDID. This could be caused by a bad cable, or a display device that does not assert hotplug correctly.

You can force a hotplug detect by altering the kernel command line file (`cmdline.txt`) that is stored in the boot partition of a #pios SD card. You can edit this file on another system, using whatever editor you prefer. Add the following to the end of the `cmdline.txt` file:

```
video=HDMI-A-1:1280x720@60D
```

If you are using the second HDMI port, replace `HDMI-A-1` with `HDMI-A-2`. You can also specify a different resolution and frame rate, but make sure you choose ones that the display device supports.

#note[Documentation on the kernel command line settings for video can be found here: #link("https://www.kernel.org/doc/Documentation/fb/modedb.txt]")]

#warning[Older graphics stacks supported the use of a `config.txt` entry to set hotplug detect, but at the time of writing this has not been implemented on KMS. It may be supported in future firmware releases. The `config.txt` entry is `hdmi_force_hotplug`, and you can specify the specific HDMI port that the hotplug applies to using either `hdmi_force_hotplug:0=1` or `hdmi_force_hotplug:1=1`. Note that the nomenclature for KMS refers to the HDMI ports as 1 and 2, while #pi uses 0 and 1.]

== EDID problems

A minority of display devices are incapable of returning an EDID if they are turned off, or when the wrong AV input is selected. This can be an issue when the #pi-prefix and the display devices are on the same power strip, and the #pi-prefix device boots faster than the display. With devices like this, you may need to provide an EDID manually.

Even more unusually, some display devices have EDID blocks that are badly formatted and cannot be parsed by the KMS EDID system. In these circumstances, it may be possible to read an EDID from a device with a similar resolution and use that.

In either case, the following instructions set out how to read an EDID from a display device and configure KMS to use it, instead of KMS trying to interrogate the device directly.


=== Copying an EDID to a file

Creating a file containing EDID metadata from scratch is not usually feasible, and using an existing one is much easier. It is generally possible to obtain an EDID from a display device and store it on the #pi's SD card so it can be used by KMS instead of getting an EDID from the display device. The easiest option here is to ensure that the display device is up and running and on the correct AV input and that the #pi has started up the HDMI system correctly. From the terminal, you can now copy the EDID to a file with the following command:

```
sudo cp /sys/class/drm/card?-HDMI-A-1/edid /lib/firmware/myedid.dat
```

=== Finding an EDID using a pre-Bookworm OS release

On #pios releases before Bookworm, there is a tool called `tvservice` that can be used to dump an EDID from the display device when using the legacy graphics stack.

#note[As #pi-prefix 5 only supports Bookworm and newer releases, this process is not available on that model.]

You need to boot the device in a non-KMS mode that does succeed in booting to the desktop or console, then copy the EDID that the firmware will (hopefully) successfully read to a file.

- Boot to legacy graphics mode.
 - Edit `config.txt` in the boot partition, making sure to run your editor using `sudo`, and change the line that says `dtoverlay=vc4-kms-v3d` to `#dtoverlay=vc4-kms-v3d`.
 - Reboot.
- The desktop or login console should now appear.
 - Using the terminal, copy the EDID from the attached display device to a file with the following command:

```
tvservice -d myedid.dat
sudo mv myedid.dat /lib/firmware/
```

=== Using a file-based EDID instead of interrogating the display device

Edit `/boot/cmdline.txt`, making sure to run your editor using `sudo`,  and add the following to the kernel command line:

```
drm.edid_firmware=myedid.dat
```

You can apply the EDID to a specific HDMI port as follows:

```
drm.edid_firmware=HDMI-A-1:myedid.dat
```

If necessary, boot back into KMS mode by doing the following:

- Edit `config.txt` in the boot partition, making sure to run your editor using `sudo`, and change the line that says `#dtoverlay=vc4-kms-v3d` to `dtoverlay=vc4-kms-v3d`.
- Reboot.

#note[If you use a file-based EDID, but still have problems with hotplug, you can force hotplug detection by adding the following to the kernel command line: `video=HDMI-A-1:D`.]