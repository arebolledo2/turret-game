class_name ShopOffer
extends RefCounted

## Validated transaction boundary. UI dictionaries remain a serialization format.
var kind: String
var asset_id: String
var price: int
var sold: bool = false
var locked: bool = false

func _init(offer_kind: String, id: String, cost: int) -> void:
	kind = offer_kind
	asset_id = id
	price = cost

func to_dictionary() -> Dictionary:
	return {"type": kind, kind + "_id": asset_id, "price": price, "sold": sold, "locked": locked}

static func from_dictionary(data: Dictionary) -> ShopOffer:
	var kind_value = data.get("type")
	if kind_value not in ["item", "turret"] or not data.get("price") is int:
		return null
	var id_value = data.get(str(kind_value) + "_id")
	if not id_value is String or id_value.is_empty() or data.price < 0:
		return null
	if not data.get("sold", false) is bool or not data.get("locked", false) is bool:
		return null
	var result := ShopOffer.new(kind_value, id_value, data.price)
	result.sold = data.get("sold", false)
	result.locked = data.get("locked", false)
	return result
