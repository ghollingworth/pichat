#import "@local/rpi-style:0.0.1": * 

#import "../../globalvars.typ": *

#show: rpi_whitepaper.with(
    title: "Raspberry Pi Touch Display Enclosure Mechanical Design",
    version_string: [Version 1.1],
    version_history: (
    [1.0], [1 November 2021], [Initial release],
    [1.1], [27 April 2022], [Copy edit, public release],
    ), 
    platforms: ()
)

#disp (#link("https://www.raspberrypi.com/products/raspberry-pi-touch-display/")

= Introduction

This whitepaper provides information for designing mechanical enclosures for the #disp.

The #disp is dual-source manufactured, and there are very slight differences in the mechanical design between the two manufacturers. This document describes those differences and provides possible mitigation mechanisms for ensuring that enclosure designs can incorporate either version of the panel. For the purposes of this document, the two versions of the panel will be designated '#sa' and '#sb'. #trading will not be publishing the names of the manufacturers used for the liquid crystal display (LCD) panel, or the panel datasheets.

#note[Both devices appear exactly the same to the #pi-prefix software, so from an operational point of view any differences can be ignored.]

= Mechanical differences

The actual differences between the two boards are minor, but the design of enclosures must ensure that the differences do not affect the integrity of the panels. Appendix A contains mechanical diagrams of the two displays, but the main difference is in the depth of the glass touchscreen on the panel. For #sa this is 0.70mm, while for #sb it is 1.10mm.

While this may seem insignificant, it does affect the design and/or implementation of the mechanical fixing of the display to an enclosure. Since the overall distance from the front of the display to the back of the display mount points is the same for both displays, this difference in glass thickness means that the distance from the rear of the glass to the back of the display mount points varies according to the supplier.

This variation must be taken into account when designing an enclosure, as if excess pressure is exerted on the back face of the glass when the mount screws are tightened, this can pull the glass away from the front of the panel, or perhaps crack it.

The issue is demonstrated in the following diagram. The blue ovals show that the glass is flush against the enclosure lip. However, due to the increased glass width, the same overall depth,  and consequently slightly smaller frame depth, there is now a gap between the mount points on the frame and the back of the enclosure, indicated in red. Overtightening the mount screws here applies excessive pressure on the edges of the display, and can lead to detachment or damage.

#figure(
  image("diagrams/enclosure_the_issue.svg"),
  caption: [Lipped enclosure showing the issue]
)

= Mitigation

There are a number of options available to mitigate the issues, including, but not limited to, the following:

- Optional shims/washers applied to the rear mount points when using #sb to ensure that the pressure on the glass back face is removed.
- Ensure mount screws are not over-torqued when using #sb, which would apply excessive pressure to the front of the panel. This may require a thread lock as the mount points cannot be tightened against the enclosure.
- Crushable foam around any enclosure lip to absorb the difference in glass depth. Applicable to all panel types. The foam must be carefully selected to ensure that the pressure on the back of the glass is minimised.
- Design enclosures to avoid the touchscreen glass sitting against a surface or lip that can apply pressure. Applicable to all panel types.
- Use double-sided tape around the edge of the display to stick to a lip on the enclosure, and do not use the mount points on the rear of the panel. You should ensure that any tape used is appropriate for the environment in which the display is used; for example, a hot environment may result in bonding failure.

#note[These are only suggestions as to possible mitigations. The enclosure designer is responsible for determining the most appropriate mounting scheme for the panel in their specific environment.]

#figure(
  image("diagrams/enclosure_foam_and_shims.svg", width: 70%),
  caption: [Lipped enclosure with possible mitigations]
)

#figure(
  image("diagrams/enclosure_no_lip.svg", width: 35%),
  caption: [Lipless enclosure]
)

= Appendix A

#figure(
  image("diagrams/panelA-mech.png"),
)
#figure(
  image("diagrams/panelB-mech.png"),
)

= Appendix B

== Standard handling precautions

- Avoid any strong mechanical shock which can break the glass.
- Do not apply excessive force to the panel surface.
- Avoid exposing the panel to static electricity which can damage the electronics. When working with the panel, be sure to ground your body and any electrical equipment you may be using.
- Do not expose the panel to sunlight or fluorescent light.
- The panel should be kept in an antistatic bag or other container resistant to static when in storage.
- Do not remove the panel or frame from the panel assembly.
- The polarising plate of the display is very fragile. Handle it very carefully, and do not touch, push, or rub the exposed polarising plate with anything harder than an HB pencil lead (glass, tweezers, etc.)
- Do not wipe the polarising plate with a dry cloth, as this may easily scratch the surface of the plate.
- Do not use ketone- or aromatic-based solvent to clean the panel. Clean using a soft cloth soaked with a naphtha-based solvent.
- When soldering, control the temperature and time of soldering to 320 ± 10°C and 3&#8211;5 seconds.
- Avoid liquids (include organic solvent) touching the panel, as this can stain.
- Strong electromagnetic interference sources such as switched-mode power supplies can lead to touch malfunctions (e.g. ghost touches). Therefore, the touch panel should be thoroughly tested once assembled in the target application.
- Continuously displaying the same static image can result in image burn-in.
- When using double-sided tape to attach the display to an enclosure, follow the rules and regulations as supplied by the original manufacturer of the double-sided tape.
- The liquids in an LCD are hazardous substances. Do not lick and swallow. If the liquid comes into contact with skin, cloth, etc., thoroughly wash immediately.
- The length of the mounting screws cannot exceed the depth from the thread hole to the back of the thin-film transistor backlight, to avoid bezel distortion caused by screw pressure.
- Do not operate the panel above the absolute maximum ratings.
- The panel may be coated with a film to protect the display surface. Be careful when peeling off this protective film since static electricity may be generated.
- The panels are designed to be used in an enclosure. If the final assembly has a different mechanical design, for example with the panel hanging in the air, the positioning and protection of the panel should be taken into account.
