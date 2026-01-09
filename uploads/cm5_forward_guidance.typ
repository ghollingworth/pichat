#import "@local/rpi-style:0.0.1": * 

#import "../../globalvars.typ": *

#show: rpi_whitepaper.with(
    title: "Raspberry Pi Compute Module 5 Forward Guidance",
    version_string: [Version 1.5],
    version_history: (
    [1.0], [1 Nov 2023], [Initial release],
    [1.1], [19 Mar 2024], [Fix pinout table for swapped information on pins 104/106; added information on extra USB 3 ports; removed connectors section.],
    [1.2], [3 May 2024], [Reinstated connectors section],
    [1.3], [10 May 2024], [Updated pin 100 information],
    [1.4], [20 Jun 2024], [RAM options updated.],
    [1.5], [25 Jun 2024], [Update CM4 obsolescence date to 2034.],
    ), 
    platforms: ("CM5")
)

= Introduction

Raspberry Pi Compute Module 5 builds on the #pi tradition of taking the latest main-line #pi computers and producing a small product suitable for embedded applications. At the time of writing, the Raspberry Pi Compute Module 5 is under development, and *currently* follows the same compact form factor as the Raspberry Pi Compute Module 4 but provides higher performance and an improved feature set. There are, of course, some differences between Raspberry Pi Compute Module 4 and Raspberry Pi Compute Module 5. These are described here.

#note[For the few customers who are unable to use the Raspberry Pi Compute Module 5, the Raspberry Pi Compute Module 4 will stay in production till at least 2034.]

The information below is still subject to change, and will not be confirmed until the launch of the Raspberry Pi Compute Module 5.

= Main features

The Raspberry Pi Compute Module 5 will have the following features.

- 4× A76 clocked \@ 2GHz
- Maximum 8GB LPDDR4× SDRAM ^[1]^
- Onboard eMMC options ^[2]^
- 2× USB 3.0 ports
- 1Gbit Ethernet interface
- 2× 4-lane DSI/CSI ports
- 2× HDMI ports capable of 4Kp60
- 28× GPIO pins
- Onboard test points to simplify production programming
- Internal EEPROM on the bottom to improve security
- Onboard RTC (external battery via 100pin connectors)
- Onboard fan controller
- Onboard Wi-Fi/Bluetooth
- 1 lane PCIe 2.0. ^[3]^
- Type C PD PSU support

^[1]^ Exact options are yet to be decided. 1GB, 2GB, 4GB and 8GB are likely to be available. +
^[2]^ Exact options are yet to be decided. 8GB, 16GB and 32GB are likely to be available. +
^[3]^ In some applications PCI Gen 3 is possible, but this is not officially supported.

#note[Not all SDRAM/eMMC configurations will be available.]

== Raspberry Pi Compute Module 4 compatibility

For most customers, the Raspberry Pi Compute Module 5 will be pin-compatible with the Raspberry Pi Compute Module 4.

The following features have been removed from the Raspberry Pi Compute Module 5 when compared to the Raspberry Pi Compute Module 4:

- Composite video
- 2 lane DSI port
- 2 lane CSI port
- 2× ADC inputs

== Detailed pinout changes

CAM1 signals become dual-purpose and can be used for either a CSI camera or a DSI display.

DSI1 signals become dual-purpose and can be used for either a CSI camera or a DSI display.

The Raspberry Pi Compute Module 4 has extra ESD protection on the HDMI, SDA, SCL, HPD and CEC signals. This is removed from the Raspberry Pi Compute Module 5.

What was CAM0 on the Compute Module 4 now supports a USB 3.0 Port. What was DSI0 now supports a USB 3.0 port. The original Compute Module 4 VDAC_COMP pin is now a VBUS enable pin for the two USB 3 ports and is active high.

#table(
    columns: 4, 
    table.header([Pin], [CM4], [CM5], [Comment]),
    [16], [SYNC_IN], [Fan_tacho], [Fan tacho input],
    [19], [Ethernet nLED1], [Fan_pwn], [Fan PWM output],
    [76], [Reserved], [VBAT], [RTC battery. Note, there will be a constant load of a few uA even if the CM5 is powered.],
    [92], [RUN_PG], [PWR_Button], [Replicates the power button on Raspberry Pi 5. A short press signals that the device should wake up or shut down. A long press forces shutdown.],
    [93], [nRPIBOOT], [nRPIBOOT], [For a short time after power-up, if the PWR_button is low this pin will also be set low.],
    [94], [AnalogIP1], [CC1], [This pin can connect to the CC1 line of a Type C USB connector to enable the PMIC to negotiate 5A.],
    [96], [AnalogIP0], [CC2], [This pin can connect to the CC2 line of a Type C USB connector to enable the PMIC to negotiate 5A.],
    [99], [Global_EN], [PMIC_ENABLE], [No external change.],
    [100], [nEXTRST], [CAM_GPIO1], [Pulled up on Raspberry Pi Compute Module 5, but can be forced low to emulate a RESET signal.],
    [104], [Reserved], [PCIE_DET_nWAKE], [PCIE nWAKE. Pull up to CM5_3v3 with an 8.2K resistor.],
    [106], [Reserved], [PCIE_PWR_EN], [Signals if the PCIe device can be powered up or down. Active high.],
    [111], [VDAC_COMP], [VBUS_EN], [Output to signal USB VBUS should be enabled.],
    [128], [CAM0_D0_N], [USB3-0-RX_N], [May be P/N swapped.],
    [130], [CAM0_D0_P], [USB3-0-RX_P], [May be P/N swapped.],
    [134], [CAM0_D1_N], [USB3-0-DP], [USB 2 signal.],
    [136], [CAM0_D1_P], [USB3-0-DM], [USB 2 signal.],
    [140], [CAM0_C_N], [USB3-0-TX_N], [May be P/N swapped.],
    [142], [CAM0_C_P], [USB3-0-TX_P], [May be P/N swapped.],
    [157], [DSI0_D0_N], [USB3-1-RX_N], [May be P/N swapped.],
    [159], [DSI0_D0_P], [USB3-1-RX_P], [May be P/N swapped.],
    [163], [DSI0_D1_N], [USB3-1-DP], [USB 2 signal.],
    [165], [DSI0_D1_P], [USB3-1-DM], [USB 2 signal.],
    [169], [DSI0_C_N], [USB3-1-TX_N], [May be P/N swapped.],
    [171], [DSI0_C_P], [USB3-1-TX_P], [May be P/N swapped.],
)


In addition to the above, the PCIe CLK signals are no longer capacitively coupled.

The PCB is likely to be thicker, and will probably measure 1.24mm+/-10%

== Track lengths

HDMI0 track lengths have changed. Each P/N pair remains matched, but the skew between pairs is now \<1mm for existing motherboards. This is unlikely to make a difference as the skew between pairs can be in the order of 25mm.

HDMI1 track lengths have also changed. Each P/N pair remains matched, but the skew between pairs is now \<5mm for existing motherboards. This is unlikely to make a difference as the skew between pairs can be in the order of 25mm.

Ethernet track lengths have changed. Each P/N pair remains matched, but the skew between pairs is now \<4mm for existing motherboards. This is unlike to make a difference as the skew between pairs can be in the order of 12mm.

== Connectors

The two 100-pin connectors have changed to an alternative brand. These are compatible with the existing connectors but have been tested at high currents. The mating part to go onto a motherboard is Amphenol P/N 10164227-1001A1RLF.


== Power budget

As the Raspberry Pi Compute Module 5 is significantly more powerful than the Raspberry Pi Compute Module 4, it will consume more power. Power supply designs should budget for 5V up to 2.5A. If this creates an issue with an existing motherboard design, it is possible to reduce the CPU clock rate to reduce the peak power consumption.

== Contact Details for more information

Please contact `applications@raspberrypi.com` if you have any queries about this information.

Web: `www.raspberrypi.com`
