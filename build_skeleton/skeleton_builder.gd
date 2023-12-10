@tool
extends Node3D
class_name Skeleton_Builder

var skeleton_data = load_skeleton_data()
@onready var skeleton = $human/Human_rig/Skeleton3D
@onready var human_mesh = $human/Human_rig/Skeleton3D/Human

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
		
func load_skeleton_data():
	var data = Utils.read_json("res://build_skeleton/skeleton_data.json")
	for i in data.basis.size():
		data.basis[i] = Utils.array_to_vector3(data.basis[i])
	for shape_name in data.shape_keys:
		for i in data.shape_keys[shape_name].size():
			data.shape_keys[shape_name][i] = Utils.array_to_vector3(data.shape_keys[shape_name][i])
	return data

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
	set_blend_shape_value(low_sk_id,1-age_range.ratio)
	set_blend_shape_value(high_sk_id,age_range.ratio)

func set_blend_shape_value(sk_id,value):
	human_mesh.set_blend_shape_value(sk_id,value)
	
func reset_shape_keys():
	for id in human_mesh.get_blend_shape_count():
		set_blend_shape_value(id,0)

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
	var pos_array = skeleton_data.basis.duplicate(true)
	
	for shape_id in skeleton_data.shape_keys:
		var shape_value = human_mesh.get_blend_shape_value(int(shape_id))
		if not shape_value == 0:
			for bone_id in skeleton.get_bone_count():
				var bone_pos = skeleton_data.shape_keys[shape_id][bone_id]
				bone_pos *= shape_value
				pos_array[bone_id] += bone_pos
	
	for bone_id in skeleton.get_bone_count():
		var bone_pos = pos_array[bone_id]
#		var bone_id = skeleton.find_bone(bone_name)
		var parent_id = skeleton.get_bone_parent(bone_id)
		if not parent_id == -1:
			var parent_xform = skeleton.get_bone_global_pose(parent_id)
			bone_pos = bone_pos * parent_xform
		skeleton.set_bone_pose_position(bone_id,bone_pos)
		skeleton.set_bone_rest(bone_id,skeleton.get_bone_pose(bone_id))
	human_mesh.skin = skeleton.create_skin_from_rest_transforms()
