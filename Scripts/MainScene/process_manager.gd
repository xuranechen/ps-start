extends "res://Scripts/MainScene/config_base.gd"


var matchmaker_container = HBoxContainer
var cirrus_container = HBoxContainer
var mk_process_thread: Thread
var mk_process_output: FileAccess
var mk_process = null

func _ready() -> void:
	matchmaker_container = $Control/VBoxContainer/matchmaker
	cirrus_container = $Control/VBoxContainer/cirrus

# 启动matchmaker进程
func _start_mk_instance():
	print("开始初始化MK运行环境")
	_stop_mk_instance() # 如果已经有进程在运行，先终止它
	_run_mk_instance(_read_config("MatchmakerPath"))

# 运行matchmaker
func _run_mk_instance(path: String):
	print("开始运行MK:", path)
	mk_process = OS.execute_with_pipe("node", [path, "--HttpPort", "80", "--MatchmakerPort", "89"])
	mk_process_output = mk_process["stdio"]
	mk_process_thread = Thread.new()
	mk_process_thread.start(_listen_mk_output)

# 监听matchmaker输出日志
func _listen_mk_output():
	var has_emitted = false
	while mk_process_output.is_open() and mk_process_output.get_error() == OK:
		var line = mk_process_output.get_line()
		print(line)
		call_deferred("_on_mk_logout", line)
		if not has_emitted and line != "":
			call_deferred("_emit_process_done", "已启动Matchmaker")
			has_emitted = true

# 根据matchmaker输出日志，判断执行任务
func _on_mk_logout(logout: String):
	# 当用户连接并监测到暂无空闲实例时，自动开启新实例（信令+exe）
	if logout.contains("WARNING: No empty Cirrus servers are available"):
		cirrus_container._start_cirrus_instance()
	# 监测到某端口的exe信号丢失，自动重启该端口的exe
	elif logout.contains("streamer disconnected"):
		print()
	# 监测到实例开启成功
	elif logout.contains("streamer connected"):
		print()
	# 监测到有用户连接
	elif logout.contains("Client connected to Cirrus server"):
		print()
	# 监测到用户关闭连接
	elif logout.contains("Client disconnected from Cirrus server"):
		print()
	# 监测到信令服务器从MatchMaker断开（此时认为管理员正常关闭），自动关闭该端口实例
	elif logout.contains("disconnected from Matchmaker"):
		print()

# 子进程触发信号
func _emit_process_done(message: String):
	matchmaker_container._show_mk_state(message)
	#process_done.emit(message)

# 终止matchmaker进程
func _stop_mk_instance():
	if mk_process == null or mk_process.is_empty():
		return
	OS.kill(mk_process["pid"])
	mk_process_thread.wait_to_finish()
	mk_process_thread = null
	print("MK进程已终止")
	call_deferred("_emit_process_done", "Matchmaker尚未启动")

func _exit_tree() -> void:
	_stop_mk_instance()
