extends "res://Scripts/MainScene/config_base.gd"


var ip_list: OptionButton
var ip_input: LineEdit
var mk_container:HBoxContainer
var main_node:Node2D

func _ready() -> void:
	ip_list = $IPList
	ip_input = $IP
	mk_container = $"../matchmaker"
	main_node = $"../../.."
	
	ip_list.item_selected.connect(_set_ip)
	ip_input.text = _read_config("SelectedIP")
	_get_simple_network_info()
	
	# 查找选项字符串中是否包含_read_config("SelectedIP")，如果包含则设置选择该选项
	var selected_ip = _read_config("SelectedIP")
	var find_config_ip = false
	for i in range(ip_list.get_item_count()):
		if ip_list.get_item_text(i).find(selected_ip) != -1:
			ip_list.select(i)
			find_config_ip = true
			break
	
	if find_config_ip == false:
		ip_list.select(0)
		ip_input.text = ip_list.get_item_text(0)
		selected_ip = ip_input.text
	
	#mk_container._start_mk_instance()
	main_node._start_mk_instance()

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
				ip_list.add_item(interface_type + ":" + address)
				print("    %s" % [address])
	if(ip_list.item_count == 1):
		_set_ip(0)
		ip_input.text = _read_config("SelectedIP")

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
	mk_container._start_mk_instance()
