#import "@local/rpi-style:0.0.1": * 

#import "../../globalvars.typ": *

#show: rpi_whitepaper.with(
    title: "Troubleshooting the USB Interface on a Compute Module 4 Carrier Board",
    version_string: [Version 1.0],
    version_history: (
    [1.0], [14 April 2021], [Initial release]
    ), 
    platforms: ("CM 4")
)

= Introduction

Providing that the example design from the Raspberry Pi Compute Module (CM) 4 IO Board has been followed closely, there should be relatively few issues with getting the Universal Serial Bus (USB) working on a third-party CM 4 carrier board. However, there are some areas that need special attention, and this document will attempt to shed light on possible problem areas.

This whitepaper assumes that the Raspberry Pi CM 4 is running the Raspberry Pi operating system (OS; Linux), and is fully up to date with the latest firmware and kernels.

= Hardware design

If you follow the #pi-prefix CM 4 IO Board circuit diagrams closely when designing your own carrier board with USB, there should be few issues. However, there are a number of points where you should take care when designing a board.

== Impedance

Ensure that any USB pairs are routed as a 90R differential pair with a continuous reference plane.

== Ground vias

As shown by the #pi-prefix CM 4 IO Board reference design, when you have fast signals such as those for USB it is important that when a signal via goes from one layer to another the ground return paths must be kept as short as possible to prevent impedance problems. The #pi-prefix CM 4 IO Board is a four-layer printed circuit board (PCB), with the middle two layers used as ground planes. It can been seen from the design that the two ground planes are bonded together with vias as close as possible to any signal vias moving from the top to the bottom layer. As a rule of thumb you should have at least two ground plan vias for a differential pair of vias, although four would be better. Failure to ensure a short return ground path can lead to erratic impedance (USB needs 90ohms) and also electromagnetic compatibility (EMC) problems.

== Track distancing

As a rule of thumb, the spacing between tracks and unrelated tracks, including floods, should be three times the distance of the track to the ground plane, to prevent EMC and interference issues.

So, for example, if the distance between a layer and a ground plane on a PCB is 0.2mm, tracks should be at least 0.6mm apart.


= Software considerations

If you are using a standard #pios installation then all the USB drivers will be preinstalled. There are a number of configuration items that can be used to change the specific functionality of USB; for example, you may wish to use the device in On-The-Go (OTG) mode.

By default on the CM 4 the USB interface is disabled to save power. To enable it you need to add `dtoverlay=dwc2,dr_mode=host` to the `config.txt` file.

Also, to use the full USB 2.0 extensible host controller interface (XHCI) controller on what is normally the OTG port requires `otg_mode=1` in `config.txt`. Setting this to 1 enables the `xhci` controller in place of `dwc_otg`, using the same USB 2.0 OTG PHY (physical layer). Changing the controller over has to be done at boot time as access to the other peripheral is explicitly disabled by the switch.

