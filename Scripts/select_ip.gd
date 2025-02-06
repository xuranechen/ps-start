extends "res://Scripts/config_base.gd"


var ip_list:OptionButton

func _ready() -> void:
	ip_list = get_node("/root/Node2D/Control/VBoxContainer/ip/IPList")
	
	_get_simple_network_info()
	
func _get_simple_network_info():
	var interfaces = IP.get_local_interfaces()
	for interface in interfaces:
		var interface_name = interface["friendly"]
		var addresses = interface["addresses"]
		var interface_type = _get_interface_type(interface_name)
		
		# 打印接口的所有内容
		print("Interface: %s" % [interface_name])
		print("  Type: %s" % [interface_type])
		print("  Addresses:")
		for address in addresses:
			if address != "127.0.0.1":
				ip_list.add_item(address)
				print("    %s" % [address])

# 根据接口名称判断类型
func _get_interface_type(interface_name: String) -> String:
	if interface_name.begins_with("WLAN"):
		return "无线网"
	elif interface_name.begins_with("以太网"):
		return "以太网"
	else:
		return "Unknown"
