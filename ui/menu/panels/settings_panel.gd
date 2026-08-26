extends MenuPanel

const QUALITY_KEYS := ["settings.quality.low", "settings.quality.medium", "settings.quality.high"]
const LOCALES := ["pt_BR", "it"]
const FLAGS := {
	"pt_BR": preload("res://assets/art/UI/Flags/flag_pt_br.webp"),
	"it": preload("res://assets/art/UI/Flags/flag_it.webp"),
}
## "Português (Brasil)" nao cabe na caixa e sai truncado com reticencias
const LOCALE_NAMES := {"pt_BR": "Português", "it": "Italiano"}

@onready var _music_slider: HSlider = $Panel/Rows/MusicRow/MusicSlider
@onready var _sfx_slider: HSlider = $Panel/Rows/SfxRow/SfxSlider
@onready var _quality_option: OptionButton = $Panel/Rows/QualityRow/QualityOption
@onready var _language_option: OptionButton = $Panel/Rows/LanguageRow/LanguageOption

func _ready() -> void:
	super()
	_music_slider.value = Settings.music_volume
	_sfx_slider.value = Settings.sfx_volume
	_fill_quality()
	_fill_language()

	_music_slider.value_changed.connect(func(value): Settings.set_value("music_volume", value))
	_sfx_slider.value_changed.connect(func(value): Settings.set_value("sfx_volume", value))
	_quality_option.item_selected.connect(func(index): Settings.set_value("quality", index))
	_language_option.item_selected.connect(_on_language_selected)

func _fill_quality() -> void:
	_quality_option.clear()
	for key in QUALITY_KEYS:
		_quality_option.add_item(tr(key))
	_quality_option.selected = Settings.quality

func _fill_language() -> void:
	_language_option.clear()
	for index in LOCALES.size():
		var code: String = LOCALES[index]
		_language_option.add_icon_item(FLAGS[code], LOCALE_NAMES[code])
	_language_option.selected = LOCALES.find(Settings.locale)

func _on_language_selected(index: int) -> void:
	Settings.set_value("locale", LOCALES[index])
	# os Labels se retraduzem sozinhos; os itens do dropdown nao
	_fill_quality()
	_fill_language()
