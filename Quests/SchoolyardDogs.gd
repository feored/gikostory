extends Quest

var quest_stages = {
    "initial":
    {
        "id": "initial",
        "condition": "setupTrap",
        "condition_type" : Quests.QuestConditionType.Flag,
        "completed": "placeBurger",
        "next" : "talkToShobon"
    },
    "talkToShobon" :
    {
        "id" : "talkToShobon",
        "condition" : "finishedSchoolyardDogs",
        "condition_type" : Quests.QuestConditionType.Flag,
        "completed" : "shobonGoesHome",
        "next": "final"
    },
    "final": {"id": "final"}
}


func _init().(quest_stages):
    pass


## CONDITIONS

func setupTrap() -> bool:
    return Quests.QUEST_FLAGS["qSetSchoolyardTrap"]

func finishedSchoolyardDogs() -> bool:
    return Quests.QUEST_FLAGS["qFinishedSchoolyardDogs"]

## COMPLETED

func placeBurger() -> void:
    Items.addActiveItem("school_ground", "gikoburger", Vector2(8,0), Items.ITEMS["gikoburger"]["default_world_scale"])
    for zonuNPCID in ["WildZonu1", "WildZonu2", "WildZonu3", "WildZonu4", "WildZonu5"]:
        var zonu = Rooms.getGikoByNpcId(zonuNPCID)
        if zonu != null:
            zonu.startTargetting(Vector2(8,0))
        NPCs.updateNPCPosition("school_ground", zonuNPCID, Vector2(1, 1))
    NPCs.removeAllQuestDialogue("school_ground", "ScaredShobon")
    NPCs.addQuestDialogue("school_ground", "ScaredShobon", 
    {
        "info": {"name" : "WeirdSchoolyardSpot", "requeue" : false, "start": "start"},
            "start":
            {
                "id": "start",
                "type": Constants.LineType.Text,
                "text":
                "Thank you...I can finally go home to play Wanko to Kurasou!!",
                "flags" : [{"flag": "qFinishedSchoolyardDogs", "type": "set", "value": true}]
            }
    })

func shobonGoesHome() -> void:
    var shobon = Rooms.getGikoByNpcId("ScaredShobon")
    if shobon != null:
        shobon.targetTile = Vector2(5,0)
        shobon.isTargeting = true
    NPCs.removeActiveNPC("school_ground", "ScaredShobon")
    NPCs.addActiveNPC("school_ground", "ShiisSong", Constants.Directions.DIR_DOWN, Vector2(4, 4))
    NPCs.addActiveNPC("school_ground", "ShiisSongHimawari", Constants.Directions.DIR_DOWN, Vector2(4, 5))
    

## SETUP

func setup() -> void:
    NPCs.addQuestDialogue(
        "school_ground",
        "ScaredShobon",
        Utils.makeSimpleDialogue(["[nervous]Help...The dogs think I'm their next meal...[/nervous]"])
    )

    Items.addEnvironmentDialogue(
        "school_ground",
        Vector2(8,0),
        {
            "info": {"name" : "WeirdSchoolyardSpot", "requeue" : true, "start": "start"},
            "start":
            {
                "id": "start",
                "type": Constants.LineType.Text,
                "text":
                "Something very strange is happening to people who stand in this spot. It might explain the sudden disparitions reported around this school...or perhaps not.",
                "nextId": "WeirdSchoolyardSpot2"
            },
            "WeirdSchoolyardSpot2" :
            {
                "id": "WeirdSchoolyardSpot2",
                "type": Constants.LineType.Choice,
                "choices":
                [
                    {
                        "text": "Place the burger on this spot.",
                        "condition": {
                            "type" : Constants.ConditionType.Item,
                            "value" : "gikoburger"
                        },
                        "costs" : ["gikoburger"],
                        "flags" : [{"flag": "qSetSchoolyardTrap", "type": "set", "value": true}]
                    },
                    {
                        "text": "..."
                    }
                ],
            }
        }
    )
    
