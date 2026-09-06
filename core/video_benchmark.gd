class_name VideoBenchmark
extends Node

## Mede fps tocando um video escondido no primeiro boot; reprovou, quality cai pra 0.
## Roda uma vez e nunca mais: depois disso o ajuste no menu manda.

signal done

const SAMPLE_VIDEO := "res://assets/video/menu.ogv"
const FIRST_FRAME_TIMEOUT := 3.0
const SAMPLE_DURATION := 2.0
const PASS_RATIO := 0.8
## Video de 24 fps nao precisa de mais que 60 fps: monitor de 144 Hz nao sobe o limiar.
const REFERENCE_REFRESH_RATE := 60.0

var finished := false

static func passes(average_fps: float, refresh_rate: float) -> bool:
	var reference := minf(refresh_rate, REFERENCE_REFRESH_RATE) if refresh_rate > 0.0 else REFERENCE_REFRESH_RATE
	return average_fps >= reference * PASS_RATIO

func _ready() -> void:
	var player := _make_player()
	var got_first_frame := await _wait_first_frame(player)
	var passed := false
	if got_first_frame:
		passed = passes(await _measure_fps(), DisplayServer.screen_get_refresh_rate())
	if not passed:
		Settings.set_value("quality", 0)
	Settings.set_value("benchmarked", true)
	finished = true
	done.emit()
	queue_free()

## Toca em tela cheia e transparente: custo de decode e de desenho iguais ao uso real.
func _make_player() -> VideoStreamPlayer:
	var player := VideoStreamPlayer.new()
	player.stream = load(SAMPLE_VIDEO)
	player.volume_db = -80.0
	player.expand = true
	player.size = get_viewport().get_visible_rect().size
	player.modulate.a = 0.0
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(player)
	player.play()
	return player

func _wait_first_frame(player: VideoStreamPlayer) -> bool:
	var waited := 0.0
	while player.stream_position <= 0.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if waited > FIRST_FRAME_TIMEOUT:
			return false
	return true

func _measure_fps() -> float:
	var elapsed := 0.0
	var frames := 0
	while elapsed < SAMPLE_DURATION:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		frames += 1
	return frames / elapsed
