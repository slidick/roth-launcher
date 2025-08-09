extends Node

signal installations_updated
signal game_launched
signal game_closed

const OLD_EXE: String = "3.925"
const NEW_EXE: String = "3.983"


var installations: Array = []
var current_installation: String = ""
var custom_maps: Array = []
var current_map: String = "0"


func _ready() -> void:
	var roth: Variant = Settings.settings.get("roth")
	if roth:
		installations = roth.get("installations", [])
		current_installation = roth.get("current_installation", "")
		custom_maps = roth.get("custom_maps", [])
		current_map = roth.get("current_map", "0")
	if custom_maps.is_empty():
		custom_maps = [
			{
				"map_name": "Original Game",
				"uuid": "0",
				"internal_version": 1.0,
				"map_title": "Realms of the Haunting",
				"release_date": "1996",
				"description": "Play the original game.",
				"story": "\tAssume the role of Adam Randall whose father's untimely death leads him to the remote and seemingly desolate Cornish country village of Helston where things aren't quite as they seem.\n\n\tThrough the contents of a strange parcel, hand delivered by one of his father's reputed friends in the English clergy, Adam is pulled into a grand skein woven within the fabric of time and space towards his ultimate destiny by the forces gathering in the Parish of St. Michaels.\n\n\tRealms of the Haunting is a disturbing vision of the future, based on the many beliefs of the Apocalypse. The horror in Realms is the underlying fear of the end; the collapse of light and the dawn of a new age of darkness.\n\n\tStep by step, the forces of Darkness have broken the Seals that protect the world of Light. Evil is preparing for its final assault and only one force can stop the world of Shadows from eternal reign: You!",
				"install_date": Time.get_datetime_string_from_system().split("T")[0],
				"last_played": Time.get_datetime_string_from_unix_time(0).split("T")[0],
				"screenshots": [
					"uid://dcdoos2d07eqe",
					"uid://v06snv0tb0mf",
					"uid://bsm7rwwx64vi4",
					"uid://dcp24xhbq7vqr",
					"uid://wqwfop6cvovq",
					"uid://llhmkep66et1",
					"uid://cwjsq85w57533",
				]
			}
		]
		Settings.update_settings("roth", {"custom_maps": custom_maps})


func add_installation(directory: String) -> void:
	installations.append(directory)
	Settings.update_settings("roth", {"installations": installations})
	installations_updated.emit()


func remove_installation(directory: String) -> void:
	installations.erase(directory)
	Settings.update_settings("roth", {"installations": installations})
	installations_updated.emit()


func set_current_installation(directory: String) -> void:
	current_installation = directory
	Settings.update_settings("roth", {"current_installation": current_installation})


func set_current_map(custom_map: Dictionary) -> void:
	current_map = custom_map.uuid
	for map: Dictionary in custom_maps:
		if map.uuid == custom_map.uuid:
			map.last_played = Time.get_datetime_string_from_system().split("T")[0]
	Settings.update_settings("roth", {"current_map": current_map, "custom_maps": custom_maps})


func is_valid_installation_directory(directory: String) -> bool:
	if FileAccess.file_exists(directory.path_join("ROTH/ROTH.RES")):
		return true
	else:
		return false


func get_installation_information(directory: String) -> Dictionary:
	if not is_valid_installation_directory(directory):
		return {"res_version": "Invalid installation directory."}
	
	var installation_info: Dictionary = {}
	
	var file := FileAccess.open(directory.path_join("ROTH/ROTH.RES"), FileAccess.READ)
	var version: String = file.get_line().split("=")[1].trim_prefix("\"").trim_suffix("\"")
	match version:
		"Roth Version F1.4":
			installation_info["res_version"] = "F1.4"
			installation_info["exe_version"] = "3.925"
			installation_info["language"] = "UK English"
		"Roth Version 1.12":
			installation_info["res_version"] = "1.12"
			installation_info["exe_version"] = "3.983"
			installation_info["language"] = "US English"
		"Roth Version F1.8":
			installation_info["res_version"] = "F1.8"
			installation_info["exe_version"] = "3.925"
			installation_info["language"] = "German"
		"Roth Version F1.14":
			installation_info["res_version"] = "F1.14"
			installation_info["exe_version"] = "3.925"
			installation_info["language"] = "French"
		"Spanish Roth F1":
			installation_info["res_version"] = "F1"
			installation_info["exe_version"] = "3.983"
			installation_info["language"] = "Spanish"
		"Roth Version 1.8":
			installation_info["res_version"] = "1.8"
			installation_info["exe_version"] = "3.983"
			installation_info["language"] = "Italian"
		_:
			installation_info["res_version"] = version
			installation_info["exe_version"] = "unknown"
			installation_info["language"] = "unknown"
	
	if FileAccess.file_exists(directory.path_join("gog.ico")):
		installation_info["store"] = "GOG"
	elif directory.to_lower().contains("steam"):
		installation_info["store"] = "Steam"
	else:
		installation_info["store"] = "Unknown"
	
	return installation_info


func launch(custom_map: Dictionary, installation_directory: String, options: Dictionary) -> void:
	set_current_map(custom_map)
	
	var install_info: Dictionary = get_installation_information(installation_directory)
	
	var dosbox_settings_filepath: String = OS.get_user_data_dir().path_join("dosbox/dosbox_roth_settings.conf")
	var dosbox_autoexec_filepath: String = OS.get_user_data_dir().path_join("dosbox/dosbox_roth_auto.conf")
	var dosbox_mapper_filepath: String = OS.get_user_data_dir().path_join("dosbox/dosbox_roth_mapper.txt")
	
	var roth_directory: String = ""
	if custom_map.uuid == "0":
		roth_directory = installation_directory
	else:
		roth_directory = OS.get_user_data_dir().path_join("installs").path_join(installation_directory.md5_text()).path_join(custom_map.uuid)
	
	if not DirAccess.dir_exists_absolute(roth_directory):
		print("First run; creating install at %s" % roth_directory)
		create_install(installation_directory, roth_directory)
	
	write_dosbox_settings_file(dosbox_settings_filepath)
	write_dosbox_mapper_file(dosbox_mapper_filepath)
	write_dosbox_autoexec_filepath(dosbox_autoexec_filepath, installation_directory, roth_directory, options)
	
	var read_only_installation: bool = false
	var virtual_store: String = ""
	
	var test_file := FileAccess.open(installation_directory.path_join("test.tmp"), FileAccess.WRITE)
	if test_file:
		test_file.close()
		DirAccess.remove_absolute(installation_directory.path_join("test.tmp"))
	else:
		read_only_installation = true
		if OS.get_name() == "Windows":
			virtual_store = OS.get_user_data_dir().path_join("../../Local/VirtualStore").path_join(installation_directory.right(-3))
		else:
			Dialog.information("Read-only filesystem not supported", "Error", false, Vector2(400, 150), "Close", HORIZONTAL_ALIGNMENT_CENTER)
			return
	
	if options.skip_intro:
		if read_only_installation:
			if OS.get_name() == "Windows":
				if not DirAccess.dir_exists_absolute(virtual_store.path_join("DATA/GDV")):
					DirAccess.make_dir_recursive_absolute(virtual_store.path_join("DATA/GDV"))
				var f := FileAccess.open(virtual_store.path_join("DATA/GDV/GREMLOGO.GDV"), FileAccess.WRITE)
				f.close()
				f = FileAccess.open(virtual_store.path_join("DATA/GDV/INTRO.GDV"), FileAccess.WRITE)
				f.close()
		else:
			DirAccess.rename_absolute(installation_directory.path_join("DATA/GDV/GREMLOGO.GDV"), installation_directory.path_join("DATA/GDV/GREMLOGO.GDV.BAK"))
			DirAccess.rename_absolute(installation_directory.path_join("DATA/GDV/INTRO.GDV"), installation_directory.path_join("DATA/GDV/INTRO.GDV.BAK"))
	if options.disable_cutscenes and custom_map.uuid == "0":
		if read_only_installation:
			if OS.get_name() == "Windows":
				if not DirAccess.dir_exists_absolute(virtual_store.path_join("DATA/GDV")):
					DirAccess.make_dir_recursive_absolute(virtual_store.path_join("DATA/GDV"))
				for file in DirAccess.get_files_at(installation_directory.path_join("DATA/GDV")):
					var f := FileAccess.open(virtual_store.path_join("DATA/GDV").path_join(file), FileAccess.WRITE)
					f.close()
		else:
			DirAccess.rename_absolute(installation_directory.path_join("DATA/GDV"), installation_directory.path_join("DATA/GDV_BAK"))
	if custom_map.uuid == "0":
		if read_only_installation:
			write_config_ini(virtual_store.path_join("ROTH/CONFIG.INI"), true)
			if install_info.exe_version == NEW_EXE:
				var roth_ini_copy_from_filepath := ""
				if FileAccess.file_exists(virtual_store.path_join("ROTH/ROTH.INI")):
					DirAccess.rename_absolute(virtual_store.path_join("ROTH/ROTH.INI"), virtual_store.path_join("ROTH/ROTH.INI.BAK"))
					roth_ini_copy_from_filepath = virtual_store.path_join("ROTH/ROTH.INI.BAK")
				else:
					roth_ini_copy_from_filepath = installation_directory.path_join("ROTH/ROTH.INI")
				var roth_ini_file_copy_from := FileAccess.open(roth_ini_copy_from_filepath, FileAccess.READ)
				var roth_ini_file := FileAccess.open(virtual_store.path_join("ROTH/ROTH.INI"), FileAccess.WRITE)
				while roth_ini_file_copy_from.get_position() < roth_ini_file_copy_from.get_length():
					var line: String = roth_ini_file_copy_from.get_line()
					if not line.begins_with("Key"):
						roth_ini_file.store_string("%s\n" % line)
				roth_ini_file_copy_from.close()
				roth_ini_file.close()
		else:
			if options.skip_intro or options.disable_cutscenes:
				if not FileAccess.file_exists(installation_directory.path_join("DATA/DATA/FILELIST.TXT.BAK")):
					DirAccess.rename_absolute(installation_directory.path_join("DATA/DATA/FILELIST.TXT"), installation_directory.path_join("DATA/DATA/FILELIST.TXT.BAK"))
				var filelist_file := FileAccess.open(installation_directory.path_join("DATA/DATA/FILELIST.TXT"), FileAccess.WRITE)
				filelist_file.close()
			if not FileAccess.file_exists(installation_directory.path_join("ROTH/CONFIG.INI.BAK")):
				DirAccess.rename_absolute(installation_directory.path_join("ROTH/CONFIG.INI"), installation_directory.path_join("ROTH/CONFIG.INI.BAK"))
			write_config_ini(installation_directory.path_join("ROTH/CONFIG.INI"), true)
			if install_info.exe_version == NEW_EXE:
				DirAccess.rename_absolute(installation_directory.path_join("ROTH/ROTH.INI"), installation_directory.path_join("ROTH/ROTH.INI.BAK"))
				var roth_ini_file_copy_from := FileAccess.open(installation_directory.path_join("ROTH/ROTH.INI.BAK"), FileAccess.READ)
				var roth_ini_file := FileAccess.open(installation_directory.path_join("ROTH/ROTH.INI"), FileAccess.WRITE)
				while roth_ini_file_copy_from.get_position() < roth_ini_file_copy_from.get_length():
					var line: String = roth_ini_file_copy_from.get_line()
					if not line.begins_with("Key"):
						roth_ini_file.store_string("%s\n" % line)
				roth_ini_file_copy_from.close()
				roth_ini_file.close()
	
	var pid: int = -1
	
	if OS.get_name() == "Windows":
		var dosbox_bin: String = installation_directory.path_join("DOSBOX/DOSBox.exe")
		var args := [
			'/C',
			'cd /D "%s" && "%s" -conf "%s" -conf "%s" -noconsole' % [OS.get_user_data_dir().path_join("dosbox"), dosbox_bin, dosbox_settings_filepath, dosbox_autoexec_filepath]
		]
		pid = OS.create_process("cmd", args)
	else:
		var dosbox_bin := "/usr/bin/dosbox"
		var args := [
			"-conf",
			dosbox_settings_filepath,
			"-conf",
			dosbox_autoexec_filepath,
			"-noconsole",
		]
		pid = OS.create_process(dosbox_bin, args)
	
	game_launched.emit()
	
	
	#await get_tree().create_timer(1).timeout
	#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	
	while OS.is_process_running(pid):
		await get_tree().create_timer(1).timeout
	
	game_closed.emit()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	if options.skip_intro:
		if read_only_installation:
			if OS.get_name() == "Windows":
				DirAccess.remove_absolute(virtual_store.path_join("DATA/GDV/GREMLOGO.GDV"))
				DirAccess.remove_absolute(virtual_store.path_join("DATA/GDV/INTRO.GDV"))
		else:
			DirAccess.rename_absolute(installation_directory.path_join("DATA/GDV/GREMLOGO.GDV.BAK"), installation_directory.path_join("DATA/GDV/GREMLOGO.GDV"))
			DirAccess.rename_absolute(installation_directory.path_join("DATA/GDV/INTRO.GDV.BAK"), installation_directory.path_join("DATA/GDV/INTRO.GDV"))
	if options.disable_cutscenes and custom_map.uuid == "0":
		if read_only_installation:
			if OS.get_name() == "Windows":
				for file in DirAccess.get_files_at(virtual_store.path_join("DATA/GDV")):
					DirAccess.remove_absolute(virtual_store.path_join("DATA/GDV").path_join(file))
		else:
			DirAccess.rename_absolute(installation_directory.path_join("DATA/GDV_BAK"), installation_directory.path_join("DATA/GDV"))
	if custom_map.uuid == "0":
		if read_only_installation:
			DirAccess.remove_absolute(virtual_store.path_join("ROTH/CONFIG.INI"))
		else:
			if options.skip_intro or options.disable_cutscenes:
				DirAccess.remove_absolute(installation_directory.path_join("DATA/DATA/FILELIST.TXT"))
				DirAccess.rename_absolute(installation_directory.path_join("DATA/DATA/FILELIST.TXT.BAK"), installation_directory.path_join("DATA/DATA/FILELIST.TXT"))
			DirAccess.remove_absolute(installation_directory.path_join("ROTH/CONFIG.INI"))
			DirAccess.rename_absolute(installation_directory.path_join("ROTH/CONFIG.INI.BAK"), installation_directory.path_join("ROTH/CONFIG.INI"))
			if install_info.exe_version == NEW_EXE:
				pass


func create_install(installation_directory: String, roth_directory: String) -> void:
	#remove_dir_recursive(roth_directory)
	DirAccess.make_dir_recursive_absolute(roth_directory.path_join("DATA"))
	DirAccess.make_dir_recursive_absolute(roth_directory.path_join("DIGI"))
	#DirAccess.make_dir_recursive_absolute(roth_directory.path_join("GDV"))
	DirAccess.make_dir_recursive_absolute(roth_directory.path_join("M"))
	DirAccess.make_dir_recursive_absolute(roth_directory.path_join("MIDI"))
	
	DirAccess.copy_absolute(installation_directory.path_join("DATA/DBASE100.DAT"), roth_directory.path_join("DBASE100.DAT"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/DBASE200.DAT"), roth_directory.path_join("DBASE200.DAT"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/DBASE300.DAT"), roth_directory.path_join("DBASE300.DAT"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/DBASE400.DAT"), roth_directory.path_join("DBASE400.DAT"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/DBASE500.DAT"), roth_directory.path_join("DBASE500.DAT"))
	
	DirAccess.copy_absolute(installation_directory.path_join("DATA/DOS4GW.EXE"), roth_directory.path_join("DOS4GW.EXE"))
	if FileAccess.file_exists(installation_directory.path_join("DATA/ROTH.RES")):
		DirAccess.copy_absolute(installation_directory.path_join("DATA/ROTH.RES"), roth_directory.path_join("ROTH.RES"))
	elif FileAccess.file_exists(installation_directory.path_join("DATA/INSTALL/ROTH.RES")):
		DirAccess.copy_absolute(installation_directory.path_join("DATA/INSTALL/ROTH.RES"), roth_directory.path_join("ROTH.RES"))
	else:
		Dialog.information("Couldn't find required file", "Invalid installation", false, Vector2(350, 150), "Close", HORIZONTAL_ALIGNMENT_CENTER)
		return
	
	if FileAccess.file_exists(installation_directory.path_join("DATA/ROTH.EXE")):
		DirAccess.copy_absolute(installation_directory.path_join("DATA/ROTH.EXE"), roth_directory.path_join("ROTH.EXE"))
	elif FileAccess.file_exists(installation_directory.path_join("DATA/INSTALL/ROTH.EXE")):
		DirAccess.copy_absolute(installation_directory.path_join("DATA/INSTALL/ROTH.EXE"), roth_directory.path_join("ROTH.EXE"))
	else:
		Dialog.information("Couldn't find required file", "Invalid installation", false, Vector2(350, 150), "Close", HORIZONTAL_ALIGNMENT_CENTER)
		return
	
	var seek_value: int = 0
	if (FileAccess.get_md5(roth_directory.path_join("ROTH.EXE")) == "f0f93c7931b9a678469095d3d7f54c04" or 
			FileAccess.get_md5(roth_directory.path_join("ROTH.EXE")) == "c11ab446c6d92e4e89d557864aa62997"):
		seek_value = 145767
	elif (FileAccess.get_md5(roth_directory.path_join("ROTH.EXE")) == "d56e7641e8f5d4ec3144bb1c140a7677" or 
			FileAccess.get_md5(roth_directory.path_join("ROTH.EXE")) == "f588469eb868373a339bebb5fba5a9bb"):
		seek_value = 147338
	else:
		print(FileAccess.get_md5(roth_directory.path_join("ROTH.EXE")))
		return
	
	# Patch the EXE to read the GDV files from G:\
	var roth_exe_file := FileAccess.open(roth_directory.path_join("ROTH.EXE"), FileAccess.READ_WRITE)
	roth_exe_file.seek(seek_value)
	roth_exe_file.store_8(0x47)
	roth_exe_file.store_8(0x3A)
	roth_exe_file.store_8(0x5C)
	roth_exe_file.store_8(0x00)
	roth_exe_file.close()
	
	
	DirAccess.copy_absolute(installation_directory.path_join("DATA/DATA/ICONS.ALL"), roth_directory.path_join("DATA/ICONS.ALL"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/DATA/BACKDROP.RAW"), roth_directory.path_join("DATA/BACKDROP.RAW"))
	
	#DirAccess.copy_absolute(installation_directory.path_join("DATA/DATA/FILELIST.TXT"), roth_directory.path_join("DATA/FILELIST.TXT"))
	var filelist_file := FileAccess.open(roth_directory.path_join("DATA/FILELIST.TXT"), FileAccess.WRITE)
	filelist_file.close()
	
	#DirAccess.copy_absolute(installation_directory.path_join("DATA/DATA/FXSCRIPT.SFX"), roth_directory.path_join("DATA/FXSCRIPT.SFX"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/DATA/FX22.SFX"), roth_directory.path_join("DATA/FXSCRIPT.SFX"))
	
	DirAccess.copy_absolute(installation_directory.path_join("DATA/DIGI/HMIDET.386"), roth_directory.path_join("DIGI/HMIDET.386"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/DIGI/HMIDRV.386"), roth_directory.path_join("DIGI/HMIDRV.386"))
	
	
	DirAccess.copy_absolute(installation_directory.path_join("DATA/MIDI/DRUM.BNK"), roth_directory.path_join("MIDI/DRUM.BNK"))
	#DirAccess.copy_absolute(installation_directory.path_join("DATA/MIDI/GRAVIS.INI"), roth_directory.path_join("MIDI/GRAVIS.INI"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/MIDI/HMIMDRV.386"), roth_directory.path_join("MIDI/HMIMDRV.386"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/MIDI/MELODIC.BNK"), roth_directory.path_join("MIDI/MELODIC.BNK"))
	#DirAccess.copy_absolute(installation_directory.path_join("DATA/MIDI/MT32MAP.MTX"), roth_directory.path_join("MIDI/MT32MAP.MTX"))
	
	
	
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/ADEMO.DAS"), roth_directory.path_join("M/ADEMO.DAS"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/DEMO.DAS"), roth_directory.path_join("M/DEMO.DAS"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/DEMO1.DAS"), roth_directory.path_join("M/DEMO1.DAS"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/DEMO2.DAS"), roth_directory.path_join("M/DEMO2.DAS"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/DEMO3.DAS"), roth_directory.path_join("M/DEMO3.DAS"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/DEMO4.DAS"), roth_directory.path_join("M/DEMO4.DAS"))
	
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/ABAGATE2.RAW"), roth_directory.path_join("M/ABAGATE2.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/AELF.RAW"), roth_directory.path_join("M/AELF.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/ANUBIS.RAW"), roth_directory.path_join("M/ANUBIS.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/AQUA1.RAW"), roth_directory.path_join("M/AQUA1.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/AQUA2.RAW"), roth_directory.path_join("M/AQUA2.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/CAVERNS.RAW"), roth_directory.path_join("M/CAVERNS.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/CAVERNS2.RAW"), roth_directory.path_join("M/CAVERNS2.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/CAVERNS3.RAW"), roth_directory.path_join("M/CAVERNS3.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/CHURCH1.RAW"), roth_directory.path_join("M/CHURCH1.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/DOMINION.RAW"), roth_directory.path_join("M/DOMINION.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/DOPPLE.RAW"), roth_directory.path_join("M/DOPPLE.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/ELOHIM1.RAW"), roth_directory.path_join("M/ELOHIM1.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/GNARL1.RAW"), roth_directory.path_join("M/GNARL1.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/GRAVE.RAW"), roth_directory.path_join("M/GRAVE.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/LRINTH.RAW"), roth_directory.path_join("M/LRINTH.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/LRINTH1.RAW"), roth_directory.path_join("M/LRINTH1.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/MAS3.RAW"), roth_directory.path_join("M/MAS3.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/MAS4.RAW"), roth_directory.path_join("M/MAS4.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/MAS6.RAW"), roth_directory.path_join("M/MAS6.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/MAS7.RAW"), roth_directory.path_join("M/MAS7.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/MAUSO1EA.RAW"), roth_directory.path_join("M/MAUSO1EA.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/MAUSO1EB.RAW"), roth_directory.path_join("M/MAUSO1EB.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/MAZE.RAW"), roth_directory.path_join("M/MAZE.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/OPTEMP1.RAW"), roth_directory.path_join("M/OPTEMP1.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/RAQUIA1.RAW"), roth_directory.path_join("M/RAQUIA1.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/RAQUIA2.RAW"), roth_directory.path_join("M/RAQUIA2.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/RAQUIA3.RAW"), roth_directory.path_join("M/RAQUIA3.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/RAQUIA4.RAW"), roth_directory.path_join("M/RAQUIA4.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/RAQUIA5.RAW"), roth_directory.path_join("M/RAQUIA5.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/SALVAT.RAW"), roth_directory.path_join("M/SALVAT.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/SOULST2.RAW"), roth_directory.path_join("M/SOULST2.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/SOULST3.RAW"), roth_directory.path_join("M/SOULST3.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/STUDY1.RAW"), roth_directory.path_join("M/STUDY1.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/STUDY2.RAW"), roth_directory.path_join("M/STUDY2.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/STUDY3.RAW"), roth_directory.path_join("M/STUDY3.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/STUDY4.RAW"), roth_directory.path_join("M/STUDY4.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/TEMPLE1.RAW"), roth_directory.path_join("M/TEMPLE1.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/TGATE1F.RAW"), roth_directory.path_join("M/TGATE1F.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/TGATE1G.RAW"), roth_directory.path_join("M/TGATE1G.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/TGATE1H.RAW"), roth_directory.path_join("M/TGATE1H.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/TGATE1I.RAW"), roth_directory.path_join("M/TGATE1I.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/TOWER1.RAW"), roth_directory.path_join("M/TOWER1.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/VICAR.RAW"), roth_directory.path_join("M/VICAR.RAW"))
	DirAccess.copy_absolute(installation_directory.path_join("DATA/M/VICAR1.RAW"), roth_directory.path_join("M/VICAR1.RAW"))
	
	write_config_ini(roth_directory.path_join("CONFIG.INI"), false)
	
	var roth_ini_file := FileAccess.open(roth_directory.path_join("ROTH.INI"), FileAccess.WRITE)
	roth_ini_file.store_string("SpeechSub=ON\n")
	roth_ini_file.store_string("SpeechAud=ON\n")
	roth_ini_file.store_string("MovieSub=ON\n")
	roth_ini_file.store_string("MovieAud=ON\n")
	roth_ini_file.store_string("VideoMode=8\n")
	roth_ini_file.store_string("ViewSize=0\n")
	roth_ini_file.store_string("SoundFXVol=0x100\n")
	roth_ini_file.store_string("SpeechVol=0xd0\n")
	roth_ini_file.store_string("MovieVol=0x100\n")
	roth_ini_file.store_string("MusicVol=0x100\n")
	roth_ini_file.store_string("MouseSpeed=0x40\n")
	roth_ini_file.close()


func remove_dir_recursive(directory: String) -> void:
	if DirAccess.dir_exists_absolute(directory):
		for dir in DirAccess.get_directories_at(directory):
			remove_dir_recursive(directory.path_join(dir))
		for file in DirAccess.get_files_at(directory):
			DirAccess.remove_absolute(directory.path_join(file))
		DirAccess.remove_absolute(directory)


func write_dosbox_settings_file(dosbox_settings_filepath: String) -> void:
	if not DirAccess.dir_exists_absolute(dosbox_settings_filepath.get_base_dir()):
		DirAccess.make_dir_recursive_absolute(dosbox_settings_filepath.get_base_dir())
	
	var dosbox_settings: Dictionary = Settings.settings.get("dosbox_settings")
	
	var dosbox_settings_file := FileAccess.open(dosbox_settings_filepath, FileAccess.WRITE)
	dosbox_settings_file.store_string("[sdl]\n")
	dosbox_settings_file.store_string("fullscreen=%s\n" % dosbox_settings.fullscreen)
	dosbox_settings_file.store_string("fulldouble=%s\n" % dosbox_settings.fulldouble)
	dosbox_settings_file.store_string("fullresolution=%s\n" % dosbox_settings.fullresolution)
	dosbox_settings_file.store_string("windowresolution=%s\n" % dosbox_settings.windowresolution)
	dosbox_settings_file.store_string("output=%s\n" % dosbox_settings.output)
	dosbox_settings_file.store_string("autolock=%s\n" % dosbox_settings.autolock)
	dosbox_settings_file.store_string("sensitivity=100\n")
	dosbox_settings_file.store_string("waitonerror=true\n")
	dosbox_settings_file.store_string("priority=higher,normal\n")
	dosbox_settings_file.store_string("mapperfile=%s\n" % dosbox_settings_filepath.get_base_dir().path_join("dosbox_roth_mapper.txt"))
	dosbox_settings_file.store_string("usescancodes=true\n")
	dosbox_settings_file.store_string("[dosbox]\n")
	dosbox_settings_file.store_string("language=\n")
	dosbox_settings_file.store_string("machine=svga_s3\n")
	dosbox_settings_file.store_string("captures=capture\n")
	dosbox_settings_file.store_string("memsize=16\n")
	dosbox_settings_file.store_string("[render]")
	dosbox_settings_file.store_string("frameskip=0\n")
	dosbox_settings_file.store_string("aspect=false\n")
	dosbox_settings_file.store_string("scaler=%s\n" % dosbox_settings.scaler)
	dosbox_settings_file.store_string("[cpu]\n")
	dosbox_settings_file.store_string("core=auto\n")
	dosbox_settings_file.store_string("cputype=auto\n")
	dosbox_settings_file.store_string("cycles=%s\n" % dosbox_settings.cycles)
	dosbox_settings_file.store_string("cycleup=10000\n")
	dosbox_settings_file.store_string("cycledown=10000\n")
	dosbox_settings_file.store_string("[mixer]\n")
	dosbox_settings_file.store_string("nosound=false\n")
	dosbox_settings_file.store_string("rate=22050\n")
	dosbox_settings_file.store_string("blocksize=2048\n")
	dosbox_settings_file.store_string("prebuffer=80\n")
	dosbox_settings_file.store_string("[midi]\n")
	dosbox_settings_file.store_string("mpu401=intelligent\n")
	dosbox_settings_file.store_string("device=default\n")
	dosbox_settings_file.store_string("config=\n")
	dosbox_settings_file.store_string("[sblaster]\n")
	dosbox_settings_file.store_string("sbtype=sb16\n")
	dosbox_settings_file.store_string("sbbase=220\n")
	dosbox_settings_file.store_string("irq=7\n")
	dosbox_settings_file.store_string("dma=1\n")
	dosbox_settings_file.store_string("hdma=5\n")
	dosbox_settings_file.store_string("mixer=true\n")
	dosbox_settings_file.store_string("oplmode=auto\n")
	dosbox_settings_file.store_string("oplrate=22050\n")
	dosbox_settings_file.store_string("[gus]\n")
	dosbox_settings_file.store_string("gus=false\n")
	dosbox_settings_file.store_string("[speaker]\n")
	dosbox_settings_file.store_string("pcspeaker=false\n")
	dosbox_settings_file.store_string("pcrate=22050\n")
	dosbox_settings_file.store_string("tandy=auto\n")
	dosbox_settings_file.store_string("tandyrate=22050\n")
	dosbox_settings_file.store_string("disney=true\n")
	dosbox_settings_file.store_string("[joystick]\n")
	dosbox_settings_file.store_string("joysticktype=none\n")
	dosbox_settings_file.store_string("timed=true\n")
	dosbox_settings_file.store_string("autofire=false\n")
	dosbox_settings_file.store_string("swap34=false\n")
	dosbox_settings_file.store_string("buttonwrap=true\n")
	dosbox_settings_file.store_string("[serial]\n")
	dosbox_settings_file.store_string("serial1=dummy\n")
	dosbox_settings_file.store_string("serial2=dummy\n")
	dosbox_settings_file.store_string("serial3=disabled\n")
	dosbox_settings_file.store_string("serial4=disabled\n")
	dosbox_settings_file.store_string("[dos]\n")
	dosbox_settings_file.store_string("xms=true\n")
	dosbox_settings_file.store_string("ems=true\n")
	dosbox_settings_file.store_string("umb=true\n")
	dosbox_settings_file.store_string("keyboardlayout=none\n")
	dosbox_settings_file.close()


func write_dosbox_mapper_file(dosbox_mapper_filepath: String) -> void:
	if not DirAccess.dir_exists_absolute(dosbox_mapper_filepath.get_base_dir()):
		DirAccess.make_dir_recursive_absolute(dosbox_mapper_filepath.get_base_dir())
	
	var dosbox_keymap: Dictionary = Settings.settings.get("dosbox_keymap")
	
	var dosbox_mapper_file := FileAccess.open(dosbox_mapper_filepath, FileAccess.WRITE)
	dosbox_mapper_file.store_string("hand_shutdown\n")
	dosbox_mapper_file.store_string("hand_capmouse %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("capture_mouse", [])))
	dosbox_mapper_file.store_string("hand_fullscr %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("toggle_fullscreen", [])))
	dosbox_mapper_file.store_string("hand_mapper\n")
	dosbox_mapper_file.store_string("hand_speedlock\n")
	dosbox_mapper_file.store_string("hand_recwave\n")
	dosbox_mapper_file.store_string("hand_caprawmidi\n")
	dosbox_mapper_file.store_string("hand_scrshot\n")
	dosbox_mapper_file.store_string("hand_video\n")
	dosbox_mapper_file.store_string("hand_decfskip\n")
	dosbox_mapper_file.store_string("hand_incfskip\n")
	dosbox_mapper_file.store_string("hand_cycledown %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("cycles_down", [])))
	dosbox_mapper_file.store_string("hand_cycleup %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("cycles_up", [])))
	dosbox_mapper_file.store_string("hand_debugger %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("debugger", [])))
	dosbox_mapper_file.store_string("hand_caprawopl\n")
	dosbox_mapper_file.store_string("hand_swapimg\n")
	dosbox_mapper_file.store_string("key_esc %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("escape", [])))
	dosbox_mapper_file.store_string("key_f1 %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("hide_weapon", [])))
	dosbox_mapper_file.store_string("key_f2 %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("toggle_subtitles", [])))
	dosbox_mapper_file.store_string("key_f3 %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("toggle_adventure_mode", [])))
	dosbox_mapper_file.store_string("key_f4\n")
	dosbox_mapper_file.store_string("key_f5 %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("toggle_mouse_buttons", [])))
	dosbox_mapper_file.store_string("key_f6\n")
	dosbox_mapper_file.store_string("key_f7\n")
	dosbox_mapper_file.store_string("key_f8 %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("display_version", [])))
	dosbox_mapper_file.store_string("key_f9 %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("quicksave", [])))
	dosbox_mapper_file.store_string("key_f10 %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("quickload", [])))
	dosbox_mapper_file.store_string("key_f11\n")
	dosbox_mapper_file.store_string("key_f12\n")
	dosbox_mapper_file.store_string("key_grave\n")
	dosbox_mapper_file.store_string("key_1 %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("unarmed", [])))
	dosbox_mapper_file.store_string("key_2 %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("quickslot_1", [])))
	dosbox_mapper_file.store_string("key_3 %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("quickslot_2", [])))
	dosbox_mapper_file.store_string("key_4 %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("quickslot_3", [])))
	dosbox_mapper_file.store_string("key_5 %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("quickslot_4", [])))
	dosbox_mapper_file.store_string("key_6 %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("quickslot_5", [])))
	dosbox_mapper_file.store_string("key_7\n")
	dosbox_mapper_file.store_string("key_8\n")
	dosbox_mapper_file.store_string("key_9\n")
	dosbox_mapper_file.store_string("key_0\n")
	dosbox_mapper_file.store_string("key_minus %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("decrease_viewport", [])))
	dosbox_mapper_file.store_string("key_equals %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("increase_viewport", [])))
	dosbox_mapper_file.store_string("key_bspace\n")
	dosbox_mapper_file.store_string("key_tab\n")
	dosbox_mapper_file.store_string("key_q\n")
	dosbox_mapper_file.store_string("key_w\n")
	dosbox_mapper_file.store_string("key_e\n")
	dosbox_mapper_file.store_string("key_r\n")
	dosbox_mapper_file.store_string("key_t %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("redraw_screen", [])))
	dosbox_mapper_file.store_string("key_y\n")
	dosbox_mapper_file.store_string("key_u\n")
	dosbox_mapper_file.store_string("key_i %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("inventory", [])))
	dosbox_mapper_file.store_string("key_o\n")
	dosbox_mapper_file.store_string("key_p\n")
	dosbox_mapper_file.store_string("key_lbracket\n")
	dosbox_mapper_file.store_string("key_rbracket\n")
	dosbox_mapper_file.store_string("key_enter %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("enter", [])))
	dosbox_mapper_file.store_string("key_capslock %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("toggle_run", [])))
	dosbox_mapper_file.store_string("key_a %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("jump", [])))
	dosbox_mapper_file.store_string("key_s\n")
	dosbox_mapper_file.store_string("key_d %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("main_menu", [])))
	dosbox_mapper_file.store_string("key_f\n")
	dosbox_mapper_file.store_string("key_g\n")
	dosbox_mapper_file.store_string("key_h\n")
	dosbox_mapper_file.store_string("key_j\n")
	dosbox_mapper_file.store_string("key_k\n")
	dosbox_mapper_file.store_string("key_l\n")
	dosbox_mapper_file.store_string("key_semicolon\n")
	dosbox_mapper_file.store_string("key_quote\n")
	dosbox_mapper_file.store_string("key_backslash\n")
	dosbox_mapper_file.store_string("key_lshift %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("hold_run", [])))
	dosbox_mapper_file.store_string("key_lessthan\n")
	dosbox_mapper_file.store_string("key_z %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("crouch", [])))
	dosbox_mapper_file.store_string("key_x\n")
	dosbox_mapper_file.store_string("key_c %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("increase_gamma", [])))
	dosbox_mapper_file.store_string("key_v %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("decrease_gamma", [])))
	dosbox_mapper_file.store_string("key_b\n")
	dosbox_mapper_file.store_string("key_n\n")
	dosbox_mapper_file.store_string("key_m %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("toggle_textures", [])))
	dosbox_mapper_file.store_string("key_comma %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("strafe_left", [])))
	dosbox_mapper_file.store_string("key_period %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("strafe_right", [])))
	dosbox_mapper_file.store_string("key_slash\n")
	dosbox_mapper_file.store_string("key_rshift\n")
	dosbox_mapper_file.store_string("key_lctrl %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("attack", [])))
	dosbox_mapper_file.store_string("key_lalt\n")
	dosbox_mapper_file.store_string("key_space %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("reload_after_death", [])))
	dosbox_mapper_file.store_string("key_ralt\n")
	dosbox_mapper_file.store_string("key_rctrl\n")
	dosbox_mapper_file.store_string("key_printscreen\n")
	dosbox_mapper_file.store_string("key_scrolllock\n")
	dosbox_mapper_file.store_string("key_pause\n")
	dosbox_mapper_file.store_string("key_insert\n")
	dosbox_mapper_file.store_string("key_home %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("tilt_up", [])))
	dosbox_mapper_file.store_string("key_pageup %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("look_up", [])))
	dosbox_mapper_file.store_string("key_delete\n")
	dosbox_mapper_file.store_string("key_end %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("tilt_down", [])))
	dosbox_mapper_file.store_string("key_pagedown %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("look_down", [])))
	dosbox_mapper_file.store_string("key_up %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("move_forward", [])))
	dosbox_mapper_file.store_string("key_left %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("turn_left", [])))
	dosbox_mapper_file.store_string("key_down %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("move_backward", [])))
	dosbox_mapper_file.store_string("key_right %s\n" % SDL.get_sdl_keycode_string(dosbox_keymap.get("turn_right", [])))
	dosbox_mapper_file.store_string("key_numlock\n")
	dosbox_mapper_file.store_string("key_kp_divide\n")
	dosbox_mapper_file.store_string("key_kp_multiply\n")
	dosbox_mapper_file.store_string("key_kp_minus\n")
	dosbox_mapper_file.store_string("key_kp_7\n")
	dosbox_mapper_file.store_string("key_kp_8\n")
	dosbox_mapper_file.store_string("key_kp_9\n")
	dosbox_mapper_file.store_string("key_kp_plus\n")
	dosbox_mapper_file.store_string("key_kp_4\n")
	dosbox_mapper_file.store_string("key_kp_5\n")
	dosbox_mapper_file.store_string("key_kp_6\n")
	dosbox_mapper_file.store_string("key_kp_1\n")
	dosbox_mapper_file.store_string("key_kp_2\n")
	dosbox_mapper_file.store_string("key_kp_3\n")
	dosbox_mapper_file.store_string("key_kp_enter\n")
	dosbox_mapper_file.store_string("key_kp_0\n")
	dosbox_mapper_file.store_string("key_kp_period\n")
	dosbox_mapper_file.store_string("jbutton_0_0\n")
	dosbox_mapper_file.store_string("jbutton_0_1\n")
	dosbox_mapper_file.store_string("jaxis_0_1-\n")
	dosbox_mapper_file.store_string("jaxis_0_1+\n")
	dosbox_mapper_file.store_string("jaxis_0_0-\n")
	dosbox_mapper_file.store_string("jaxis_0_0+\n")
	dosbox_mapper_file.store_string("jbutton_0_2\n")
	dosbox_mapper_file.store_string("jbutton_0_3\n")
	dosbox_mapper_file.store_string("jbutton_1_0\n")
	dosbox_mapper_file.store_string("jbutton_1_1\n")
	dosbox_mapper_file.store_string("jaxis_0_2-\n")
	dosbox_mapper_file.store_string("jaxis_0_2+\n")
	dosbox_mapper_file.store_string("jaxis_0_3-\n")
	dosbox_mapper_file.store_string("jaxis_0_3+\n")
	dosbox_mapper_file.store_string("jaxis_1_0-\n")
	dosbox_mapper_file.store_string("jaxis_1_0+\n")
	dosbox_mapper_file.store_string("jaxis_1_1-\n")
	dosbox_mapper_file.store_string("jaxis_1_1+\n")
	dosbox_mapper_file.store_string("jbutton_0_4\n")
	dosbox_mapper_file.store_string("jbutton_0_5\n")
	dosbox_mapper_file.store_string("jhat_0_0_0\n")
	dosbox_mapper_file.store_string("jhat_0_0_3\n")
	dosbox_mapper_file.store_string("jhat_0_0_2\n")
	dosbox_mapper_file.store_string("jhat_0_0_1\n")
	dosbox_mapper_file.store_string("mod_1\n")
	dosbox_mapper_file.store_string("mod_2\n")
	dosbox_mapper_file.store_string("mod_3\n")
	dosbox_mapper_file.close()


func write_dosbox_autoexec_filepath(dosbox_autoexec_filepath: String, installation_directory: String, roth_directory:String, options: Dictionary) -> void:
	if not DirAccess.dir_exists_absolute(dosbox_autoexec_filepath.get_base_dir()):
		DirAccess.make_dir_recursive_absolute(dosbox_autoexec_filepath.get_base_dir())
	
	var dosbox_autoexec := FileAccess.open(dosbox_autoexec_filepath, FileAccess.WRITE)
	dosbox_autoexec.store_string("[autoexec]\n")
	dosbox_autoexec.store_string("mount c \"%s\n" % roth_directory)
	if not options.disable_cutscenes:
		dosbox_autoexec.store_string("mount g \"%s\n" % installation_directory.path_join("DATA/GDV"))
	dosbox_autoexec.store_string("c:\n")
	
	if installation_directory == roth_directory:
		dosbox_autoexec.store_string("cd \\roth\n")
	dosbox_autoexec.store_string("ROTH.EXE @ROTH.RES\n")
	dosbox_autoexec.store_string("exit\n")
	dosbox_autoexec.close()


func write_config_ini(config_ini_filepath: String, original_game: bool) -> void:
	if not DirAccess.dir_exists_absolute(config_ini_filepath.get_base_dir()):
		DirAccess.make_dir_recursive_absolute(config_ini_filepath.get_base_dir())
	var config_ini_file := FileAccess.open(config_ini_filepath, FileAccess.WRITE)
	if original_game:
		config_ini_file.store_string("SourcePath=C:\\DATA\n")
		config_ini_file.store_string("DestinationPath=C:\\ROTH\n")
	config_ini_file.store_string("SoundCard=0xe018\n")
	config_ini_file.store_string("SoundPort=0x220\n")
	config_ini_file.store_string("SoundIRQ=7\n")
	config_ini_file.store_string("SoundDMA=5\n")
	config_ini_file.store_string("MusicCard=0xa009\n")
	config_ini_file.store_string("MusicPort=0x388\n")
	config_ini_file.close()
