#import "@local/rpi-style:0.2.0": *
#import "../../globalvars.typ": *

#let AWS="Amazon Web Services"
#let vscode="Visual Studio Code"
#let vscode_short="VSCode"

#show: rpi_whitepaper.with(
    title: [#AWS: Getting started on #boardname_pi5],
    release: [3],
    version_history: (
    [1], [20 Nov 2025], [Initial release],
    [2], [21 Nov 2025], [Update GitHub repository name],
    [3], [16 Dec 2025], [Copy edit],
    ),
    platforms: ("Pi 5"),
)

// If you are using CSpell for spell checking, add any words to ignore here. 
//cspell: ignore boardname venv boto3 awscli

= Introduction

== Applicable operating systems for this guide


This guide assumes you are using #pios with a full desktop and browser. Other OS installations (e.g. Ubuntu) are also likely to work, but this is not guaranteed. Some instructions require you to use a browser to set up #AWS; a full #pios installation includes both Chromium and Firefox.


= Overview

This document describes how to use #boardname_pi5 to connect to an #AWS (AWS) instance. #pi is a general-purpose computing device, so rather than providing a specific AWS IoT application, this document describes the basics of obtaining certificates, adding them to a #boardname_pi5, and testing the device using AWS Device Compliance.

This example uses Python and the AWS Python bindings to provide proof of principle. It does not go into detail on how to write AWS applications, nor does it cover the use of the AWS Internet of Things (IoT) C/C++ SDK.

= Hardware

#boardname_pi5 is a single-board computer (SBC) from #trading. It is a general-purpose computing device that can leverage AWS APIs and libraries to connect to AWS IoT.

== Product datasheet

Information on #boardname_pi5 can be found here:

/ Product brief: 
#link("https://pip-assets.raspberrypi.com/categories/892-raspberry-pi-5/documents/RP-008348-DS-1-raspberry-pi-5-product-brief.pdf")

== Standard kit contents

#boardname_pi5 is usually sold as a standalone unit, but it can also be purchased in Desktop Kit form with a keyboard, a mouse, a case, a power supply, micro-HDMI cables, and a copy of _The Official Raspberry Pi Beginner's Guide_.

#link("https://www.raspberrypi.com/products/raspberry-pi-5/")


== User-sourced items

Unless supplied in a Desktop Kit, the user will need to source their own power supply, HDMI cable, mouse, keyboard, and SD card. #trading sells all of these items globally through our Approved Reseller network.

#link("https://www.raspberrypi.com/resellers")


== Purchasable third-party items

None.

== Additional hardware references

None.

= Setting up your development environment

==	Tool installation (IDEs, toolchains, SDKs):

#set enum(numbering: ("1.a"))

+ IDE-based
 + #trading recommends Microsoft #vscode (#vscode_short) for software development on #trading devices, but this is not mandatory — users can use whichever integrated development environment (IDE) or development system they prefer 
 + If you are installing on a #trading device, use the following:
    ```bash
    sudo apt update
    sudo apt install code
    ```
 +	On Windows or Linux devices, please follow the standard #vscode_short installation instructions: #link("https://code.visualstudio.com/download")
 + 	You may find it useful to install #vscode_short extensions for Python
+ CLI-based:
 + The example code described here is written in Python and can easily be run from the command line
+ Python 3 is required, along with the AWS Python bindings

=== Creating a project folder and a Python virtual environment

The latest versions of Python and #pios require you to use virtual environments, into which the Python packages needed for the applications are installed.

To create a project folder and a Python virtual environment, do the following:

```sh
mkdir Pi5AWSExample
cd Pi5AWSExample

# Create the virtual environment
python3 -m venv venv

# Activate it 
source venv/bin/activate

# Update everything
pip install --upgrade pip

# Install AWS-specific libraries
pip install AWSIoTPythonSDK
```

=== Installing the example application

The example application is available from #trading's GitHub repo. Use the following command to clone the code to a pre-existing folder named `Pi5AWSExample`:

```bash
cd Pi5AWSExample
git clone https://github.com/raspberrypi/rpi-aws-examples.git
```

In a later section, we will edit the example Python code to customise it with the user's AWS 'thing' name, security keys, and topic names.

== Additional software references

Technical support for #trading devices can be found on the #trading forums at #link("https://www.raspberrypi.com/forums").

= Setting up your hardware

Full instructions for setting up a #boardname_pi5 can be found on the #trading website.

#link("https://www.raspberrypi.com/documentation/computers/getting-started.html")

= Setting up your AWS account and permissions

If you do not have an existing AWS account, refer to the online AWS documentation at #link("https://docs.aws.amazon.com/iot/latest/developerguide/setting-up.html", "Set up AWS account"). To get started, follow the steps outlined in the sections below:

- #link("https://docs.aws.amazon.com/iot/latest/developerguide/setting-up.html#aws-registration", "Sign up for an AWS account")

- #link("https://docs.aws.amazon.com/iot/latest/developerguide/setting-up.html#create-an-admin", "Create a user with administrative access")

- #link("https://docs.aws.amazon.com/iot/latest/developerguide/setting-up.html#iot-console-signin", "Open the AWS IoT console")


Pay special attention to the note sections.

== AWS terminology

Getting to grips with #AWS terminology and permissions is vital to ensuring everything works as expected. The following section explains the various concepts and naming schemes involved. 

=== ARNs, policies, permissions, and roles

==== ARNs

An Amazon Resource Name (ARN) is a unique identifier for an AWS resource, such as an EC2 instance, an S3 bucket, or an IAM user. It's a string that enables you to manage and control access to these resources within AWS services, including IAM policies, API calls, etc.

==== Policies

#quote(attribution: [Amazon], block: true)[
    In AWS, a policy is a document/object that defines permissions for an entity (user, group, or role) or resource. It dictates what actions an entity can perform on which AWS resources. These policies are crucial for managing access to AWS services and ensuring security within the AWS environment.]

/ How it works:\ 
Policies control access to AWS resources by specifying which actions are allowed or denied. 

Policies are typically written in JSON format and consist of statements defining the effect (allow or deny), actions, resources, and conditions of permissions. 

There are different types of policies, including:
- Identity-based policies, which are attached to users, groups, or roles and control what those identities can do
- Resource-based policies, which are attached to a specific resource (like an S3 bucket) and control who can access that resource

==== Permissions

#quote(attribution: [Amazon], block: true)[
    In AWS, a permission defines what actions a user, role, or service can perform on specific AWS resources. It's a grant of access, allowing or denying specific operations based on defined rules.]

/ How it works:\ 
Permissions are defined using identity and access management (IAM) policies, which specify which actions are allowed or denied. IAM is the AWS service responsible for managing permissions. 

==== Roles
#quote(attribution: [Amazon], block: true)[
    An AWS IAM role is an AWS identity that you create to grant permissions to trusted entities to access AWS resources, without needing to create separate credentials for each entity. It's like a set of permissions that can be assumed by users, applications, or services, to temporarily access specific resources within your AWS environment.]

/ How it works:\ 
Instead of assigning long-term credentials to users or applications, you create a role with specific permissions and allow trusted entities to assume that role temporarily. Unlike users, roles do not have passwords or access keys associated with them. Instead, roles provide temporary security credentials to whoever has the ability to assume that role.

=== Things

An AWS 'thing' is a device or a virtual entity that is registered and managed within the IoT platform. It's a way to model and track physical devices — such as sensors or actuators — or even abstract entities within the AWS ecosystem. Each thing has associated certificates and policies that define its interactions with AWS IoT services.

So, a Raspberry Pi SBC could be an AWS IoT thing. You can use the AWS console to give a thing a name and generate a unique certificate for that thing. These certificates need to be downloaded on the thing itself, as they uniquely identify it.

#note()[When you generate a certificate set on the console, you must download it straight away — you cannot go back and download them later.]

When the certificate is generated, the AWS console also provides a set of four keys: one private, one public, and two Amazon Root certificates, which are Certificate Authority blocks. See https://docs.aws.amazon.com/privateca/latest/userguide/PcaTerms.html

During the creation of an AWS thing, you also assign a policy to it, which is actually attached to the certificate. This policy defines what the thing is able to do (see above).

= Creating resources in AWS IoT

== Making a thing object

#note()[All of the following operations can be carried out on #boardname_pi5 itself.]

Rather than outlining how to do this here, please refer to the AWS documentation on creating a thing object. #link("https://docs.aws.amazon.com/iot/latest/developerguide/create-iot-resources.html#create-aws-thing")

In short, you should create a new thing with the name `Pi5AWSExample`, select 'No shadow', and then select 'Auto-generate a new certificate'. You do not need to attach a policy.

#warning()[During the creation process, you will be asked to download the certificate and keys. This is the only time that option is available, so make sure all of the keys are downloaded to your #boardname_pi5. You will need to add these keys to the example application.] 

= Provisioning the device with credentials

As this is simple example software, there are a few things you need to manually do to get it up and running. The main thing is to add the credentials (keys) downloaded in the previous section to the example code. These items are hardcoded into the example, so they need to be updated to the user's specific keys.

+ Copy all of the downloaded keys to where the example application was cloned (these can have rather long file names consisting of seemingly random letters)
+ Edit the program, filling in the following entries with the updated information

#block(inset: (left: 3.5em, right: 10em), 
table( columns: 2,
        table.header([Entry], [Content]),
        [THING_NAME], [Pi5AWSExample],
        [PRIVATE_KEY_PATH], [xxxxx-private.pem.key],
        [CERTIFICATE_PATH], [xxxxx-certificate.pem.crt],
        [IOT_ENDPOINT], [The endpoint is found in the test suite data (See the 'Run the example code' section below)],
)
)

The 'xxxxx' prefix represents the lengthy hexadecimal file names of the downloaded keys. 

== Creating a Device Advisor test suite

From the AWS IoT console, select 'Device Advisor/Test Suites', then select 'Create test suite'. Choose 'AWS IoT Core qualification test suite' for the test suite type, and 'MQTT 3.1.1' as the protocol, then click 'Next'. You will now be presented with a page titled 'Create test suite', which contains the tests needed for the Device Advisor qualification. Click 'Test suite properties' and give the test suite an appropriate name — for our example, we use 'Device Advisor Suite'. Click 'Next'. You now need to select a role; this is how you grant permission for AWS to use your certificates and such during Device Advisor testing. For our example, we'll create a new role, so select 'Create new role'.

== Creating a role

We need to specify access available to the Device Advisor.

For the 'Connect' option, enter the thing name that was specified when we created the #boardname_pi5 thing. In our example, this was `Pi5AWSExample`.

For 'Publish', 'Subscribe', 'Receive', and 'RetainPublish', we will enter a wildcard topic: `Pi5AWSExample*`, which allows any topics starting with `Pi5AWSExample` to be validated.

= Building the example code

As the software is written in Python, there is no need for any compilation.

= Running the example code

Start the test suite and run the example code on your #boardname_pi5. The SBC will then communicate with the test suite.

From the AWS IoT console, select 'Device Advisor/Test Suites', then select your newly created test suite by clicking on its name. On the subsequent screen, select 'Actions', then 'Run test suite'.

Select the AWS thing you want to test — in our case, `Pi5AWSExample`. In the 'Test endpoint' section, select 'Account-level endpoint'.

#important()[You need to copy the endpoint information from the 'Test endpoint' section into the Python example application (see the IOT_ENDPOINT configuration item in the example above). This tells the example application where to find the Device Advisor tests. As this endpoint is fixed to the test suite, it does not change, so you only need to do this once.]

Once the example code is updated with the endpoint, you can run the test suite by clicking 'Run test'. This will start up the Device Advisor test suite. You now need to run the example code in order to communicate with the test suite.

```bash
# cd to the location of your cloned example repository.
cd Pi5AWSExample/rpi-aws-examples
# Run the example
python3 Pi5AWSExample
```

After a few minutes — if all is working correctly — the Device Advisor test suite will display the results of the test.

= Verifying messages in AWS IoT Core

You can examine the logging done during the test by selecting the test case log links next to each part of the test suite. These are on the qualification results page displayed while the test is running. These logs display all of the messages that were exchanged between #boardname_pi5 and AWS, and can be very useful if you find that some tests are not passing.

= Debugging

As a #boardname_pi5 running #pios is a full Linux-based system (rather than a dedicated and targeted device), debugging is considerably easier. All of the features are available and easily accessible when working with the #pios desktop.

Device console output is simply viewed in the terminal windows used to start the example software, and it is easy to modify the example code in place (by adding commands like debugging print statements) to help with debugging. All of the standard Linux logging is available, and you can use #vscode_short's Python debugger, for example, to debug the Python example code.

Applications developed in C/C++ (not shown here) can also use IDEs like #vscode_short to carry out development and debugging on the device.


= Troubleshooting

Incorrect permissions are almost always the reason why programs may not work as intended, or at all. Remember to double-check your roles, permissions, policies, and device names.

Please use the #trading forums #link("https://forums.raspberrypi.com") for technical support from the community — this is usually the fastest way to get help. You can also get in touch with #trading's applications team at #link("mailto:applications@raspberrypi.com").

= Conclusions

This document describes how to get a simple AWS application up and running and how to pass the Device Advisor certification tests. It shows that #trading's SBCs are an effective way to provide IoT compute power that can easily leverage AWS to provide cloud-based back-end services.

The example application is extremely basic, and is there to show the principles of connecting, publishing, and subscribing. Users will need to develop their own applications targeted to their specific use case. Although the example application uses Python, AWS also provides a C/C++ SDK and other language bindings for application development, and the user should consider which option is most appropriate for them.

Although testing was carried out on a #boardname_pi5, there is no reason why earlier models running the same Raspberry Pi OS system would not work in the same way. Users should choose the device that is most appropriate for their application.
