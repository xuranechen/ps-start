extends "res://Scripts/MainScene/config_base.gd"


var params:LineEdit

func _ready() -> void:
	params = $Params
	params.text = _read_config("Params")
	params.text_submitted.connect(_input_params)

func _input_params(new_text:String):
	_save_config("Params",new_text)
