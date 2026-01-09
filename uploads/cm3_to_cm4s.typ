#import "@local/rpi-style:0.0.1": * 

#import "../../globalvars.typ": *

#show: rpi_whitepaper.with(
    title: "Transitioning from Compute Module 1/3 to Compute Module 4S",
    version_string: [Version 1.5],
    version_history: (
    [1.0], [30 September 2021], [Initial release],
    [1.1], [23 February 2022], [Added section on updating firmware],
    [1.2], [27 April 2022], [Copy edit, public release],
    [1.3], [21 June 2023], [Minor clarifications on display usage],
    [1.4], [11 Dec 2023], [Change URL from .org to .com],
    [1.5], [5 Nov 2024], [Add information on GPIO behaviour on startup],
    ),
    platforms: ("CM1", "CM3", "CM4S")
)

= Introduction

This whitepaper is for those who wish to move from using a #pi-prefix Compute Module (CM) 1 or 3 to a #pi-prefix CM 4S.
There are several reasons why this might be desirable:

- Greater computing power
- More memory
- Higher-resolution output up to 4Kp60
- Better availability
- Longer product life (last time buy _not_ before January 2028)

From a software perspective, the move from #pi-prefix CM 1/3 to #pi-prefix CM 4S is relatively painless, as a #pi-prefix operating system (OS) image should work on all platforms. If, however, you are using a custom kernel, some things will need to be considered in the move. The hardware changes are considerable, and the differences are described in a later section.

== Terminology

Legacy graphics stack: A graphics stack wholly implemented in the VideoCore firmware blob with a shim application programming interface exposed to the kernel. This is what has been used on the majority of #trading Pi devices since launch, but is gradually being replaced by (F)KMS/DRM.

FKMS: Fake Kernel Mode Setting. While the firmware still controls the low-level hardware (for example the HDMI ports, Display Serial Interface, etc.), standard Linux libraries are used in the kernel itself.

KMS: The full Kernel Mode Setting driver. Controls the entire display process, including talking to the hardware directly with no firmware interaction.

DRM: Direct Rendering Manager, a subsystem of the Linux kernel used to communicate with graphical processing units. Used in partnership with FKMS and KMS.

== Compute Module comparison

=== Functional differences

The following table gives some idea of the basic electrical and functional differences between the models.

#table(
        columns: (auto, auto, auto, auto),
    stroke: (x: 0.4pt, y: 0.4pt),
    align: (left, left, left, left),
    table.header(
    [Feature], [CM 1], [CM 3/3+], [CM 4S],
    ),
    [Processor], [BCM2835], [BCM2837], [BCM2711],
    [Random access memory], [512MB], [1GB], [1GB],
    [Embedded MultiMediaCard (eMMC) memory], [--], [0/8/16/32GB], [0/8/16/32GB],
    [Ethernet], [None], [None], [None],
    [Universal Serial Bus (USB)], [1 #sym.times USB 2.0], [1 #sym.times USB 2.0], [1 #sym.times USB 2.0],
    [HDMI], [1 #sym.times 1080p60], [1 #sym.times 1080p60], [1 #sym.times 4K],
    [Form factor], [SODIMM], [SODIMM], [SODIMM],
)


=== Physical differences

The #pi-prefix CM 1, CM 3/3+, and CM 4S form factor is based around a small-outline dual inline memory module (SODIMM) connector. This provides a physically compatible upgrade path between these devices.

#note[These devices _cannot_ be used in a memory slot as a SODIMM device.]

== Power supply details

The #pi-prefix CM 3 requires an external 1.8V power supply unit (PSU). The #pi-prefix CM 4S no longer uses an external 1.8V PSU rail so these pins on the #pi-prefix CM 4S are no longer connected. This means that future baseboards will not need the regulator fitted, which simplifies the power-on sequencing. If existing boards already have a +1.8V PSU, no harm will occur to the #pi-prefix CM 4S.

The #pi-prefix CM 3 uses a BCM2837 system on a chip (SoC), whereas the CM 4S uses the new BCM2711 SoC. The BCM2711 has significantly more processing power available, so it is possible, indeed likely, for it to consume more power. If this is a concern then limiting the maximum clock rate in `config.txt` can help.


== General purpose I/O (GPIO) usage during boot

Internal booting of the #pi-prefix CM 4S starts from an internal serial peripheral interface (SPI) electronically erasable programmable read-only memory (EEPROM) using the BCM2711 GPIO40 to GPIO43 pins; once booting is complete the BCM2711 GPIOs are switched to the SODIMM connector and so behave as on the #pi-prefix CM 3. Also, if an in-system upgrade of the EEPROM is required (this is not recommended) then the GPIO pins GPIO40 to GPIO43 from the BCM2711 revert to being connected to the SPI EEPROM and so these GPIO pins on the SODIMM connector are no longer controlled by the BCM2711 during the upgrade process.

== GPIO behaviour on initial power on

GPIO lines can have a very brief point during start up where they are not pulled low or high, therefore making their behaviour unpredictable. This nondeterministic behaviour can vary between the CM3 and the CM4S, and also with chip batch variations on the same device. In the majority of use cases this has no effect on usage, however, if you have a MOSFET gate attached to a tri-state GPIO, this could risk any stray capacitances holding volts and turning on any connected downstream device. It is good practice to ensure a gate bleed resistor to ground is incorporated in to the design of the board, whether using CM3 or CM4S, so that these capacitive charges are bled away.

Suggested values for the resistor are between 10K and 100K.

== Disabling eMMC

On the #pi-prefix CM 3, EMMC_Disable_N electrically prevents signals from accessing the eMMC. On the #pi-prefix CM 4S this signal is read during boot to decide whether the eMMC or USB should be used for booting. This change should be transparent for most applications.


== EEPROM_WP_N

The #pi-prefix CM 4S boots from an onboard EEPROM that is programmed during manufacture. The EEPROM has a write protect feature that can be enabled via software. An external pin is also provided to support write protection. This pin on the SODIMM pinout was a ground pin, so by default if the write protection is enabled via software the EEPROM is write protected. It is not recommended that the EEPROM be updated in the field. Once the development of a system is complete the EEPROM should be write-protected via software to prevent in-field changes.


= Software changes required

If you are using a fully updated #pios then the software changes needed when moving between any #trading boards are minimal; the system automatically detects which board is running and will set up the operating system appropriately. So, for example, you can move your OS image from a #pi-prefix CM 3+ to a #pi-prefix CM 4S and it should work without changes.

#note[You should ensure that your #pios installation is up to date by going through the standard update mechanism. This will ensure that all firmware and kernel software is appropriate for the device in use.]

If you are developing your own minimal kernel build or have any customisations in the `boot` folder then there may be some areas where you will need to ensure you are using the correct setup, overlays, and drivers.

While using an updated #pios _should_ mean that the transition is fairly transparent, for some 'bare metal' applications it is possible that some memory addresses have changed and a recompilation of the application is required. See #link("https://datasheets.raspberrypi.com/bcm2711/bcm2711-peripherals.pdf")[the BCM2711 peripherals documentation] for more details on the extra features of the BCM2711 and register addresses.

== Updating firmware on an older system

In some circumstances it may not be possible to update an image to the latest version of #pios. However, the CM4S board will still need updated firmware to work correctly. There is a whitepaper available from #trading which describes updating firmware in detail, however, in short, the process is as follows:

Download the firmware files from the following location:

#link("https://github.com/raspberrypi/firmware/archive/refs/heads/stable.zip")

This zip file contains several different items, but the ones we are interested in at this stage are in the `boot` folder.

The firmware files have names of the form `start*.elf` and their associated support files `fixup*.dat`.

The basic principle is to copy the required start and fixup files from this zip file to replace the same named files on the destination operation system image. The exact process will depend on how the operating system has been set up, but as an example, this is how it would be done on a #pios image.






The image should now be ready for use on the CM4S.


== Graphics

By default, the #pi-prefix CM 1&#8211;3+ use the legacy graphics stack, while the #pi-prefix CM 4S uses the KMS graphics stack.

While it is possible to use the legacy graphics stack on the #pi-prefix CM 4S, this does not support 3D acceleration, so moving to KMS is recommended.

== HDMI

Whilst the BCM2711 has two HDMI ports, only HDMI-0 is available on the #pi-prefix CM 4S, and this can be driven at up to 4Kp60. All other display interfaces (DSI, DPI and composite) are unchanged.


