#import "@local/rpi-style:0.0.1": * 

#import "../../globalvars.typ": *

#show: rpi_whitepaper.with(
    title: "Building a Custom Operating System Image for the Raspberry Pi",
    version_string: [Version 1.0],
    version_history: (
    [1.0], [19 October 2021], [Initial release],
    ), 
    platforms: ("AllSBC", "AllCM", "Pi400", "Pi500")
)

= Introduction

#trading maintains and distributes a standard Linux-based operating system (OS) for the #pi-prefix called #pios. This is a full-featured OS that comes in three versions.

#table(
    columns: 2, 
    table.header([Version], [Features]),
    [Lite], [A cut-down version of #pios that boots to a console],
    [With desktop], [Standard #pios distribution that boots to a desktop],
    [With desktop and software], [Standard #pios distribution that boots to a desktop and also includes our recommended software (e.g. LibreOffice)],
)


While our three versions cover many use cases, when choosing an OS for a industrial system, perhaps in an embedded environment, you may find that none of them are suitable. This document introduces systems for creating your own OS image with the exact feature set you need for your use case.

#note[Before embarking on building your own OS image, it's also worth checking for third-party OS distributions that may be more suited to your requirements. #trading does not maintain a list of third-party operating systems as it would be constantly changing, but they are easily found using a web search.]

== What to expect

Building an OS image is not a trivial task, and although there are tools available to make it easier, you need to ensure that you have the resources and skillset to complete the task. You will need a system to do the building of the OS; you can use a #pi-prefix for this, but we recommend something with a little more processing power, for example a decent i7 or equivalent machine with 8GB of random-access memory and a fast solid-state disk.

Linux provides the optimal environment for #br and #yo, which can be native on the machine or running in a virtual machine such as VirtualBox.

The end result of the #br project should be a custom image targetted specifically at your requirements. This is likely to be smaller in size than the standard #pios images and it could also perform better, with faster boot times.

This document should be regarded as an introduction to two common methods of generating a distribution. It is by no means comprehensive, and the user will need to refer to the appropriate documentation for anything more than the simple cases outlined here.

= Choosing a toolchain

There are two main build systems for custom Linux distributions, #br and #yo. While the end results are similar, they approach the problem in different ways; there are pros and cons to both.

#note[#trading does not use either #br or #yo, but a Debian-specific package builder with extra custom scripts. This is usually much too complicated for most industrial use cases so will not be described here.]

Features common to #br and #yo

- Can build a complete file system, read-only if required, from the sources; packages can be customised via configuration files or patches
- Allow selection of specific kernels
- Can be built using cross-toolchains for faster development

== Advantages of #br

- Uses relatively easy to understand makefiles
- Easy to customise the root file system using overlays
- Low resource requirements, so faster on #pi-prefix devices

== Advantages of #yo

- Being a Linux Foundation project, it has a larger community of users that can help with problems
- Using meta-layers, the build configuration can be easily shared
- Includes a package management system

On the whole, unless you need a package management system, #br is probably the best option for an industrial or commercial device. However, this document will briefly describe how to use both build systems; the user is left to decide which one is most suitable for their use case.


= Buildroot

It is not possible to incorporate all the required #br instructions here; #br has its own #link("https://buildroot.org/")[website] and documentation to which you should refer while reading this document.


== Prerequisites

Buildroot only runs on Linux systems and expects a number of standard Linux tools to be preinstalled. Many of the following are usually already installed on a standard Linux system, but this command will install all the required packages:

```console
sudo apt install sed make binutils gcc g++ bash patch gzip bzip2 perl tar cpio python unzip rsync wget libncurses-dev
```

You can download the #br system from GitHub:

```console
git clone git://git.buildroot.net/buildroot
```

By default, this will get you a development branch; use `git branch -a` to find the latest version, which will be something like 2021.08.x.

```console
cd buildroot
git checkout 2021.08.x
```

== Getting started

We now need to configure the #br system. There are a number of different menu systems that can be used, some requiring more libraries to be installed. For simplicity, we will us one that works out of the box.

There is actually quite of lot of configuration needed, and fortunately #br provides us with a shortcut by including a lot of predefined configurations, including many for #pi-prefix devices. You can list all the available default configurations using:

```console
make list-defconfigs
```

For our examples here, we will chose a #pi-prefix 4B default.

```console
make raspberrypi4_defconfig
```

At this stage we could actually build our system! This might take a while (3 hours or more on a #pi-prefix 4), so skip this to go on to customising the build.

#note[On a #pi-prefix 4 there is about a minute of thinking before anything appears, so be patient! Also, don't use the -j option to parallelise the build: this is done automatically in subprojects, and using -j can stop the build from completing successfully.]

```console
make all
```

Now, to actually change the build to something more specific we run the configuration scripts, which provide a hierarchical menu allowing us to set many different options.

```console
make nconfig
```

We will make a simple change at this point just to get the hang of the menus. Select 'System Configuration', then 'System banner'. Enter some new text to replace the 'Welcome to Buildroot' text. Now press F9, and save the new configuration.

Now we can build. During the build a lot of source code is downloaded and built, and this can take a few hours on a #pi-prefix 4.

```console
make all
```

=== Configuring a new project

It's almost certain you will need to customise the build to your specific use case. There are a number of ways of doing this; here, we will discuss creating new board project files and configuration files.

All boards supported by buildroot, including #pi-prefix boards, are stored in the `boards` folder; the #pi-prefix configurations are in `boards/raspberrypi*`. In addition, the configuration files for each #pi-prefix device are in `configs`. It's these configuration files that are used to produce the list of configurations when using `make list-defconfigs`. These configuration files will reference the data in the `boards/raspberrypi*` folders, as we will see in a moment.

To create a new configuration, and assuming you are going to make changes to the `config.txt` and other files, first make a copy of the `boards/raspberrypi` folder.

```console
cp -R board/raspberrypi board/raspberrypi_custom
```

This gives us a safe place for our new project.

Now we need to create a new configuration file for our new project. We do this by loading up a standard configuration, making some changes, then saving it as a new configuration. We will be using a #pi-prefix 4B as our base; you can use any of the Raspberry Pi ones listed by `make list-defconfigs`.

```console
make raspberrypi4_defconfig
make nconfig
```

To save the current configuration as a new config, you can do the following:

```console
make nconfig
```

Now select the 'Build options' item and set the 'Location to save #br config' option to the required location. In this example case, let's just change raspberrypi4_defconfig to raspberrypi_custom_defconfig.

While we are configuring, we can also change the location of the board-specific data to match our new `boards/raspberrypi_custom` location.

Select the 'System Configuration' option from the top level, find the 'Custom scripts to run before creating filesystem images' option, and set the location to the new folder. Do the same for 'Custom scripts to run after creating filesystem images'. We'll be altering these scripts later.

Now exit the configuration, and do the following to save the configuration as a default configuration:

```console
make savedefconfig
```

If you make any further changes (adding packages, etc.) you should use `make savedefconfig` to ensure that the current config is copied to the default configuration.


=== Adding new features to the build

So far, our configuration is the same as the minimal #pi-prefix 4B supplied by buildroot. Now we need to customise the build to our specific use case. Of course, the specifics of any particular use case are down to you, the customer, so this document will simply show the basic principles.

For this example we will add the secure shell (SSH) server Dropbear, which is a popular and small alternative to sshd.

So, run up the #br menu system, then select Target packages', then 'Networking applications', and scroll down the list until you find 'dropbear'. Use the space bar to select the application. A number of extra menu items will appear, but the default settings will be fine.

Save the configuration, and exit the menu system. You can now `make` the file system, and Dropbear will be included! Flash the new image to a Secure Digital (SD) card, start up the #pi-prefix, and you should now be able to connect to the device via Ethernet using an SSH client.

You can go ahead and add all the required packages in the same way.

=== The kernel

The default #br configuration downloads a specific kernel tree from the #pi-prefix GitHub repository, which is what is built and added to the final image.

This kernel is identified by a commit ID, which may not be the one you actually want (i.e. it may be out of date). You can change which commit ID is used when grabbing the tarball by running `make nconfig` and going to the 'Kernel' section. Find the option 'URL of custom kernel tarball', which will have a couple of really long hexadecimal numbers in it. Replace those numbers with the commit ID of the specific commit on the Linux tree on the GitHub repo you are using, which could be your own fork of the #pi-prefix repo. Note if you are using your own repo, you will also need to set the appropriate location on the same option.

If you want to change some of the kernel settings to customise the kernel for your particular use case, there are a number of options. Once the kernel has been downloaded by #br (during an initial `make all`) you can configure it in place using the standard kernel configuration menus, but via the #br make system:

```console
make linux-nconfig
```

If you already have a kernel configuration file, you can tell the build to use it by selecting the option 'Using a custom (def)config file' under 'Kernel'/'Kernel Configuration'. This will then enable an option to set a path to your kernel configuration file, which you can place in your custom board folder.

There are many other options for working with the kernel that we will not go in to here. The #br documentation is a very good reference.

=== Customising `config.txt` and firmware versions

It is very likely you will want to have your own version of `config.txt` as the one installed by default is extremely minimal, for example if you have specific hardware requirements that require one or more dtoverlay entries or similar.

#br recommends that changes to, or replacement of, `config.txt` should be done in the post-build bash script. This script is one of the files copied when the `boards/raspberrypi_custom` folder was created earlier. There are two scripts, `post_build.sh` and `post_image.sh`; we need to modify `post_build.sh` as the changes we need to make are required prior to making the final image.

One option is to add items to the script that in turn make changes to the default `config.txt` file. For example:

```
# Update our config.txt
# Check the file exists
if [ -e ${BINARIES_DIR}/rpi-firmware/config.txt ]; then
    # Add a dtoverlay option to the end of the file
    echo 'dtoverlay=gpio-shutdown,gpio_pin=5,active_low=1' >> ${BINARIES_DIR}/rpi-firmware/config.txt
fi
```

Any number of extra lines can be added to the default `config.txt` file like this. However, if you have major changes, it might be easier to simply replace the entire `config.txt` file with a custom version. The following bash snippet will replace the default config with a custom one from the `boards` folder; just add it to the `post_build.sh` script.

```
# Update our config.txt
cp board/raspberrypi_custom/config.txt ${BINARIES_DIR}/rpi-firmware/config.txt
```

Note that the `$#BINARIES_DIR/rpi-firmware/` folder also contains the kernel `cmdline.txt`, so you can also make changes there as necessary. If needed, you could also copy in specific firmware versions (`start*.elf`, `fixup*.dat`) and device tree overlays.

= Yocto

It is not possible to incorporate all the required #yo instructions here; #yo has its own #link("https://https://www.yoctoproject.org/")[website] and documentation to which you should refer while reading this document.

There is a good #link("https://docs.yoctoproject.org/current/overview-manual/yp-intro.html#what-is-the-yocto-project")[introduction to #yo] on their website.


== Prerequisites

#yo runs only on Linux systems and expects a number of standard Linux tools to be preinstalled. The #link("https://docs.yoctoproject.org/current/ref-manual/system-requirements.html#required-packages-for-the-build-host")[#yo website] has full instructions for installation on a number of different Linux systems.

Defining your file structure is up to you; here, we will create a basic project folder in which we will clone various git repositories to implement the #yo system. At the time of writing, the release branch of the #yo project is 'hardknott', which is used in the following clone.

```console
mkdir rasp_yocto_project
cd rasp_yocto_project
git clone -b hardknott git://git.yoctoproject.org/poky.git poky
```

== The layer concept

#yo uses the concept of _layers_, and for a new board you would define a new layer. However, there is already a layer defined for Raspberry Pi boards, so we will use that. Layers in turn have various recipes, which define how everything is built.

To get the meta layer for #pi-prefix, use the following git command. According to the `meta-raspberrypi` `README.txt` it has two dependencies: `poky`, which is already installed, and `openembedded`, which we also install here:

```console
git clone -b hardknott git://git.yoctoproject.org/meta-raspberrypi
git clone -b hardknott git://git.openembedded.org/meta-openembedded
```

== Building the default image

We need to initialise the build environment, using scripts provided by `poky`:

```console
. poky/oe-init-build-env
```

This will display a page of text, but what it has done is create some default configuration files that now need to be edited to add various paths to layers and their recipes. The recipes that are required for the build are listed in the `meta-raspberrypi` `README.txt` file; an extract follows:

```
## Dependencies

This layer depends on:

* URI: git://git.yoctoproject.org/poky
  * branch: master
  * revision: HEAD

* URI: git://git.openembedded.org/meta-openembedded
  * layers: meta-oe, meta-multimedia, meta-networking, meta-python
  * branch: master
  * revision: HEAD
```

So, for the `meta-openembedded` layers we need to provide direction to the `meta-oe`, `meta-multimedia`, `meta-networking`, and `meta-python` sublayers.

```console
nano build/conf/bblayers.conf
```

Add the following to the 'BBLAYERS' section:

```
  ${TOPDIR}/../meta-raspberrypi
  ${TOPDIR}/../meta-openembedded/meta-oe \
  ${TOPDIR}/../meta-openembedded/meta-multimedia \
  ${TOPDIR}/../meta-openembedded/meta-networking \
  ${TOPDIR}/../meta-openembedded/meta-python \
```

Now we have to edit the local configuration file to specify the final details of the build, for example which machine it targets:

```console
nano build/conf/local.conf
```

Find the section with the 'MACHINE' entries, and add the following:

```
MACHINE ?= "raspberrypi4"
```

This obviously sets up the build for an image compatible with a #pi-prefix 4B. The #pi-prefix layers package provides a number of different machine types; a list can be found in `meta-raspberrypi/docs/layer-contents.md`, but is repeated here:

- raspberrypi
- raspberrypi0
- raspberrypi0-wifi
- raspberrypi2
- raspberrypi3
- raspberrypi3-64 (64-bit kernel and userspace)
- raspberrypi4
- raspberrypi4-64 (64-bit kernel and userspace)
- raspberrypi-cm (dummy alias for raspberrypi)
- raspberrypi-cm3

You also need to tell the build to create a #pi-prefix compatible image file that can be used directly by #pi-prefix Imager. Add the following to the `local.conf` file:

```
# For SD card image
IMAGE_FSTYPES = "tar.xz ext3 rpi-sdimg"
```

Depending on the capabilities of your build machine, it might be worth adding something similar to the following, to reduce the number of processor cores used during the build. Often, the default of using all cores can grind the build machine to a halt, and in some circumstances cause unexplained build errors. The following sets it to use at most two cores. Setting this to the number of cores minus one or two will give a slower build, but your machine will continue to be usable during the build!

```
BB_NUMBER_THREADS = "2"
PARALLEL_MAKE = "-j 2"
```

You can now make the image, which is a simple `bitmake` command. On a first run this can take some hours to complete, depending on the capabilities of the build machine.

```console
bitbake core-image-base
```

After a successful build the image will be `build/tmp/deploy/images/raspberrypi4/core-image-base-raspberrypi4.rpi-sdimg`. The full location and filename will depend on the particular machine being built, in this case `MACHINE` was set to `raspberrypi4`.

You can now use #pi-prefix Imager to program an SD card via the 'Custom Image' option.

=== Customising a Yocto build

As has already been mentioned, #yo builds use the concept of layers and recipes, and it's easy to add a new recipe to your project. These recipes contain the features you may wish to add to your distribution. The OpenEmbedded project, which we have already included in our `bblayers.conf` file, has a considerable number of recipes that you can use.

The #link("https://layers.openembedded.org/layerindex/branch/master/layers/")[OpenEmbedded project website] has a useful system for finding layers and recipes you may wish to include. Select the 'Recipes' tab. This gives a search box, to help locate the package we want to include, and we will use the nano editor package as an example. Type 'nano' into the box and click 'Search'.

The results show that the nano package is in the `meta-oe` layer, which we have already added to the `bblayers.conf` file, so we now need to tell the system that we want the nano recipe to be included. Adding recipes is done using the `IMAGE_INSTALL_append` command in the `local.conf file`, so to add nano use the following, noting the leading space:

```
IMAGE_INSTALL_append = " nano"
```

Now rebuild, and you will see that the nano package is downloaded and built into the image.

=== Customising `config.txt`

The `meta-raspberrypi` layer provides a number of options that can be added to the `local.conf` file to influence the content of the `config.txt` file. The full set is documented at `../meta-raspberrypi/docs/extra-build-config.md`. For example, to set the boot delay and add a configuration that is not covered by the standard set of options (`arm_64bit`), try the following:

```
BOOT_DELAY = "10"

RPI_EXTRA_CONFIG = ' \n \
# Use 64 bit kernel \n \
arm_64bit=1 \n \
'
```

After a build, you can examine the contents of the `config.txt` file at `build/tmp/deploy/images/raspberrypi4/bootfiles/config.txt`. The `boot_delay` parameter will be set to 10, and there will be a new section at the end of the file with the extra configuration options.

// ==== Customising `cmdline.txt`

//TBD
//****
//EDIT QUERY +
//TBD!
//****

= Conclusion

This document has only scratched the surface of what is possible with these distribution build tools. They both have extensive documentation which should be followed to really get the best out of the systems. Hopefully this introduction will be enough to get you started.

As to the choice between #br and #yo, if you are looking to generate a small, customised image for a #pi-prefix device, #br is easy to install and easy to configure. It does not provide in-field updating, and some of its more interesting features can be difficult to figure out.

#yo does provide the ability for in-field updates, and has a better support community, but can be a little more difficult to get up and running, and tuned to your particular use case.