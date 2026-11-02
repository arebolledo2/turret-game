class_name ShopOffer
extends RefCounted

## One shop slot. `kind` is "turret" or "item"; `asset_id` is the registry id.
## A turret offer also carries the level it arrives at and, from level 5, the evolved form it arrives in.
var kind: String
var asset_id: String
var price: int
var sold: bool = false
var locked: bool = false
var level: int = 1
var form: String = ""

func _init(offer_kind: String, id: String, cost: int, turret_level: int = 1, turret_form: String = "") -> void:
	kind = offer_kind
	asset_id = id
	price = cost
	level = turret_level
	form = turret_form
