#import "@local/rpi-style:0.0.1": * 

#import "../../globalvars.typ": *

#show: rpi_whitepaper.with(
    title: "Transitioning A Product From Raspberry Pi 3 To Raspberry Pi",
    version_string: [Version 1.1],
    version_history: (
    [1.0], [10 September 2021], [Initial release],
    [1.1], [27 April 2022], [Copy edit, public release],
    ), 
    platforms: ("Pi3 B", "Pi4")
)


= Introduction

This whitepaper is for those who wish to move from using a #pi-prefix 3B+ to the #pi-prefix 4 device.

There are a number of reasons why this might be desirable:

- Greater computing power
- More memory
- More High-Definition Multimedia Interface (HDMI) ports
- Higher resolution output up to 4kp60
- Faster Ethernet
- Faster wireless
- Faster Universal Serial Bus (USB)
- Better availability

From a software perspective, the move from the #pi-prefix 3B+ to the #pi-prefix 4B is relatively painless as a #pi-prefix operating system (OS) image should work on all platforms. If, however, you are using a custom kernel, there are some things that will need to be considered in the move.

The hardware changes are more extensive, and the differences are described in a later section.

== Terminology

Legacy graphics stack: A graphics stack wholly implemented in the VideoCore firmware blob with a shim application programming interface (API) exposed to the kernel. This is what has been used on the majority of #tradings Pi devices since launch, but is gradually being replaced by (F)KMS/DRM.

FKMS: Fake Kernel Mode Setting. While the firmware still controls the low-level hardware (for example the HDMI ports, Display Serial Interface (DSI), etc.), standard Linux libraries are used in the kernel itself.

KMS: The full Kernel Mode Setting driver. Controls the entire display process, including talking to the hardware directly with no firmware interaction.

DRM: Direct Rendering Manager, a subsystem of the Linux kernel used to communicate with graphics processing units. Used in partnership with FKMS and KMS.


= Differences between models

== Comparison of #pi-prefix 3B+ and #pi-prefix 4B

The following table gives some idea of the basic electrical differences between the two models. On the whole, the #pi-prefix 4B is simply a much more powerful #pi-prefix 3B+.

#table(
    columns: 3, 
    table.header([Feature], [Pi 3B+], [Pi 4B]),
    [Processor], [BCM2837], [BCM2711],
    [Memory], [1GB], [2/4/8GB],
    [Ethernet], [0.35Gbps], [1.0Gbps],
    [Wireless], [b/g/n/ac dual band], [b/g/n/ac dual band],
    [Bluetooth], [4.2], [5.0],
    [USB], [4#sym.times USB 2.0], [2 #sym.times USB 2.0, 2 #sym.times USB 3.0],
    [HDMI], [1 #sym.times full size to 1080p60], [2 #sym.times micro HDMI, up to 4kp60],
    [Power connector], [micro USB], [USB-C],
)


While they are at first glance very similar, there are some major physical differences between the two boards:

- Two micro HDMI ports on the #pi-prefix 4B versus the single full-size port on the #pi-prefix 3B+
- USB-C power connector on #pi-prefix 4B versus micro USB power on the #pi-prefix 3B+
- The USB and Ethernet ports have swapped location

These physical differences mean that cases designed for the #pi-prefix 3B+ are no longer suitable for the #pi-prefix 4B, and that enclosures may need to have internal connectors repositioned.

= Form factor changes

In the transition from #pi-prefix 3B to #pi-prefix 4B, some major components have moved. The most obvious change is in the location of the USB and Ethernet ports, which have swapped places. The different power connector and the move to two micro HDMI ports is the other major change.

The mount holes have _not_ changed location.

#figure(
  image("diagrams/pi3b_mech.png"),
  caption: [Pi 3B mechanical drawing]
)

#figure(
  image("diagrams/pi4b_mech.png"),
  caption: [Pi 4B mechanical drawing]
)


= Software changes required

If you are using a fully updated #pios, then the software changes when moving between the two boards are minimal; the system automatically detects which board it is running on and will set up the operating system appropriately. So, for example, you can move the Secure Digital (SD) card from a #pi-prefix 3B+ to a #pi-prefix 4B and it should work without changes.

#note[You should ensure that your #pios installation is up to date by going through the standard update mechanism. This will ensure that all firmware and kernel software is appropriate for the #pi-prefix 4B.]

If you are developing your own minimal kernel build, then there are some areas where you will need to ensure you are using the correct drivers.

== Graphics

By default the #pi-prefix 3B+ uses our legacy graphics stack, while the #pi-prefix 4B uses the KMS graphics stack

While it is possible to use the legacy graphics stack on the #pi-prefix 4B, this does not support 3D acceleration, so moving to KMS when available is recommended.

== HDMI

The #pi-prefix 4B has two HDMI ports that are capable of dual 4kp30 output, or a single port at 4kp60. From a software perspective there is little that needs to be done to take advantage of the extra ports and resolution. Although all graphics stacks can detect the dual ports, when using KMS (or FKMS) the graphics system provides stretching of the desktop over both displays, duplication, rotation, and flipping.

There are some caveats to using the higher-resolution output facilities:

- 4kp60 is only available on HDMI port 0 and is disabled by default. 4kp60 can be enabled using `hdmi_enable_4kp60=1` in `config.txt`.
- The H264 decoder can handle a maximum of 1080p60. Use the High-Efficiency Video Coding (HEVC) decoder for higher-resolution video.


== Ethernet

On the #pi-prefix 3B+ the Ethernet interface is provided by a separate chip, a Microchip LAN7515, which is connected via USB 2.0, giving a maximum throughput of about 0.35Gbps. This chip uses the LAN78xx driver, which is enabled using the `CONFIG_USB_LAN78XX` kernel option.

The #pi-prefix 4B system-on-a-chip has a built in Ethernet media access controller (MAC), which provides full gigabit networking, so a theoretical maximum of 1.0Gbps. This MAC is supplied by Broadcom, and uses the Broadcom GENET (Gigabit Ethernet) controller driver. This is enabled in a kernel build using `CONFIG_BCMGENET`.

Apart from ensuring that the correct drivers are installed when building your Linux kernel, no other changes are required; aside from a difference in speed, no functional difference should be seen at the user level.

#note[If you require any sort of network-based root file system or network booting, then the Ethernet drivers need to be built in to the kernel, not loaded as modules.]

== Wireless/Bluetooth

Wireless and Bluetooth connectivity is provided on both devices by a separate chip, a
Cypress CYW43455, connected to the Secure Digital Input Output (SDIO) port. This chip is the same on both models, so there should be no need to make any software changes.

#note[The Cypress CYW43455 device was originally manufactured by Broadcom, and the driver's name reflects its origins. The driver used is for the BCM4345/6, which requires `brcmfmac43455-sdio` firmware.]

= Power supply

BCM2711-based devices such as the #pi-prefix 4B will generally require slightly more power than the BCM2837-equipped #pi-prefix 3B+, although the specific requirements will depend on the use case.

As a reference, #trading power supplies are rated at 2.5A for the #pi-prefix 3B+ and 3A for the #pi-prefix 4B.

= Thermal considerations

It should be noted that the processor cores on the #pi-prefix 4B, ARM A72s, are considerably more power efficient than the A53 on the #pi-prefix 3B+. This means that for equivalent average workloads, the #pi-prefix 4B will run slightly cooler than the #pi-prefix 3B+. Running both devices at full speed will result in similar thermal characteristics, with the #pi-prefix 4 performing approximately 60% to 100% more work in the same time period and with approximately the same heat dissipation.

You should use the same methods for heat dissipation for both models. For example, in open air you would not expect the devices to throttle due to overheating except in extreme circumstance; in an enclosed case, you may need to use passive or active cooling if you wish to ensure that the device does not throttle under load.

#note[The onboard firmware on both devices will ensure that the devices do not overheat and damage themselves; they will always throttle performance to keep temperatures within a safe range.]
