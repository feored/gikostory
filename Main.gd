extends Node2D

var rng = RandomNumberGenerator.new()

const Giko = preload("res://Giko/Giko.gd")
const PlayerGiko = preload("res://Giko/PlayerGiko.gd")

var gikoPrefab = preload("res://Giko/Giko.tscn")

var lightPrefab = preload("res://Quests/Misc/Flashlight.tscn")

var messages: Dictionary = {}

var totalMessages = 0

var playerGiko : Node

var activeItems : Dictionary = {}
var activeNPCs : Dictionary = {}
var environmentItems : Dictionary = {}

var timeElapsed = 0


const DEFAULT_NEXT_GIKO_TIME = 20
var nextGikoTime = Utils.rng.randfn(DEFAULT_NEXT_GIKO_TIME, 5)


var adjacentRoomsThread
var adjacentRoomsCache = []


onready var camera = $"%Camera2D"
onready var dialogueManager = $"%Dialogue"
# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	#loadRandomRoom()
	loadRoom("idoA")
	spawnRandomGikos()
	spawnPlayerGiko(Rooms.currentRoomData["doors"].keys()[0])

	Quests.initQuests()

	# dialogueManager.setLineSet(Utils.makeSimpleDialogue([
	# 	"Welcome to Giko Story!",
	# 	"This server is an amalgamation of the international and Japanese servers.",
	# 	"Go explore, talk to everyone, pick up items and have fun!"
	# ]), "")
	# dialogueManager.show()


func loadRandomRoom() -> void:
	#loadRoom("admin")
	loadRoom(Rooms.ROOMS.keys()[Utils.rng.randi() % Rooms.ROOMS.keys().size()])


func cleanRoom() -> void:
	for n in $"%zObjects".get_children():
		$"%zObjects".remove_child(n)
		n.queue_free()


func spawnRandomGikos(number : int = Utils.rng.randi() % 10) -> void:
	for _i in range(number):
		var randomGiko = getAvailableRandomGikoPair()
		spawnRandomGiko(randomGiko[0], randomGiko[1])

func getAvailableRandomGikoPair() -> Array:
	if Utils.rng.randf() > 0.6:
		return [
			"Anonymous",
			Constants.Character.values()[Utils.rng.randi() % Constants.Character.values().size()]
		]
	else:
		var randomGiko = Constants.RANDOM_GIKOS[Utils.rng.randi() % Constants.RANDOM_GIKOS.size()]
		return [randomGiko["name"], randomGiko["character"]]



func spawnRandomGikoAtDoor() -> void:
	var randomGiko = getAvailableRandomGikoPair()
	var randomRoom = Rooms.getRandomDoorInRoom()
	spawnRandomGiko(randomGiko[0], randomGiko[1], randomRoom, true)


func changeRoom(newRoom : String):
	$"%zObjects".remove_child(playerGiko)
	cleanRoom()
	loadRoom(newRoom)
	spawnRandomGikos()
	$"%zObjects".add_child(playerGiko)

func doorChangeRoom(target):
	changeRoom(target["roomId"])
	
	playerGiko.place(
		Vector2(
			Rooms.currentRoomData["doors"][target["doorId"]]["x"],
			Rooms.currentRoomData["doors"][target["doorId"]]["y"]
		),
		Utils.roomDirectionToEnum(Rooms.currentRoomData["doors"][target["doorId"]]["direction"])
	)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	timeElapsed += delta
	if timeElapsed > nextGikoTime:
		nextGikoTime = Utils.rng.randfn(DEFAULT_NEXT_GIKO_TIME, 5)
		timeElapsed = 0
		spawnRandomGikoAtDoor()


func adjacentRoomsLoaded():
	adjacentRoomsThread.wait_to_finish()

func loadAdjacentRooms(adjacentRooms):
	
	for room in adjacentRooms:
		adjacentRoomsCache.push_back(load(room))
	call_deferred("adjacentRoomsLoaded")

func setLoading(isLoading : bool) -> void:
	$"%Loading".visible = isLoading
	
func loadRoom(roomName: String) -> void:
	Rooms.loaded = false
	Rooms.updateRoomData(roomName)
	if (Rooms.currentRoomData.has("exterior") && Rooms.currentRoomData["exterior"] == true):
		$"%Snow".visible = true
	else:
		$"%Snow".visible = false
	var newRoomTexture = load("res://" + Rooms.ROOMS[roomName]["backgroundImageUrl"])
	$Background.scale = Vector2(Rooms.currentRoomScale/4, Rooms.currentRoomScale/4)
	$Background.texture = newRoomTexture
	$Background.position = Rooms.getCurrentRoomOffset()
	$"%RoomName".setNewRoom(Rooms.DISPLAY_NAMES[roomName])

	timeElapsed = 0
	
	loadObjects()
	loadItems()
	loadNPCs()
	loadEnvironment()
	$"%Grid".draw_grid()


	## Room specific:

	if roomName == "bar_giko_square":
		if State.BLACKOUT:
			var newLight = lightPrefab.instance()
			$"%zObjects".add_child(newLight)
			newLight.position = Utils.getTilePosAtCoords(Vector2(1, 10))
			newLight.color = Color("ffc4c4")
			newLight.texture_scale = 1.0

	#adjacentRoomsThread = Thread.new()
	#adjacentRoomsCache.clear()

	var adjacentRooms = []
	for door in Rooms.currentRoomData["doors"].values():
		if door["target"] != null:
			adjacentRooms.push_back(
				"res://" + Rooms.ROOMS[door["target"]["roomId"]]["backgroundImageUrl"]
			)
	#adjacentRoomsThread.start(self, "loadAdjacentRooms", adjacentRooms)

	Rooms.loaded = true

	return


func loadObjects() -> void:
	for object in Rooms.currentRoomData["objects"]:
		var objectSprite = Sprite.new()
		objectSprite.centered = false
		objectSprite.texture = load(
			"res://rooms/" + Rooms.currentRoomId + "/" + object["url"]
		)
		objectSprite.scale = Vector2(0.25 , 0.25) * (object["scale"] if object.has("scale") else 1)
		$"%zObjects".add_child(objectSprite)
		var roomOffset: Vector2 = Rooms.getCurrentRoomOffset()
		objectSprite.position = Vector2(
			roomOffset.x + (object["offset"]["x"] * (object["scale"] if object.has("scale") else 1)) , roomOffset.y + (object["offset"]["y"] * (object["scale"] if object.has("scale") else 1))
		)
		var coords = Vector2(object["x"], object["y"])
		objectSprite.z_index = Utils.getTilePosAtCoords(coords).y
		
func loadEnvironment() -> void:
	environmentItems.clear()
	if Items.BACKGROUND_ENVIRONMENT.has(Rooms.currentRoomId):
		for itemPosition in Items.BACKGROUND_ENVIRONMENT[Rooms.currentRoomId]:
			var itemData = Items.BACKGROUND_ENVIRONMENT[Rooms.currentRoomId][itemPosition]
			loadEnvironmentItem(itemPosition, itemData)
			

func loadEnvironmentItem(itemPosition : Vector2, itemData : Dictionary) -> void:
	var itemSprite = Sprite.new()
	itemSprite.texture = load(itemData["url"])
	itemSprite.scale = Vector2(itemData["world_scale"], itemData["world_scale"])
	itemSprite.rotation_degrees = itemData["rotation"]
	$"%zObjects".add_child(itemSprite)

	itemSprite.position = Utils.getTilePosAtCoords(itemPosition) + itemData["offset"]
	itemSprite.z_index = itemSprite.position.y
	environmentItems[itemPosition] = itemSprite

func removeEnvironmentItem(position: Vector2) -> void:
	if environmentItems.has(position):
		environmentItems[position].queue_free()
		environmentItems.erase(position)
	
func replaceEnvironmentItem(position: Vector2, itemData : Dictionary) -> void:
	removeEnvironmentItem(position)
	loadEnvironmentItem(position, itemData)

func loadItems() -> void:
	activeItems.clear()
	if Items.ACTIVE_ITEMS.has(Rooms.currentRoomId):
		for item in Items.ACTIVE_ITEMS[Rooms.currentRoomId]:
			loadItem(item)
	
				

func loadItem(item : Dictionary) -> void:
	var itemSprite = Sprite.new()
	var itemData = Items.ITEMS[item["id"]]
	#itemSprite.centered = false
	itemSprite.texture = load(itemData["url"])
	itemSprite.scale = Vector2(item["world_scale"], item["world_scale"])
	itemSprite.rotation_degrees = item["rotation"]
	$"%zObjects".add_child(itemSprite)
	
	var coords = Vector2(item["x"], item["y"])
	itemSprite.position = Utils.getTilePosAtCoords(coords)
	itemSprite.z_index = itemSprite.position.y
	activeItems[coords] = itemSprite

func loadNPCs() -> void:
	activeNPCs.clear()
	if NPCs.ACTIVE_NPCs.has(Rooms.currentRoomId):
		for npcData in NPCs.ACTIVE_NPCs[Rooms.currentRoomId].values():
			spawnNPCGiko(npcData)


func removeActiveItem(item : Dictionary) -> void:
	var tile = Vector2(item["x"], item["y"])
	if activeItems.has(tile):
		activeItems[tile].queue_free()
		activeItems.erase(tile)

func talkToNPC(NPCId : String) -> void:
	if (dialogueManager.isDialoguing):
		dialogueManager.skipToNext()
		return
	else:
		if (NPCs.ACTIVE_NPCs[Rooms.currentRoomId][NPCId].has("lines") && NPCs.ACTIVE_NPCs[Rooms.currentRoomId][NPCId]["lines"].size() > 0):
			var qLine = NPCs.ACTIVE_NPCs[Rooms.currentRoomId][NPCId]["lines"].pop_front()
			dialogueManager.setLineSet(qLine, NPCId)
			dialogueManager.show()
			if qLine["info"]["requeue"]:
				NPCs.ACTIVE_NPCs[Rooms.currentRoomId][NPCId]["lines"].push_back(qLine)
		elif NPCs.NPCs[NPCId].lines.size() > 0:
			var dialogueLine = NPCs.NPCs[NPCId].lines.pop_front()
			NPCs.NPCs[NPCId].lines.push_back(dialogueLine)
			dialogueManager.setLineSet(dialogueLine, NPCId)
			dialogueManager.show()

func talkToEnvironment(tile : Vector2) -> void:
	if (dialogueManager.isDialoguing):
		dialogueManager.skipToNext()
		return
	else:
		if (Items.ACTIVE_ENVIRONMENT.has(Rooms.currentRoomId) && Items.ACTIVE_ENVIRONMENT[Rooms.currentRoomId].has(tile)):
			dialogueManager.setLineSet(
				Items.ACTIVE_ENVIRONMENT[Rooms.currentRoomId][tile],
				""
			)
			dialogueManager.show()

func spawnPlayerGiko(door: String) -> void:
	var newGiko = gikoPrefab.instance()
	newGiko.set_script(PlayerGiko)
	newGiko.character = Constants.Character.Giko
	newGiko.displayName = "Anonymous"

	## prepare callbacks
	newGiko.changeRoom = funcref(self, "doorChangeRoom")
	newGiko.removeActiveItem = funcref(self, "removeActiveItem")
	newGiko.talkToNPC = funcref(self, "talkToNPC")
	newGiko.talkToEnvironment = funcref(self, "talkToEnvironment")
	
	newGiko.place(
		Vector2(
			Rooms.currentRoomData["doors"][door]["x"],
			Rooms.currentRoomData["doors"][door]["y"]
		),
		Utils.roomDirectionToEnum(Rooms.currentRoomData["doors"][door]["direction"])
	)

	$"%zObjects".add_child(newGiko)
	playerGiko = newGiko
	$Camera2D.player = playerGiko
	#playerGiko.message("I miss Mona.")


func spawnNPCGiko(NPCData : Dictionary) -> void:
	var newGiko = gikoPrefab.instance()
	newGiko.set_script(Giko)
	newGiko.initializeNPC(NPCData)
	$"%zObjects".add_child(newGiko)

func spawnRandomGiko(name : String, character : int, door = null, playSound = false) -> void:
	var newGiko = gikoPrefab.instance()
	newGiko.set_script(Giko)
	newGiko.initializeRandom(name, character)
	$"%zObjects".add_child(newGiko)
	if door != null:
		newGiko.place(
		Vector2(
			Rooms.currentRoomData["doors"][door]["x"],
			Rooms.currentRoomData["doors"][door]["y"]
		),
		Utils.roomDirectionToEnum(Rooms.currentRoomData["doors"][door]["direction"])
	)
	if playSound:
		Audio.playFX(Audio.FX.Login)

func save() -> Dictionary:
	return {
		"ROOM" : Rooms.currentRoomId,
		"PLAYER_POSITION" : Vector2(playerGiko.currentTile),
		"PLAYER_DIRECTION" : playerGiko.currentDirection
	}

func load(save : Dictionary) -> void:
	changeRoom(save["ROOM"])
	playerGiko.place(save["PLAYER_POSITION"], save["PLAYER_DIRECTION"])
