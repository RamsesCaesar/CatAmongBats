extends KinematicBody2D

const PlayerHurtSound = preload("res://Player/PlayerHurtSound.tscn")
const defeatScreen = preload("res://UI/Menus and Pop Ups/DefeatScreen.tscn")

export var ACCELERATION = 510
export var MAX_SPEED = 90
export var SPRINT_SPEED = 165
export var FRICTION = 600

enum {
	MOVE
	SPRINT
	ATTACK
}

var state = MOVE
var velocity = Vector2.ZERO
var sprint_vector = Vector2.DOWN
var stats = PlayerStats

# Links to other Nodes further down the tree:
onready var animationPlayer = $AnimationPlayer
onready var animationTree = $AnimationTree
onready var animationState = animationTree.get("parameters/playback")
onready var swordHitbox = $"HitBoxPivot/Sword-Hitbox"
onready var hurtbox = $HurtBox
onready var blinkAnimationPlayer = $BlinkAnimationPlayer

func _ready():
	randomize()
	stats.connect("no_health", self, "death")
	animationTree.active = true
	swordHitbox.knockback_vector = sprint_vector
	
# (Disable hitbox, because it can easily be wrongfully activated in the editor:)
	$"HitBoxPivot/Sword-Hitbox/CollisionShape2D".disabled = true
	
# (Disable the blinkAnimationPlayer if the game is restarted:)
	blinkAnimationPlayer.play("Stop")
	
# When the player dies:
func death():
	queue_free()
	get_tree().current_scene.get_node("CanvasLayer/DefeatScreen").show()

# Every frame:
func _process(delta):
	match state:
		MOVE:
			move_state(delta)
		SPRINT:
			sprint_state()
		ATTACK:
			attack_state()

# movement:
func move_state(delta):
	var input_vector = determine_input_vector()
	# acceleration:
	if input_vector != Vector2.ZERO:
		sprint_vector = input_vector
		swordHitbox.knockback_vector = input_vector
		set_animation_tree_direction(input_vector)
		velocity = velocity.move_toward(input_vector * MAX_SPEED, ACCELERATION * delta)
		animationState.travel("Run")
	# stopping:
	else:
		animationState.travel("Idle")
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	
	if Input.is_action_just_pressed("sprint"):
		state = SPRINT
	if Input.is_action_just_pressed("attack"):
		state = ATTACK
	move()
# attack:
func attack_state():
	animationState.travel("Attack")
# sprint:
func sprint_state():
	velocity = sprint_vector * SPRINT_SPEED
	animationState.travel("Sprint")
	move()

# The move() function takes all the calculations that were made 
# for the "velocity" variable and performs the movement of the Player scene
# upon its parent scene.
func move():
	velocity = move_and_slide(velocity)

# This function is called by the Player scene's child, AnimationPlayer, when one 
# of the attack animations finishes. (This is a mechanism that gets set with 
# the Godot editor rather than code).
func attack_animation_finished():
	state = MOVE
	
func sprint_animation_finished():
	velocity *= 0.8
	state = MOVE


func _on_HurtBox_area_entered(area):
	# Deduct health point(s)
	stats.health -= area.damage
	# Start temporary invincibility.
	hurtbox.start_invincibility(1)
	hurtbox.create_hit_effect()
	# Make a meow sound every second time the player (cat) takes damage.
	if stats.health % 2 == 0:
		var playerHurtsound = PlayerHurtSound.instance()
		get_tree().current_scene.add_child(playerHurtsound)


func _on_HurtBox_invincibility_started():
	blinkAnimationPlayer.play("Start")

func _on_HurtBox_invincibility_ended():
	blinkAnimationPlayer.play("Stop")
	
func determine_input_vector():
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	input_vector = input_vector.normalized()
	return input_vector
	
func set_animation_tree_direction(input_vector):
	animationTree.set("parameters/Idle/blend_position", input_vector)
	animationTree.set("parameters/Run/blend_position", input_vector)
	animationTree.set("parameters/Attack/blend_position", input_vector)
	animationTree.set("parameters/Sprint/blend_position", input_vector)
