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
	
static func save_json(file_path, data):
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_line(JSON.stringify(data))
	
static func vector3_to_array(vec:Vector3):
	var array = []
	array.append(vec.x)
	array.append(vec.y)
	array.append(vec.z)
	return array

static func array_to_vector3(array:Array):
	var vec = Vector3(array[0],array[1],array[2])
	return vec
