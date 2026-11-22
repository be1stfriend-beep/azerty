extends Interactable
## Opens the craft menu on the interacting player's screen.


func interact(_player: PlayerBase) -> void:
	Game.show_craft_menu()
