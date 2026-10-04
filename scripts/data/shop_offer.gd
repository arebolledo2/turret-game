class_name ShopOffer
extends RefCounted

## One shop slot. `kind` is "turret" or "item"; `asset_id` is the registry id.
var kind: String
var asset_id: String
var price: int
var sold: bool = false
var locked: bool = false

func _init(offer_kind: String, id: String, cost: int) -> void:
	kind = offer_kind
	asset_id = id
	price = cost
