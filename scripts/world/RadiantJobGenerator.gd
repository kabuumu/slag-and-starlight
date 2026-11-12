class_name RadiantJobGenerator
extends Node
## Procedural Radiant Job Generator for Rust-Spire Outpost surface terminal.

const ENEMY_TYPES: Array[Dictionary] = [
	{"id": "slag_tick", "label": "Slag-Ticks"},
	{"id": "mining_drone", "label": "Rogue Mining Drones"},
	{"id": "feral_driller", "label": "Feral Drillers"},
]

const ITEM_TYPES: Array[Dictionary] = [
	{"id": "power_cell", "label": "Power Cell"},
	{"id": "raw_ore", "label": "Raw Khoros Ore"},
	{"id": "hacking_deck", "label": "Hacking Deck"},
]

const SECTORS: Array[String] = [
	"Sub-Level 04: Deep Bore",
	"Shaft 09: Slag Pit",
	"Sector B: Ore Conveyor",
	"Abandoned Rig 12",
]

const FACTIONS: Array[String] = [
	"Mining Union",
	"Khoros Corp",
	"Free Drifters",
]

var _job_counter: int = 0


func generate_job() -> QuestResource:
	if randi() % 2 == 0:
		return generate_extermination_job()
	return generate_recovery_job()


func generate_extermination_job() -> QuestResource:
	_job_counter += 1
	var enemy: Dictionary = ENEMY_TYPES[randi() % ENEMY_TYPES.size()]
	var sector: String = SECTORS[randi() % SECTORS.size()]
	var title: String = "Clear %s in %s" % [enemy["label"], sector]
	var qid: String = "radiant_exterm_%d_%s" % [_job_counter, enemy["id"]]

	var stage := QuestStage.new()
	stage.stage_id = "kill_%s" % enemy["id"]
	stage.journal_text = title
	stage.objective_type = QuestStage.ObjectiveType.KILL
	stage.target_id = str(enemy["id"])
	stage.xp_reward = 50
	stage.credit_reward = 35

	var quest := QuestResource.new()
	quest.quest_id = qid
	quest.id = qid
	quest.title = title
	quest.description = "Contract posting from Rust-Spire Outpost: %s." % title
	quest.is_radiant = true
	quest.stages = [stage]
	quest.reward_xp = 80
	quest.reward_credits = 75
	return quest


func generate_recovery_job() -> QuestResource:
	_job_counter += 1
	var item: Dictionary = ITEM_TYPES[randi() % ITEM_TYPES.size()]
	var sector: String = SECTORS[randi() % SECTORS.size()]
	var faction: String = FACTIONS[randi() % FACTIONS.size()]
	var title: String = "Recover lost %s from %s for %s." % [item["label"], sector, faction]
	var qid: String = "radiant_recover_%d_%s" % [_job_counter, item["id"]]

	var stage := QuestStage.new()
	stage.stage_id = "fetch_%s" % item["id"]
	stage.journal_text = title
	stage.objective_type = QuestStage.ObjectiveType.FETCH
	stage.target_id = str(item["id"])
	stage.xp_reward = 45
	stage.credit_reward = 40

	var quest := QuestResource.new()
	quest.quest_id = qid
	quest.id = qid
	quest.title = title
	quest.description = "Contract posting from Rust-Spire Outpost: %s" % title
	quest.is_radiant = true
	quest.stages = [stage]
	quest.reward_xp = 75
	quest.reward_credits = 85
	return quest
