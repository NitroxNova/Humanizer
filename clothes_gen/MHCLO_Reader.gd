extends Resource
class_name MHCLO_Reader

var vertex_data = []
enum SECTION {header,vertices,delete_vertices}

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
				vertex_data.append(line_array)
