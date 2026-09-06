class_name VideoBenchmark
extends Node

## Mede fps tocando um video escondido no primeiro boot; reprovou, quality cai pra 0.

const PASS_RATIO := 0.8
const DEFAULT_REFRESH_RATE := 60.0

static func passes(average_fps: float, refresh_rate: float) -> bool:
	var reference := refresh_rate if refresh_rate > 0.0 else DEFAULT_REFRESH_RATE
	return average_fps >= reference * PASS_RATIO
