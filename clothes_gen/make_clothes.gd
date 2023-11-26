@tool
extends Skeleton_Builder

var clothes_helper = Clothes_Helper.new("res://clothes_gen/male_casualsuit04")

func update():
	super()
	make_clothes()

func make_clothes():
	var new_clothes_array = clothes_helper.surface_arrays.duplicate(true)
	for v_index in clothes_helper.vertex_data.size():
		var v = clothes_helper.vertex_data[v_index]
		var index = v[0]
		var coords = Vector3.ZERO
		for i in 3:
			var g_index = v[i]
			var weight = v[i+3]
			coords += human_mesh.get_blended_vertex_position(g_index) * weight
		var offset = Vector3(v[6],v[7],v[8]) * 0.10000000149011612
		coords += offset
		new_clothes_array[Mesh.ARRAY_VERTEX][v_index] = coords
	var new_clothes_mesh = ArrayMesh.new()
	new_clothes_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,new_clothes_array)
	$Clothes.mesh = new_clothes_mesh
	$Clothes.set_surface_override_material(0,clothes_helper.material)
	$Clothes.skin = $human/Human_rig/Skeleton3D.create_skin_from_rest_transforms()
		


func _on_gender_changed():
	if gender:
		clothes_helper = Clothes_Helper.new("res://clothes_gen/male_casualsuit04")
	else:
		clothes_helper = Clothes_Helper.new("res://clothes_gen/female_casualsuit02")
