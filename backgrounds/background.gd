class_name SceneBackground
extends Node2D

## Fundo de tela: still + shader em quality 0, video por cima nos outros niveis.

static func wants_video(quality: int) -> bool:
	return quality >= 1

## Sprite2D e VideoStreamPlayer nao tem ancora: escala que cobre o viewport inteiro.
static func cover_scale(viewport_size: Vector2, texture_size: Vector2) -> float:
	return maxf(viewport_size.x / texture_size.x, viewport_size.y / texture_size.y)
