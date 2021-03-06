extends KinematicBody

# How strong gravity pulls us down.
const GRAVITY = -24.8
# Our KinematicBody’s velocity.
var vel = Vector3()
# The fastest speed we can reach. Once we hit this speed, we will not go any faster.
const MAX_SPEED = 20
# How high we can jump.
const JUMP_SPEED = 18
# How quickly we accelerate. The higher the value, the sooner we get to max speed.
const ACCEL = 4.5
# How quickly we are going to decelerate. The higher the value,
# the sooner we will come to a complete stop.
const DEACCEL = 16

# Sprinting Variables
const MAX_SPRINT_SPEED = 30
const SPRINT_ACCEL = 18
var is_sprinting = false

# This is a variable we will be using to hold the player’s flash light node.
var flashlight
var is_flashlightOn = true

var dir = Vector3()

# The steepest angle our KinematicBody will consider as a ‘floor’.
const MAX_SLOPE_ANGLE = 40

# The Camera node.
var camera
# A Spatial node holding everything we want to rotate on the X axis (up and down).
var rotation_helper

# How sensitive the mouse is. I find a value of 0.05 works well for my mouse,
# but you may need to change it based on how sensitive your mouse is.
var MOUSE_SENSITIVITY = 0.1

# The value of the mouse scroll wheel.
var mouse_scroll_value = 0
# How much a single scroll action increases mouse_scroll_value
var MOUSE_SENSITIVITY_SCROLL_WHEEL = 0.08

# This will hold the AnimationPlayer node and its script, which we wrote previously.
var animation_manager

# The name of the weapon we are currently using.
var current_weapon_name = "UNARMED"
# A dictionary that will hold all the weapon nodes.
var weapons = {"UNARMED":null, "KNIFE":null, "PISTOL":null, "RIFLE":null}
# A dictionary allowing us to convert from a weapon’s number to its name.
# We’ll use this for changing weapons.
const WEAPON_NUMBER_TO_NAME = {0:"UNARMED", 1:"KNIFE", 2:"PISTOL", 3:"RIFLE"}
# A dictionary allowing us to convert from a weapon’s name to its number.
# We’ll use this for changing weapons.
const WEAPON_NAME_TO_NUMBER = {"UNARMED":0, "KNIFE":1, "PISTOL":2, "RIFLE":3}
# A boolean to track whether or not we are changing guns/weapons.
var changing_weapon = false
# The name of the weapon we want to change to.
var changing_weapon_name = "UNARMED"

# The amount of grenades the player is currently carrying (for each type of grenade).
var grenade_amounts = {"Grenade":2, "Sticky Grenade":2}
# The name of the grenade the player is currently using.
var current_grenade = "Grenade"
# The grenade scene we worked on earlier.
var grenade_scene = preload("res://Grenade.tscn")
# The sticky grenade scene we worked on earlier.
var sticky_grenade_scene = preload("res://Sticky_Grenade.tscn")
# The force at which the player will throw the grenades.
const GRENADE_THROW_FORCE = 50
# Maximum grenade player can have
const MAX_GRENADE = 4

# A variable to hold the grabbed RigidBody node.
var grabbed_object = null
# The force with which the player throws the grabbed object.
const OBJECT_THROW_FORCE = 120
# The distance away from the camera at which the player holds the grabbed object.
const OBJECT_GRAB_DISTANCE = 7
# The distance the Raycast goes. This is the player’s grab distance.
const OBJECT_GRAB_RAY_DISTANCE = 10
# Variable's to store grabbed object collision properties
var grabbed_object_collision_layer
var grabbed_object_collision_mask

# A variable to track whether or not the player is currently trying to reload.
var reloading_weapon = false

# How much health our player has.
var health = 100
# The maximum amount of health a player can have.
const MAX_HEALTH = 150

# The amount of time (in seconds) it takes to respawn.
const RESPAWN_TIME = 4
# A variable to track how long the player has been dead.
var dead_time = 0
# A variable to track whether or not the player is currently dead.
var is_dead = false

# A variable to hold the Globals.gd singleton.
var globals

# A label to show how much health we have, and how much ammo we have both in
# our gun and in reserve.
var UI_status_label

# Called when the node enters the scene tree for the first time.
func _ready():
	
	# Get the Globals.gd singleton and assigning it to globals.
	globals = get_node("/root/Globals")
	# Set the player’s global position by setting the origin in the player’s
	# global Transform to the position returned by globals.get_respawn_position.
	global_transform.origin = globals.get_respawn_position()
	
	# Set the Mouse sensitivity
	MOUSE_SENSITIVITY = globals.mouse_sensitivity
	MOUSE_SENSITIVITY_SCROLL_WHEEL = globals.mouse_scroll_sensitivity
	
	# Getting Elements in variable
	camera = $Rotation_Helper/Camera
	rotation_helper = $Rotation_Helper
	
	# we get the AnimationPlayer node and assign it to the animation_manager variable.
	animation_manager = $Rotation_Helper/Model/Animation_Player
	# set the callback function to a FuncRef that will call the player’s
	# fire_bullet function.
	animation_manager.callback_function = funcref(self, "fire_bullet")
	
	# Setting Mouse as input mode
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Get all the weapon nodes and assign them to weapons.
	weapons["KNIFE"] = $Rotation_Helper/Gun_Fire_Points/Knife_Point
	weapons["PISTOL"] = $Rotation_Helper/Gun_Fire_Points/Pistol_Point
	weapons["RIFLE"] = $Rotation_Helper/Gun_Fire_Points/Rifle_Point
	
	# Get Gun_Aim_Point’s global position so we can rotate the player’s weapons
	# to aim at it.
	var gun_aim_point_pos = $Rotation_Helper/Gun_Aim_Point.global_transform.origin
	
	for weapon in weapons:
		var weapon_node = weapons[weapon]
		if weapon_node != null:
			# Set its player_node variable to this script (Player.gd)
			weapon_node.player_node = self
			
			weapon_node.look_at(gun_aim_point_pos, Vector3(0,1,0))
			weapon_node.rotate_object_local(Vector3(0,1,0), deg2rad(180))
	
	current_weapon_name = "UNARMED"
	changing_weapon_name = "UNARMED"
	
	UI_status_label = $HUD/Panel/Gun_label
	flashlight = $Rotation_Helper/Flashlight

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if !is_dead:
		process_input(delta)
		process_movement(delta)
	
	if grabbed_object == null:
		process_changing_weapons(delta)
		process_reloading(delta)
	
	process_UI(delta)
	process_respawn(delta)

#warning-ignore:unused_argument
func process_input(delta):
	#------------------------------------------------------------------
	#---------------------------- WALKING -----------------------------
	# Will be used for storing the direction the player intends to move towards.
	# Because we do not want the player’s previous input to effect the player beyond
	# a single process_movement call, we reset dir.
	dir = Vector3()
	var cam_xfrom = camera.get_global_transform()
	
	var input_movement_vector = Vector2()
	
	if Input.is_action_pressed("movement_forward"):
		input_movement_vector.y += 1
	if Input.is_action_pressed("movement_backward"):
		input_movement_vector.y -= 1
	if Input.is_action_pressed("movement_right"):
		input_movement_vector.x += 1
	if Input.is_action_pressed("movement_left"):
		input_movement_vector.x -= 1
	
	input_movement_vector = input_movement_vector.normalized()
	
	dir += -cam_xfrom.basis.z.normalized() * input_movement_vector.y
	dir += cam_xfrom.basis.x.normalized() * input_movement_vector.x
	#------------------------------------------------------------------
	
	#------------------------------------------------------------------
	#---------------------------- JUMPING -----------------------------
	if is_on_floor():
		if Input.is_action_pressed("movement_jump"):
			vel.y = JUMP_SPEED
	#------------------------------------------------------------------
	
	#------------------------------------------------------------------
	#---------------- Capturing/Freeing the cursor --------------------
	if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	#------------------------------------------------------------------
	
	#------------------------------------------------------------------
	#--------------------------- SPRINTING ----------------------------
	if Input.is_action_pressed("movement_sprint"):
		is_sprinting = true
	else:
		is_sprinting = false
	#------------------------------------------------------------------
	
	#------------------------------------------------------------------
	#------------------- Truning Flashlight ON/OFF --------------------
	if Input.is_action_just_pressed("flashlight"):
		if is_flashlightOn:
			flashlight.hide()
			is_flashlightOn = false
		else:
			flashlight.show()
			is_flashlightOn = true
	#------------------------------------------------------------------
	
	#------------------------------------------------------------------
	#----------------------- Changing Weapons -------------------------
	# Get the current weapon’s number and assign it to weapon_change_number.
	var weapon_change_number = WEAPON_NAME_TO_NUMBER[current_weapon_name]
	
	if Input.is_key_pressed(KEY_1):
		weapon_change_number = 0
	if Input.is_key_pressed(KEY_2):
		weapon_change_number = 1
	if Input.is_key_pressed(KEY_3):
		weapon_change_number = 2
	if Input.is_key_pressed(KEY_4):
		weapon_change_number = 3
	
	if Input.is_action_just_pressed("shift_weapon_positive"):
		weapon_change_number += 1
	if Input.is_action_just_pressed("shift_weapon_negative"):
		weapon_change_number -= 1
	
	weapon_change_number = clamp(weapon_change_number, 0, WEAPON_NAME_TO_NUMBER.size() - 1)
	
	if changing_weapon == false:
		if reloading_weapon == false:
			if WEAPON_NUMBER_TO_NAME[weapon_change_number] != current_weapon_name:
				changing_weapon_name = WEAPON_NUMBER_TO_NAME[weapon_change_number]
				changing_weapon = true
				mouse_scroll_value = weapon_change_number
	#------------------------------------------------------------------
	
	#------------------------------------------------------------------
	#------------------------- Firing Weapon --------------------------
	if Input.is_action_pressed("fire"):
		if reloading_weapon == false:
			if changing_weapon == false:
				var current_weapon = weapons[current_weapon_name]
				if current_weapon != null:
					if current_weapon.ammo_in_weapon > 0:
						if animation_manager.current_state == current_weapon.IDLE_ANIM_NAME:
							animation_manager.set_animation(current_weapon.FIRE_ANIM_NAME)
					else:
						reloading_weapon = true
	#------------------------------------------------------------------
	
	#------------------------------------------------------------------
	#------------------ Changing & Throwing Grenade -------------------
	if Input.is_action_just_pressed("change_grenade"):
		if current_grenade == "Grenade":
			current_grenade = "Sticky Grenade"
		elif current_grenade == "Sticky Grenade":
			current_grenade = "Grenade"
	
	if Input.is_action_just_pressed("fire_grenade"):
		if grenade_amounts[current_grenade] > 0:
			grenade_amounts[current_grenade] -= 1
			
			var grenade_clone
			if current_grenade == "Grenade":
				grenade_clone = grenade_scene.instance()
			elif current_grenade == "Sticky Grenade":
				grenade_clone = sticky_grenade_scene.instance()
				# Sticky grenades will stick to the player if we do not pass ourselves
				grenade_clone.player_body = self
			
			get_tree().root.add_child(grenade_clone)
			grenade_clone.global_transform = $Rotation_Helper/Grenade_Toss_Pos.global_transform
			grenade_clone.apply_impulse(Vector3(0,0,0), grenade_clone.global_transform.basis.z * GRENADE_THROW_FORCE)
	#------------------------------------------------------------------
	
	#------------------------------------------------------------------
	#------------------ Grabbing & Throwing Objects -------------------
	if Input.is_action_just_pressed("fire") and current_weapon_name == "UNARMED":
		if grabbed_object == null:
			var state = get_world().direct_space_state
			
			var center_position = get_viewport().size/2
			var ray_from = camera.project_ray_origin(center_position)
			var ray_to = ray_from + camera.project_ray_normal(center_position) * OBJECT_GRAB_RAY_DISTANCE
			var ray_result = state.intersect_ray(ray_from, ray_to, [self, $Rotation_Helper/Gun_Fire_Points/Knife_Point/Area])
			if ray_result.size() > 0:
				if ray_result["collider"] is RigidBody:
					grabbed_object = ray_result["collider"]
					print(grabbed_object)
					grabbed_object.mode = RigidBody.MODE_STATIC

					grabbed_object_collision_layer = grabbed_object.collision_layer
					grabbed_object_collision_mask = grabbed_object.collision_mask
					grabbed_object.collision_layer = 0
					grabbed_object.collision_mask = 0
		else:
			grabbed_object.mode = RigidBody.MODE_RIGID
			
			grabbed_object.apply_impulse(Vector3(0,0,0), -camera.global_transform.basis.z.normalized() * OBJECT_THROW_FORCE)
			
			grabbed_object.collision_layer = grabbed_object_collision_layer
			grabbed_object.collision_mask = grabbed_object_collision_mask
			grabbed_object_collision_layer = 0
			grabbed_object_collision_mask = 0
			
			grabbed_object = null
	
	if grabbed_object != null:
		grabbed_object.global_transform.origin = camera.global_transform.origin + \
		(-camera.global_transform.basis.z.normalized() * OBJECT_GRAB_DISTANCE)
	#------------------------------------------------------------------
	
	#------------------------------------------------------------------
	#--------------------------- RELOADING ----------------------------
	if reloading_weapon == false:
		if changing_weapon == false:
			if Input.is_action_just_pressed("reload"):
				var current_weapon = weapons[current_weapon_name]
				if current_weapon != null:
					if current_weapon.CAN_RELOAD == true:
						var current_anim_state = animation_manager.current_state
						var is_reloading = false
						for weapon in weapons:
							var weapon_node = weapons[weapon]
							if weapon_node != null:
								if current_anim_state == weapon_node.RELOADING_ANIM_NAME:
									is_reloading = true
						if is_reloading == false:
							reloading_weapon = true
	#------------------------------------------------------------------

func process_movement(delta):
	dir.y = 0
	# We normalize dir to ensure we’re within a 1 radius unit circle.
	dir = dir.normalized()
	
	# We add gravity to the player.
	vel.y += delta * GRAVITY
	
	var hvel = vel
	hvel.y = 0
	
	var target = dir
	# We multiply that by the player’s max speed so we know how far the player
	# will move in the direction provided by dir.
	if is_sprinting:
		target *= MAX_SPRINT_SPEED
	else:
		target *= MAX_SPEED
	
	var accel
	# We then take the dot product of hvel to see if the player is moving
	# according to hvel. Remember, hvel does not have any Y velocity,
	# meaning we are only checking if the player is moving forwards, backwards,
	# left, or right.
	if dir.dot(hvel) > 0:
		if is_sprinting:
			accel = SPRINT_ACCEL
		else:
			accel = ACCEL
	else:
		accel = DEACCEL
	
	hvel = hvel.linear_interpolate(target, accel*delta)
	vel.x = hvel.x
	vel.z = hvel.z
	vel = move_and_slide(vel, Vector3(0,1,0), 0.05, 4, deg2rad(MAX_SLOPE_ANGLE))

func process_changing_weapons(delta):
	# The first thing we do is make sure we’ve received input to change weapons.
	# We do this by making sure changing_weapons is true.
	if changing_weapon == true:
		# To check whether the current weapon has been successfully unequipped or not.
		var weapon_unequipped = false
		# Get the current weapon from weapons.
		var current_weapon = weapons[current_weapon_name]
		
		if current_weapon == null:
			weapon_unequipped = true
		else:
			if current_weapon.is_weapon_enabled == true:
				weapon_unequipped = current_weapon.unequip_weapon()
			else:
				weapon_unequipped = true
		
		if weapon_unequipped == true:
			var weapon_equipped = false
			var weapon_to_equip = weapons[changing_weapon_name]
			
			if weapon_to_equip == null:
				weapon_equipped = true
			else:
				if weapon_to_equip.is_weapon_enabled == false:
					weapon_equipped == weapon_to_equip.equip_weapon()
				else:
					weapon_equipped = true
			
			if weapon_equipped == true:
				changing_weapon = false
				current_weapon_name = changing_weapon_name
				changing_weapon_name = ""

func process_UI(delta):
	if current_weapon_name == "UNARMED" or current_weapon_name == "KNIFE":
		UI_status_label.text = "HEALTH: " + str(health) + \
			"\n" + current_grenade + ": " + str(grenade_amounts[current_grenade])
	else:
		var current_weapon = weapons[current_weapon_name]
		UI_status_label.text = "HEALTH: " + str(health) + \
		"\nAMMO: " + str(current_weapon.ammo_in_weapon) + \
		"/" + str(current_weapon.spare_ammo) + \
		"\n" + current_grenade + ": " + str(grenade_amounts[current_grenade])

func process_reloading(delta):
	if reloading_weapon == true:
		var current_weapon = weapons[current_weapon_name]
		if current_weapon != null:
			current_weapon.reload_weapon()
		reloading_weapon = false

func process_respawn(delta):
	# If we've just died
	if health <= 0 and !is_dead:
		$Body_CollisionShape.disabled = true
		$Feet_CollisionShape.disabled = true
		
		changing_weapon = true
		changing_weapon_name = "UNARMED"
		
		$HUD/Death_Screen.visible = true
		
		$HUD/Panel.visible = false
		$HUD/Crosshair.visible = false
		
		dead_time = RESPAWN_TIME
		is_dead = true
		
		if grabbed_object != null:
			grabbed_object.mode = RigidBody.MODE_RIGID
			grabbed_object.apply_impulse(Vector3(0,0,0), -camera.global_transform.basis.z.normalized() * OBJECT_THROW_FORCE / 2)
			
			grabbed_object.collision_layer = grabbed_object_collision_layer
			grabbed_object.collision_mask = grabbed_object_collision_mask
			grabbed_object_collision_layer = 0
			grabbed_object_collision_mask = 0
			
			grabbed_object = null
	
	if is_dead:
		dead_time -= delta
		
		var dead_time_formatted = str(dead_time).left(3)
		$HUD/Death_Screen/Label.text = "You died\n" + dead_time_formatted + " seconds till respawn"
		
		if dead_time <= 0:
			global_transform.origin = globals.get_respawn_position()
			
			$Body_CollisionShape.disabled = false
			$Feet_CollisionShape.disabled = false
			
			$HUD/Death_Screen.visible = false
			
			$HUD/Panel.visible = true
			$HUD/Crosshair.visible = true
			
			for weapon in weapons:
				var weapon_node = weapons[weapon]
				if weapon_node != null:
					weapon_node.reset_weapon()
			
			health = 100
			grenade_amounts = {"Grenade": 2, "Sticky Grenade": 2}
			current_grenade = "Grenade"
			
			is_dead = false

func _input(event):
	if is_dead:
		return
	
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation_helper.rotate_x(deg2rad(event.relative.y * MOUSE_SENSITIVITY))
		self.rotate_y(deg2rad(event.relative.x * MOUSE_SENSITIVITY * -1))
	
	var camera_rot = rotation_helper.rotation_degrees
	camera_rot.x = clamp(camera_rot.x, -70, 70)
	rotation_helper.rotation_degrees = camera_rot
	
	# If the event is an InputEventMouseButton event and
	# that the mouse mode is MOUSE_MODE_CAPTURED. 
	if event is InputEventMouseButton and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == BUTTON_WHEEL_UP or event.button_index == BUTTON_WHEEL_DOWN:
			if event.button_index == BUTTON_WHEEL_UP:
				mouse_scroll_value += MOUSE_SENSITIVITY_SCROLL_WHEEL
			elif event.button_index == BUTTON_WHEEL_DOWN:
				mouse_scroll_value -= MOUSE_SENSITIVITY_SCROLL_WHEEL
			
			mouse_scroll_value = clamp(mouse_scroll_value, 0, WEAPON_NUMBER_TO_NAME.size() -1)
			
			if changing_weapon == false:
				if reloading_weapon == false:
					var round_mouse_scroll_value = int(round(mouse_scroll_value))
					if WEAPON_NUMBER_TO_NAME[round_mouse_scroll_value] != current_weapon_name:
						changing_weapon_name = WEAPON_NUMBER_TO_NAME[round_mouse_scroll_value]
						changing_weapon = true
						mouse_scroll_value = round_mouse_scroll_value

# This function will be called by AnimationManager at key points defined in Animation.
func fire_bullet():
	if changing_weapon == true:
		return
	
	weapons[current_weapon_name].fire_weapon()

func create_sound(sound_name, loop, position=null):
	globals.play_sound(sound_name, loop, position)

func add_ammo(additional_ammo):
	if current_weapon_name != "UNARMED":
		if weapons[current_weapon_name].CAN_REFILL == true:
			weapons[current_weapon_name].spare_ammo += \
			weapons[current_weapon_name].AMMO_IN_MAG * additional_ammo

func add_health(additional_health):
	# Add additional_health to the player’s current health.
	health += additional_health
	# Clamp the health so that it cannot take on a value higher than MAX_HEALTH,
	# nor a value lower than 0.
	health = clamp(health, 0, MAX_HEALTH)

func add_grenade(additional_grenade):
	for grenade in grenade_amounts:
		grenade_amounts[grenade] += additional_grenade
		grenade_amounts[grenade] = clamp(grenade_amounts[grenade], 0, MAX_GRENADE)

func bullet_hit(damage, bullet_hit_pos):
	health -= damage

