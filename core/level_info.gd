class_name LevelInfo
extends Resource

## Ficha de uma fase pro Modo Livre. Mora ao lado da cena como <fase>.level.tres;
## o LevelCatalog acha sozinho.

enum Skill { COLORS, NUMBERS, LETTERS, MEMORY, COORDINATION }
enum Mechanic { DRAG_DROP, PAINT, SEQUENCE, ASSEMBLE, MEMORY, PATH, ACTION, PICK_RIGHT, GUIDE }

const SKILL_KEYS: Array[String] = [
	"skill.colors", "skill.numbers", "skill.letters", "skill.memory", "skill.coordination",
]
const MECHANIC_KEYS: Array[String] = [
	"mechanic.drag_drop", "mechanic.paint", "mechanic.sequence", "mechanic.assemble",
	"mechanic.memory", "mechanic.path", "mechanic.action", "mechanic.pick_right", "mechanic.guide",
]

@export var id := ""
## Chave de tr() ou texto literal.
@export var title := ""
@export_multiline var description := ""
@export var cover: Texture2D
@export var skills: Array[Skill] = []
@export var mechanic := Mechanic.DRAG_DROP
## Vazio = fase oficial da Floresta.
@export var author := ""
@export_file("*.tscn") var scene_path := ""

func matches(text: String, skill: int, mechanic_filter: int) -> bool:
	if skill >= 0 and not skills.has(skill):
		return false
	if mechanic_filter >= 0 and mechanic != mechanic_filter:
		return false
	var needle := text.strip_edges().to_lower()
	if needle.is_empty():
		return true
	return tr(title).to_lower().contains(needle) or tr(description).to_lower().contains(needle)
