extends SceneTree

## Regras puras dos fundos em video. Roda via run_headless_script (godot --headless --script).

func _init() -> void:
	var failures := 0
	failures += check("passa a 60 fps em 60 Hz", VideoBenchmark.passes(60.0, 60.0))
	failures += check("passa exatamente em 48 fps em 60 Hz", VideoBenchmark.passes(48.0, 60.0))
	failures += check("reprova a 47 fps em 60 Hz", not VideoBenchmark.passes(47.0, 60.0))
	failures += check("monitor desconhecido (-1) assume 60 Hz", not VideoBenchmark.passes(47.0, -1.0))
	failures += check("monitor desconhecido (0) assume 60 Hz", VideoBenchmark.passes(48.0, 0.0))
	failures += check("120 Hz exige 96 fps", not VideoBenchmark.passes(90.0, 120.0))
	failures += check("quality 0 usa still", not SceneBackground.wants_video(0))
	failures += check("quality 1 usa video", SceneBackground.wants_video(1))
	failures += check("quality 2 usa video", SceneBackground.wants_video(2))
	failures += check("cover: 16:9 dentro de 4:3 escala pela altura", is_equal_approx(SceneBackground.cover_scale(Vector2(1440, 1080), Vector2(1280, 720)), 1.5))
	failures += check("cover: 16:9 dentro de 16:9 escala pela largura", is_equal_approx(SceneBackground.cover_scale(Vector2(1920, 1080), Vector2(1280, 720)), 1.5))
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)

func check(name: String, ok: bool) -> int:
	print(("PASS " if ok else "FAIL ") + name)
	return 0 if ok else 1
