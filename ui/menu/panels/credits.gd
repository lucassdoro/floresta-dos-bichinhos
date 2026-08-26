extends MenuPanel

const PARENTAL_GATE := preload("res://ui/menu/panels/parental_gate.tscn")

## Vazio esconde o chip do site — o link so' existe quando houver endereco.
@export var site_url := ""

func _ready() -> void:
	super()
	$Panel/SiteChip.visible = not site_url.is_empty()
	$Panel/SiteChip.pressed.connect(_open_gate)

func _open_gate() -> void:
	var gate := PARENTAL_GATE.instantiate()
	gate.site_url = site_url
	add_child(gate)
