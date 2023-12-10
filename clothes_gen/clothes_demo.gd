@tool
extends Skeleton_Builder

@export var fancy_clothes = true:
	set(value):
		fancy_clothes = value
		change_clothes()

func update():
	super()
	reset_skins()

func reset_skins():
	$Clothes.skin = $human/Human_rig/Skeleton3D.create_skin_from_rest_transforms()	
	
func set_blend_shape_value(sk_id,value):
	super(sk_id,value)
	$Clothes.set_blend_shape_value(sk_id,value)	
	
func change_clothes():
	if fancy_clothes:
		if gender:
			$Clothes.mesh = load("res://clothes_gen/male_elegantsuit01/mesh.res")
		else:
			$Clothes.mesh = load("res://clothes_gen/female_elegantsuit01/mesh.res")
	else:
		if gender:
			$Clothes.mesh = load("res://clothes_gen/male_casualsuit04/mesh.res")
		else:
			$Clothes.mesh = load("res://clothes_gen/female_casualsuit02/mesh.res")
	reset_skins()
	
	
func _on_gender_changed():
	change_clothes()
