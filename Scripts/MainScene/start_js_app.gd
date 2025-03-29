extends Node

# 启动JS应用的函数
func _start_js_app():
	var js_app_path = "path/to/your/js/app.js"  # 请替换为您的JS应用路径
	var output = []
	var process = OS.execute("node", [js_app_path], output)
	
	if process == null:
		print("Failed to start JS application.")
	else:
		print("JS application started successfully.")

# 在_ready函数中调用启动JS应用的函数
func _ready():
	_start_js_app()
