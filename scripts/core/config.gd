## Loads balance/tuning data from res://data/*.json.
## Keeping numbers in data files means balancing never needs a code change.
extends RefCounted


static func load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Config file missing or empty: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Config file is not a JSON object: %s" % path)
		return {}
	return parsed
