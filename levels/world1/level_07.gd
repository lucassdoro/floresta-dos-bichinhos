extends LevelBase

## Fase 7 do mundo 1 — "Salada da Sophy": alimentos sao arremessados em arco
## e a crianca corta passando o dedo. Cortar bomba custa uma estrela; a cada
## 5 alimentos perdidos, mais uma.

const INTRO_DELAY := 0.6
const INTRO_HOLD := 0.8
const SPAWN_GAP := 0.85
const SPAWN_JITTER := 0.2
const WAVE_REST := 0.6
const SHAKE_SECONDS := 0.35
const SHAKE_AMPLITUDE := 14.0
const HOP_SECONDS := 0.32
const HOP_HEIGHT := 22.0
const MIN_STEP := 12.0
const RESOUND_DISTANCE := 350.0

const SLASH_SFX := preload("res://assets/audio/SFX/slash.wav")
const SLICE_SFX := preload("res://assets/audio/SFX/fruit_slice.wav")
const EXPLOSION_SFX := preload("res://assets/audio/SFX/explosion.wav")

# nome, tamanho logico, giro calmo
const FOOD_KINDS := [
	["orange", 170.0, false],
	["apple", 150.0, false],
	["watermelon", 250.0, true],
	["grapes", 160.0, true],
]
const BOMB_SIZE := 150.0
# as duas primeiras ondas nao tem bomba: treino antes da regra
const WAVES := [[3, 0], [4, 0], [4, 1], [5, 1], [5, 1]]

var _arena_enabled := false
var _pressing := false
var _last_point := Vector2.ZERO
var _since_sound := 0.0
var _bombs_cut := 0
var _foods_dropped := 0
var _shake := 0.0
var _hop := 0.0
var _sophy_base_y := 0.0

@onready var _trail: SlashTrail = %Trail
@onready var _game_root: Control = %GameRoot
@onready var _sophy: AnimatedSprite2D = %Sophy
@onready var _bubble: SpeechBubble = %Bubble
@onready var _confetti: GPUParticles2D = $Confetti

func _ready() -> void:
	super()
	_sophy_base_y = _sophy.position.y
	_run_level()

func _run_level() -> void:
	await _wait(INTRO_DELAY)
	if _dead():
		return
	_bubble.show_bubble()
	_bubble.say(tr("level17.intro"))
	if Voice.play("Sophy", "02_intro"):
		await Voice.finished
	if _dead():
		return
	if _bubble._typing:
		await _bubble.typing_finished
	await _wait(INTRO_HOLD)
	if _dead():
		return
	_bubble.hide_bubble()
	_arena_enabled = true
	_run_waves()

func _run_waves() -> void:
	for wave in WAVES:
		var queue: Array[bool] = []
		for i in wave[0]:
			queue.append(false)
		for i in wave[1]:
			queue.append(true)
		queue.shuffle()
		for is_bomb in queue:
			if _dead():
				return
			_spawn(is_bomb)
			await _wait(SPAWN_GAP + randf_range(-SPAWN_JITTER, SPAWN_JITTER))
		while not _dead() and _has_live_items():
			await _wait(0.1)
		if _dead():
			return
		await _wait(WAVE_REST)
	if _dead():
		return
	_arena_enabled = false
	_trail.clear()
	_confetti.restart()
	win()

func _has_live_items() -> bool:
	for child in _game_root.get_children():
		if child is FlyingItem and not child.sliced:
			return true
	return false

func stars_now() -> int:
	return clampi(3 - (_bombs_cut + _foods_dropped / 5), 1, 3)

func _spawn(is_bomb: bool) -> void:
	var start_x := size.x * randf_range(0.25, 0.8)
	var start_y := size.y + 120.0
	var apex_y := size.y * randf_range(0.18, 0.45)
	var vy := -sqrt(2.0 * FlyingItem.GRAVITY * (start_y - apex_y))
	var to_center := signf(size.x / 2.0 - start_x)
	var vx := to_center * randf_range(40.0, 160.0)

	if is_bomb:
		var bomb := FlyingBomb.new()
		bomb.item_size = Vector2.ONE * BOMB_SIZE
		bomb.velocity = Vector2(vx, vy)
		bomb.spin = _random_spin(false)
		bomb.despawn_x = size.x + 500.0
		bomb.despawn_y = size.y + 400.0
		bomb.position = Vector2(start_x, start_y)
		for i in range(4):
			bomb.fuse_frames.append(load("res://assets/art/MiniGames/FruitSlice/bomb_%02d.webp" % i))
		for i in range(4, 15):
			bomb.blast_frames.append(load("res://assets/art/MiniGames/FruitSlice/bomb_%02d.webp" % i))
		bomb.exploded.connect(_on_bomb_cut)
		_game_root.add_child(bomb)
		return

	var kind: Array = FOOD_KINDS[randi() % FOOD_KINDS.size()]
	var food := FlyingFood.new()
	food.whole = load("res://assets/art/MiniGames/FruitSlice/%s_whole.webp" % kind[0])
	food.top = load("res://assets/art/MiniGames/FruitSlice/%s_top.webp" % kind[0])
	food.bottom = load("res://assets/art/MiniGames/FruitSlice/%s_bottom.webp" % kind[0])
	var texture_size := Vector2(food.whole.get_width(), food.whole.get_height())
	food.item_size = texture_size * (kind[1] / maxf(texture_size.x, texture_size.y))
	food.velocity = Vector2(vx, vy)
	food.spin = _random_spin(kind[2])
	food.despawn_x = size.x + 500.0
	food.despawn_y = size.y + 400.0
	food.position = Vector2(start_x, start_y)
	food.escaped.connect(_on_food_dropped)
	_game_root.add_child(food)

## Giro leve: 1/9 a 1/4 de volta no voo. Sprite grande sorteia a metade de
## baixo da faixa.
func _random_spin(calm: bool) -> float:
	var magnitude := randf_range(0.4, 0.7) if calm else randf_range(0.4, 1.0)
	return magnitude if randf() < 0.5 else -magnitude

# ----- corte -----

func _unhandled_input(event: InputEvent) -> void:
	if not _arena_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_last_point = event.position
			_since_sound = 0.0
			_trail.add_point(event.position)
			Audio.play_sfx(SLASH_SFX)
			# encostar ja corta: crianca pequena toca a fruta em vez de riscar
			_slash(event.position, event.position)
		else:
			_pressing = false
	elif event is InputEventMouseMotion and _pressing:
		var to: Vector2 = event.position
		var step := to.distance_to(_last_point)
		if step < MIN_STEP:
			return
		var from := _last_point
		_last_point = to
		_trail.add_point(to)
		_slash(from, to)
		_since_sound += step
		if _since_sound >= RESOUND_DISTANCE:
			_since_sound = 0.0
			Audio.play_sfx(SLASH_SFX)

func _slash(from: Vector2, to: Vector2) -> void:
	if completed:
		return
	var cut_angle := atan2(to.y - from.y, to.x - from.x)
	for child in _game_root.get_children():
		if not (child is FlyingItem) or child.sliced:
			continue
		if not _segment_hits_circle(from, to, child.position, child.hit_radius()):
			continue
		if child is FlyingFood:
			child.slice(cut_angle)
			Audio.play_sfx(SLICE_SFX)
			_hop = HOP_SECONDS
		elif child is FlyingBomb:
			child.explode()

func _segment_hits_circle(a: Vector2, b: Vector2, center: Vector2, radius: float) -> bool:
	var ab := b - a
	var length_squared := ab.length_squared()
	if length_squared < 1e-6:
		return center.distance_to(a) <= radius
	var t := clampf((center - a).dot(ab) / length_squared, 0.0, 1.0)
	return center.distance_to(a + ab * t) <= radius

func _on_bomb_cut() -> void:
	_bombs_cut += 1
	_shake = SHAKE_SECONDS
	Audio.play_sfx(EXPLOSION_SFX)
	header.set_stars(stars_now())

func _on_food_dropped() -> void:
	_foods_dropped += 1
	header.set_stars(stars_now())

func _process(delta: float) -> void:
	if _hop > 0.0:
		_hop -= delta
		var t := clampf(1.0 - _hop / HOP_SECONDS, 0.0, 1.0)
		_sophy.position.y = _sophy_base_y - sin(t * PI) * HOP_HEIGHT
		if _hop <= 0.0:
			_sophy.position.y = _sophy_base_y
	if _shake > 0.0:
		_shake -= delta
		var strength := clampf(_shake / SHAKE_SECONDS, 0.0, 1.0)
		if _shake > 0.0:
			position = Vector2(
				randf_range(-1.0, 1.0) * SHAKE_AMPLITUDE * strength,
				randf_range(-1.0, 1.0) * SHAKE_AMPLITUDE * strength)
		else:
			position = Vector2.ZERO

func _dead() -> bool:
	return completed or not is_inside_tree()

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
