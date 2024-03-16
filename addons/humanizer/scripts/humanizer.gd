@tool
class_name Humanizer
extends Node3D

const humanizer_mesh_instance = preload('res://addons/humanizer/scripts/assets/humanizer_mesh_instance.gd')
const _BASE_MESH_NAME: String = 'Human'
const _DEFAULT_SKIN_COLOR = Color.WHITE
const _DEFAULT_EYE_COLOR = Color.SKY_BLUE
const _DEFAULT_HAIR_COLOR = Color.WEB_MAROON
## Vertex ids
const shoulder_id: int = 16951 
const waist_id: int = 17346
const hips_id: int = 18127

var skeleton: Skeleton3D
var body_mesh: MeshInstance3D
var baked := false
var scene_loaded: bool = false
var main_collider: CollisionShape3D
var _base_motion_scale: float:
	get:
		var rig: HumanizerRig = HumanizerRegistry.rigs[human_config.rig.split('-')[0]]
		var sk: Skeleton3D
		if human_config.rig.ends_with('RETARGETED'):
			sk = rig.load_retargeted_skeleton()
		else:
			sk = rig.load_skeleton()
		return sk.motion_scale
var _base_hips_height: float:
	get:
		return shapekey_data.basis[hips_id].y
var _shapekey_data: Dictionary = {}
var shapekey_data: Dictionary:
	get:
		if _shapekey_data.size() == 0:
			_shapekey_data = HumanizerUtils.get_shapekey_data()
		return _shapekey_data
var _helper_vertex: PackedVector3Array = []
var save_path: String:
	get:
		var path = HumanizerGlobal.config.human_export_path
		if path == null:
			path = 'res://data/humans'
		return path.path_join(human_name)
var human_name: String = 'MyHuman'
var _save_path_valid: bool:
	get:
		if FileAccess.file_exists(save_path.path_join(human_name + '.tscn')):
			printerr('A human with this name has already been saved.  Use a different name.')
			return false
		return true
var bake_surface_name: String

var skin_color: Color = _DEFAULT_SKIN_COLOR:
	set(value):
		skin_color = value
		if scene_loaded and body_mesh.material_config.overlays.size() == 0:
			return
		human_config.skin_color = skin_color
		body_mesh.material_config.overlays[0].color = skin_color
		body_mesh.material_config.update_material()
var hair_color: Color = _DEFAULT_HAIR_COLOR:
	set(value):
		hair_color = value
		if human_config == null:
			return
		human_config.hair_color = hair_color
		var slots: Array = [&'RightEyebrow', &'LeftEyebrow', &'Eyebrows', &'Hair']
		for slot in slots:
			if not human_config.body_parts.has(slot):
				return
			var mesh = get_node(human_config.body_parts[slot].resource_name)
			(mesh as MeshInstance3D).get_surface_override_material(0).albedo_color = hair_color
var eye_color: Color = _DEFAULT_EYE_COLOR:
	set(value):
		eye_color = value
		if human_config == null:
			return
		human_config.eye_color = eye_color
		var slots: Array = [&'RightEye', &'LeftEye', &'Eyes']
		for slot in slots:
			if not human_config.body_parts.has(slot):
				return
			var mesh = get_node(human_config.body_parts[slot].resource_name)
			mesh.material_config.overlays[1].color = eye_color

@export var _bake_meshes: Array[MeshInstance3D]

@export_category("Humanizer Node Settings")
@export var human_config: HumanConfig:
	set(value):
		human_config = value
		if human_config.rig == '':
			human_config.rig = HumanizerGlobal.config.default_skeleton
		# This gets set before _ready causing issues so make sure we're loaded
		if scene_loaded:
			load_human()

@export_group('Node Overrides')
## The root node type for baked humans
@export_enum("CharacterBody3D", "RigidBody3D", "StaticBody3D") var _baked_root_node: String = HumanizerGlobal.config.default_baked_root_node
## The scene to be added as an animator for the character
@export var _animator: PackedScene:
	set(value):
		_animator = value
		_reset_animator()
## THe rendering layers for the human's 3d mesh instances
@export_flags_3d_render var _render_layers:
	set(value):
		_render_layers = value
		for child in get_children():
			if child is MeshInstance3D:
				child.layers = _render_layers
## The physics layers the character collider resides in
@export_flags_3d_physics var _character_layers:
	set(value):
		_character_layers = value
		if main_collider != null:
			pass
## The physics layers the character collider collides with
@export_flags_3d_physics var _character_mask:
	set(value):
		_character_mask = value
		if main_collider != null:
			pass
## The physics layers the physical bones reside in
@export_flags_3d_physics var _ragdoll_layers:
	set(value):
		_ragdoll_layers = value
## The physics layers the physical bones collide with
@export_flags_3d_physics var _ragdoll_mask:
	set(value):
		_ragdoll_mask = value



func _ready() -> void:
	scene_loaded = true
	load_human()
	skeleton.physical_bones_start_simulation()

####  HumanConfig Resource Management ####
func _add_child_node(node: Node) -> void:
	add_child(node)
	node.owner = self
	if node is MeshInstance3D:
		var render_layers = _render_layers
		if render_layers == null:
			render_layers = HumanizerGlobal.config.default_character_render_layers
		(node as MeshInstance3D).layers = render_layers

func _delete_child_node(node: Node) -> void:
	remove_child(node)
	node.queue_free()

func _delete_child_by_name(name: String) -> void:
	for child in get_children():
		if child.name == name:
			_delete_child_node(child)

func _get_asset_by_name(mesh_name: String) -> HumanAsset:
	var res: HumanAsset = null
	for slot in human_config.body_parts:
		if human_config.body_parts[slot].resource_name == mesh_name:
			res = human_config.body_parts[slot] as HumanBodyPart
	if res == null:
		for cl in human_config.clothes:
			if cl.resource_name == mesh_name:
				res = cl as HumanClothes
	return res

func load_human() -> void:
	if human_config == null:
		reset_human()
	else:
		var mesh_path := human_config.resource_path.get_base_dir().path_join('mesh.res')
		baked = false
		reset_human(false)
		deserialize()
		notify_property_list_changed()

func reset_human(reset_config: bool = true) -> void:
	baked = false
	_helper_vertex = shapekey_data.basis.duplicate(true)
	for child in get_children():
		if child is MeshInstance3D:
			_delete_child_node(child)
	_set_body_mesh(load("res://addons/humanizer/data/resources/base_human.res"))
	_delete_child_by_name('MainCollider')
	main_collider = null
	if reset_config:
		human_config = HumanConfig.new()
	skin_color = _DEFAULT_SKIN_COLOR
	hair_color = _DEFAULT_HAIR_COLOR
	eye_color = _DEFAULT_EYE_COLOR
	notify_property_list_changed()
	print('Reset human')

func deserialize() -> void:
	set_shapekeys(human_config.shapekeys, true)
	set_rig(human_config.rig, body_mesh.mesh)
	for slot in human_config.body_parts:
		var bp = human_config.body_parts[slot]
		var mat = human_config.body_part_materials[slot]
		set_body_part(bp)
		set_body_part_material(bp.slot, mat)
	for clothes in human_config.clothes:
		apply_clothes(clothes)
		set_clothes_material(clothes.resource_name, human_config.clothes_materials[clothes.resource_name])
	if human_config.body_part_materials.has(&'skin'):
		set_skin_texture(human_config.body_part_materials[&'skin'])
	for component in human_config.components:
		set_component_state(true, component)
	
func save_human_scene() -> void:
	## Save to files for easy load later
	if not _save_path_valid:
		return
	DirAccess.make_dir_recursive_absolute(save_path)
	
	var new_mesh = _combine_meshes()
	var scene = PackedScene.new()
	var root_node: Node
	if _baked_root_node == &'StaticBody3D':
		root_node = StaticBody3D.new()
	elif _baked_root_node == &'CharacterBody3D':
		root_node = CharacterBody3D.new()
	elif _baked_root_node == &'RigidBody3D':
		root_node = RigidBody3D.new()

	if HumanizerGlobal.config.default_human_script not in ['', null]:
		root_node.set_script(load(HumanizerGlobal.config.default_human_script))
	
	var sk = skeleton.duplicate(true) as Skeleton3D
	root_node.add_child(sk)
	sk.owner = root_node
	
	if main_collider != null:
		var coll = main_collider.duplicate(true)
		root_node.add_child(coll)
		coll.owner = root_node
	
	var animator = get_node_or_null(^'AnimationTree')
	if animator == null:
		animator = get_node_or_null(^'AnimationPlayer')
	if animator != null:
		animator = animator.duplicate(true)
		root_node.add_child(animator)
		animator.owner = root_node
	
	root_node.name = human_name
	var mi = MeshInstance3D.new()
	mi.mesh = new_mesh
	root_node.add_child(mi)
	mi.owner = root_node
	mi.skeleton = NodePath('../' + sk.name)
	mi.skin = sk.create_skin_from_rest_transforms()
	
	for surface in mi.mesh.get_surface_count():
		var mat = mi.mesh.surface_get_material(surface)
		var surf_name: String = mi.mesh.surface_get_name(surface)
		if mat.albedo_texture != null:
			var path := save_path.path_join(surf_name + '_albedo.png')
			ResourceSaver.save(mat.albedo_texture, path)
			mat.albedo_texture.take_over_path(path)
		if mat.normal_texture != null:
			var path := save_path.path_join(surf_name + '_normal.png')
			ResourceSaver.save(mat.albedo_texture, path)
			mat.normal_texture.take_over_path(path)
		if mat.ao_texture != null:
			var path := save_path.path_join(surf_name + '_ao.png')
			ResourceSaver.save(mat.albedo_texture, path)
			mat.ao_texture.take_over_path(path)
		var path := save_path.path_join(surf_name + '_material.tres')
		ResourceSaver.save(mat, path)
		mat.take_over_path(path)
		
	var path := save_path.path_join('mesh.tres')
	ResourceSaver.save(mi.mesh, path)
	mi.mesh.take_over_path(path)
	path = save_path.path_join(human_name + '.res')
	ResourceSaver.save(human_config, save_path.path_join(human_name + '_config.res'))
	scene.pack(root_node)
	ResourceSaver.save(scene, save_path.path_join(human_name + '.tscn'))
	print('Saved human to : ' + save_path)

	## TODO
	## Maybe store base mesh with all occluded vertices restored
	## will make swapping clothes later easier.  if many shapekeys
	## are set reloading and rebaking may be slow.  Will need to 
	## re-write logic in this script to allow starting points other 
	## than standard base mesh

#### Mesh Management ####
func _set_body_mesh(meshdata: ArrayMesh) -> void:
	_delete_child_by_name(_BASE_MESH_NAME)
	body_mesh = MeshInstance3D.new()
	body_mesh.name = _BASE_MESH_NAME
	body_mesh.mesh = meshdata
	body_mesh.set_surface_override_material(0, StandardMaterial3D.new())
	body_mesh.set_script(humanizer_mesh_instance)
	if skeleton != null:
		body_mesh.skeleton = skeleton.get_path()
		body_mesh.skin = skeleton.create_skin_from_rest_transforms()
	_add_child_node(body_mesh)

func set_body_part(bp: HumanBodyPart) -> void:
	if human_config.body_parts.has(bp.slot):
		var current = human_config.body_parts[bp.slot]
		_delete_child_by_name(current.resource_name)
	human_config.body_parts[bp.slot] = bp
	var mi = load(bp.scene_path).instantiate() as MeshInstance3D
	if bp.default_overlay != null:
		setup_overlay_material(bp, mi)
	else:
		mi.get_surface_override_material(0).resource_path = ''
	_add_child_node(mi)
	_add_bone_weights(bp)
	set_shapekeys(human_config.shapekeys)
	#notify_property_list_changed()

func clear_body_part(clear_slot: String) -> void:
	for slot in human_config.body_parts:
		if slot == clear_slot:
			var res = human_config.body_parts[clear_slot]
			_delete_child_by_name(res.resource_name)
			human_config.body_parts.erase(clear_slot)
			return

func apply_clothes(cl: HumanClothes) -> void:
	for wearing in human_config.clothes:
		for slot in cl.slots:
			if slot in wearing.slots:
				remove_clothes(wearing)
	print('applying ' + cl.resource_name + ' clothes')
	if not cl in human_config.clothes:
		human_config.clothes.append(cl)
	var mi = load(cl.scene_path).instantiate()
	if cl.default_overlay != null:
		setup_overlay_material(cl, mi)
	_add_child_node(mi)
	_add_bone_weights(cl)
	set_shapekeys(human_config.shapekeys)

func clear_clothes_in_slot(slot: String) -> void:
	for cl in human_config.clothes:
		if slot in cl.slots:
			print('clearing ' + cl.resource_name + ' clothes')
			remove_clothes(cl)

func remove_clothes(cl: HumanClothes) -> void:
	for child in get_children():
		if child.name == cl.resource_name:
			#print('removing ' + cl.resource_name + ' clothes')
			_delete_child_node(child)
	human_config.clothes.erase(cl)

func update_hide_vertices() -> void:
	var skin_mat = body_mesh.get_surface_override_material(0)
	var arrays: Array = (body_mesh.mesh as ArrayMesh).surface_get_arrays(0)
	var delete_verts_gd := []
	delete_verts_gd.resize(arrays[Mesh.ARRAY_VERTEX].size())
	var delete_verts_mh := []
	delete_verts_mh.resize(_helper_vertex.size())
	var remap_verts_gd := [] #old to new
	remap_verts_gd.resize(arrays[Mesh.ARRAY_VERTEX].size())
	remap_verts_gd.fill(-1)
	
	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var res: HumanAsset = _get_asset_by_name(child.name)
		if res != null:
			for entry in load(res.mhclo_path).delete_vertices:
				if entry.size() == 1:
					delete_verts_mh[entry[0]] = true
				else:
					for mh_id in range(entry[0], entry[1] + 1):
						delete_verts_mh[mh_id] = true
			
	for gd_id in arrays[Mesh.ARRAY_VERTEX].size():
		var mh_id = arrays[Mesh.ARRAY_CUSTOM0][gd_id]
		if delete_verts_mh[mh_id]:
			delete_verts_gd[gd_id] = true
	
	var new_gd_id = 0
	for old_gd_id in arrays[Mesh.ARRAY_VERTEX].size():
		if not delete_verts_gd[old_gd_id]:
			remap_verts_gd[old_gd_id] = new_gd_id
			new_gd_id += 1
	
	var new_mesh = ArrayMesh.new()
	var new_arrays := []
	new_arrays.resize(Mesh.ARRAY_MAX)
	new_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	new_arrays[Mesh.ARRAY_CUSTOM0] = PackedFloat32Array()
	new_arrays[Mesh.ARRAY_INDEX] = PackedInt32Array()
	new_arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
	new_arrays[Mesh.ARRAY_BONES] = PackedInt32Array()
	new_arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array()
	var bone_count = arrays[Mesh.ARRAY_BONES].size()/arrays[Mesh.ARRAY_VERTEX].size()
	var lods := {}
	var fmt = body_mesh.mesh.surface_get_format(0)
	for gd_id in delete_verts_gd.size():
		if not delete_verts_gd[gd_id]:
			new_arrays[Mesh.ARRAY_VERTEX].append(arrays[Mesh.ARRAY_VERTEX][gd_id])
			new_arrays[Mesh.ARRAY_CUSTOM0].append(arrays[Mesh.ARRAY_CUSTOM0][gd_id])
			new_arrays[Mesh.ARRAY_TEX_UV].append(arrays[Mesh.ARRAY_TEX_UV][gd_id])
			new_arrays[Mesh.ARRAY_BONES].append_array(arrays[Mesh.ARRAY_BONES].slice(gd_id * bone_count, (gd_id + 1) * bone_count))
			new_arrays[Mesh.ARRAY_WEIGHTS].append_array(arrays[Mesh.ARRAY_WEIGHTS].slice(gd_id * bone_count, (gd_id + 1) * bone_count))
	for i in arrays[Mesh.ARRAY_INDEX].size()/3:
		var slice = arrays[Mesh.ARRAY_INDEX].slice(i*3,(i+1)*3)
		if delete_verts_gd[slice[0]] or delete_verts_gd[slice[1]] or delete_verts_gd[slice[2]]:
			continue
		slice = [remap_verts_gd[slice[0]], remap_verts_gd[slice[1]], remap_verts_gd[slice[2]]]
		new_arrays[Mesh.ARRAY_INDEX].append_array(slice)
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_arrays, [], lods, fmt)
	new_mesh = MeshOperations.generate_normals_and_tangents(new_mesh)
	_set_body_mesh(new_mesh)
	body_mesh.set_surface_override_material(0, skin_mat)
	body_mesh.skeleton = skeleton.get_path()

func restore_hidden_vertices() -> void:
	load_human()

func set_shapekeys(shapekeys: Dictionary, override_zero: bool = false):
	var prev_sk = human_config.shapekeys.duplicate()
	if override_zero:
		for sk in prev_sk:
			prev_sk[sk] = 0

	for sk in shapekeys:
		var prev_val: float = prev_sk.get(sk, 0)
		if prev_val == shapekeys[sk]:
			continue
		for mh_id in shapekey_data.shapekeys[sk]:
			_helper_vertex[mh_id] += shapekey_data.shapekeys[sk][mh_id] * (shapekeys[sk] - prev_val)
				
	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var mesh: ArrayMesh = child.mesh

		var res: HumanAsset = _get_asset_by_name(child.name)
		if res != null:   # Body parts/clothes
			var mhclo: MHCLO = load(res.mhclo_path)
			var new_mesh = MeshOperations.build_fitted_mesh(mesh, _helper_vertex, mhclo)
			child.mesh = new_mesh
		else:             # Base mesh
			if child.name != _BASE_MESH_NAME:
				printerr('Failed to match asset resource for mesh ' + child.name + ' which is not the base mesh.')
				return
			var surf_arrays = (mesh as ArrayMesh).surface_get_arrays(0)
			var fmt = mesh.surface_get_format(0)
			var lods = {}
			var vtx_arrays = surf_arrays[Mesh.ARRAY_VERTEX]
			surf_arrays[Mesh.ARRAY_VERTEX] = _helper_vertex.slice(0, vtx_arrays.size())
			for gd_id in surf_arrays[Mesh.ARRAY_VERTEX].size():
				var mh_id = surf_arrays[Mesh.ARRAY_CUSTOM0][gd_id]
				surf_arrays[Mesh.ARRAY_VERTEX][gd_id] = _helper_vertex[mh_id]
			mesh.clear_surfaces()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surf_arrays, [], lods, fmt)
	
	for sk in shapekeys:
		human_config.shapekeys[sk] = shapekeys[sk]
	if main_collider != null:
		_adjust_main_collider()

func set_bake_meshes(subset: String) -> void:
	_bake_meshes = []
	for child in get_children():
		if not child is MeshInstance3D:
			continue
		if child.name.begins_with('Baked-'):
			continue
		var mat = (child as MeshInstance3D).get_surface_override_material(0) as BaseMaterial3D
		var add: bool = false
		add = add or subset == 'All'
		add = add or subset == 'Opaque' and mat != null and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
		add = add or subset == 'Transparent' and mat != null and mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
		if add:
			bake_surface_name = subset
			_bake_meshes.append(child)
		else:
			bake_surface_name = ''
	notify_property_list_changed()
	
func standard_bake() -> void:
	if baked:
		printerr('Already baked.  Reload the scene, load a human_config, or reset human to start over.')
		return
	adjust_skeleton()
	update_hide_vertices()
	set_bake_meshes('Opaque')
	bake_surface()
	set_bake_meshes('Transparent')
	bake_surface()

func bake_surface() -> void:
	if bake_surface_name in [null, '']:
		bake_surface_name = 'Surface0'
	for child in get_children():
		if child.name == 'Baked-' + bake_surface_name:
			printerr('Surface ' + bake_surface_name + ' already exists.  Choose a different name.')
			return
	var mi: MeshInstance3D = HumanizerSurfaceCombiner.new(_bake_meshes).run()
	mi.name = 'Baked-' + bake_surface_name
	add_child(mi)
	mi.owner = self
	mi.skeleton = skeleton.get_path()
	for mesh in _bake_meshes:
		remove_child(mesh)
		mesh.queue_free()
	_bake_meshes = []
	baked = true

func _combine_meshes() -> ArrayMesh:
	var new_mesh = ArrayMesh.new()
	new_mesh.set_blend_shape_mode(Mesh.BLEND_SHAPE_MODE_NORMALIZED)
	var i = 0
	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var surface_arrays = child.mesh.surface_get_arrays(0)
		var blend_shape_arrays = child.mesh.surface_get_blend_shape_arrays(0)
		var lods := {}
		var format = child.mesh.surface_get_format(0)
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays, blend_shape_arrays, lods, format)
		new_mesh.surface_set_name(i, child.name)
		if child.get_surface_override_material(0) != null:
			new_mesh.surface_set_material(i, child.get_surface_override_material(0).duplicate(true))
		else:
			new_mesh.surface_set_material(i, child.mesh.surface_get_material(0).duplicate(true))
		i += 1
	return new_mesh

#### Materials ####
func set_skin_texture(name: String) -> void:
	var base_texture: String
	if not HumanizerRegistry.skin_textures.has(name):
		human_config.body_part_materials['skin'] = ''
	else:
		human_config.body_part_materials['skin'] = name
		base_texture = HumanizerRegistry.skin_textures[name].albedo
	body_mesh.material_config.set_base_textures(HumanizerOverlay.from_dict({'name': name, 'albedo': base_texture, 'color': skin_color}))
	body_mesh.update_material()

func set_body_part_material(set_slot: String, texture: String) -> void:
	#print('setting material ' + texture + ' on ' + set_slot)
	var bp: HumanBodyPart = human_config.body_parts[set_slot]
	human_config.body_part_materials[set_slot] = texture
	var mi = get_node(bp.resource_name) as MeshInstance3D
	if bp.default_overlay != null:
		var mat_config: HumanizerMaterial = (mi as HumanizerMeshInstance).material_config
		var overlay_dict = {'albedo': bp.textures[texture]}
		if mi.get_surface_override_material(0).normal_texture != null:
			overlay_dict['normal'] = mi.get_surface_override_material(0).normal_texture.resource_path
		if mi.get_surface_override_material(0).ao_texture != null:
			overlay_dict['ao'] = mi.get_surface_override_material(0).ao_texture.resource_path
		mat_config.set_base_textures(HumanizerOverlay.from_dict(overlay_dict))
	else:
		var mat: BaseMaterial3D = mi.get_surface_override_material(0)
		mat.albedo_texture = load(bp.textures[texture])
	if bp.slot in [&'LeftEye', &'RightEye', &'Eyes']:
		await get_tree().process_frame
		mi.material_config.overlays[1].color = eye_color
	if bp.slot in [&'RightEyebrow', &'LeftEyebrow', &'Eyebrows', &'Hair']:
		await get_tree().process_frame
		mi.get_surface_override_material(0).albedo_color = hair_color

func set_clothes_material(cl_name: String, texture: String) -> void:
	#print('setting texture ' + texture + ' on ' + cl_name)
	var cl: HumanClothes = HumanizerRegistry.clothes[cl_name]
	var mi: MeshInstance3D = get_node(cl.resource_name)

	if cl.default_overlay != null:
		var mat_config: HumanizerMaterial = (mi as HumanizerMeshInstance).mat_config
		var overlay_dict = HumanizerOverlay.from_dict({'albedo': cl.textures[texture]})
		if mi.get_surface_override_material(0).normal_texture != null:
			overlay_dict['normal'] = mi.get_surface_override_material(0).normal_texture.resource_path
		if mi.get_surface_override_material(0).ao_texture != null:
			overlay_dict['ao'] = mi.get_surface_override_material(0).ao_texture.resource_path
		mat_config.set_base_textures(HumanizerOverlay.from_dict(overlay_dict))
	else:
		mi.get_surface_override_material(0).albedo_texture = load(cl.textures[texture])
	human_config.clothes_materials[cl_name] = texture

func setup_overlay_material(asset: HumanAsset, mi: MeshInstance3D) -> void:
	mi.set_script(load("res://addons/humanizer/scripts/assets/humanizer_mesh_instance.gd"))
	await get_tree().process_frame
	var mat_config = mi.material_config as HumanizerMaterial
	var overlay_dict = {'albedo': asset.textures.values()[0]}
	if mi.get_surface_override_material(0).normal_texture != null:
		overlay_dict['normal'] = mi.get_surface_override_material(0).normal_texture.resource_path
	if mi.get_surface_override_material(0).ao_texture != null:
		overlay_dict['ao'] = mi.get_surface_override_material(0).ao_texture.resource_path
	mat_config.set_base_textures(HumanizerOverlay.from_dict(overlay_dict))
	mat_config.add_overlay(asset.default_overlay)

#### Animation ####
func set_rig(rig_name: String, basemesh: ArrayMesh = null) -> void:
	# Delete existing skeleton
	for child in get_children():
		if child is Skeleton3D:
			_delete_child_node(child)
	if rig_name == '':
		return
	if baked:
		printerr('Cannot change rig on baked mesh.  Reset the character.')
		return
	
	if basemesh == null:
		basemesh = load('res://addons/humanizer/data/resources/base_human.res')
	var retargeted: bool = rig_name.ends_with('-RETARGETED')
	var rig: HumanizerRig = HumanizerRegistry.rigs[rig_name.split('-')[0]]
	human_config.rig = rig_name
	skeleton = rig.load_skeleton()  # Json file needs base skeleton names
	var skinned_mesh: ArrayMesh = MeshOperations.skin_mesh(rig, skeleton, basemesh)

	# Set rig in scene
	if retargeted:
		skeleton = rig.load_retargeted_skeleton()
	_add_child_node(skeleton)
	skeleton.unique_name_in_owner = true
	_reset_animator()
	# Set new mesh
	var mat = body_mesh.get_surface_override_material(0)
	_set_body_mesh(skinned_mesh)
	body_mesh.set_surface_override_material(0, mat)
	body_mesh.skeleton = skeleton.get_path()
	adjust_skeleton()
	set_shapekeys(human_config.shapekeys)
	for cl in human_config.clothes:
		_add_bone_weights(cl)
	for bp in human_config.body_parts.values():
		_add_bone_weights(bp)

func _add_bone_weights(asset: HumanAsset) -> void:
	var mi: MeshInstance3D = get_node_or_null(asset.resource_name)
	if mi == null:
		return
		
	var rig = human_config.rig.split('-')[0]
	var bone_weights = HumanizerUtils.read_json(HumanizerRegistry.rigs[rig].bone_weights_json_path)
	var bone_count = bone_weights.bones[0].size()
	var mhclo: MHCLO = load(asset.mhclo_path) 
	var mh2gd_index = mhclo.mh2gd_index
	var mesh: ArrayMesh

	mesh = mi.mesh as ArrayMesh
	var new_sf_arrays = mesh.surface_get_arrays(0)
	
	new_sf_arrays[Mesh.ARRAY_BONES] = PackedInt32Array()
	new_sf_arrays[Mesh.ARRAY_BONES].resize(bone_count * new_sf_arrays[Mesh.ARRAY_VERTEX].size())
	new_sf_arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array()
	new_sf_arrays[Mesh.ARRAY_WEIGHTS].resize(bone_count * new_sf_arrays[Mesh.ARRAY_VERTEX].size())

	for mh_id in mhclo.vertex_data.size():
		var bones = []
		var weights = []
		var v_data = mhclo.vertex_data[mh_id]
		if v_data.format == 'single':
			var id = v_data.vertex[0]
			bones = bone_weights.bones[id]
			weights = bone_weights.weights[id]
		else:
			for i in 3:
				var v_id = v_data.vertex[i]
				var v_weight = v_data.weight[i]
				var vb_id = bone_weights.bones[v_id]
				var vb_weights = bone_weights.weights[v_id]
				for j in bone_count:
					var l_weight = vb_weights[j]
					if not l_weight == 0:
						var l_bone = vb_id[j]
						l_weight *= v_weight
						if l_bone in bones:
							var l_id = bones.find(l_bone)
							weights[l_id] += l_weight
						else:
							bones.append(l_bone)
							weights.append(l_weight)
						
		# only 4 bone weights, this may cause problems later
		# also, should probably normalize weights array, but tested weights were close enough to 1				
		while bones.size() < bone_count:
			bones.append(0)
			weights.append(0)
		
		if mh_id < mh2gd_index.size():
			var g_id_array = mh2gd_index[mh_id]
			for g_id in g_id_array:
				for i in bone_count:
					new_sf_arrays[Mesh.ARRAY_BONES][g_id * bone_count + i] = bones[i]
					new_sf_arrays[Mesh.ARRAY_WEIGHTS][g_id * bone_count + i] = weights[i]
		else:
			print("missing " + str(mh_id) + " from " + mhclo.name)

	var flags = mesh.surface_get_format(0)
	var lods = {}
	var bs_arrays = mesh.surface_get_blend_shape_arrays(0)
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_sf_arrays, bs_arrays, lods, flags)
	mi.mesh = mesh
	mi.skeleton = skeleton.get_path()
	mi.skin = skeleton.create_skin_from_rest_transforms()

func adjust_skeleton() -> void:
	var shapekey_data = HumanizerUtils.get_shapekey_data()
	skeleton.reset_bone_poses()
	var rig = human_config.rig.split('-')[0]
	var skeleton_config = HumanizerUtils.read_json(HumanizerRegistry.rigs[rig].config_json_path)
	for bone_id in skeleton.get_bone_count():
		var bone_data = skeleton_config[bone_id]
		var bone_pos = Vector3.ZERO
		for vid in bone_data.head.vertex_indices:
			var mh_id = int(vid)
			var coords = shapekey_data.basis[mh_id]
			for sk_name in human_config.shapekeys:
				var sk_value = human_config.shapekeys[sk_name]
				if sk_value != 0:
					if mh_id in shapekey_data.shapekeys[sk_name]:
						coords += sk_value * shapekey_data.shapekeys[sk_name][mh_id]
			bone_pos += coords
		bone_pos /= bone_data.head.vertex_indices.size()

		var parent_id = skeleton.get_bone_parent(bone_id)
		if not parent_id == -1:
			var parent_xform = skeleton.get_bone_global_pose(parent_id)
			bone_pos = bone_pos * parent_xform
		skeleton.set_bone_pose_position(bone_id,bone_pos)
		skeleton.set_bone_rest(bone_id,skeleton.get_bone_pose(bone_id))
	skeleton.reset_bone_poses()
	for child in get_children():
		if child is MeshInstance3D:
			child.skin = skeleton.create_skin_from_rest_transforms()
	
	skeleton.motion_scale = _base_motion_scale * _helper_vertex[hips_id].y / _base_hips_height
	print('Fit skeleton to mesh')

func _reset_animator() -> void:
	for child in get_children():
		if child is AnimationTree or child is AnimationPlayer:
			_delete_child_node(child)
	var animator: PackedScene = _animator
	if animator == null:
		animator = HumanizerGlobal.config.default_animation_tree
	if animator != null:
		var tree := animator.instantiate() as AnimationTree
		if tree == null:
			printerr('Default animation tree scene does not have an AnimationTree as its root node')
			return
		_add_child_node(tree)
		tree.active = true
		set_editable_instance(tree, true)
		var root_bone = skeleton.get_bone_name(0)
		if root_bone in ['Root']:
			tree.root_motion_track = NodePath(str(skeleton.get_path()) + ":" + root_bone)

#### Additional Components ####
func set_component_state(enabled: bool, component: String) -> void:
	if enabled:
		if not human_config.components.has(component):
			human_config.components.append(component)
		if component == &'main_collider':
			_add_main_collider()
		elif component == &'ragdoll':
			_add_physical_skeleton()
	else:
		human_config.components.erase(component)
		if component == &'main_collider':
			_delete_child_node(main_collider)
			main_collider = null
		elif component == &'ragdoll':
			skeleton.physical_bones_stop_simulation()
			for child in skeleton.get_children():
				_delete_child_node(child)

func _add_main_collider() -> void:
	if get_node_or_null('MainCollider') != null:
		main_collider = $MainCollider
	else:
		main_collider = CollisionShape3D.new()
		main_collider.shape = CapsuleShape3D.new()
		main_collider.name = &'MainCollider'
		_add_child_node(main_collider)
	_adjust_main_collider()

func _add_physical_skeleton() -> void:
	var layers = _ragdoll_layers
	var mask = _ragdoll_mask
	if layers == null:
		layers = HumanizerGlobal.config.default_physical_bone_layers
	if mask == null:
		mask = HumanizerGlobal.config.default_physical_bone_mask
	HumanizerPhysicalSkeleton.new(skeleton, _helper_vertex, layers, mask).run()
	skeleton.physical_bones_start_simulation()

func _adjust_main_collider():
	var height = _helper_vertex[14570].y
	main_collider.shape.height = height
	main_collider.position.y = height/2

	var width_ids = [shoulder_id,waist_id,hips_id]
	var max_width = 0
	for mh_id in width_ids:
		var vertex_position = _helper_vertex[mh_id]
		var distance = Vector2(vertex_position.x,vertex_position.z).distance_to(Vector2.ZERO)
		if distance > max_width:
			max_width = distance
	main_collider.shape.radius = max_width * 1.5
