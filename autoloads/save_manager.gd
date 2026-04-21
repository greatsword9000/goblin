extends Node
## SaveManager — versioned save/load for all subsystems.
##
## Owns: save slot serialization, version + migration registry.
## Listens to: EventBus.save_requested / load_requested (TODO — M13).
##
## TODO(M13): gather_save_data(), apply_save_data(), _migrate_v1_to_v2(), etc.

const SAVE_VERSION: int = 1
const SAVE_DIR: String = "user://saves/"
