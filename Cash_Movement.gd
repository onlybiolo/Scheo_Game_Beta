extends CharacterBody2D

@export var walk_speed = 100.0
@export var run_speed = 180.0
@export var crouch_speed = 50.0
@export var idle_breathe_delay = 4.0  # secondi prima del breathe idle

var last_direction = "down"
var is_crouching = false
var is_transitioning = false
var idle_timer = 0.0
var is_breathing = false

@onready var collision = $CollisionShape2D
@onready var anim = $Player

func _physics_process(delta):
	var input_dir = Vector2(
		Input.get_axis("ui_right", "ui_left"),
		Input.get_axis("ui_up", "ui_down")
	)

	# bloccato durante transizione crouch
	if is_transitioning:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# crouch toggle solo se fermo
	if Input.is_action_just_pressed("crouch") and input_dir == Vector2.ZERO:
		is_transitioning = true
		idle_timer = 0.0
		is_breathing = false
		if is_crouching:
			_play_transition("crouch_up")
		else:
			_play_transition("crouch_down")
		return

	var is_running = Input.is_action_pressed("run") and not is_crouching

	var speed
	if is_crouching:
		speed = crouch_speed
	elif is_running:
		speed = run_speed
	else:
		speed = walk_speed

	velocity = input_dir.normalized() * speed
	move_and_slide()

	# gestione timer breathe — si accumula solo se fermo e non in crouch
	if input_dir == Vector2.ZERO and not is_crouching:
		idle_timer += delta
		if idle_timer >= idle_breathe_delay and not is_breathing:
			is_breathing = true
			_play_breathe()
	else:
		idle_timer = 0.0
		is_breathing = false

	_update_animation(input_dir, is_running)


func _play_transition(anim_name: String):
	match last_direction:
		"side": anim.play(anim_name + "_side")
		"up":   anim.play(anim_name + "_up")
		"down": anim.play(anim_name + "_down")
	await anim.animation_finished
	is_crouching = !is_crouching
	is_transitioning = false
	_aggiorna_hitbox()


func _play_breathe():
	# breathe solo per down e side, up non si vede bene su 32x32
	match last_direction:
		"down": anim.play("idle_breathe_down")
		"side": anim.play("idle_breathe_side")
		"up":   pass  # niente breathe di schiena, torna idle normale
	await anim.animation_finished
	is_breathing = false
	idle_timer = 0.0


func _aggiorna_hitbox():
	if is_crouching:
		collision.shape.size = Vector2(8, 8)
		collision.position = Vector2(0.5, 5.5)
	else:
		collision.shape.size = Vector2(8, 16)
		collision.position = Vector2(0.5, 0.5)


func _update_animation(input_dir: Vector2, is_running: bool):
	# se sta facendo il breathe non interrompere
	if is_breathing:
		return

	if input_dir != Vector2.ZERO:
		if abs(input_dir.x) > abs(input_dir.y):
			last_direction = "side"
			anim.flip_h = input_dir.x < 0
		elif input_dir.y < 0:
			last_direction = "up"
		else:
			last_direction = "down"

		var prefix
		if is_crouching:
			prefix = "crouch"
		elif is_running:
			prefix = "run"
		else:
			prefix = "walk"

		match last_direction:
			"side": anim.play(prefix + "_side")
			"up":   anim.play(prefix + "_up")
			"down": anim.play(prefix + "_down")
	else:
		if is_crouching:
			match last_direction:
				"side": anim.play("crouch_still_side")
				"up":   anim.play("crouch_still_up")
				"down": anim.play("crouch_still_down")
		else:
			match last_direction:
				"side": anim.play("idle_side")
				"up":   anim.play("idle_up")
				"down": anim.play("idle_down")


# ============================================================
# ANIMAZIONI RICHIESTE — 23 totali
# ============================================================
#
# --- IDLE (fermo in piedi) — 6 frame ---
# idle_down           — fermo, guarda in giu, respiro leggero - done
# idle_up             — fermo, guarda in su, spalle che si muovono - done
# idle_side           — fermo, guarda di lato, dondolio leggero - done
#
# --- IDLE BREATHE (dopo 4 sec fermo) — 8 frame ---
# idle_breathe_down   — respiro profondo frontale, più vivo dell'idle - to do
# idle_breathe_side   — respiro profondo laterale - to do
# (idle_up non ha breathe — di schiena non si vede su 32x32)
#
# --- WALK (cammina) — 8 frame ---
# walk_down           — ciclo camminata frontale, braccia oscillano - done
# walk_up             — ciclo camminata di schiena - done
# walk_side           — ciclo camminata laterale, braccia oscillano - done
#
# --- RUN (corre) — 6 frame ---
# run_down            — corpo inclinato in avanti, stride ampio - to do
# run_up              — stesso di schiena, gambe più aperte - to do
# run_side            — corpo inclinato, stride più largo del walk - to do
#
# --- CROUCH TRANSIZIONE GIU (si sta accucciando) — 4 frame ---
# crouch_down_down    — si piega sulle ginocchia, frontale - to do
# crouch_down_up      — stesso di schiena - to do
# crouch_down_side    — si abbassa di lato - done
#
# --- CROUCH TRANSIZIONE SU (si sta rialzando) — 4 frame ---
# crouch_up_down      — si rialza frontale (frame inversi del crouch_down) - to do
# crouch_up_up        — stesso di schiena - to do
# crouch_up_side      — si rialza di lato - done
#
# --- CROUCH STILL (fermo accucciato) — 5 frame ---
# crouch_still_down   — accucciato frontale, respiro minimo - to do
# crouch_still_up     — accucciato di schiena - to do
# crouch_still_side   — accucciato di lato - to do
#
# --- CROUCH WALK (cammina accucciato) — 6 frame ---
# crouch_down         — avanza accucciato frontale, passi corti - to do
# crouch_up           — stesso di schiena - to do
# crouch_side         — striscia di lato, gambe basse - to do
#
# ============================================================
# NOTA FLIP:
# le animazioni _side usano flip_h automatico
# flip_h = true  → guarda a sinistra
# flip_h = false → guarda a destra
# disegna sempre lo sprite che guarda a destra,
# Godot lo specchia da solo per sinistra
#
# NOTA BREATHE:
# idle_breathe_down e idle_breathe_side si attivano
# automaticamente dopo idle_breathe_delay secondi (default 4.0)
# modificabile dall'Inspector senza toccare il codice
# ============================================================
