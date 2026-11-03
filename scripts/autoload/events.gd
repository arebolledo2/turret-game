extends Node

# Autoload singleton for global events (signal bus)
# Add to Project Settings > Autoload as "Events"
# World combat notifications live on the run-owned Combat3D, not here.

signal modifiers_changed() # Emitted when items are purchased/modifiers added
signal hero_leveled(level: int) # The hero gained at least one level from scrap
signal hero_evolved(form_id: String) # The hero took an evolution in the shop
