extends Node2D

## Letreiro de neon da DOMA, copia da cena de packages/doma_splash do stackit
## (neon_painter, layout, scene, word_text, timeline). Simbolo em unidades de
## logo (caixa de 1024), texto em pixels; enquadramento sai da caixa da ARTE.
##
## Cada camada de halo e' um traco largo desfocado. Aqui ela e' desenhada sem
## desfoque num SubViewport (halo_source.gd chama draw_halo) e borrada em duas
## passadas do shader neon_blur; so' o nucleo e' desenhado direto. O reflexo
## no piso espelha a tela pronta (shader neon_reflection), por isso o derrame
## de luz e a poeira entram depois dele (halo_source.gd chama draw_ambient).

const LogoPaths := preload("res://ui/splash/logo_paths.gd")

const PART_ONSET := {"D_PURPLE": 0.15, "D_WHITE": 0.70, "DPAD_CROSS": 1.30, "DPAD_BUTTONS": 1.60}
const PART_DURATION := {"D_PURPLE": 0.70, "D_WHITE": 0.70, "DPAD_CROSS": 0.45, "DPAD_BUTTONS": 0.40}
const WORD_ONSET := 2.05
const WORD_DURATION := 0.55
const FLASH_AT := 3.05
const SPLASH_END := 3.7
## Quedas de tubo entre o hold e o estouro: irregular de proposito.
const BLACKOUTS := [[2.72, 2.80], [2.88, 2.93]]

const PURPLE := Color("6c30d6")
const WHITE := Color("f6f6f8")

## Tubo, em unidades de logo: [largura, desfoque, alpha, quanto embranquece].
## As duas primeiras sao halos (viewport + blur), a ultima e' o nucleo.
const TUBE_LAYERS := [[28.0, 13.0, 0.10, 0.0], [11.0, 5.0, 0.45, 0.15], [4.0, 0.0, 1.0, 0.80]]
## Nome: [alpha, quanto embranquece]. O desfoque do nome usa o do tubo da
## mesma camada (0,20 e 0,09 do corpo na referencia: quase o mesmo valor).
const WORD_LAYERS := [[0.22, 0.0], [0.60, 0.30], [1.0, 0.92]]
## Halos renderizam a meia resolucao.
const HALO_SCALE := 0.5

const MARK_COVERAGE := 0.44
const WORD_SCALE := 0.155
const GAP_SCALE := 0.17
const LIGHT_REACH := 0.30
const DUST_COUNT := 40

## Baixo (~0.75) porque o post do jogo ja aplica bloom por cima.
@export var glow := 0.75
@export var studio_name := "Doma Studio"
@export var font: Font
## Gradiente radial branco -> transparente: derrame de luz no fundo.
@export var light_texture: Texture2D
## Sprites finais dos halos, na ordem de TUBE_LAYERS (largo, medio).
@export var halos: Array[Sprite2D] = []
## ColorRect com o shader neon_reflection: recebe a linha do espelho.
@export var reflection: ColorRect

## Relogio da cena, dirigido pela AnimationPlayer da splash.
var elapsed := 0.0:
	set(value):
		elapsed = value
		queue_redraw()

var _parts := {}
var _screen := Vector2.ZERO
var _art := Rect2()
var _scale := 1.0
var _origin := Vector2.ZERO
var _word_at := Vector2.ZERO
var _font_size := 16
var _bottom := 0.0
var _motes := []

func _ready() -> void:
	var raw := {
		"D_PURPLE": LogoPaths.D_PURPLE,
		"D_WHITE": LogoPaths.D_WHITE,
		"DPAD_CROSS": LogoPaths.DPAD_CROSS,
		"DPAD_BUTTONS": LogoPaths.DPAD_BUTTONS,
	}
	for part in raw:
		_parts[part] = raw[part].map(_clean)
	_art = _bounds_of_all()
	_layout()
	_seed_dust()

func _draw() -> void:
	var state := _state_at(elapsed)
	var level: float = glow * (1.0 + state.flash * 0.6) * state.dip
	for layer in halos.size():
		halos[layer].modulate = Color(1.0, 1.0, 1.0, clampf(WORD_LAYERS[layer][0] * level, 0.0, 1.0))
	var core: Array = TUBE_LAYERS[2]
	draw_set_transform_matrix(_logo_transform())
	for part in _parts:
		var color: Color = color_of(part).lerp(Color.WHITE, core[3])
		color.a = clampf(core[2] * state.draw[part] * level, 0.0, 1.0)
		_stroke(self, _reveal(_parts[part], state.draw[part]), color, core[0])
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var word_color: Color = PURPLE.lerp(WHITE, WORD_LAYERS[2][1])
	word_color.a = clampf(WORD_LAYERS[2][0] * state.word * level, 0.0, 1.0)
	_word(self, word_color)

## Camada de halo, sem desfoque, opaca sobre preto. O alpha da camada vai no
## modulate do sprite final; aqui so' entra a proporcao tubo/nome e o quanto
## cada parte ja foi tracada.
func draw_halo(canvas: CanvasItem, layer: int) -> void:
	var state := _state_at(elapsed)
	var tube: Array = TUBE_LAYERS[layer]
	var word: Array = WORD_LAYERS[layer]
	canvas.draw_rect(Rect2(Vector2.ZERO, _screen), Color.BLACK)
	canvas.draw_set_transform_matrix(_logo_transform())
	for part in _parts:
		var color: Color = color_of(part).lerp(Color.WHITE, tube[3]) * (tube[2] / word[0] * state.draw[part])
		color.a = 1.0
		_stroke(canvas, _reveal(_parts[part], state.draw[part]), color, tube[0])
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	var word_color: Color = PURPLE.lerp(WHITE, word[1]) * state.word
	word_color.a = 1.0
	_word(canvas, word_color)

func _stroke(canvas: CanvasItem, contours: Array, color: Color, width: float) -> void:
	for contour in contours:
		if contour.size() >= 2:
			canvas.draw_polyline(contour, color, width)

func _word(canvas: CanvasItem, color: Color) -> void:
	if color.a <= 0.0 or font == null:
		return
	var baseline := _word_at + Vector2(0.0, _baseline_offset())
	canvas.draw_string(font, baseline, studio_name, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, color)

func draw_ambient(canvas: CanvasItem) -> void:
	var lights := _lights(_state_at(elapsed))
	_draw_backdrop(canvas, lights)
	_draw_dust(canvas, lights)

## Derrame de luz no fundo: o preto nunca fica chapado.
func _draw_backdrop(canvas: CanvasItem, lights: Array) -> void:
	if light_texture == null:
		return
	var radius := maxf(_screen.x, _screen.y) * LIGHT_REACH
	for light in lights:
		var color: Color = light[1]
		color.a = 0.055 * clampf(light[2], 0.0, 1.0)
		canvas.draw_texture_rect(light_texture, Rect2(light[0] - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, color)

## Poeira no ar, deriva lenta com oscilacao lateral pra nao parecer chuva.
func _draw_dust(canvas: CanvasItem, lights: Array) -> void:
	if lights.is_empty():
		return
	var reach := maxf(_screen.x, _screen.y) * LIGHT_REACH
	for mote in _motes:
		var y: float = fposmod(mote[1] - mote[3] * elapsed * 0.1, 1.0)
		var x: float = fposmod(mote[0] + sin(elapsed * 0.5 + mote[4]) * 0.01, 1.0)
		var at := Vector2(x * _screen.x, y * _screen.y)
		var light: Array = _nearest_light(at, lights)
		var falloff := clampf(1.0 - at.distance_to(light[0]) / reach, 0.0, 1.0)
		var color: Color = light[1]
		color.a = clampf(0.30 * light[2] * falloff, 0.0, 1.0)
		canvas.draw_circle(at, mote[2], color)

## Todos os contornos avancam juntos, por comprimento: a forma nasce inteira,
## nao em fila.
func _reveal(contours: Array, fraction: float) -> Array:
	if fraction <= 0.0:
		return []
	if fraction >= 1.0:
		return contours
	var out := []
	for contour in contours:
		out.append(_slice_by_length(contour, fraction))
	return out

func _slice_by_length(contour: PackedVector2Array, fraction: float) -> PackedVector2Array:
	var total := 0.0
	for i in range(1, contour.size()):
		total += contour[i].distance_to(contour[i - 1])
	var target := total * fraction
	var out := PackedVector2Array([contour[0]])
	var walked := 0.0
	for i in range(1, contour.size()):
		var segment := contour[i].distance_to(contour[i - 1])
		if walked + segment >= target:
			out.append(contour[i - 1].lerp(contour[i], (target - walked) / maxf(segment, 0.0001)))
			return out
		walked += segment
		out.append(contour[i])
	return out

## draw: quanto de cada parte ja foi tracado (e' tambem o aceso da parte);
## dip: pisca e quedas de tubo, global; word: aceso do nome sem o dip.
func _state_at(seconds: float) -> Dictionary:
	var t := clampf(seconds, 0.0, SPLASH_END)
	var flicker := 1.0 + 0.05 * sin(t * 17.3) * sin(t * 6.1)
	var draw := {}
	for part in _parts:
		draw[part] = _progress(t, float(PART_ONSET[part]), float(PART_DURATION[part]))
	return {
		"draw": draw,
		"dip": flicker * (0.12 if _in_blackout(t) else 1.0),
		"word": _progress(t, WORD_ONSET, WORD_DURATION),
		"flash": _flash(t),
	}

func _in_blackout(t: float) -> bool:
	for window in BLACKOUTS:
		if t >= window[0] and t < window[1]:
			return true
	return false

## Rampa 0..1 suavizada nas pontas.
func _progress(t: float, start: float, length: float) -> float:
	var raw := clampf((t - start) / length, 0.0, 1.0)
	return raw * raw * (3.0 - 2.0 * raw)

## Sobe rapido no estouro e decai devagar.
func _flash(t: float) -> float:
	if t < FLASH_AT:
		return 0.0
	var since := t - FLASH_AT
	var rise := 0.06
	if since < rise:
		return since / rise
	return maxf(0.0, 1.0 - (since - rise) / 0.30)

## Fontes de luz [centro na tela, cor, intensidade], uma por parte acesa.
func _lights(state: Dictionary) -> Array:
	var lights := []
	for part in _parts:
		var lit: float = state.draw[part] * state.dip
		if lit <= 0.0:
			continue
		var center: Vector2 = _bounds_of(_parts[part]).get_center()
		lights.append([_origin + center * _scale, color_of(part), lit])
	return lights

func _nearest_light(at: Vector2, lights: Array) -> Array:
	var best: Array = lights[0]
	var best_distance: float = at.distance_squared_to(best[0])
	for light in lights.slice(1):
		var distance: float = at.distance_squared_to(light[0])
		if distance >= best_distance:
			continue
		best = light
		best_distance = distance
	return best

func color_of(part: String) -> Color:
	return PURPLE if part in ["D_PURPLE", "DPAD_BUTTONS"] else WHITE

func _logo_transform() -> Transform2D:
	return Transform2D(0.0, Vector2.ONE * _scale, 0.0, _origin)

## Simbolo com 44% da menor dimensao da tela, nome embaixo, bloco centrado.
func _layout() -> void:
	_screen = get_viewport_rect().size
	var mark_width := minf(_screen.x, _screen.y) * MARK_COVERAGE
	_scale = mark_width / _art.size.x
	var mark_height := _art.size.y * _scale
	_font_size = roundi(mark_width * WORD_SCALE)
	var word_width: float = font.get_string_size(studio_name, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x if font else 0.0
	var gap := mark_height * GAP_SCALE
	var total := mark_height + gap + _font_size
	var top := (_screen.y - total) / 2.0
	_origin = Vector2((_screen.x - mark_width) / 2.0, top) - _art.position * _scale
	_word_at = Vector2((_screen.x - word_width) / 2.0, top + mark_height + gap)
	_bottom = top + total
	for layer in halos.size():
		_layout_halo(halos[layer], TUBE_LAYERS[layer][1] * _scale * HALO_SCALE)
	if reflection:
		reflection.size = _screen
		reflection.material.set_shader_parameter("mirror_v", _bottom / _screen.y)

## Sprite final <- viewport da 2a passada <- sprite da 1a passada <- viewport
## da fonte. Tamanhos seguem a tela; sigma vem do desfoque da camada.
func _layout_halo(final_sprite: Sprite2D, sigma: float) -> void:
	final_sprite.scale = Vector2.ONE / HALO_SCALE
	final_sprite.material.set_shader_parameter("sigma", sigma)
	var pass_viewport: SubViewport = owner.get_node(final_sprite.texture.viewport_path)
	var pass_sprite: Sprite2D = pass_viewport.get_child(0)
	pass_sprite.material.set_shader_parameter("sigma", sigma)
	var source_viewport: SubViewport = owner.get_node(pass_sprite.texture.viewport_path)
	var size := Vector2i(_screen * HALO_SCALE)
	pass_viewport.size = size
	source_viewport.size = size
	source_viewport.get_child(0).scale = Vector2.ONE * HALO_SCALE

## Linha de base dentro de uma caixa de altura igual ao corpo, como o texto
## de referencia (height: 1.0).
func _baseline_offset() -> float:
	var ascent := font.get_ascent(_font_size)
	var descent := font.get_descent(_font_size)
	return _font_size * ascent / maxf(ascent + descent, 0.0001)

## O potrace fecha canto com curva que volta sobre si mesma; no traco largo
## esse grampo vira um raio pra fora. Some com pontos repetidos e grampos.
func _clean(contour: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in contour:
		if out.size() > 0 and out[-1].distance_to(point) < 0.5:
			continue
		while out.size() >= 2:
			var back: Vector2 = (out[-1] - out[-2]).normalized()
			var forward: Vector2 = (point - out[-1]).normalized()
			if back.dot(forward) > -0.7:
				break
			out.remove_at(out.size() - 1)
		out.append(point)
	return out

func _bounds_of_all() -> Rect2:
	var bounds := Rect2()
	var first := true
	for part in _parts:
		var part_bounds: Rect2 = _bounds_of(_parts[part])
		bounds = part_bounds if first else bounds.merge(part_bounds)
		first = false
	return bounds

func _bounds_of(contours: Array) -> Rect2:
	var minimum := Vector2.INF
	var maximum := -Vector2.INF
	for contour in contours:
		for point in contour:
			minimum = minimum.min(point)
			maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)

## Semente fixa: a poeira e' identica em toda execucao.
func _seed_dust() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 7
	for i in DUST_COUNT:
		_motes.append([random.randf(), random.randf(), 0.4 + random.randf() * 1.6, 0.02 + random.randf() * 0.05, random.randf() * TAU])
