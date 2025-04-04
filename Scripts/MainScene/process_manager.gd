extends "res://Scripts/MainScene/config_base.gd"


var mk_process_thread: Thread
var mk_process_output: FileAccess
var mk_process = null

var peer_connection_options = "{ \\\"iceServers\\\": [{\\\"urls\\\": [\\\"stun:IPIP:19302\\\",\\\"turn:IPIP:19303\\\"], \\\"username\\\": \\\"PixelStreamingUser\\\", \\\"credential\\\": \\\"Another TURN in the road\\\"}] }";

@onready var matchmaker_container = $Control/VBoxContainer/matchmaker
@onready var cirrus_container = $Control/VBoxContainer/cirrus
@onready var instance_manager = $"Control/进程列表区/ScrollContainer/GridContainer"

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
func _init_http_port_queue() -> void:
	for i in range(5000, 5500):
		http_ports_queue.append(i)

# 初始化流媒体端口队列
func _init_streaming_port_queue() -> void:
	for i in range(1000, 1500):
		streaming_ports_queue.append(i)

# http_port入队
func _enqueue_http_port(port: int) -> void:
	http_ports_queue.append(port)

# http_port出队
func _dequeue_http_port() -> int:
	if http_ports_queue.size() > 0:
		return http_ports_queue.pop_front()
	return -1

# streaming_port入队
func _enqueue_streaming_port(port: int) -> void:
	streaming_ports_queue.append(port)

# streaming_port出队
func _dequeue_streaming_port() -> int:
	if streaming_ports_queue.size() > 0:
		return streaming_ports_queue.pop_front()
	return -1

func _get_ports() -> Dictionary:
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
func _start_mk_instance() -> void:
	print("开始初始化MK运行环境")
	_stop_mk_instance() # 如果已经有进程在运行，先终止它
	var path = _read_config("MatchmakerPath")
	print("开始运行MK:", path)
	# 隐藏命令行窗口运行
	mk_process = OS.execute_with_pipe("node", [path, "--HttpPort", "80", "--MatchmakerPort", "89"])
	mk_process_output = mk_process["stdio"]
	mk_process_thread = Thread.new()
	mk_process_thread.start(_listen_mk_output)

# 监听matchmaker输出日志
func _listen_mk_output() -> void:
	var has_emitted = false
	while mk_process_output.is_open() and mk_process_output.get_error() == OK:
		var line = mk_process_output.get_line()
		print(line)
		call_deferred("_on_mk_logout", line)
		if not has_emitted and line != "":
			call_deferred("_emit_process_done", "已启动Matchmaker")
			has_emitted = true

# 根据matchmaker输出日志，判断执行任务
func _on_mk_logout(logout: String) -> void:
	# 当用户连接并监测到暂无空闲实例时，自动开启新实例（信令+exe）
	if logout.contains("WARNING: No empty Cirrus servers are available"):
		_start_cirrus_instance()
	# 监测到某端口的exe信号丢失，自动重启该端口的exe
	elif logout.contains("streamer disconnected"):
		var port_array = logout.split(" ")
		var temp_port = str(int(port_array[3].split(":")[1]) - 4000)
		if instance_manager.item_dict.has(temp_port):
			instance_manager.item_dict[temp_port]._client_ready(false)
			app_instances.erase(temp_port)
			_start_app_instance(int(cirrus_instances[temp_port]["http_port"]), int(temp_port))
	# 监测到实例开启成功
	elif logout.contains("streamer connected"):
		var port_array = logout.split(" ")
		var temp_port = str(int(port_array[3].split(":")[1]) - 4000)
		if instance_manager.item_dict.has(temp_port):
			instance_manager.item_dict[temp_port]._client_ready(true)
	# 监测到有用户连接
	elif logout.contains("Client connected to Cirrus server"):
		var port_array = logout.split(" ")
		var temp_port = str(int(port_array[6].split(":")[1]) - 4000)
		if instance_manager.item_dict.has(temp_port):
			instance_manager.item_dict[temp_port]._client_connected()
	# 监测到用户关闭连接
	elif logout.contains("Client disconnected from Cirrus server"):
		var port_array = logout.split(" ")
		var temp_port = str(int(port_array[6].split(":")[1]) - 4000)
		if instance_manager.item_dict.has(temp_port):
			instance_manager.item_dict[temp_port]._client_disconnected()
	# 监测到信令服务器从MatchMaker断开（此时认为管理员正常关闭），自动关闭该端口实例
	elif logout.contains("disconnected from Matchmaker"):
		var port_array = logout.split(" ")
		var temp_port = str(int(port_array[3].split(":")[1]) - 4000)
		if instance_manager.item_dict.has(temp_port) and instance_manager.item_dict[temp_port] != null:
			instance_manager.item_dict[temp_port]._close_instance()

# 修改matchmaker启动状态
func _emit_process_done(message: String) -> void:
	matchmaker_container._show_mk_state(message)

# 终止matchmaker进程
func _stop_mk_instance() -> void:
	_kill_all_processes_by_name("node.exe")
	if mk_process == null or mk_process.is_empty():
		return
	OS.kill(mk_process["pid"])
	mk_process_thread.wait_to_finish()
	mk_process_thread = null
	print("MK进程已终止")
	call_deferred("_emit_process_done", "Matchmaker尚未启动")
# Matchmaker相关函数-------------------------------------------------------------

# Cirrus相关函数-----------------------------------------------------------------
func _start_cirrus_instance() -> void:
	print("开始初始化流送信令")
	_run_cirrus_instance(_get_ports())

func _run_cirrus_instance(ports: Dictionary) -> void:
	print("开始运行Cirrus:", ports["http_port"])
	# 获取IP地址
	var ip = _read_config("SelectedIP")
	var cirrus_path = _read_config("CirrusPath")
	# 设置peer连接选项
	peer_connection_options = peer_connection_options.replace("IPIP", ip)
	
	# 构建命令行参数字符串
	var cmd_args = "node \"" + cirrus_path + "\" " + \
		"--UseMatchmaker true " + \
		"--MatchmakerAddress " + ip + " " + \
		"--PublicIp " + ip + " " + \
		"--HttpPort " + str(ports["http_port"]) + " " + \
		"--StreamerPort " + str(ports["streaming_port"]) + " " + \
		"--peerConnectionOptions \"" + peer_connection_options + "\""

	# 检查是否已存在相同端口的进程，如果有则终止
	if cirrus_instances.has(str(ports["streaming_port"])):
		OS.kill(cirrus_instances[str(ports["streaming_port"])]["pid"])
		cirrus_instances.erase(str(ports["streaming_port"]))

	# 显示命令行窗口运行
	# 直接使用node或无窗口模式运行信令服务器，无法正确流送应用
	var temp_cirrus_process = OS.execute_with_pipe("cmd.exe", ["/c", "start", "cmd", "/c", cmd_args])
	
	# 保存进程信息
	cirrus_instances[str(ports["streaming_port"])] = {
		"pid": temp_cirrus_process["pid"],
		"http_port": ports["http_port"],
		"streaming_port": ports["streaming_port"],
		"is_cmd_process": true 
	}
	app_port2cirrus_port[str(ports["streaming_port"])] = str(ports["http_port"])
	# 创建实例UI
	instance_manager.create_instance(temp_cirrus_process, ip, str(ports["http_port"]), str(ports["streaming_port"]), _read_config("AppExe"))
	# 启动应用程序
	_start_app_instance(ports["http_port"], ports["streaming_port"])

func _stop_cirrus_instance(port: int) -> void:
	if cirrus_instances.has(str(port)):
		print("开始终止信令进程:", cirrus_instances[str(port)]["pid"])
		# 如果是通过cmd启动的，我们需要通过taskkill终止相应的node进程
		if cirrus_instances[str(port)].get("is_cmd_process", false):
			# 通过端口号构建唯一标识，用于查找和终止对应的node进程
			var port_str = str(cirrus_instances[str(port)]["streaming_port"])
			_kill_node_process_by_port(port_str)
			
			# 终止cmd窗口进程
			var cmd_pid = cirrus_instances[str(port)]["pid"]
			print("终止CMD窗口进程:", cmd_pid)
			# 使用taskkill强制终止cmd进程及其子进程
			OS.execute("taskkill", ["/F", "/T", "/PID", str(cmd_pid)], [])
			# 额外检查并确保进程已终止
			var output = []
			OS.execute("tasklist", ["/FI", "PID eq " + str(cmd_pid)], output)
			if output.size() > 0 and output[0].contains(str(cmd_pid)):
				print("警告: CMD进程仍在运行，尝试再次终止")
				OS.execute("taskkill", ["/F", "/T", "/PID", str(cmd_pid)], [])
		else:
			# 直接通过pid终止
			OS.kill(cirrus_instances[str(port)]["pid"])
		
		cirrus_instances.erase(str(port))
		app_instances.erase(str(port))
		cirrus_instances.erase(app_port2cirrus_port[str(port)])
		app_port2cirrus_port.erase(str(port))
	print("信令进程已终止")

# 通过端口号查找并终止node进程
func _kill_node_process_by_port(port: String) -> void:
	# 使用netstat查找使用该端口的进程
	var output = []
	OS.execute("cmd.exe", ["/c", "netstat -ano | findstr :" + port], output)
	
	if not output.is_empty() and output[0].length() > 0:
		var lines = output[0].split("\n")
		for line in lines:
			if line.contains(":" + port):
				var parts = line.split(" ", false)
				if parts.size() > 4:
					var pid = parts[parts.size() - 1].strip_edges()
					print("找到端口 " + port + " 对应的进程PID: " + pid)
					OS.execute("taskkill", ["/F", "/PID", pid], [])
# Cirrus相关函数-----------------------------------------------------------------

# 流送应用相关函数-----------------------------------------------------------------
func _start_app_instance(cirrus_port: int, app_port: int) -> void:
	print("开始初始化流送应用")
	# 获取应用程序路径和IP地址
	var app_path = _read_config("AppExe")
	var ip = _read_config("SelectedIP")
	var start_commands = _read_config("Params")
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
	print("流送应用启动参数:", args)
	# 启动应用程序进程
	var temp_app_process = OS.execute_with_pipe(app_path, args)
	if temp_app_process.has("pid"):
		print("启动流送应用完成，端口：" + str(app_port))
		# 保存进程信息
		app_instances[str(app_port)] = {
			"pid": temp_app_process["pid"],
			"cirrus_port": cirrus_port
		}

func _stop_app_instance(port: int) -> void:
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

func _stop_all_app_instance() -> void:
	# 先获取所有应用进程名称
	var app_name = _read_config("AppName")
	if not app_name.is_empty():
		_kill_all_processes_by_name(app_name)
	
	# 然后清理进程记录
	var app_keys = app_instances.keys()
	for app in app_keys:
		print("停止流送应用：", app)
		if app_instances.has(str(app)):
			var pid = app_instances[str(app)]["pid"]
			OS.kill(pid)
	app_instances.clear()
	print("所有流送应用进程已终止")

# 通过进程名称查找并关闭所有相关进程
func _kill_all_processes_by_name(process_name: String) -> void:
	# 在Windows上使用tasklist和taskkill命令查找和终止进程
	var output = []
	var exit_code = OS.execute("tasklist", ["/FI", "IMAGENAME eq " + process_name], output)
	if exit_code != 0:
		print("获取进程列表失败")
		return
	# 检查输出中是否包含进程名
	var process_found = false
	for line in output[0].split("\n"):
		if line.contains(process_name):
			process_found = true
			break
	if process_found:
		# 终止所有同名进程
		var kill_result = []
		OS.execute("taskkill", ["/F", "/IM", process_name], kill_result)
		print("已终止所有 " + process_name + " 进程")
# 流送应用相关函数-----------------------------------------------------------------

func _exit_tree() -> void:
	# 先停止所有应用实例
	_stop_all_app_instance()
	# 再停止所有Cirrus实例
	var cirrus_keys = cirrus_instances.keys()
	for key in cirrus_keys:
		_stop_cirrus_instance(int(key))
	# 最后停止Matchmaker
	_stop_mk_instance()
