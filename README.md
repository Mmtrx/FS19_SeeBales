# FS19_SeeBales
This mod will cause both the PDA player map and the ingame Menu map to show small hotspots for bale and pallet objects where ever they exist. The hotspots will either show icons representing the various objects, whether bales or pallets, or small colored markers.

The icons will look like the object itself, whereas the markers will represent objects by different colors, e.g.:

- Straw Bales ~ Light Brown
- Hay Bales ~ Light Green
- Grass Bales ~ Dark Green
- Silage Bales ~ Pink
- Wool Pallet ~ Light Gray

Display type and size of the map markers can be configured in the SeeBales menu (Shift-b to show menu, only outside a vehicle).

## ATTENTION:
On size setting "small" the icons/ markers are very tiny, they only show up at a rather high map zoom level (they do not show at default zoom).

Whenever the game is saved, these settings will be saved to a file "BaleSee.xml" in the /modsSettings directory. If this file is present during load of a savegame, initial values for the configuruation settings will be read in.

The SeeBales menu also displays some statistics about all ingame bales and pallets. Lines with count = 0 are not shown in the statistics tables.

## CHANGE LOG:
V2.1.0.0: 
- Added Multiplayer support.
- Hotspot details boxes now always display the bale or pallet image (together with name of owner farm in MP)
- Added support for non-standard bales (e.g. from Maizeplus, Maizeplus Forage Extension).
- Statistics now count bales of different sizes sepatarely.

V2.0.0.1: 
- Added support for non-standard pallets (e.g. for straw harvest add-on). 

V2.0.0.0: 
- Added menu to configure settings - Shift-b to show (only outside a vehicle). 
- Added bale / pallet statistics tables. 
- Included cotton bales. 
- Marker size now configurable.

## LIMITATIONS:
The mod does not account for any bales / pallets in corresponding storage mods, e.g. [BaleStacks](https://www.farming-simulator.com/mod.php?lang=en&country=de&mod_id=141307&title=fs2019)).

## Acknowledgement
Thank you [Royal-Modding](https://royal-modding.github.io/) for permission to use your framework.
