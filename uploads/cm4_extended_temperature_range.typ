#import "@local/rpi-style:0.1.0": * 

#import "../../globalvars.typ": *

#show: rpi_whitepaper.with(
    title: [Compute~Module~4~extended temperature range report],
    release: [1],
    version_history: (
    [1], [1 Apr 2025], [Initial release],
    ), 
    platforms: ("CM4")
)

CM4 extended temperature range only.

#let oldrange="-20°C to +85°C"
#let newrange="-40°C to +85°C"
#let cm4="Compute Module 4"

= Introduction

The standard #pi-prefix #cm4 (CM4) is rated for use within a temperature range of #oldrange.

#trading has developed several extended temperature variants of #cm4 that can be used within the range of #newrange. This was achieved by using memory components with a wider temperature tolerance than those on the standard device; both the RAM and the eMMC have been upgraded to operate within the #newrange range. All other parts on the board were already rated to the extended range.


= Testing

The devices used were 2GB RAM, 4GB eMMC memory variants of #cm4. Three were tested in parallel.

== Constant stress test

Testing took place with the devices powered up, and with test scripts exercising the eMMC (basic Linux file handling) and RAM (allocating memory, writing to the memory, executing read-back tests, deallocating memory). Devices were connected to the network via Ethernet at all times and monitored remotely via an SSH connection.

Testing took place in a test oven, cycling from -40°C to +85°C to -40°C in approximately two hours. These cycles continued for 384 hours uninterrupted, with the devices running the test scripts the entire time. At the end of the testing process, the devices were powered down, removed from the oven, and booted up, and a Linux memory tester application was run to ensure there were no issues with the RAM.

== Cold startup test

This test was to prove that startup works as expected in very cold environments. The test chamber was set to -50°C, and unpowered boards were left to cool down for 30 minutes. The test involved powering up the devices from cold and recording the results. After each subsequent test, the boards were allowed to cool down for 10 minutes, and then the test restarted.

== Long-term general usage test

For this test, #pios was installed on #cm 4. The device was powered up in a test chamber set to cycle between -40°C and +85°C for a minimum of 500 hours. Interactions with the OS (checking the desktop was running, typing in a terminal prompt, moving windows around, etc.) were performed at random intervals. The `stress` program was occasionally run on the device (exercising all four cores at 100%) to simulate spontaneous high workloads.

== Results

During the tests, the #cm4 devices continued to function correctly and remained connected to the network via Ethernet at all times. No memory failures were reported during the test, nor during the post-oven memory testing. 

During the high-temperature stages of testing, at an ambient temperature of 85°C, the SoC reached 102°C and began to run at a reduced speed. This was due to thermal throttling, which was triggered to reduce the core temperature as much as possible. A device having an extended temperature range does NOT mean that the CPU's performance is improved at higher temperatures, and users should be aware that the extended temperature devices use the same throttling mechanism as the standard range ones, so will perform in the same way. 

#cm4 ran uninterrupted for the full 500-hour long-term general usage test, with no faults detected.


== Conclusion

#pi now has a #cm4 variant with an operating temperature range of #newrange, non-condensing. It should be noted that optimal RF wireless performance occurs between -20°C and +75°C.

The extended temperature range variant of #cm4 is a special-order device.
