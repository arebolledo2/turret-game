class_name TurretVisualHandles
extends RefCounted

## What a form's visual builder hands back to `TurretActor` after adding hardware to the chassis: the nodes the attack code
## reads. A builder fills only the fields its form needs and returns null when it exposes nothing.
var flame_emitters: Array[Node3D] = []
var bowling_hardware: BowlingEvolutionVisual
## The Stormblade's barrel exits, in firing order (its own muzzle first).
var gun_muzzles: Array[Node3D] = []
## Omnifire's radial exits.
var crossfire_muzzles: Array[Node3D] = []
