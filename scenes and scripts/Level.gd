extends Spatial

var size_x : int = 8
var size_z : int = 8
var coll_matrix: Array = []
var obj_dict: Dictionary = {}
var printed_once: bool = false

var MovableObj = preload("res://scenes and scripts/MovableObj.tscn")

func _ready():
	#initialize coll_matrix
	for x in range(size_x):
		coll_matrix.append([])
		for z in range(size_z):
			coll_matrix[x].append(false)
	# test objects
	add_movable_obj(4,4)
	add_movable_obj(5,5)
	

func add_movable_obj(pos_x,pos_z,obj_size_x=1,obj_size_z=1):
	var new_movable_obj = MovableObj.instance()
	add_child(new_movable_obj)
	new_movable_obj.global_transform.origin = Vector3(pos_x+(0.5*obj_size_x),0.5,pos_z+(0.5*obj_size_z))
	new_movable_obj.size_x = obj_size_x
	new_movable_obj.size_z = obj_size_z
	var obj_cs = new_movable_obj.get_node("CollisionShape")
	var obj_dmi = new_movable_obj.get_node("DefaultMeshInstance")
	obj_cs.shape.extents = Vector3(obj_size_x/2.0, 0.5, obj_size_z/2.0)
	obj_dmi.mesh.size = Vector3(obj_size_x,1,obj_size_z)
	for x in range(obj_size_x):
		for z in range(obj_size_z):
			coll_matrix[pos_x+x][pos_z+z] = true
	obj_dict[new_movable_obj] = { "pos": Vector3(pos_x, 0, pos_z) }

func coll_lift(movable_obj):
	var obj_pos = movable_obj.global_transform.origin + Vector3(-movable_obj.size_x/2.0,0,-movable_obj.size_z/2.0)
	for x in range(movable_obj.size_x):
		for z in range(movable_obj.size_z):
			coll_matrix[obj_pos.x+x][obj_pos.z+z] = false

func coll_place(movable_obj):
	var obj_pos = movable_obj.global_transform.origin + Vector3(-movable_obj.size_x/2.0,0,-movable_obj.size_z/2.0)
	obj_dict[movable_obj]["pos"] = Vector3(obj_pos.x, 0, obj_pos.z)
	for x in range(movable_obj.size_x):
		for z in range(movable_obj.size_z):
			coll_matrix[obj_pos.x+x][obj_pos.z+z] = true

func valid_place(pos_x,pos_z,obj_size_x,obj_size_z):
	for x in range(obj_size_x):
		for z in range(obj_size_z):
			var check_x = pos_x+x
			var check_z = pos_z+z
			if check_x >= size_x or check_z >= size_z:
				return false
			if check_x < 0 or check_z < 0:
				return false
			if coll_matrix[check_x][check_z]:
				return false
	return true

func debug_print_coll_matrix():
	print("========")
	for z in size_z:
		var s = ""
		for x in size_x:
			s += "T" if coll_matrix[x][z] else "F"
		print(s)
