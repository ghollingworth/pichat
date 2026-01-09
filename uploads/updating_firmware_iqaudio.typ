#import "@local/rpi-style:0.0.1": * 

#import "../../globalvars.typ": *


#show: rpi_whitepaper.with(
    title: "How to update Firmware on an IQ Audio board",
    version_string: [Version 1.0],
    version_history: (
    [1.0], [21 Jan 2023], [Initial release],
    ), 
    platforms: ()
)

- #IQ Codec Zero
- #IQ DAC+
- #IQ DAC Pro
- #IQ DigiAmp+


= Introduction

The #pi-prefix #IQ range of audio HATs have a EEPROM on board that contains firmware that provides information to the host #pi-prefix device on the boards required driver. This information is programmed in to the device during manufacture.

There are some circumstances where the end user may wish to update this firmware, and this document describes how to upload that information to the board using command line tools supplied by #trading.

This whitepaper assumes that the #pi is running #pios, and is fully up to date with the latest firmware and kernels.

= Getting the firmware and tools

All the required firmware is available in the Raspberry Pi Product Information Portal (PIP). The flashing tools are available in Github.

Download the firmware from the link below, and extract it to an appropriate folder.

//Link to firmware to be added

Clone the flashing tools from this Github repository.

```bash
git clone git@github.com:raspberrypi/hats.git
```

The tools are in the `eepromutils` folder.


= Identification of the EEPROM write protect link

By default, the EEPROM on the #IQ boards are write protected. It is necessary to short the write protect line to ground to enable programming of the EEPROM. The write protect line must be pulled low for the entirety of the programming process.

The following diagrams show where on the boards these links are located. You need to connect the two pads indicated in the red boxes together during the programming process.

== Codec Zero

Note this image shows a Zero Ohm resister already fitted to the link.

#figure(
  image("diagrams/Codec_Zero_TOP.jpg"),
)

== DAC Plus

#figure(
  image("diagrams/DAC_+_TOP.jpg"),
)

== DAC Pro

#figure(
  image("diagrams/DAC_Pro_TOP.jpg"),
)

== DigiAmp

#figure(
  image("diagrams/DigiAmp_TOP.jpg"),
)


= Programming the device

Once the write protect line has been pulled down, the EEPROM can be programmed.

Firstly, identify which board you are programming and locate the correct `eep` file from the extracted file downloaded from PIP. The extracted folders will also contain a tools folder in which you will find the `eepflash.sh` script which is used to programme the device.

Then use the following command to program that eep file to the #IQ device.

```
sudo eepflash.sh -w -f=<path to required eep file> -t=24c32
```

#note[You will need to provide the path to the `eepflash.sh` script as it will not be in the system path.]

#table(
    columns: 2, 
    table.header([Device], [Filename]),
    [#IQ Codec Zero], [Pi-CodecZero.eep],
    [#IQ DAC+], [Pi-DACPlus.eep],
    [#IQ DAC Pro], [Pi-DACPRO.eep],
    [#IQ DigiAmp+], [Pi-DigiAMP.eep],
)



== Using Device Tree overlays instead of programming

When programmed the IQ Audio boards EEPROM proves information to the host system on which device tree overlays need to be loaded in order for the board to be started up and used. It is possible to manually specify these device tree entries in the `config.txt` file.

The procedure is simple, edit the `config.txt` file using your favourite editor (you will need to run the editor as root using `sudo`), and add the following line:

```
dtoverlay <name of overlay>
```

Use the correct overlay for your device.

#table(
    columns: 2, 
    table.header([Device], [Overlay name]),
    [#IQ Codec Zero], [rpi-codeczero],
    [#IQ DAC+], [rpi-dacplus],
    [#IQ DAC Pro], [rpi-dacpro],
    [#IQ DigiAmp+], [rpi-digiampplus],
)
