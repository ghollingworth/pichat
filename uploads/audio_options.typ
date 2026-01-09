#import "@local/rptl-style:0.0.1": * 

#import "../../globalvars.typ": *

#show: rptl_whitepaper.with(
    title: "A whitepaper giving a high-level overview of audio options on Raspberry Pi SBCs",
    version_string: [Version 1.0],
    version_history: (
    [1.0], [1 Apr 2025], [Initial release],
    ), 
    platforms: ("AllSBC", "AllCM", "Pi400", "Pi500")
)

#let sbc="Raspberry Pi SBC"
#let sbcs="Raspberry Pi SBCs"
#let PA=raw("PulseAudio")
#let PW=raw("PipeWire")
#let BT="Bluetooth"

= Introduction

Over the years, the options available for audio output on #sbcs (single-board computers) have become more numerous, and the way they are driven from software has changed.

This document will go through many of the available options for audio output on your #pi-prefix device and provide instructions on how to use audio options from the desktop and the command line.


This whitepaper assumes that the #pi device is running #pios and is fully up to date with the latest firmware and kernels.

= Raspberry Pi audio hardware

== HDMI

All #sbcs have an HDMI connector that supports HDMI audio. Connecting your #sbc to a monitor or television with speakers will automatically enable HDMI audio output through those speakers. HDMI audio is a high-quality digital signal, so the results can be very good, and multichannel audio like DTS is supported.

If you are using HDMI video but want the audio signal to split off — for example, to an amplifier that does not support HDMI input — then you will need to use an additional piece of hardware called a splitter to extract the audio signal from the HDMI signal. This can be expensive, but there are other options, and these are described below.

== Analogue PCM/3.5 mm jack

#pi models B+, 2, 3, and 4 feature a 4-pole 3.5 mm audio jack that can support audio and composite video signals. This is a low-quality analogue output generated from a PCM (pulse-code modulation) signal, but it is still suitable for headphones and desktop speakers.

#note[There is no analogue audio output on #pi-prefix 5.]

The jack plug signals are defined in the following table, starting from the cable end and ending at the tip. Cables are available with different assignments, so make sure you have the correct one.

#table(
    columns:2, 
    table.header([Jack segment], [Signal]),
    [Sleeve], [Video],
    [Ring 2], [Ground],
    [Ring 1], [Right],
    [Tip], [Left],
)


== I2S-based adapter boards

All models of #sbcs have an I2S peripheral available on the GPIO header. I2S is an electrical serial bus interface standard used to connect digital audio devices and communicate PCM audio data between peripherals in an electronic device.

#trading manufactures a range of audio boards that connect to the GPIO header and use the I2S interface to transfer audio data from the SoC (system on a chip) to the add-on board.

Note: Add-on boards that connect via the GPIO header and adhere to the appropriate specifications are known as HATs (Hardware Attached on Top). Their specifications can be found here: #link("https://datasheets.raspberrypi.com/")

The full range of audio HATs can be seen on the #trading website: #link("https://www.raspberrypi.com/products/")

There are also a large number of third-party HATs available for audio output, for example from Pimoroni, HiFiBerry, Adafruit, etc., and these provide a multitude of different features.


== USB audio

If it is not possible to install a HAT, or you are looking for a quick and easy way to attach a jack plug for a headphone output or a microphone input, then a USB audio adapter is a good choice. These are simple, cheap devices that plug into one of the USB-A ports on the #sbc.

#pios includes drivers for USB audio by default; as soon as a device is plugged in, it should show up on the device menu that appears when the speaker icon on the taskbar is right-clicked.

The system will also automatically detect if the attached USB device has a microphone input and enable the appropriate support.


== Bluetooth

#BT audio refers to the wireless transmission of sound data via #BT technology, which is very widely used. It enables the #sbc to talk to #BT speakers and headphones/earbuds, or any other audio device with #BT support. The range is fairly short — about 10 m maximum.

#BT devices need to be 'paired' with the #sbc and will appear in the audio settings on the desktop once this is done. #BT is installed by default on #pios, with the #BT logo appearing on the desktop taskbar on any devices that have #BT hardware installed (either built in or via a #BT USB dongle). When #BT is enabled, the icon will be blue; when it is disabled, the icon will be grey.


= Software support

The underlying audio support software has changed considerably in the full #pios image, and, for the end user, these changes are mostly transparent. The original sound subsystem used was ALSA. #PA succeeded ALSA, before being replaced by the current system, which is called #PW. This system has the same functionality as #PA, and a compatible API, but it also has extensions to handle video and other features, making the integration of video and audio much easier. Because #PW uses the same API as #PA, #PA utilities work fine on a #PW system. These utilities are used in the examples below.

To keep the image size down, #pios Lite still uses ALSA to provide audio support and does not include any #PW, #PA, or #BT audio libraries. However, it is possible to install the appropriate libraries to add those features as required, and this process is also described below.

== Desktop

As mentioned above, audio operations are handled via the speaker icon on the desktop taskbar. Left-clicking on the icon brings up the volume slider and mute button, whilst right-clicking brings up a list of available audio devices. Simply click on the audio device that you want to use. There is also an option, via right-click, to change the profiles used by each device. These profiles usually provide different quality levels.

If microphone support is enabled, a microphone icon will appear on the menu; right-clicking on this will bring up microphone-specific menu options, such as input device selection, whilst left-clicking brings up input level settings.

=== #BT

To pair a #BT device, left-click on the #BT icon on the taskbar, then select 'Add Device'. The system will then start looking for available devices, which will need to be put into 'Discover' mode to be seen. Click on the device when it appears in the list and the devices should then pair. Once paired, the audio device will appear in the menu, which is selected by clicking the speaker icon on the taskbar.


== Command line

Because #PW uses the same API as #PA, the majority of the #PA commands used to control audio work on #PW. `pactl` is the standard way of controlling #PA: type `man pactl` into the command line for more details. 


=== Prerequisites for #pios Lite

On a full installation of #pios, all the required command line applications and libraries are already installed. On the Lite version, however, #PW is not installed by default and must be manually installed to be able to play back sound.

To install the required libraries for #PW on #pios Lite, please input the following:

```
sudo apt install pipewire pipewire-pulse pipewire-audio pulseaudio-utils
```

If you intend on running applications that use ALSA, you will also need to install the following:

```
sudo apt install pipewire-alsa
```


Rebooting after installation is the easiest way to get everything up and running.

=== Audio playback examples

Display a list of installed #PA modules in short form (the long form contains a lot of information and is difficult to read):

```
$ pactl list modules short
```

Display a list of #PA sinks in short form:

```
$ pactl list sinks short
```

On a #pi-prefix 5 connected to an HDMI monitor with built-in audio and an additional USB sound card, this command gives the following output:

```
$ pactl list sinks short
179	alsa_output.platform-107c701400.hdmi.hdmi-stereo	PipeWire	s32le 2ch 48000Hz	SUSPENDED
265	alsa_output.usb-C-Media_Electronics_Inc._USB_PnP_Sound_Device-00.analog-stereo-output	PipeWire	s16le 2ch 48000Hz	SUSPENDED
```

#note[#pi-prefix 5 does not have analogue out.]

For a #pios Lite install on a #pi-prefix 4 — which has HDMI and analogue out — the following is returned:

```
$ pactl list sinks short
69 alsa_output.platform-bcm2835_audio.stereo-fallback	PipeWire 	s16le 2ch 48000Hz	SUSPENDED
70 alsa_output.platform-107c701400.hdmi.hdmi-stereo	PipeWire	s32le 2ch 48000Hz	SUSPENDED
```

To display and change the default sink to HDMI audio (noting that it may already be the default) on this installation of #pios Lite, type in:

```
$ pactl get-default-sink
alsa_output.platform-bcm2835_audio.stereo-fallback
$ pactl set-default-sink 70
$ pactl get-default-sink
alsa_output.platform-107c701400.hdmi.hdmi-stereo
```


To play back a sample, it first needs to be uploaded to the sample cache, in this case on the default sink. You can change the sink by adding its name to the end of the `pactl play-sample` command:

```
$ pactl upload-sample sample.mp3 samplename
$ pactl play-sample samplename
```

There is a #PA command that is even easier to use to play back audio:

```
$ paplay sample.mp3
```

`pactl` has an option to set the volume for the playback. Because the desktop uses #PA utilities to get and set audio information, the execution of these command line changes will also be reflected in the volume slider on the desktop.

This example reduces the volume by 10%:

```
$ pactl set-sink-volume @DEFAULT_SINK@ -10%
```

This example sets the volume to 50%:

```
$ pactl set-sink-volume @DEFAULT_SINK@ 50%
```

There are many, many #PA commands that are not mentioned here. The #PA website (#link("https://www.freedesktop.org/wiki/Software/PulseAudio/)") and the man pages for each command offer extensive information about the system.

=== #BT

Controlling #BT from the command line can be a complicated process. When using #pios Lite, the appropriate commands are already installed. The most useful command is `bluetoothctl`, and some examples of it in use are provided below.

Make the device discoverable to other devices:

```
$ bluetoothctl discoverable on
```

Make the device pairable with other devices:

```
$ bluetoothctl pairable on
```

Scan for #BT devices in range:

```
$ bluetoothctl scan on
```

Turn off scanning:

```
$ bluetoothctl scan off
```

`bluetoothctl` also has an interactive mode, which is invoked by using the command with no parameters. The following example runs the interactive mode, where the `list` command is entered and the results shown, on a #pi-prefix 4 running #pios Lite Bookworm:

```
$ bluetoothctl
Agent registered
[bluetooth]# list
Controller D8:3A:DD:3B:00:00 Pi4Lite [default]
[bluetooth]#
```

You can now type commands into the interpreter and they will be executed.

A typical process for pairing with, and then connecting to, a device may read as follows:

```
$ bluetoothctl
Agent registered
[bluetooth]# discoverable on
Changing discoverable on succeeded
[CHG] Controller D8:3A:DD:3B:00:00 Discoverable on
[bluetooth]# pairable on
Changing pairable on succeeded
[CHG] Controller D8:3A:DD:3B:00:00 Pairable on
[bluetooth]# scan on

< could be a long list of devices in the vicinity >

[bluetooth]# pair [mac address of device, from the scan command or from the device itself, in the form xx:xx:xx:xx:xx:xx]
[bluetooth]# scan off
[bluetooth]# connect [same mac address]
```

The #BT device should now appear in the list of sinks, as shown in this example from a #pios Lite installation:

```
$ pactl list sinks short
69 alsa_output.platform-bcm2835_audio.stereo-fallback	PipeWire 	s16le 2ch 48000Hz	SUSPENDED
70 alsa_output.platform-107c701400.hdmi.hdmi-stereo	PipeWire	s32le 2ch 48000Hz	SUSPENDED
71 bluez_output.CA_3A_B2_CA_7C_55.1	PipeWire	s32le 2ch 48000Hz	SUSPENDED
$ pactl set-default-sink 71
$ paplay <example_audio_file>
```

You can now make this the default and play back audio on it.


= Conclusions

There are a number of different ways to produce an audio output from #trading devices, catering to the vast majority of user requirements. This whitepaper has outlined those mechanisms and provided information about many of them. It is hoped that the advice presented here will help the end user choose the right audio output scheme for their project. Simple examples of how to use the audio systems have been provided, but the reader should consult the manuals and man pages for the audio and #BT commands for more detail.
