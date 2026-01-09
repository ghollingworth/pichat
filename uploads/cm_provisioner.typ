#import "@local/rpi-style:0.0.1": * 

#import "../../globalvars.typ": *

#let CM="Compute Module"

#show: rpi_whitepaper.with(
    title: "Provisioning Compute Module 3 and 4",
    version_string: [Version 1.4],
    version_history: (
    [1.0], [1 Jul 2021], [Initial release],
    [1.1], [27 Apr 2022], [Copy edit, public release],
    [1.2], [3 May 2022], [Update to add the #CM 3 and #CM 4S],
    [1.3], [1 Jul 2022], [Update to add verification information],
    [1.4], [19 Jun 2023], [Add appendix for production line scenarios]
    ), 
    platforms: ("CM3", "CM4")
)


= Introduction

The #provfullname is a web application designed to make programming a large number of #pi-prefix Compute Module (CM) devices much easier and quicker. It is simple to install and simple to use.

It provides an interface to a database of kernel images that can be uploaded, and allows the use of scripts to customise various parts of the installation during the flashing process.

Label printing and firmware updating are also supported.

This white paper assumes that the #provname server, software version 1.5 or newer, is running on a #boardname.


= How it all works

== #CM 4

The #provname system needs to be installed on its own wired network; the #boardname running the server is plugged into a switch, along with as many #CM 4 devices as the switch can support. Any CM4 plugged into this network will be detected by the provisioning system and automatically flashed with the user's required firmware. The reason for having a dedicated wired network becomes clear when you consider that _any_ CM4 plugged into this network will be provisioned, so keeping the network separate from any live network is essential to prevent the unintentional reprogramming of devices.

#figure(
  image("diagrams/blockdiagram.png"),
  caption: "block diagram"
)

By using a #boardname as the server, it is possible to use wired networking for the #provname but still have access to external networks using wireless connectivity. This allows easy downloading of images to the server, ready for the provisioning process, and allows the #boardname to serve up the #provname web interface.  Multiple images can be downloaded; the #provname keeps a database of images and makes it easy to select the appropriate image for setting up different devices.

When a #CM 4 is attached to the network and is powered up it will try to boot, and once other options have been tried, network booting is attempted. At this point the #provname Dynamic Host Configuration Protocol (DHCP) system responds to the booting CM4 and provides it with a #link("https://github.com/raspberrypi/scriptexecutor")[minimal bootable image] that is downloaded to the CM4 and then run as root. This image can program the embedded Multi-Media Card (eMMC) and run any required scripts, as instructed by the #provname.

=== More details

#CM 4 ships with a boot configuration that will try to boot from eMMC first; if that fails because the eMMC is empty, it will perform a preboot execution environment (PXE) network boot.

So, with #CM 4 units that have not yet been provisioned, and that have an empty eMMC, a network boot will be performed by default.

During a network boot on a provisioning network, a lightweight utility operating system image (actually a Linux kernel and a `scriptexecute` `initramfs`) will be served by the provisioning server to the #CM 4 over the network, and this image handles the provisioning.

== CM3 and CM4S

Compute Module devices based on the SODIMM connector cannot network boot, so programming is achieved over USB. Each device will need to be connected to the #provname. If you need to connect more than four devices (the number of USB ports on #pi), you can use a USB hub. Use good quality USB A to micro USB cables, connecting from the #pi or hub to the USB slave port of each CMIO board. All the CMIO boards will also need a power supply, and the J4 USB slave boot enable jumper should be set to enable (en).

#figure(
  image("diagrams/blockdiagramUSB.png"),
  caption: "USB block diagram"
)

IMPORTANT: When using the #provname to program SODIMM-based Compute Modules over USB, do NOT connect the Ethernet port of the server #boardname. Its wireless connection is used to access the management web interface.

= Installation

The following instructions were correct at the time of issue. The very latest installation instructions can be found on the #provname  #link("https://github.com/raspberrypi/cmprovision")[GitHub page].

== Installing the #provname web application on a #boardname

#warning[Make sure `eth0` connects to an Ethernet switch to which only the #CM 4 units that are to be provisioned are connected. Do _not_ connect `eth0` to your office network or public network, or it may 'provision' other #boardname devices in your network as well. Use the #boardname wireless connection to connect to your local network.]

The Lite version of #pios is recommended as the base OS on which to install the #provname. For simplicity, use #pi-prefix Imager, and activate the advanced settings menu (Ctrl-Shift-X) to set up the password, hostname, and wireless settings.

Once the OS is installed on the #boardname, you will need to set up the Ethernet system:

```console
sudo nano /etc/dhcpcd.conf```

```console
interface eth0
static ip_address=172.20.0.1/16
```
```console
sudo apt update
sudo apt full-upgrade
```
```console
sudo apt install ./cmprovision4_*_all.deb
```
```console
sudo /var/lib/cmprovision/artisan auth:create-user
```

You can now access the web interface of the #provname from a web browser, using the wireless IP address of the #boardname and the username and password that you entered in the previous section. Type or paste the IP address into the address bar of your browser and press Enter, and then enter the username and password when prompted.

= Usage

When you first connect to the #provname web application with your web browser you will see the Dashboard screen, which will look something like this:

#figure(
  image("diagrams/dashboard.png"),
  caption: "Dashboard display"
)

This landing page simply gives some information on the latest action performed by the #provname (in the example above, a single #CM 4 has been provisioned).

== Uploading images

The first operation you need to carry out when setting up is to load your image to the server, from where you can use it to provision your Compute Module 4 boards. Click the 'Images' menu item at the top of the web page and you should see a screen similar to the one shown below, displaying a list of currently uploaded images (which will initially be empty).

#figure(
  image("diagrams/images.png"),
  caption: "Images page"
)

Select the Add Image button to upload an image; you will see this screen:

#figure(
  image("diagrams/addimage.png", width: 50%),
  caption: "Add image dialog"
)

The image needs to be accessible on the device on which the web browser is running, and in one of the image formats specified. Select the image from your machine using the standard file dialogue, and click 'Upload'. This will copy the image from your machine to the #provname server running on the #boardname; this can take some time.

Once your image is uploaded, you will see it on the Images page.

== Adding a project

Next you need to create a project. You can specify any number of projects, and each can have a different image, set of scripts, or label. The active project is the one that is currently used for provisioning.

Click on the 'Projects' menu item to bring up the Projects page. The example in the image below already has one project, called 'Test project', set up.

#figure(
  image("diagrams/projects.png"),
  caption: "Projects page"
)

Now click on 'Add project' to set up a new project.

#figure(
  image("diagrams/addproject.png", width: 50%),
  caption: "Add project dialog"
)

Give the project an appropriate name, then select the image you want this project to use from the drop-down list. You can also set several other parameters at this stage, but often just specifying the image will suffice.

If you are using v1.5 or newer of the #provname, then you have the option of verifying that the flashing has been completed correctly. Selecting this will read back the data from the CM device after flashing, and confirm that it matches the original image. This will add extra time to the provisioning of each device; the amount of time added will depend on the size of the image.

If you select the firmware to install (this is optional), you can also customise this firmware with some specific configuration entries that will be merged into the bootloader binary. The available options can be found in the #link("https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#raspberry-pi-bootloader-configuration")[documentation on the Raspberry Pi website].

Click 'Save' when you have finished defining your new project; you will return to the Projects page, and your new project will be listed. Note that only one project can be active at any one time, and you can select it from this list.

== Scripts

A really useful feature of the #provname is the ability to run scripts on the image, before or after installation. Three scripts are installed by default in the #provname and can be selected when creating a new project. They are listed on the Scripts page.

#figure(
  image("diagrams/scripts.png"),
  caption: "Scripts page"
)

An example use of scripts might be to add custom entries to `config.txt`. The standard script `Add dtoverlay=dwc2 to config.txt` does this, using the following shell code:

```
#!/bin/sh
set -e

mkdir -p /mnt/boot
mount -t vfat $PART1 /mnt/boot
echo "dtoverlay=dwc2,dr_mode=host" >> /mnt/boot/config.txt
umount /mnt/boot
```

Click on 'Add script' to add your own customisations:

#figure(
  image("diagrams/addscript.png", width: 50%),
  caption: "Add script page"
)

== Labels

The #provname has the facility to print out labels for the devices being provisioned. The Labels page shows all the predefined labels that can be selected during the project editing process. For example, you may wish to print out DataMatrix or quick response (QR) codes for each board provisioned, and this feature makes this very easy.

#figure(
  image("diagrams/labels.png"),
  caption: "Labels page"
)

Click 'Add label' to specify your own:

#figure(
  image("diagrams/addlabel.png", width: 50%),
  caption: "Add label dialog"
)

== Firmware

The #provname provides the ability to specify which version of the bootloader firmware you wish to install on the #CM 4. On the Firmware page, there is a list of all the possible options, but the most recent one is usually the best.

#figure(
  image("diagrams/firmware.png"),
  caption: "Firmware page"
)

To update the list with the latest versions of the bootloader, click on the 'Download new firmware from GitHub' button.


= Possible problems

== Out-of-date bootloader firmware

If your #CM 4 is not detected by the #provname system when you plug it in, the bootloader firmware may be out of date. Note that all CM4 devices manufactured since February 2021 have the correct bootloader installed at the factory, so this will only happen with devices that were manufactured before that date.

== Already programmed eMMC

If the CM4 already has boot files in the eMMC from a previous provisioning attempt, then it will boot from the eMMC and the network boot required for provisioning will not occur.

If you wish to reprovision a CM4, you will need to:

- Connect a USB cable between the provisioning server and the micro USB port of the #CM 4 IO Board (labelled 'USB slave').
- Put a jumper on the CM4 IO Board (J2, 'Fit jumper to disable eMMC boot').

This will cause the Compute Module to perform a USB boot, in which case the provisioning server will transfer the files of the utility OS over USB.

After the utility OS has booted, it will contact the provisioning server over Ethernet to receive further instructions, and download additional files (e.g. the OS image to be written to eMMC) as usual.

Note, therefore, that an Ethernet connection in addition to the USB cable is still necessary.

== Spanning Tree Protocol (STP) on managed Ethernet switches

PXE booting will not work correctly if STP is enabled on a managed Ethernet switch. This can be the default on some switches (e.g. Cisco), and if that is the case then STP will need to be disabled for the provisioning process to work correctly.

= Production scenarios

== How to identify devices after programming

Often, a production line uses the #provname to program multiple devices at the same time and prints out labels that need to be appropriately assigned to boards; for example, with unique serial number information. This creates a need for some way of identifying which board requires which label.

=== #CM 4 IO board GPIO method

If you are using the #CM 4 IO board to program devices, then you can use the GPIO pins in a binary fashion on the IO board to define a programming device number. A post-install script can then be used to determine which board has just finished programming, and the label can be printed with, for example, the #CM 4 IO board designation so a production line operator can apply the label correctly.

Use jumpers at GPIO 5, 13, and 21 to the GND pin opposite those pins (pin 29 to pin 30, pin 33 to pin 34, and pin 39 to pin 40). The binary number you set with the jumpers will set the `$provisionboard` macro in the label template. Note that with three GPIO pins and thus three bits, only eight different programming stations are supported.

=== USB device method

If you are programming devices in situ in the final product, there may be no GPIO pins available for setting a board identifier. In this case, if USB ports are available, then a set of small-capacity USB memory sticks can be used, each one containing a file with a unique identifier. A USB stick is inserted into each device being programmed, and when programming is complete, a post-programming script reads the identifier; this ID is then used on the label so the operator knows which device to apply the label to.

=== Managed Ethernet switch

A further possibility is to use a managed Ethernet switch, which can identify which device is plugged into which port. One option is to colour-code the cables from the switch to the IO boards, and indicate on the labels which colour they correspond to.


== Resetting a CM4 to factory settings

Once a #pi-prefix CM4 device has been programmed, it will no longer appear to the #provname if you connect it wishing to reprogram it. This is because it now has a bootable system on its eMMC, so the network boot required by the #provname is never executed (unless the previous provisioning step has specifically enabled network boot as its primary boot mechanism).

Using USB to program the device has already been described in a previous section. There is also a procedure to reset the device to factory settings, should you wish to do this. The following instructions assume the use of a #pi-prefix device as the host as well as the standard #CM 4 IO board. The host should be running #pios with desktop.

Install the USBBOOT application and associated utilities using the instructions in its GitHub repository; this only needs to be done once: #link("https://github.com/raspberrypi/usbboot#readme")

Mount the #pi-prefix CM 4 on the IO board. Connect the IO board to the host #pi-prefix, and install a link on the header marked "Fit jumper to disable eMMC boot".

Now use `rpiboot` to start the CM4 in Mass Storage Mode.

```
cd usbboot
sudo ./rpiboot
```

Power up the IO board. After a few moments, one or more drives will appear on the host #pi-prefix. You can display these devices using the following:

```
lsblk
```

Which will produce output similar to the following:

```
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda           8:0    1 14.6G  0 disk
├─sda1        8:1    1  256M  0 part /media/pi/bootfs
└─sda2        8:2    1  3.6G  0 part /media/pi/rootfs
mmcblk0     179:0    0 14.8G  0 disk
├─mmcblk0p1 179:1    0  256M  0 part /boot
└─mmcblk0p2 179:2    0 14.6G  0 part /
```

You now need to reformat the device that is mounted at `/media/pi/bootfs`, which is `sda1`, as follows:

#warning[Make sure you have the right device! This could reformat the SD card in the #pi-prefix if you get the wrong one.]

```
umount /media/pi/bootfs
sudo mkfs -t vfat /dev/sda1
```

For most situations, the #pi-prefix CM4 should now appear to the #provname as a blank device. However, you may wish to format the `/media/pi/rootfs` device as well, to completely clear the system of data.

If the bootloader was changed during the original programming, then one final action is needed to reset that to factory settings:

```
cd usbboot/recovery
./update-pieeprom.sh
../rpiboot -d .
```

Reboot the IO board and the device's bootloader will be replaced with the default.

#note[Because of the way eMMC uses wear levelling, reformatting a device will not necessarily clear all the data. If you have private data on the eMMC you should use more advanced methods to wipe the device.]



