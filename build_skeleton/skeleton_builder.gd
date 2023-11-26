@tool
extends Node3D
class_name Skeleton_Builder

var mixamo_config = load_mixamo_config()
var b2g_index = read_json("res://build_skeleton/b2g_index.json")
var vertex_groups = read_json("res://build_skeleton/basemesh_vertex_groups.json")
var red_dot_scene = preload("res://vertex_finder/red_dot.tscn")
@onready var skeleton = $human/Human_rig/Skeleton3D
@onready var human_mesh = $human/Human_rig/Skeleton3D/Human
@onready var mesh_arrays = human_mesh.mesh.surface_get_arrays(0)
@onready var vertex_array = mesh_arrays[Mesh.ARRAY_VERTEX]
@onready var blend_shapes = human_mesh.mesh.surface_get_blend_shape_arrays(0)

signal gender_changed

@export var gender : bool = false:
	set(value):
		gender = value
		gender_changed.emit()
		update()

@export_range(0,1) var age : float = 0:
	set(value):
		age = value
		update()	

func load_mixamo_config():
	var in_data = read_json("res://build_skeleton/rig.mixamo.json").bones
	var out_data = {}
	for in_name in in_data:
		var out_name = in_name.replace(":","_")
		var parent_name = in_data[in_name].parent.replace(":","_")
		out_data[out_name] = in_data[in_name]
		out_data[out_name].parent = parent_name
	return out_data

func update():
	update_blend_shapes()
	build_skeleton()

func update_blend_shapes():
	reset_shape_keys()
	var gender_string = "female"
	if gender == true:
		gender_string = "male"
	var age_range = get_age_range(age)
#	print(age_range)
	var low_sk_id = human_mesh.find_blend_shape_by_name("caucasian-" + gender_string + "-" + age_range.low)
	var high_sk_id = human_mesh.find_blend_shape_by_name("caucasian-" + gender_string + "-" + age_range.high)
	human_mesh.set_blend_shape_value(low_sk_id,1-age_range.ratio)
	human_mesh.set_blend_shape_value(high_sk_id,age_range.ratio)
	
func reset_shape_keys():
	for id in human_mesh.get_blend_shape_count():
		human_mesh.set_blend_shape_value(id,0)

func get_age_range(value):
	var age_map = {"baby"=-0.01,"child"=0.1874999,"young"=0.49999,"old"=1.01}
	var low_age = ""
	var high_age = ""
	for age_name in age_map:
		if value < age_map[age_name]:
			high_age = age_name
			var total = age_map[high_age]-age_map[low_age]
			var diff = value - age_map[low_age]
			var ratio : float = diff/total
			return {"low"=low_age,"high"=high_age, "ratio"=ratio}
		else:
			low_age	 = age_name
	
func build_skeleton():
	skeleton.reset_bone_poses()
	for bone_id in $human/Human_rig/Skeleton3D.get_bone_count():
		var bone_name = $human/Human_rig/Skeleton3D.get_bone_name(bone_id)
#		print(bone_name)
		var bone_data = mixamo_config[bone_name]
		var bone_pos = calculate_bone_position(bone_name)
#		var bone_id = skeleton.find_bone(bone_name)
		
		if not bone_data.parent == "":
			var parent_id = skeleton.find_bone(bone_data.parent)
			var parent_xform = skeleton.get_bone_global_pose(parent_id)
			bone_pos = bone_pos * parent_xform
		skeleton.set_bone_pose_position(bone_id,bone_pos)
		skeleton.set_bone_rest(bone_id,skeleton.get_bone_pose(bone_id))
		human_mesh.skin = skeleton.create_skin_from_rest_transforms()

func calculate_bone_position(bone_name:String):
	var bone_data = mixamo_config[bone_name]
	var bone_pos = Vector3.ZERO
	if bone_data.head.strategy == "MEAN":
		bone_pos = average_bone_vertex(bone_data.head.vertex_indices)
	elif bone_data.head.strategy == "CUBE":
		var cube_name = bone_data.head.cube_name
		var cube_data = vertex_groups[cube_name][0]
		var index_array = []
		for i in range(cube_data[0],cube_data[1]+1):
			index_array.append(i)
		bone_pos = average_bone_vertex(index_array)
	return bone_pos
			
func average_bone_vertex(index_array:Array):
	var bone_pos = Vector3.ZERO
	for b_index in index_array:
		var g_index = b2g_index[b_index][0]
		bone_pos += get_blended_vertex_position(g_index)
	bone_pos /= index_array.size()
	return bone_pos
	
func get_blended_vertex_position(g_index):
	var coords = vertex_array[g_index]
	var change_amount = Vector3.ZERO
	for bs_index in human_mesh.get_blend_shape_count():
		var bs_value = human_mesh.get_blend_shape_value(bs_index)
		if not bs_value == 0:
			var bs_coords = blend_shapes[bs_index][Mesh.ARRAY_VERTEX][g_index]
			if not bs_coords == coords:
				var diff = bs_coords - coords
				change_amount += diff * bs_value
	coords += change_amount
	return coords

func array_to_vector3(array:Array):
	var vec3 = Vector3(array[0],array[1],array[2])
	return vec3

func read_json(file_name:String):
	var json_as_text = FileAccess.get_file_as_string(file_name)
	var json_as_dict = JSON.parse_string(json_as_text)
	return json_as_dict
