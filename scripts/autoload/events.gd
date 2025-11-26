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
signal player_damaged(current_health: float, max_health: float)
signal player_died()
signal damage_dealt(position: Vector2, amount: float)

# Turret Events
signal turret_spawned(turret: Node2D, position: Vector2)
signal turret_fired(turret: Node2D)
signal turret_picked_up(turret: Node2D)
signal turret_placed(turret: Node2D, position: Vector2)
signal turret_dropped(turret: Node2D, position: Vector2)

# Pickup Events
signal xp_dropped(position: Vector2, amount: int)
signal xp_collected(amount: int, total: int)

# UI Events
signal show_wave_announcement(wave_number: int)
signal hide_wave_announcement()
signal show_difficulty_select()
signal difficulty_selected(difficulty: int)
signal update_hud()
