extends Control

@export var world_select_scene: PackedScene
@export var settings_panel_scene: PackedScene
@export var credits_scene: PackedScene
@export var quit_confirm_scene: PackedScene

@onready var _menu_ui: Control = $MenuUI
@onready var _sign: Control = $WelcomeSign
@onready var _overlays: CanvasLayer = $Overlays
@onready var _logo_animation: AnimationPlayer = $MenuUI/Logo/LogoAnimation

func _ready() -> void:
	_logo_animation.animation_finished.connect(_on_logo_intro_finished)
	$MenuUI/Buttons/StoryMode.pressed.connect(open_panel.bind(world_select_scene, true))
	$MenuUI/Buttons/SettingsButton.pressed.connect(open_panel.bind(settings_panel_scene, false))
	$MenuUI/Buttons/CreditsButton.pressed.connect(open_panel.bind(credits_scene, false))
	$MenuUI/Buttons/QuitButton.pressed.connect(open_modal.bind(quit_confirm_scene))

## Painel que substitui o menu: esconde os botoes (e a placa, quando pedido).
func open_panel(scene: PackedScene, hide_sign: bool) -> void:
	if scene == null:
		return
	_menu_ui.visible = false
	_sign.visible = not hide_sign
	_add_panel(scene)

## Modal que aparece por cima, com o menu ainda a' vista.
func open_modal(scene: PackedScene) -> void:
	if scene == null:
		return
	_add_panel(scene)

func _add_panel(scene: PackedScene) -> void:
	var panel := scene.instantiate()
	panel.closed.connect(_on_panel_closed)
	_overlays.add_child(panel)

func _on_panel_closed() -> void:
	_menu_ui.visible = true
	_sign.visible = true

func _on_logo_intro_finished(animation_name: StringName) -> void:
	if animation_name != &"intro":
		return
	_logo_animation.play("idle")
