# GOBLIN — Backlog

Ideas parked for post-Phase-1 phases. **Do not implement during Phase 1.** If you notice yourself designing or building something here during a Phase 1 session, stop and note it instead.

Each entry: one-liner + earliest phase it might land.

## Phase 2 (spirit pass)

- Opening cutscene: parents murdered by adventurers
- Goblin-Ork voice pass for UI text + minion barks
- Minion reaction expansion (context-specific animations, more barks)
- Pet system (second entity that follows the kid, non-combat)
- One random encounter (lost adventurer shows up, you choose fate)
- Music layering by intensity (cozy → tension → raid)
- Warm/cozy lighting pass on built areas
- Full art pass on first biome

## Phase 3 (content)

- Procedural dungeon generation (port Physics Survivors Plug/Socket system)
- Multi-tier tools (pickaxe upgrade unlocks the purple special wall)
- Equipment system for minions
- Skill growth per minion (mining minions get better at mining)
- Kitchen / sleeping area functional tiers
- Additional enemy archetypes (knight boss, champion, siege weapons)
- Reputation / encounter system (choices have downstream consequences)

## Phase 4+ (scope)

- Multiple biomes (each with art, enemy composition, tile set)
- Endless mode
- Boss enemies with unique mechanics
- Champion recruitment quests
- Rooms-affect-skills system (kitchen near sleeping area = morale boost)
- Multi-day run structure with narrative arc
- Co-op / multiplayer

## Phase 1 polish (before M14 demo)

- **Tendril visual rebuild** — M03 first pass (verlet rope + ImmediateMesh ribbon) didn't land. Physics worked (positions sane, reach grew to 9.77m) but the ribbon render was unreadable (triangle-strip winding + thin radius + cull issues). Functional click input (`ring_primary`) is sufficient for M04 (click-to-mine) and M05 (pickup). Real fix options: (a) use a procedurally tessellated tube via CSGPolygon3D with `mode = PATH` following the verlet points, (b) use Line3D / GPUParticles3D ribbon, (c) ship a pre-authored rope mesh with a skeleton that gets bent along the verlet points. Revisit when we have minions in-world to make the "it's a telekinetic beam" read legible.


- **Synty wall art pass** — Dungeon Realms walls measured at 5m × 5m × 0.56m with asymmetric X pivot (origin at edge, not center). Incompatible with our 2m cell grid as direct cell-fillers. Phase 1 uses primitive box walls (2m × 4m × 2m, StaticBody3D + BoxShape3D collision). Real fix options for the art pass: (a) drive wall placement from a `WallRing` builder that lays 5m modules edge-to-edge around the perimeter (not per-cell), (b) import a pack with true 2m modular walls (Dungeon Pack has candidates to check), or (c) commission 2m wall tiles authored center-pivoted.
- **Synty throne pile intrudes neighbors** — gold_pile_large is 8.5m × 9m at full scale; current 0.3 scale = 2.55m × 2.7m which still spills ~0.3m into adjacent floor cells. Acceptable for Phase 1 (it's the centerpiece) but proper fix is a smaller prop or multi-cell decor footprint.
- **Verify Synty scale before placing** — CLAUDE.md's "2m cell matches Synty scale" claim was wrong for Dungeon Realms (5m). Before adopting a new Synty pack, run the AABB measurement script.

## Ideas to evaluate (timing unclear)

- Ragdoll goblin funeral barks when minions die (Phase 2?)
- Minion nickname generator from personality + deeds ("Grobnar the Oft-Slapped") (Phase 2)
- Treasure pile as physics objects that spill when damaged (Phase 3?)
- Adventurer corpse looting by minions (Phase 3)
- "Purple wall" reveals deeper biome teaser art (Phase 2 hook, Phase 3 payoff)

---

**When adding an entry:** just the idea + best-guess phase. No design docs. If it grows past a one-liner it's either Phase 1 work (handle now) or needs its own doc (make one in `designs/` when that phase arrives).
