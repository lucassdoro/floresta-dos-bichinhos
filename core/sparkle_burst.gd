class_name SparkleBurst
extends GPUParticles2D

func burst(at: Vector2, color: Color, count: int, max_size: float) -> void:
	# material e' compartilhado entre instancias; sem duplicar, um burst muda os outros
	process_material = process_material.duplicate()
	global_position = at
	amount = count
	modulate = color
	process_material.scale_max = max_size / texture.get_width()
	process_material.scale_min = process_material.scale_max * 0.22
	emitting = true
	finished.connect(queue_free)
