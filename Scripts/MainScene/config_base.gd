extends Node

func _read_config(config_Name: String) -> String:
	var config = ConfigFile.new()
	var err = config.load("res://config.cfg")  # 修改为项目文件夹下的路径
	if err == OK:
		var saved_path = config.get_value("Settings", config_Name, "")  # 获取保存的文件路径
		if saved_path != "":
			#print("读取的配置:", saved_path)  # 输出读取的路径
			return saved_path  # 返回读取的路径
		else:
			print("未找到保存的配置。")
			return ""
	else:
		print("无法加载配置文件。")
		return ""

func _save_config(config_Name: String, config_Value: String) -> void:
	var config = ConfigFile.new()
	var err = config.load("res://config.cfg")  # 修改为项目文件夹下的路径
	if err == OK or err == ERR_FILE_NOT_FOUND:
		config.set_value("Settings", config_Name, config_Value)  # 设置键值对
		var save_err = config.save("res://config.cfg")  # 修改为项目文件夹下的路径
		if save_err == OK:
			print("内容保存到配置文件。")
		else:
			print("无法保存配置文件。")
	else:
		print("无法加载配置文件。")
