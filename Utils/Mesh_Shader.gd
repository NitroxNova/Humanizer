extends Resource
class_name Mesh_Shader

var import_mesh :ArrayMesh
var import_sf_arrays = []
var import_blend_arrays = []
var shaded_mesh = ArrayMesh.new()
var lite_mesh = ArrayMesh.new()
var ST = SurfaceTool.new()
var blend_shapes = []

func _init(im:ArrayMesh):
	import_mesh = im
	import_sf_arrays = import_mesh.surface_get_arrays(0)
	import_blend_arrays = import_mesh.surface_get_blend_shape_arrays(0)
	
func run():
	var start_time = Time.get_ticks_msec()
	shaded_mesh.set_blend_shape_mode(Mesh.BLEND_SHAPE_MODE_NORMALIZED)
	var mesh_arrays = make_basis()
	make_lite_mesh()
	for bs_index in import_mesh.get_blend_shape_count():
		process_shape_key(bs_index)
	shaded_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh_arrays,blend_shapes)
	var end_time = Time.get_ticks_msec()
	print(end_time-start_time)
	return shaded_mesh

func make_lite_mesh():
	lite_mesh.set_blend_shape_mode(Mesh.BLEND_SHAPE_MODE_NORMALIZED)
	for bs_index in import_mesh.get_blend_shape_count():
		var bs_name = import_mesh.get_blend_shape_name(bs_index)
		lite_mesh.add_blend_shape(bs_name)
	var new_sf_arrays = []
	new_sf_arrays.resize(Mesh.ARRAY_MAX)
	new_sf_arrays[Mesh.ARRAY_VERTEX] = import_sf_arrays[Mesh.ARRAY_VERTEX]
	new_sf_arrays[Mesh.ARRAY_INDEX] = import_sf_arrays[Mesh.ARRAY_INDEX]
	new_sf_arrays[Mesh.ARRAY_TEX_UV] = import_sf_arrays[Mesh.ARRAY_TEX_UV]
	lite_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,new_sf_arrays,import_blend_arrays)
	
func make_basis():
	var bone_count = import_sf_arrays[Mesh.ARRAY_BONES].size() / import_sf_arrays[Mesh.ARRAY_VERTEX].size()
	ST.create_from(import_mesh,0)
	if bone_count == 8:
		ST.set_skin_weight_count(SurfaceTool.SKIN_8_WEIGHTS)
	ST.generate_normals()
	ST.generate_tangents()
	var mesh_arrays = ST.commit_to_arrays()
	ST.clear()
	return mesh_arrays
	
func process_shape_key(bs_index):
	var bs_name = import_mesh.get_blend_shape_name(bs_index)
	ST.create_from_blend_shape(lite_mesh,0,bs_name)
	ST.generate_normals()
	ST.generate_tangents()
#	ST.commit(new_mesh)
	var commit_array = ST.commit_to_arrays()
	shaded_mesh.add_blend_shape(bs_name)
	var curr_bs = []
	curr_bs.resize(Mesh.ARRAY_MAX)
	curr_bs[Mesh.ARRAY_VERTEX] = commit_array[Mesh.ARRAY_VERTEX]
	curr_bs[Mesh.ARRAY_NORMAL] = commit_array[Mesh.ARRAY_NORMAL]
	curr_bs[Mesh.ARRAY_TANGENT] = commit_array[Mesh.ARRAY_TANGENT]
	#print(commit_array[Mesh.ARRAY_VERTEX].size())
	blend_shapes.append(curr_bs)
	ST.clear()
