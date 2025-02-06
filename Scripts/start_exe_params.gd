extends "res://Scripts/config_base.gd"


var params:LineEdit

func _ready() -> void:
	params = get_node("/root/Node2D/Control/VBoxContainer/启动参数/Params")
	params.text = _read_config("Params")
	params.text_submitted.connect(_input_params)

func _input_params(new_text:String):
	_save_config("Params",new_text)
