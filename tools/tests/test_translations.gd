extends Node

## Toda chave do ui.csv precisa de texto em todos os idiomas (uma coluna por idioma).
## Roda como cena headless (run_headless_scene).

const CSV_PATH := "res://assets/i18n/ui.csv"

func _ready() -> void:
	var missing := find_missing(CSV_PATH)
	for entry in missing:
		print("FAIL sem traducao: " + entry)
	print("FAILURES: %d" % missing.size())
	get_tree().quit(1 if missing.size() > 0 else 0)

## Devolve "chave (idioma)" para cada celula vazia ou linha incompleta.
static func find_missing(csv_path: String) -> PackedStringArray:
	var missing := PackedStringArray()
	var file := FileAccess.open(csv_path, FileAccess.READ)
	var header := file.get_csv_line()
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 1 and row[0].strip_edges().is_empty():
			continue
		for column in range(1, header.size()):
			if column >= row.size() or row[column].strip_edges().is_empty():
				missing.append("%s (%s)" % [row[0], header[column]])
	return missing
