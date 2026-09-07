extends Node2D

## Camada auxiliar do letreiro: desenha, por conta do Logo, uma camada de halo
## (dentro de um SubViewport, sem desfoque; o blur vem do shader neon_blur) ou,
## com layer -1, o ambiente (derrame de luz e poeira) depois do reflexo.

@export var logo: Node2D
@export var layer := 0

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if logo == null:
		return
	if layer < 0:
		logo.draw_ambient(self)
		return
	logo.draw_halo(self, layer)
