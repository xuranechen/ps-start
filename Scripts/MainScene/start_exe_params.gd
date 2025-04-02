extends "res://Scripts/MainScene/config_base.gd"


@onready var params = $Params

func _ready() -> void:
	params.text = _read_config("Params")
	params.text_submitted.connect(_input_params)

func _input_params(new_text:String) -> void:
	_save_config("Params",new_text)
