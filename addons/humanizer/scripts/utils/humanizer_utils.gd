@tool
extends RefCounted
class_name HumanizerUtils

#requires that the mh_id already be set in the Custom0 array, which happens in the obj_to_mesh importer
static func get_mh2gd_index_from_mesh(input_mesh:ArrayMesh):
	var mh2gd_index = []
	var sf_arrays = input_mesh.surface_get_arrays(0)
	for gd_id in sf_arrays[Mesh.ARRAY_VERTEX].size():
		var mh_id = sf_arrays[Mesh.ARRAY_CUSTOM0][gd_id]
		if not mh_id < mh2gd_index.size():
			mh2gd_index.resize(mh_id + 1)
		if mh2gd_index[mh_id] == null:
			mh2gd_index[mh_id] = PackedInt32Array()
		mh2gd_index[mh_id].append(gd_id)
	return mh2gd_index

static func read_json(file_name:String):
	var json_as_text = FileAccess.get_file_as_string(file_name)
	var json_as_dict = JSON.parse_string(json_as_text)
	return json_as_dict
	
static func save_json(file_path, data):
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_line(JSON.stringify(data))

static func get_shapekey_data() -> Dictionary:
	var shapekey_data: Dictionary
	var file := FileAccess.open("res://addons/humanizer/data/resources/shapekeys.dat", FileAccess.READ)	
	
	shapekey_data.basis = file.get_var(true)
	shapekey_data.shapekeys = file.get_var(true)
	file.close()
	return shapekey_data
	
static func show_window(interior, closeable: bool = true, size=Vector2i(500, 500)) -> void:
	if not Engine.is_editor_hint():
		return
	var window = Window.new()
	if interior is PackedScene:
		interior = interior.instantiate()
	window.add_child(interior)	
	if closeable:
		window.close_requested.connect(func(): window.queue_free())
	window.size = size
	EditorInterface.popup_dialog_centered(window)

static func generate_normals_and_tangents(import_mesh:ArrayMesh):
	var ST = SurfaceTool.new()
	ST.clear()
	ST.create_from(import_mesh,0)
	ST.set_skin_weight_count(SurfaceTool.SKIN_8_WEIGHTS)
	ST.generate_normals()
	ST.generate_tangents()
	var flags = import_mesh.surface_get_format(0)
	var new_mesh = ST.commit(null,flags)
	return new_mesh


static func build_fitted_mesh(mesh: ArrayMesh, helper_vertex_array: PackedVector3Array, mhclo: MHCLO) -> ArrayMesh: 
	# the static mesh with no shapekeys
	var new_mesh = ArrayMesh.new()
	var new_sf_arrays = build_fitted_arrays(mesh, helper_vertex_array, mhclo)
	var flags = mesh.surface_get_format(0)
	var lods := {}
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,new_sf_arrays, [], lods, flags)
	return new_mesh

static func build_fitted_arrays(mesh: ArrayMesh, helper_vertex_array: PackedVector3Array, mhclo: MHCLO) -> Array: 
	var new_sf_arrays = mesh.surface_get_arrays(0)
	var clothes_scale = Vector3.ZERO
	clothes_scale.x = calculate_scale("x", helper_vertex_array, mhclo)
	clothes_scale.y = calculate_scale("y", helper_vertex_array, mhclo)
	clothes_scale.z = calculate_scale("z", helper_vertex_array, mhclo)
	for mh_id in mhclo.vertex_data.size():
		var vertex_line = mhclo.vertex_data[mh_id]
		var new_coords = Vector3.ZERO
		if vertex_line.format == "single":
			var vertex_id = vertex_line.vertex[0]
			new_coords = helper_vertex_array[vertex_id]
		else:
			for i in 3:
				var vertex_id = vertex_line.vertex[i]
				var v_weight = vertex_line.weight[i]
				var v_coords = helper_vertex_array[vertex_id]
				v_coords *= v_weight
				new_coords += v_coords
			new_coords += (vertex_line.offset * clothes_scale)
		var g_id_array = mhclo.mh2gd_index[mh_id]
		for g_id in g_id_array:
			new_sf_arrays[Mesh.ARRAY_VERTEX][g_id] = new_coords
			
	#if bone_weights_enabled:
	#	add_bone_weights(new_sf_arrays)
	return new_sf_arrays

static func calculate_scale(axis: String, helper_vertex_array: Array, mhclo: MHCLO) -> float:
	# axis = x y or z
	var scale_data = mhclo.scale_config[axis]
	var start_coords = helper_vertex_array[scale_data.start]
	var end_coords = helper_vertex_array[scale_data.end]
	var basemesh_dist = absf(end_coords[axis] - start_coords[axis])
	var scale = basemesh_dist/scale_data.length
	return scale
	
