extends "res://Scripts/MainScene/config_base.gd"


var file_dialog: FileDialog
@onready var app_path = $AppPath

func _ready() -> void:
	# 使用 ConfigFile 读取文件路径
	app_path.text = _read_config("AppExe")

func _select_file() -> void:
	# 创建文件对话框实例
	file_dialog = FileDialog.new()
	add_child(file_dialog)
	
	# 基本设置
	file_dialog.set_mode_overrides_title(false) # 设置不自动设置标题
	file_dialog.title = "选择流送应用" # 设置对话框标题为"选择流送应用"
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM # 访问完整文件系统
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE # 选择单个文件
	file_dialog.filters = ["*.exe"] # 文件类型过滤
	
	# 设置按钮文本为中文
	file_dialog.set_ok_button_text("确定") # 设置确定按钮文本
	file_dialog.set_cancel_button_text("取消") # 设置取消按钮文本
	
	# 连接信号
	file_dialog.file_selected.connect(_on_file_selected)
	file_dialog.canceled.connect(_on_cancel)
	
	# 弹出对话框
	file_dialog.popup_centered(Vector2i(800, 500))

func _on_file_selected(path: String) -> void:
	app_path.text = path # 将选择的文件路径赋值给输入框
	print("选择的文件:", path) # 汉化输出信息
	# 使用 ConfigFile 保存文件路径
	_save_config("AppExe", path)
	
func _on_cancel() -> void:
	print("操作取消")
