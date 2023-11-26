extends Resource
class_name Clothes_Helper

var mhclo_reader : MHCLO_Reader
var mesh : ArrayMesh
var surface_arrays
var clothes_b2g_index = []
var vertex_data = []
var material

func _init(path_to_folder:String):
	var clothes_name = path_to_folder.get_file()
	material = load(path_to_folder + "/material.tres")
	var mhclo_filename = path_to_folder + "/" + clothes_name + ".mhclo"
	mhclo_reader = MHCLO_Reader.new(mhclo_filename)
	mesh = load(path_to_folder + "/mesh.res")
	surface_arrays = mesh.surface_get_arrays(0)
	clothes_b2g_index = Utils.create_unique_index(surface_arrays[Mesh.ARRAY_VERTEX])
	vertex_data.resize(surface_arrays[Mesh.ARRAY_VERTEX].size())
	for b_index in mhclo_reader.vertex_data.size():
		var v_data = mhclo_reader.vertex_data[b_index]
		var g_index_array = clothes_b2g_index[b_index]
		for g_index in g_index_array:
			vertex_data[g_index] = v_data
	
