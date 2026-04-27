class_name OreDefinition extends Resource
## Describes one ore type for procedural vein generation.
## Consumed by OreVeinGenerator — each cave-rock cell rolls against
## rarity_per_cell. If it hits, a cluster of size cluster_size_min..max
## connected cave-rock cells gets converted to `mineable_tile`.

## Stable id, e.g. "gold", "copper", "crystal".
@export var id: String = ""
## Display label for UI / logs.
@export var display_name: String = ""
## The tile that replaces cave_rock when a cell becomes part of a vein.
## Its own `drops` list governs what minions get when they mine it.
@export var mineable_tile: TileResource = null
## Per-cell seed chance (0..1). 0.01 = 1% of rock cells seed a vein.
@export_range(0.0, 1.0, 0.001) var rarity_per_cell: float = 0.01
## Random cluster size, inclusive. Cluster of 1 = just the seed cell.
@export var cluster_size_min: int = 1
@export var cluster_size_max: int = 4

## Noise-based clustering. 0 = uniform random distribution. Higher
## values bias veins toward "rich pockets" — noise peaks get more
## veins, troughs get fewer. Typical useful range 0.0–1.5.
@export_range(0.0, 3.0, 0.05) var noise_boost: float = 0.0
## Spatial scale of the noise. Smaller = bigger, smoother rich zones.
## 0.08 gives ~12-cell wide pockets in a 101×101 dungeon.
@export_range(0.01, 0.5, 0.01) var noise_frequency: float = 0.08
