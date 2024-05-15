extends VSplitContainer

func _ready():
	$Navbar/Gamemodes/GamemodeBhop.pressed.connect($Margin/LevelSelect.set_gamemode_bhop)
	$Navbar/Gamemodes/GamemodeLongjump.pressed.connect($Margin/LevelSelect.set_gamemode_longjump)
