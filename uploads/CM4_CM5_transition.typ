#import "@local/rpi-style:0.1.0": *

#import "../../globalvars.typ": *

#show: rpi_whitepaper.with(
    title: [Transitioning~from Compute~Module~4 to Compute~Module~5],
    release: [1],
    version_history: (
     [1], [Mar 2025], [Initial release. This document is heavily based on the 'Raspberry Pi Compute Module 5 forward guidance' whitepaper.],
    ), 
    platforms: ("CM4", "CM5"),
)

= Introduction

#cm 5 continues the #pi tradition of taking the latest flagship #pi computer and producing a small, hardware-equivalent product suitable for embedded applications. #cm 5 has the same compact form factor as #cm 4 but provides higher performance and an improved feature set. There are, of course, some differences between #cm 4 and #cm 5, and these are described in this document.

#note[For the few customers who are unable to use #cm 5, #cm 4 will stay in production until at least 2034.]

The #cm 5 datasheet should be read in conjunction with this whitepaper. #link("https://datasheets.raspberrypi.com/cm5/cm5-datasheet.pdf").

= Main features

#cm 5 has the following features:

- Quad-core 64-bit Arm Cortex-A76 (Armv8) SoC clocked \@ 2.4GHz
- 2GB, 4GB, 8GB, or 16GB LPDDR4#sym.times SDRAM 
- On-board eMMC flash memory; 0GB (Lite model), 16GB, 32GB, or 64GB options
- 2#sym.times USB 3.0 ports
- 1 Gb Ethernet interface
- 2#sym.times 4-lane MIPI ports supporting both DSI and CSI-2
- 2#sym.times HDMI® ports able to support 4Kp60 simultaneously
- 28#sym.times GPIO pins
- On-board test points to simplify production programming
- Internal EEPROM on the bottom to improve security
- On-board RTC (external battery via 100-pin connectors)
- On-board fan controller
- On-board Wi-Fi®/Bluetooth (depending on SKU)
- 1-lane PCIe 2.0 #super("1")
- Type-C PD PSU support

#note[Not all SDRAM/eMMC configurations are available. Please check with our sales team.]

#super("1") In some applications PCIe Gen 3.0 is possible, but this is not officially supported.

== #cm 4 compatibility

For most customers, #cm 5 will be pin-compatible with #cm 4.

The following features have been removed/altered between the #cm 5 and #cm 4 models:

- Composite video
 - The composite output available on #pi-prefix 5 is NOT routed out on #cm 5 
- 2-lane DSI port
 - There are two 4-lane DSI ports available on #cm 5, muxed with the CSI ports for a total of two
- 2-lane CSI port
 - There are two 4-lane CSI ports available on #cm 5, muxed with the DSI ports for a total of two
- 2#sym.times ADC inputs

=== Memory

#cm 4's maximum memory capacity is 8GB, whereas #cm 5 is available in a 16GB RAM variant.

Unlike #cm 4, #cm 5 is NOT available in a 1GB RAM variant.

=== Analogue audio

Analogue audio can be muxed onto GPIO pins 12 and 13 on #cm 5, in the same way as on #cm 4. 

Use the following device tree overlay to assign analogue audio to these pins:

#pagebreak()

```bash 
dtoverlay=audremap
# or
dtoverlay=audremap,pins_12_13
```

Due to an errata on the RP1 chip, GPIO pins 18 and 19, which could be used for analogue audio on #cm 4, are not connected to the analogue audio hardware on #cm 5 and cannot be used.

#note()[The output is a bitstream rather than a genuine analogue signal. Smoothing capacitors and an amplifier will be needed on the IO board to drive a line-level output.]


=== Changes to USB boot

USB booting from a flash drive is only supported via the USB 3.0 ports on pins 134/136 and 163/165.

#cm 5 does NOT support USB host boot on the USB-C port.

Unlike the BCM2711 processor, the BCM2712 does not have an xHCI controller on the USB-C interface, just a DWC2 controller on pins 103/105. Booting using `RPI_BOOT` is done via these pins.

=== Change to module reset and power-down mode

I/O pin 92 is now set to `PWR_Button` rather than `RUN_PG` — this means you need to use a `PMIC_EN` to reset the module.

The `PMIC_ENABLE` signal resets the PMIC, and therefore the SoC. You can view `PMIC_EN` when it's driven low and released, which is functionally similar to driving `RUN_PG` low on #cm 4 and releasing it.

#cm 4 has the added benefit of being able to reset peripherals via the nEXTRST signal. #cm 5 will emulate this functionality on CAM_GPIO1.

`GLOBAL_EN` / `PMIC_EN` are wired directly to the PMIC and bypass the OS completely. On #cm 5, use `GLOBAL_EN` / `PMIC_EN` to execute a hard (but unsafe) shutdown.

If there is a need, when using an existing IO board, to retain the functionality of toggling I/O pin 92 to start a hard reset, you should intercept the `PWR_Button` at the software level; rather than having it invoke a system shutdown, it can be used to generate a software interrupt and, from there, to trigger a system reset directly (e.g. write to `PM_RSTC`).



Device tree entry handling a power button (arch/arm64/boot/dts/broadcom/bcm2712-rpi-cm5.dtsi):

```bash
pwr_key: pwr {
                        label = "pwr_button";
                        // linux,code = <205>; // KEY_SUSPEND
                        linux,code = <116>; // KEY_POWER
                        gpios = <&gio 20 GPIO_ACTIVE_LOW>;
                        debounce-interval = <50>; // ms
                };

```

Code 116 is the standard event code for the kernel's `KEY_POWER` event, and there is a handler for this in the OS.

#pi recommends using kernel watchdogs if you are concerned about the firmware or the OS crashing and leaving the power key unresponsive. ARM watchdog support is already present in #pios via the device tree, and this can be customised to individual use cases. In addition, a long press/pull on the `PWR_Button` (7 seconds) will cause the PMIC's built-in handler to shut down the device. 

== Detailed pinout changes

CAM1 and DSI1 signals have become dual-purpose and can be used for either a CSI camera or a DSI display.

The pins previously used for CAM0 and DSI0 on #cm 4 now support a USB 3.0 port on #cm 5.

The original #cm 4 `VDAC_COMP` pin is now a VBUS-enabled pin for the two USB 3.0 ports, and is active high.

#cm 4 has extra ESD protection on the HDMI, SDA, SCL, HPD, and CEC signals. This is removed from #cm 5 due to space limitations. If required, ESD protection can be applied to the baseboard, although #trading does not regard it as essential.

#table(
    columns: 4,
    table.header([Pin], [CM4], [CM5], [Comment]),
    [16], [SYNC_IN], [Fan_tacho], [Fan tacho input],
    [19], [Ethernet nLED1], [Fan_pwn], [Fan PWM output],
    [76], [Reserved], [VBAT], [RTC battery. Note: There will be a constant load of a few uA, even if CM5 is powered.],
    [92], [RUN_PG], [PWR_Button], [Replicates the power button on #pi-prefix 5. A short press signals that the device should wake up or shut down. A long press forces shutdown.],
    [93], [nRPIBOOT], [nRPIBOOT], [If the `PWR_Button` is low, this pin will also be set low for a short time after power-up.],
    [94], [AnalogIP1], [CC1], [This pin can connect to the CC1 line of a Type-C USB connector to enable the PMIC to negotiate 5A.],
    [96], [AnalogIP0], [CC2], [This pin can connect to the CC2 line of a Type-C USB connector to enable the PMIC to negotiate 5A.],
    [99], [Global_EN], [PMIC_ENABLE], [No external change.],
    [100], [nEXTRST], [CAM_GPIO1], [Pulled up on #cm 5, but can be forced low to emulate a reset signal.],
    [104], [Reserved], [PCIE_DET_nWAKE], [PCIE nWAKE. Pull up to `CM5_3v3` with an 8.2K resistor.],
    [106], [Reserved], [PCIE_PWR_EN], [Signals whether the PCIe device can be powered up or down. Active high.],
    [111], [VDAC_COMP], [VBUS_EN], [Output to signal that USB VBUS should be enabled.],
    [128], [CAM0_D0_N], [USB3-0-RX_N], [May be P/N swapped.],
    [130], [CAM0_D0_P], [USB3-0-RX_P], [May be P/N swapped.],
    [134], [CAM0_D1_N], [USB3-0-DP], [USB 2.0 signal.],
    [136], [CAM0_D1_P], [USB3-0-DM], [USB 2.0 signal.],
    [140], [CAM0_C_N], [USB3-0-TX_N], [May be P/N swapped.],
    [142], [CAM0_C_P], [USB3-0-TX_P], [May be P/N swapped.],
    [157], [DSI0_D0_N], [USB3-1-RX_N], [May be P/N swapped.],
    [159], [DSI0_D0_P], [USB3-1-RX_P], [May be P/N swapped.],
    [163], [DSI0_D1_N], [USB3-1-DP], [USB 2.0 signal.],
    [165], [DSI0_D1_P], [USB3-1-DM], [USB 2.0 signal.],
    [169], [DSI0_C_N], [USB3-1-TX_N], [May be P/N swapped.],
    [171], [DSI0_C_P], [USB3-1-TX_P], [May be P/N swapped.],
)


In addition to the above, the PCIe CLK signals are no longer capacitively coupled.

== PCB

#cm 5's PCB is thicker than #cm 4's, measuring at 1.24mm+/-10%.

== Track lengths

HDMI0 track lengths have changed. Each P/N pair remains matched, but the skew between pairs is now \<1mm for existing motherboards. This is unlikely to make a difference, as the skew between pairs can be in the order of 25 mm.

HDMI1 track lengths have also changed. Each P/N pair remains matched, but the skew between pairs is now \<5mm for existing motherboards. This is unlikely to make a difference, as the skew between pairs can be in the order of 25 mm.

Ethernet track lengths have changed. Each P/N pair remains matched, but the skew between pairs is now \<4mm for existing motherboards. This is unlikely to make a difference, as the skew between pairs can be in the order of 12 mm.

== Connectors

The two 100-pin connectors have been changed to a different brand. These are compatible with the existing connectors but have been tested at high currents. The mating part that goes onto the motherboard is Amphenol P/N 10164227-1001A1RLF.


== Power budget

As #cm 5 is significantly more powerful than #cm 4, it will consume more electrical power. Power supply designs should budget for 5V up to 2.5A. If this creates an issue with an existing motherboard design, it is possible to reduce the CPU clock rate to lower the peak power consumption.

The firmware monitors the current limit for USB, which effectively means that `usb_max_current_enable` is always 1 on CM5; the IO board design should take the total USB current required into consideration.

The firmware will report the detected power supply capabilities (if possible) via 'device-tree'. On a running system, see `/proc/device-tree/chosen/power/*`. These files are stored as 32-bit big-endian binary data. 

= Software changes/requirements

From a software point of view, the changes in hardware between #cm 4 and #cm 5 are hidden from the user by new device tree files, which means the majority of the software that adheres to the standard Linux APIs will work without change. The device tree files ensure that the correct drivers for the hardware are loaded at boot time. 

Device tree files can be found in the #pi-prefix Linux kernel tree. For example: #link("https://github.com/raspberrypi/linux/blob/rpi-6.12.y/arch/arm64/boot/dts/broadcom/bcm2712-rpi-cm5.dtsi").


Users moving to #cm 5 are advised to use the software versions indicated in the table below, or newer. While there is no requirement to use #pios, it is a useful reference, hence its inclusion in the table.

#table(
    columns: 4,  
    table.header([Software], [Version], [Date], [Notes]),
    [Raspberry Pi OS], [Bookworm (12)], [], [],
    [Firmware], [], [From 10 Mar 2025], [See https://pip.raspberrypi.com/categories/685-app-notes-guides-whitepapers/documents/RP-003476-WP/Updating-Pi-firmware.pdf for details on upgrading firmware on an existing image. Note that #cm 5 devices come pre-programmed with appropriate firmware],
    [Kernel], [6.12.x], [From  2025], [This is the kernel used in #pios],
)

=== Moving to standard Linux APIs/libraries from proprietary drivers/firmware

All the changes listed below were part of the transition from #pios Bullseye to #pios Bookworm in October 2023. While #cm 4 was able to use the older deprecated APIs (as the required legacy firmware was still present), this is not the case on #cm 5.

#cm 5, like #pi 5, now relies on the DRM (Direct Rendering Manager) display stack, rather than the legacy stack often referred to as DispmanX. There is NO firmware support on #cm 5 for DispmanX, so moving to DRM is essential. 

A similar requirement applies to cameras; #cm 5 only supports the `libcamera` library's API, so older applications that use the legacy firmware MMAL APIs, such as `raspi-still` and `raspi-vid`, no longer function. 

Applications using the OpenMAX API (cameras, codecs) will no longer work on #cm 5, so will need to be rewritten to use V4L2. Examples of this can be found in the `libcamera-apps` GitHub repository, where it is used to access the H264 encoder hardware. 

OMXPlayer is no longer supported, as it also uses the MMAL API — for video playback, you should use the VLC application. There is no command-line compatibility between these applications: see the VLC documentation for details on usage.

#pi previously published a whitepaper that discusses these changes in more detail: #link("https://pip.raspberrypi.com/categories/685-app-notes-guides-whitepapers/documents/RP-006519-WP/Transitioning-from-Bullseye-to-Bookworm.pdf"). 


= Additional information

While not strictly related to the transition from #cm 4 to #cm 5, #trading has released a new version of the #cm provisioning software and also has two distro generation tools that users of #cm 5 may find useful.

`rpi-sb-provisioner` is a minimal-input, automatic secure boot provisioning system for Raspberry Pi devices. It is entirely free to download and use, and can be found on our GitHub page here: #link("https://github.com/raspberrypi/rpi-sb-provisioner").

`pi-gen` is the tool used to create the official #pios images, but it is also available for third parties to use to create their own distributions. This is the recommended approach for #cm applications that require customers to build a custom #pios;-based operating system for their specific use case. This is also free to download and use, and can be found here: #link("https://github.com/RPi-Distro/pi-gen"). The `pi-gen` tool integrates well with `rpi-sb-provisioner` to provide an end-to-end process for generating secure boot OS images and implementing them on #cm 5.

`rpi-image-gen` is a new image creation tool (#link("https://github.com/raspberrypi/rpi-image-gen")) that may be more appropriate for more lightweight customer distributions. 

For bring-up and testing — and where there is no requirement for the full provisioning system — `rpiboot` is still available on #cm 5. #trading recommends using a host #pi SBC running the latest version of #pios and the latest `rpiboot` from #link("https://github.com/raspberrypi/usbboot"). You must use the 'Mass Storage Gadget' option when running `rpiboot`, as the previous firmware-based option is no longer supported.