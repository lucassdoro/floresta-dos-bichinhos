extends Node2D

## Letreiro de neon tracado por partes. Tempos e piscadas vem de
## packages/doma_splash/lib/src/timeline.dart.

const LogoPaths := preload("res://ui/splash/logo_paths.gd")

const PART_ONSET := {"D_PURPLE": 0.15, "D_WHITE": 0.70, "DPAD_CROSS": 1.30, "DPAD_BUTTONS": 1.60}
const PART_DURATION := {"D_PURPLE": 0.70, "D_WHITE": 0.70, "DPAD_CROSS": 0.45, "DPAD_BUTTONS": 0.40}
## Quedas de tubo entre o hold e o estouro: irregular de proposito.
const BLACKOUTS := [[2.72, 2.80], [2.88, 2.93]]
const PURPLE := Color("6c30d6")
const WHITE := Color("f6f6f8")
const TUBE_WIDTH := 22.0
const TARGET_HEIGHT := 420.0

var elapsed := 0.0
var _art_offset := Vector2.ZERO

var _parts := {
	"D_PURPLE": LogoPaths.D_PURPLE,
	"D_WHITE": LogoPaths.D_WHITE,
	"DPAD_CROSS": LogoPaths.DPAD_CROSS,
	"DPAD_BUTTONS": LogoPaths.DPAD_BUTTONS,
}

func _ready() -> void:
	_fit_to_art()

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	# a posicao do no' e' de quem monta a cena; o enquadramento entra aqui
	draw_set_transform(_art_offset)
	var dip := flicker() * (0.12 if in_blackout() else 1.0)
	for part in _parts:
		var drawn := progress(PART_ONSET[part], PART_DURATION[part])
		if drawn <= 0.0:
			continue
		# a parte so' acende conforme e' tracada; o pisca derruba a brasa, nao apaga
		var glow := drawn * dip
		draw_part(_parts[part], drawn, color_of(part) * glow)

func draw_part(contours: Array, fraction: float, color: Color) -> void:
	var total := 0
	for contour in contours:
		total += contour.size()
	var allowed := int(total * fraction)
	for contour in contours:
		if allowed <= 1:
			return
		draw_polyline(contour.slice(0, mini(contour.size(), allowed)), color, TUBE_WIDTH, true)
		allowed -= contour.size()

## brilho tremulando: nunca apaga, so' oscila
func flicker() -> float:
	return 1.0 + 0.05 * sin(elapsed * 17.3) * sin(elapsed * 6.1)

func in_blackout() -> bool:
	for faixa in BLACKOUTS:
		if elapsed >= faixa[0] and elapsed < faixa[1]:
			return true
	return false

func progress(onset: float, duration: float) -> float:
	return clampf((elapsed - onset) / duration, 0.0, 1.0)

func color_of(part: String) -> Color:
	return PURPLE if part in ["D_PURPLE", "DPAD_BUTTONS"] else WHITE

## A arte ocupa so' parte da caixa de 1024: centrar pela caixa jogaria a logo
## pra cima da tela, entao o enquadramento sai dos pontos de verdade.
func _fit_to_art() -> void:
	var minimo := Vector2.INF
	var maximo := -Vector2.INF
	for part in _parts:
		for contour in _parts[part]:
			for ponto in contour:
				minimo = minimo.min(ponto)
				maximo = maximo.max(ponto)
	var tamanho := maximo - minimo
	var fator := TARGET_HEIGHT / tamanho.y
	scale = Vector2.ONE * fator
	_art_offset = -(minimo + tamanho / 2.0)
