#import "@local/rpi-style:0.0.1": * 

#import "../../globalvars.typ": *

#show: rpi_whitepaper.with(
    title: "Integrated Circuit Packing and Storage",
    version_string: [Version 1.0],
    version_history: (
    [1.0], [15 Oct 2022], [Initial release],
    ), 
    platforms: ("")
)

#trading Integrated Circuits only

= Introduction

This document outlines the packing procedure and storage recommendations for all discrete #trading integrated circuits.

#trading draws on the widely accepted JEDEC (Joint Electron Device Engineering Council) Solid State Technology Association standards.

One of JEDEC’s standards, MSL (Moisture Sensitivity Level), classifies the moisture sensitivity of an electronic component. The MSL classification for a #trading device can be found in that device's product databook.

Currently only two MSL classifications apply to discrete #trading products: MSL1 and MSL3.

= MSL overview

The MSL classification is an indication of the ability of the device package to withstand moisture ingress. MSL1-classified products have the most resistance, while products classified at higher levels have increasing less resistance.

#trading products undergo tests defined by JEDEC standard J-STD-020E to qualify the device to a given MSL classification.

Moisture held in the package is particularly important prior to board assembly, because interaction with heat and stress from reflow soldering can result in device damage or degradation. It is possible to expel moisture from the package using a predefined baking procedure; however, the aim of this packing and storage procedure is to avoid the need for any re-bake.

JEDEC defines maximum out-of-bag exposure times for devices, the duration differing by MSL classification. The exposure time is divided into two parts: one is for the manufacturer (Manufacturer's Exposure Time, or MET), and the other is the floor life assembly duration. #trading adheres to the maximum MET as devices are packed and sealed for distribution.


= Packing

Whether devices are packed in trays or reels makes little difference, since neither medium provides resistance to moisture. A sealed moisture barrier bag (MBB) is the recognised method for providing protection.

If customer repacking is required, #trading recommends the manufacturing packing procedure defined below.

== Vacuum-sealed MBB

A vacuum-sealed moisture barrier bag is required for MSL3 products as specified in JEDEC standard J-STD-033D. Although not strictly necessary, #trading has elected to seal MSL1 products in a MBB.

== HIC and desiccant

Both a humidity indicator card (HIC) and desiccant are required for MSL3 products and are included in the MBB contents. They serve no purpose for MSL1 and are therefore omitted for #trading MSL1-classified products.

#figure(
  image("diagrams/humidity.png"),
  caption: [Humidity Indicator Card]
)
#figure(
  image("diagrams/silicagell.png"),
  caption: [Sachet of Desiccant Silica Gel]
)

== Caution label

A caution label is included on the outside of the MBB for all moisture-sensitive products. This label identifies the sensitivity level for the product and provides details on floor life conditions and duration.

#figure(
  image("diagrams/cautionmsl.png"),
  caption: [Example caution label]
)

A caution label is not required for MSL1, but an alternative label is required indicating MSL1.

== MSID label

Another label, the MSID (Moisture Sensitive Identification) label, is included on the packing box, identifying that it has moisture-sensitive contents.

#figure(
  image("diagrams/cautionmoisture.png"),
  caption: [Example caution label]
)

Although MSL1 does have floor life restrictions, an MSL1 product is not considered a moisture-sensitive product and therefore no MSID label should be present.

= Breaking the MBB seal

The 10% spot on the humidity indicator card must remain blue upon opening. Otherwise, the condition of the material is unknown and a bake is required before use.

== Bake conditions

For MSL3 products, an eight-hour bake at 125°C + 10/-0°C < 5% relative humidity will reset the floor time. Bake time maybe reduced to six hours if exposure time is < 72 hours.

= Storage and handling

#trading recommends product storage in compliance with IPC/JEDEC standard J-STD-033D.

J-STD-033D defines two lifespans: the shelf life for a dry-packed unopened MBB, and floor life for the time between opening and soldering.

== Shelf life

For MSL1 products, the shelf life is considered unlimited footnote:[Other warranty conditions may apply] with storage conditions ≤ 30°C/85% RH.

MSL3 products have a twelve-month shelf life when correctly stored ≤ 40°C/90% RH.

After the twelve-month period, customer action is recommended on a case-by-case basis. Consider the plan for the material, the state of the humidity indicator card, and the assurance provided by a bake.

== Floor life

Once again, for MSL1 products, the floor life is considered unlimited with conditions ≤ 30°C/85% RH.

For MSL3 products, the floor life is critical: it is limited to 168 hours in a controlled environment with ≤ 30°C/60% RH.

= Handling

At all times consideration must be given to electrostatic discharge-sensitive (ESDS) devices.

#trading recommends adherence to specification JESD625 for the Handling of Electrostatic Discharge Sensitive devices.