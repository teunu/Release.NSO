# North Sawyer Overhaul Repository
North Sawyer Overhaul (NSO) is a world overhaul project for the game Stormworks. NSO aims to provide ample gameplay oppertunities, new workbenches, railways, roads and other details to the Sawyer Islands. NSO has been a main driver behind modding tools for our community as it continues development.

**Download the latest release of NSO <a href="">here</a>.**

## Our Roadmap
NSO is still in development. Meanwhile, we allow access to updates so we can gather feedback. Our priorities are on the East Island. We hope to work on the entire Meyer island chain (the green island) before calling the mod finished.

## (De) Installation and Updating
Follow these videos to help you install, uninstall, or update NSO. [LINK VIDEO]

## Commands 
**General**:
- ``?nso info`` to show the intro message
- ``?nso commands`` to list available nso commands

**Admin**:
- ``?nso spawn FILTER`` spawns nso objects.
- ``?nso despawn FILTER`` despawns nso objects.
- ``?nso respawn FILTER`` respawns nso objects.
- ``?nso catanery spawn FILTER`` spawns catanery.
- ``?nso catanery despawn FILTER`` despawns catanery.
- ``?nso catanery respawn FILTER`` respawns catanery.
- ``?nso catanery height HEIGHT FILTER`` respawns nso objects.
  - ``HEIGHT`` Translates to height above the top of the rail in meters. Default value is 5.5 
- ``?nso traffic spawn`` spawns traffic lights.
- ``?nso traffic despawn`` despawns traffic lights.
- ``?nso traffic respawn`` respawns traffic lights.

**Extra details**: <br>
- NSO (de/re)spawn commands known what objects have been spawned to prevent diplocates.
- General spawn ``FILTER`` include:
  - ``LOD`` for road markings and other level of detail objects
  - ``singalling_equipment`` for train signals and junctions
- Catanery ``FILTER`` is always optional, options are: 'Cat1', 'Cat2', ... 'Cat5'.
- Commands for managing traffic lights are seperated for technical reasons and will need to be run individually from the general commands
