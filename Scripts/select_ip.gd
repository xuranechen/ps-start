extends "res://Scripts/config_base.gd"

var ip_list: OptionButton
var ip_input: LineEdit

func _ready() -> void:
	ip_list = get_node("/root/Node2D/Control/VBoxContainer/ip/IPList")
	ip_input = get_node("/root/Node2D/Control/VBoxContainer/ip/IP")
	
	ip_list.item_selected.connect(_set_ip)
	ip_input.text = _read_config("SelectedIP")
	_get_simple_network_info()
	
	# 查找选项字符串中是否包含_read_config("SelectedIP")，如果包含则设置选择该选项
	var selected_ip = _read_config("SelectedIP")
	for i in range(ip_list.get_item_count()):
		if ip_list.get_item_text(i).find(selected_ip) != -1:
			ip_list.select(i)
			break

func _get_simple_network_info():
	var interfaces = IP.get_local_interfaces()
	for interface in interfaces:
		var interface_name = interface["friendly"]
		var addresses = interface["addresses"]
		var interface_type = _get_interface_type(interface_name)

		print("Interface: %s" % [interface_name])
		print("  Type: %s" % [interface_type])
		print("  Addresses:")
		for address in addresses:
			if interface_type != "Unknown" and address != "127.0.0.1" and ":" not in address:
				ip_list.add_item(interface_type + ":  " + address)
				print("    %s" % [address])

# 根据接口名称判断类型
func _get_interface_type(interface_name: String) -> String:
	if interface_name.begins_with("WLAN"):
		return "无线网"
	elif interface_name.begins_with("以太网"):
		return "以太网"
	else:
		return "Unknown"
		
func _set_ip(index: int):
	ip_input.text = ip_list.get_item_text(index).split(":")[1]
	_save_config("SelectedIP", ip_input.text)
