extends Node

# Autoload singleton for global events (signal bus)
# Add to Project Settings > Autoload as "Events"
# World combat notifications live on the run-owned Combat3D, not here.

signal modifiers_changed() # Emitted when items are purchased/modifiers added
signal feature_flag_changed(flag_id: String, enabled: bool)
