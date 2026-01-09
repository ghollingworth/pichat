#import "@local/rpi-style:0.0.1": * 

#import "../../globalvars.typ": *

#show: rpi_whitepaper.with(
    title: "Electrical testing of the Ethernet port on Raspberry Pi devices",
    version_string: [Version 1.0],
    version_history: (
    [1.0], [1 Jul 2023], [Initial release],
    ), 
    platforms: ("Pi1 B", "Pi2 B", "Pi3 B", "Pi4", "Pi5", "AllCM", "Pi400", "Pi500")
)


#note[Although the instructions presented here work on all the devices specified, they will usually only be required for Compute Module devices, where electrical testing of the physical Ethernet connection is required. This testing has already been done on those #pi-prefix products that are sold with Ethernet jacks already installed.]

= Introduction

This white paper describes how to install and run software that allows electrical testing of the Ethernet wiring on devices based on the #trading range of single-board computers (SBCs) and Compute Modules.

This white paper assumes that the #pi is running #pios, and is fully up to date with the latest firmware and kernels.

= Software installation

Boot the #pi device and bring up a terminal window/console.

In a terminal, install and build a copy of `mdio-tool`. The build system uses `cmake`, so you may need to install this first.

```
sudo apt install cmake
git clone https://github.com/PieVo/mdio-tool.git
cd mdio-tool
mkdir build
cd build
cmake ..
make
sudo make install
```

= Running the test

The following command will force the Ethernet device to output a 100Mbit waveform:

```
sudo ./mdio-tool w eth0 0x0 0x2100
```


The following command will force the Ethernet device to output a 1000Mbit waveform:

```
sudo ./mdio-tool w eth0 0x0 0x0140
```

You can then start any of the following tests:

Test mode 1 — transmitter droop test mode:
```
sudo ./mdio-tool w eth0 0x9 0x3f00
```

Test mode 2 — transmit jitter test in master mode:
```
sudo ./mdio-tool w eth0 0x9 0x5f00
```

Test mode 3 — transmit jitter test in secondary/slave mode:
```
sudo ./mdio-tool w eth0 0x9 0x7f00
```

Test mode 4 — transmitter distortion test:
```
sudo ./mdio-tool w eth0 0x9 0x9f00
```

Test mode 5 — normal operation at full power:
```
sudo ./mdio-tool w eth0 0x9 0xbf00
```

To end any test modes, use the following command:

```
sudo ./mdio-tool w eth0 0x0 0x1140
```