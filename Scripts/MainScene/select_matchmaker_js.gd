extends "res://Scripts/MainScene/config_base.gd"


var file_dialog: FileDialog
var mk_process_thread: Thread
var mk_process_output: FileAccess
var mk_process = null

@onready var matchmaker_path = $MatchmakerPath
@onready var matchmaker_lable = $"../MK操作栏/MatchmakerNumLabel"
@onready var cirrus_container = $"../cirrus"

signal process_done(message)

func _ready() -> void:
	process_done.connect(_show_mk_state)
	
	# 使用 ConfigFile 读取文件路径
	matchmaker_path.text = _read_config("MatchmakerPath")

func _select_file() -> void:
	# 创建文件对话框实例
	file_dialog = FileDialog.new()
	add_child(file_dialog)
	
	# 基本设置
	file_dialog.set_mode_overrides_title(false) # 设置不自动设置标题
	file_dialog.title = "选择流送应用" # 设置对话框标题为"选择流送应用"
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM # 访问完整文件系统
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE # 选择单个文件
	file_dialog.filters = ["*.js"] # 文件类型过滤
	
	# 设置按钮文本为中文
	file_dialog.set_ok_button_text("确定") # 设置确定按钮文本
	file_dialog.set_cancel_button_text("取消") # 设置取消按钮文本
	
	# 连接信号
	file_dialog.file_selected.connect(_on_file_selected)
	file_dialog.canceled.connect(_on_cancel)
	
	# 弹出对话框
	file_dialog.popup_centered(Vector2i(800, 500))

func _on_file_selected(path: String) -> void:
	matchmaker_path.text = path # 将选择的文件路径赋值给输入框
	print("选择的文件:", path) # 输出信息
	# 使用 ConfigFile 保存文件路径
	_save_config("MatchmakerPath", path)
	
func _on_cancel() -> void:
	print("操作取消")

func _get_mk_path() -> String:
	return matchmaker_path.text

# 更新matchmaker启动状态
func _show_mk_state(result) -> void:
	matchmaker_lable.text = result
