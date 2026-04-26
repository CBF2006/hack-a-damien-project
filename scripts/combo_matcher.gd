extends RefCounted
class_name ComboMatcher

var _combos: Array[String] = []

func _init(combos: Array[String]) -> void:
	_combos = combos.duplicate()
	_combos.sort_custom(func(a: String, b: String): return a.length() > b.length())

func is_exact(combo_key: String) -> bool:
	return _combos.has(combo_key)

func has_prefix(combo_key: String) -> bool:
	for combo in _combos:
		if combo.begins_with(combo_key):
			return true
	return false

func has_longer_prefix(combo_key: String) -> bool:
	for combo in _combos:
		if combo.length() > combo_key.length() and combo.begins_with(combo_key):
			return true
	return false

func find_longest_exact_from_suffix(sequence: Array[String]) -> String:
	for size in range(sequence.size(), 0, -1):
		var key := sequence_to_key(sequence.slice(sequence.size() - size, sequence.size()))
		if is_exact(key):
			return key
	return ""

static func sequence_to_key(sequence: Array[String]) -> String:
	if sequence.is_empty():
		return ""
	return ">".join(sequence)
