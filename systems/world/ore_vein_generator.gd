class_name OreVeinGenerator extends RefCounted
## Scatters ore veins across cave-rock cells after world generation.
## Deterministic per (seed, GridWorld state) — same inputs always give
## the same layout.
##
## Usage (from StarterDungeon or a dungeon generator):
##   OreVeinGenerator.populate([gold_ore_def, copper_ore_def], seed)
##
## Algorithm per ore def:
##   1. Walk all current cave-rock cells in GridWorld.
##   2. For each, roll against rarity_per_cell.
##   3. On hit, pick a random cluster_size in [min..max] and flood-fill
##      that many connected rock cells outward from the seed, replacing
##      each with the ore's mineable_tile.
##   4. Cells already part of a previous vein are skipped so clusters
##      don't overlap.

const CARDINAL_OFFSETS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]


## Scatter veins. `rock_tile_id` is used to detect which cells are
## candidate rock (usually "cave_rock"). `seed` gives deterministic
## output — pass 0 for a time-seeded run.
static func populate(
	ore_defs: Array[OreDefinition],
	rock_tile_id: String = "cave_rock",
	seed: int = 0,
) -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed if seed != 0 else int(Time.get_ticks_usec())

	# Snapshot rock cells up front; we mutate GridWorld as we go.
	var rock_cells: Array[Vector3i] = []
	for cell in GridWorld.get_all_cells():
		var t: TileResource = GridWorld.get_tile(cell)
		if t != null and t.id == rock_tile_id:
			rock_cells.append(cell)

	# Shuffle deterministically so vein order doesn't depend on dict iteration.
	rock_cells.shuffle()

	var converted: Dictionary = {}   # Vector3i -> true
	var total_veins: int = 0

	for ore in ore_defs:
		if ore == null or ore.mineable_tile == null:
			continue
		# Per-ore noise for rich-pocket clustering. Each ore gets a
		# different seed offset so gold veins and copper veins cluster
		# in DIFFERENT pockets, not the same spots.
		var noise: FastNoiseLite = null
		if ore.noise_boost > 0.0:
			noise = FastNoiseLite.new()
			noise.seed = rng.seed + hash(ore.id)
			noise.noise_type = FastNoiseLite.TYPE_PERLIN
			noise.frequency = ore.noise_frequency
		var per_ore_converted: int = 0
		for cell in rock_cells:
			if converted.has(cell):
				continue
			# Compute effective rarity for this cell: flat base, optionally
			# boosted by noise. noise returns -1..1 → we shift into 0..2
			# range and scale by boost.
			var effective_rarity: float = ore.rarity_per_cell
			if noise != null:
				var n: float = noise.get_noise_2d(float(cell.x), float(cell.z))
				effective_rarity *= 1.0 + ore.noise_boost * n
				effective_rarity = maxf(0.0, effective_rarity)
			if rng.randf() > effective_rarity:
				continue
			# Seed hit — flood a random cluster size from this cell.
			var target_size: int = rng.randi_range(
				max(1, ore.cluster_size_min),
				max(ore.cluster_size_min, ore.cluster_size_max),
			)
			var planted: int = _grow_cluster(cell, target_size, ore.mineable_tile,
				rock_tile_id, converted, rng)
			if planted > 0:
				total_veins += 1
				per_ore_converted += planted
		if per_ore_converted > 0:
			print("[OreVeinGen] %s: %d cells across veins" % [ore.id, per_ore_converted])

	return total_veins


## Flood-grow a cluster of size up to `target_size` from `seed_cell`,
## converting each cell to `ore_tile`. Only cells whose current tile is
## rock_tile_id qualify. Returns cells converted.
static func _grow_cluster(
	seed_cell: Vector3i,
	target_size: int,
	ore_tile: TileResource,
	rock_tile_id: String,
	converted: Dictionary,
	rng: RandomNumberGenerator,
) -> int:
	var planted: int = 0
	var frontier: Array[Vector3i] = [seed_cell]
	while planted < target_size and not frontier.is_empty():
		# Pick a random index for organic-looking shapes.
		var idx: int = rng.randi() % frontier.size()
		var cell: Vector3i = frontier[idx]
		frontier.remove_at(idx)
		if converted.has(cell):
			continue
		var t: TileResource = GridWorld.get_tile(cell)
		if t == null or t.id != rock_tile_id:
			continue
		# Convert this cell.
		GridWorld.set_tile(cell, ore_tile, NAN, false)
		converted[cell] = true
		planted += 1
		# Enqueue cardinal neighbors for potential expansion.
		for off in CARDINAL_OFFSETS:
			var n: Vector3i = cell + off
			if not converted.has(n):
				var nt: TileResource = GridWorld.get_tile(n)
				if nt != null and nt.id == rock_tile_id:
					frontier.append(n)
	return planted
