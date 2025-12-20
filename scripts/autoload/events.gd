extends Node

# Autoload singleton for global events (signal bus)
# Add to Project Settings > Autoload as "Events"

# Game State
signal game_started()
signal game_paused()
signal game_resumed()
signal game_over(victory: bool)

# Wave Events
signal wave_announcement_started(wave_number: int)
signal wave_started(wave_number: int)
signal wave_ended(wave_number: int)
signal wave_timer_updated(time_remaining: float)

# Combat Events
signal enemy_killed(enemy: Node2D, position: Vector2)
signal enemy_spawned(enemy: Node2D)
signal enemy_exploded(position: Vector2, radius: float, damage: float)
signal player_damaged(current_health: float, max_health: float)
signal player_died()
signal damage_dealt(position: Vector2, amount: float)
signal dot_damage_dealt(position: Vector2, amount: float)
signal status_effect_applied(enemy: Node2D, damage_type: int)
signal aoe_explosion(position: Vector2, radius: float, damage: float)
signal chain_lightning_hit(from_pos: Vector2, to_pos: Vector2, damage: float)

# Turret Events
signal turret_spawned(turret: Node2D, position: Vector2)
signal turret_fired(turret: Node2D)
signal turret_picked_up(turret: Node2D)
signal turret_placed(turret: Node2D, position: Vector2)
signal turret_dropped(turret: Node2D, position: Vector2)
signal turret_range_toggled(show_range: bool)
signal hitbox_debug_toggled(show_hitboxes: bool)

# Pickup Events
signal xp_dropped(position: Vector2, amount: int)
signal xp_collected(amount: int, total: int)

# Tech Drop Events
signal tech_drop_spawned(tech_drop: Node2D, position: Vector2)
signal tech_drop_destroyed(tech_drop: Node2D, position: Vector2)
signal tech_drop_despawned(tech_drop: Node2D)  # Wave ended

# Economy Events
signal gold_dropped(position: Vector2, amount: int)
signal gold_collected(amount: int, total: int)
signal gold_spent(amount: int, remaining: int)

# Shop Events
signal shop_opened(wave_number: int)
signal shop_closed()
signal shop_offers_generated(offers: Array)
signal shop_purchase_made(offer: Dictionary)
signal shop_rerolled(new_offers: Array, cost: int)
signal shop_insufficient_funds(required: int, current: int)

# Item Events
signal item_collected(item_data: Dictionary)

# UI Events
signal show_wave_announcement(wave_number: int)
signal hide_wave_announcement()
signal show_difficulty_select()
signal difficulty_selected(difficulty: int)
signal update_hud()

# Player Progression Events
signal player_leveled_up(new_level: int)
