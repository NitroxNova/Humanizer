@tool
extends MeshInstance3D
class_name MakeHuman_MeshInstance3D

@onready var mesh_arrays = mesh.surface_get_arrays(0)
@onready var vertex_array = mesh_arrays[Mesh.ARRAY_VERTEX]
@onready var blend_shapes = mesh.surface_get_blend_shape_arrays(0)

func get_blended_vertex_position(g_index):
	var coords = vertex_array[g_index]
	var change_amount = Vector3.ZERO
	for bs_index in get_blend_shape_count():
		var bs_value = get_blend_shape_value(bs_index)
		if not bs_value == 0:
			var bs_coords = blend_shapes[bs_index][Mesh.ARRAY_VERTEX][g_index]
			if not bs_coords == coords:
				var diff = bs_coords - coords
				change_amount += diff * bs_value
	coords += change_amount
	return coords
