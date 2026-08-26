extends SceneTree

func _init() -> void:
	TranslationServer.set_locale("pt_BR")
	print("pt: ", "OK" if tr("worldselect.title") == "Escolha o mundo" else "FALHOU %s" % tr("worldselect.title"))
	TranslationServer.set_locale("it")
	print("it: ", "OK" if tr("worldselect.title") == "Scegli il mondo" else "FALHOU %s" % tr("worldselect.title"))
	print("sem chave crua: ", "OK" if tr("quitmodal.yes") != "quitmodal.yes" else "FALHOU")
	print("creditos: ", "OK" if tr("credits.person.lucas.name") == "Lucas Dóro" else "FALHOU")
	quit()
