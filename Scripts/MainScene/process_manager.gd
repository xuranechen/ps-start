extends "res://Scripts/MainScene/config_base.gd"


var mk_process_thread: Thread
var mk_process_output: FileAccess
var mk_process = null

var peer_connection_options = "{ \\\"iceServers\\\": [{\\\"urls\\\": [\\\"stun:IPIP:19302\\\",\\\"turn:IPIP:19303\\\"], \\\"username\\\": \\\"PixelStreamingUser\\\", \\\"credential\\\": \\\"Another TURN in the road\\\"}] }";

@onready var matchmaker_container = $Control/VBoxContainer/matchmaker
@onready var cirrus_container = $Control/VBoxContainer/cirrus

var cirrus_instances: Dictionary = {}
var app_instances: Dictionary = {}
var app_port2cirrus_port: Dictionary = {}

# 端口管理
# 每个信令服务器对应不同httpport
var http_port: int = 5000
# 每个信令服务器对应不同streamingport
var streaming_port: int = 1000

# 端口队列
var http_ports_queue: Array = []
var streaming_ports_queue: Array = []

# 初始化HTTP端口队列
func _init_http_port_queue():
	for i in range(5000, 5500):
		http_ports_queue.append(i)

# 初始化流媒体端口队列
func _init_streaming_port_queue():
	for i in range(1000, 1500):
		streaming_ports_queue.append(i)

# http_port入队
func _enqueue_http_port(port: int):
	http_ports_queue.append(port)

# http_port出队
func _dequeue_http_port() -> int:
	if http_ports_queue.size() > 0:
		return http_ports_queue.pop_front()
	return -1

# streaming_port入队
func _enqueue_streaming_port(port: int):
	streaming_ports_queue.append(port)

# streaming_port出队
func _dequeue_streaming_port() -> int:
	if streaming_ports_queue.size() > 0:
		return streaming_ports_queue.pop_front()
	return -1

func _get_ports():
	var ports: Dictionary = {}
	ports["http_port"] = _dequeue_http_port()
	ports["streaming_port"] = _dequeue_streaming_port()
	return ports

# 初始化函数
func _ready() -> void:
	_init_http_port_queue()
	_init_streaming_port_queue()

# Matchmaker相关函数-------------------------------------------------------------
# 启动matchmaker进程
func _start_mk_instance():
	print("开始初始化MK运行环境")
	_stop_mk_instance() # 如果已经有进程在运行，先终止它
	var path = _read_config("MatchmakerPath")
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
		_start_cirrus_instance()
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

# 修改matchmaker启动状态
func _emit_process_done(message: String):
	matchmaker_container._show_mk_state(message)

# 终止matchmaker进程
func _stop_mk_instance():
	if mk_process == null or mk_process.is_empty():
		return
	OS.kill(mk_process["pid"])
	mk_process_thread.wait_to_finish()
	mk_process_thread = null
	print("MK进程已终止")
	call_deferred("_emit_process_done", "Matchmaker尚未启动")
# Matchmaker相关函数-------------------------------------------------------------

# Cirrus相关函数-----------------------------------------------------------------
func _start_cirrus_instance():
	print("开始初始化流送信令")
	_run_cirrus_instance(_get_ports())

func _run_cirrus_instance(ports: Dictionary):
	print("开始运行Cirrus:", ports["http_port"])
	# 获取IP地址
	var ip = _read_config("SelectedIP")
	var cirrus_path = _read_config("CirrusPath")
	# 设置peer连接选项
	peer_connection_options = peer_connection_options.replace("IPIP", ip)
	# 准备启动参数
	var args = [
		cirrus_path,
		"--UseMatchmaker", "true",
		"--MatchmakerAddress", ip,
		"--PublicIp", ip,
		"--HttpPort", str(ports["http_port"]),
		"--StreamerPort", str(ports["streaming_port"]),
		"--peerConnectionOptions", peer_connection_options
	]
	# 检查是否已存在相同端口的进程，如果有则终止
	if cirrus_instances.has(str(ports["streaming_port"])):
		OS.kill(cirrus_instances[str(ports["streaming_port"])]["pid"])
		cirrus_instances.erase(str(ports["streaming_port"]))
	# 启动进程
	var temp_cirrus_process = OS.execute_with_pipe("node", args)
	# 保存进程信息
	cirrus_instances[str(ports["streaming_port"])] = {
		"pid": temp_cirrus_process["pid"],
		"http_port": ports["http_port"],
		"streaming_port": ports["streaming_port"]
	}
	app_port2cirrus_port[str(ports["streaming_port"])] = str(ports["http_port"])
	# 更新UI显示
	cirrus_container._show_cirrus_state("信令已启动：" + str(cirrus_instances.size()) + "个实例")
	
	# 创建实例UI
	# 注意：这里需要实现类似InstanceManager.CreateInstance的功能
	# _create_instance_ui(process["pid"], ip, str(ports["http_port"]), str(ports["streaming_port"]), _read_config("AppPath"))
	
	# 启动应用程序
	_start_app_instance(ports["http_port"], ports["streaming_port"])

func _stop_cirrus_instance(port: int):
	if cirrus_instances.has(str(port)):
		OS.kill(cirrus_instances[str(port)]["pid"])
		cirrus_instances.erase(str(port))
		cirrus_container._show_cirrus_state("信令已启动：" + str(cirrus_instances.size()) + "个实例")
		app_instances.erase(str(port))
		cirrus_instances.erase(app_port2cirrus_port[str(port)])
		app_port2cirrus_port.erase(str(port))
	print("信令进程已终止")
# Cirrus相关函数-----------------------------------------------------------------

# 流送应用相关函数-----------------------------------------------------------------
func _start_app_instance(cirrus_port: int, app_port: int):
	print("开始初始化流送应用")
	# 获取应用程序路径和IP地址
	var app_path = _read_config("AppPath")
	var ip = _read_config("SelectedIP")
	var start_commands = _read_config("StartCommands")
	# 准备启动参数
	var args = [
		"-AllowPixelStreamingCommands",
		"-AudioMixer",
		"-RenderOffscreen",
		"-PixelStreamingIP=" + ip,
		"-PixelStreamingPort=" + str(app_port),
	]
	# 添加额外的启动命令
	if start_commands != "":
		args.append_array(start_commands.split(" "))
	# 启动应用程序进程
	var temp_app_process = OS.execute_with_pipe(app_path, args)
	# 保存进程信息
	app_instances[str(app_port)] = {
		"pid": temp_app_process["pid"],
		"cirrus_port": cirrus_port
	}
	
	# 更新UI显示
	# 假设有一个UI容器用于显示应用程序状态
	if has_node("Control/VBoxContainer/app"):
		$Control/VBoxContainer/app._show_app_state("应用已启动：" + str(app_instances.size()) + "个实例")

func _stop_app_instance(port: int):
	if app_instances.has(str(port)):
		# 检查进程是否存在
		var pid = app_instances[str(port)]["pid"]
		# 终止进程
		OS.kill(pid)
		# 从字典中移除
		app_instances.erase(str(port))
		# 更新UI显示
		if has_node("Control/VBoxContainer/app"):
			$Control/VBoxContainer/app._show_app_state("应用已启动：" + str(app_instances.size()) + "个实例")
	print("流送应用进程已终止")

func _stop_all_app_instance():
	print("所有流送应用进程已终止")
	var app_keys = app_instances.keys()
	for app in app_keys:
		_stop_app_instance(int(app))
	app_instances.clear()
	# 关闭所有通过进程名称找到的应用进程
	_kill_all_processes_by_name()

# 通过进程名称查找并关闭所有相关进程
func _kill_all_processes_by_name():
	var exe_name = _read_config("AppName")
	if exe_name.is_empty():
		return
	# 在Windows上使用tasklist和taskkill命令查找和终止进程
	var output = []
	var exit_code = OS.execute("tasklist", ["/FI", "IMAGENAME eq " + exe_name], output)
	if exit_code != 0:
		print("获取进程列表失败")
		return
	# 检查输出中是否包含进程名
	var process_found = false
	for line in output[0].split("\n"):
		if line.contains(exe_name):
			process_found = true
			break
	if process_found:
		# 终止所有同名进程
		var kill_result = []
		OS.execute("taskkill", ["/F", "/IM", exe_name], kill_result)
		print("已终止所有 " + exe_name + " 进程")
# 流送应用相关函数-----------------------------------------------------------------

func _exit_tree() -> void:
	_stop_mk_instance()
	# 停止所有Cirrus实例
	var cirrus_keys = cirrus_instances.keys()
	for key in cirrus_keys:
		_stop_cirrus_instance(int(key))
	# 停止所有应用实例
	_stop_all_app_instance()
