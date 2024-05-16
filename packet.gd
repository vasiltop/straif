extends Node

enum PACKET { HANDSHAKE, POSITION }
const PACKET_READ_LIMIT: int = 5

var networked_player = preload("res://networked_player/networked_player.tscn")

func send(data: Dictionary, reliable: bool = false, target: int = 0) -> void:
	# Set the send_type and channel
	var send_type: int = Steam.P2P_SEND_RELIABLE_WITH_BUFFERING if reliable else Steam.P2P_SEND_UNRELIABLE
	var channel: int = 0

	var packet_data: PackedByteArray
	packet_data.append_array(var_to_bytes(data))

	if target == 0:
		if len(SteamClient.lobby_members) > 1:
			for member in SteamClient.lobby_members:
				if member.steam_id != SteamClient.steam_id:
					Steam.sendP2PPacket(member.steam_id, packet_data, send_type, channel)
	else:
		Steam.sendP2PPacket(target, packet_data, send_type, channel)
		
func make_p2p_handshake() -> void:
	print("Sending P2P handshake to the lobby")
	send({"type": PACKET.HANDSHAKE})

func read_all_p2p_packets(read_count: int = 0):
	if read_count >= PACKET_READ_LIMIT:
		return

	if Steam.getAvailableP2PPacketSize(0) > 0:
		read_p2p_packet()
		read_all_p2p_packets(read_count + 1)

func read_p2p_packet() -> void:
	var packet_size: int = Steam.getAvailableP2PPacketSize()

	if packet_size > 0:
		var packet: Dictionary = Steam.readP2PPacket(packet_size, 0)

		if packet.is_empty() or packet == null:
			print("WARNING: read an empty packet with non-zero size!")

		var packet_sender: int = packet.steam_id_remote
		var packet_code: PackedByteArray = packet.data
		var readable_data: Dictionary = bytes_to_var(packet_code)
		print(packet_sender, readable_data)
		
		match readable_data.type:
			PACKET.HANDSHAKE:
				pass
			PACKET.POSITION:
				var map_name = get_tree().current_scene.name
				var player_object = SteamClient.is_id_spawned(packet_sender)
				
				# if the map is not ours, and the player exists, delete them
				if readable_data.map_name != map_name and player_object != null:
					SteamClient.spawned_players.erase(player_object)
					player_object.queue_free()
				# else, if the map is ours and they dont exist, spawn them
				elif readable_data.map_name == map_name and player_object == null:
						var instance: Node3D = networked_player.instantiate()
						add_child(instance)
						instance.position = readable_data.pos
						print(instance.position)
						

func _process(delta):
	if SteamClient.lobby_id != 0:
		read_all_p2p_packets()
