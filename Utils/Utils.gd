extends Resource
class_name Utils

static func create_unique_index(input_array:Array,keep_values=false):
	var unique_values = {}
	for v in input_array.size():
		var value = input_array[v]
		if not value in unique_values:
			unique_values[value] = []
		unique_values[value].append(v)
	if keep_values:
		return unique_values
	else:
		return unique_values.values()

static func read_json(file_name:String):
	var json_as_text = FileAccess.get_file_as_string(file_name)
	var json_as_dict = JSON.parse_string(json_as_text)
	return json_as_dict
