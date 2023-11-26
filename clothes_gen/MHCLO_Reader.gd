extends Resource
class_name MHCLO_Reader

var vertex_data = []
enum SECTION {header,vertices,delete_vertices}
var human_b2g_index = Utils.read_json("res://build_skeleton/b2g_index.json")

func _init(filename:String):
	var file = FileAccess.open(filename,FileAccess.READ)
	var current_section = SECTION.header
	while file.get_position() < file.get_length():
		var line = file.get_line()
		if line == "verts 0":
			current_section = SECTION.vertices
		elif line == "delete_verts":
			current_section = SECTION.delete_vertices
		elif current_section == SECTION.vertices:
			if not line == "":
				var line_array = line.split_floats(" ",false)
#				print(line_array)
				for i in 3:
					var b_index = line_array[i]
					var g_index = human_b2g_index[b_index]
					line_array[i] = g_index[0]
				vertex_data.append(line_array)
