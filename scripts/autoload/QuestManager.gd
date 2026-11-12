extends Node
## QuestManager autoload: tracks active/completed quests, listens to EventBus, advances stages, and awards XP/credits.


func _ready() -> void:
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		if bus.has_signal("enemy_killed") and not bus.enemy_killed.is_connected(_on_enemy_killed):
			bus.enemy_killed.connect(_on_enemy_killed)
		if bus.has_signal("item_picked_up") and not bus.item_picked_up.is_connected(_on_item_picked_up):
			bus.item_picked_up.connect(_on_item_picked_up)
		if bus.has_signal("minigame_completed") and not bus.minigame_completed.is_connected(_on_minigame_completed):
			bus.minigame_completed.connect(_on_minigame_completed)
		if bus.has_signal("dialogue_topic_visited") and not bus.dialogue_topic_visited.is_connected(_on_dialogue_topic_visited):
			bus.dialogue_topic_visited.connect(_on_dialogue_topic_visited)


func start_quest(quest_id: String) -> bool:
	if quest_id.is_empty():
		return false
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return false
	if gs.active_quests.has(quest_id) or quest_id in gs.completed_quests:
		return false

	var path: String = "res://resources/quests/%s.tres" % quest_id
	if not ResourceLoader.exists(path):
		return false
	var template: Resource = load(path)
	if template == null:
		return false
	var quest_instance: Resource = template.duplicate(true)
	return accept_quest(quest_instance)


func accept_quest(quest_res: Resource) -> bool:
	if quest_res == null:
		return false
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return false

	var qid: String = ""
	if quest_res.has_method("get_quest_id"):
		qid = str(quest_res.call("get_quest_id"))
	elif "quest_id" in quest_res and not str(quest_res.get("quest_id")).is_empty():
		qid = str(quest_res.get("quest_id"))
	elif "id" in quest_res:
		qid = str(quest_res.get("id"))

	if qid.is_empty():
		return false
	if gs.active_quests.has(qid) or qid in gs.completed_quests:
		return false

	gs.active_quests[qid] = quest_res
	var first_stage_id: String = ""
	var stages_val: Variant = quest_res.get("stages")
	if stages_val is Array and (stages_val as Array).size() > 0:
		var first_stage: Variant = (stages_val as Array)[0]
		if first_stage is Resource and "stage_id" in first_stage:
			first_stage_id = str(first_stage.get("stage_id"))

	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.quest_updated.emit(qid, first_stage_id)
		var q_title: String = str(quest_res.get("title")) if "title" in quest_res else qid
		bus.combat_log_entry.emit("Quest Started: %s" % q_title, "quest")
	return true


func advance_objective(objective_type: int, target_id: String) -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null or target_id.is_empty():
		return

	var ps: Node = get_node_or_null("/root/PlayerStats")
	var bus: Node = get_node_or_null("/root/EventBus")
	var quest_ids: Array = gs.active_quests.keys()

	for qid_var in quest_ids:
		var qid: String = str(qid_var)
		var quest: Variant = gs.active_quests.get(qid, null)
		if not (quest is Resource):
			continue
		var stages_val: Variant = quest.get("stages")
		if not (stages_val is Array):
			continue
		var stages: Array = stages_val
		var progressed: bool = false
		var completed_stage_id: String = ""

		for stage_var in stages:
			if not (stage_var is Resource):
				continue
			var stage: Resource = stage_var
			if bool(stage.get("is_completed")):
				continue
			if int(stage.get("objective_type")) == objective_type and str(stage.get("target_id")) == target_id:
				stage.set("is_completed", true)
				completed_stage_id = str(stage.get("stage_id"))
				progressed = true
				var s_xp: int = int(stage.get("xp_reward")) if "xp_reward" in stage else 0
				var s_cr: int = int(stage.get("credit_reward")) if "credit_reward" in stage else 0
				if ps != null:
					if s_xp > 0 and ps.has_method("add_xp"):
						ps.call("add_xp", s_xp)
					if s_cr > 0:
						ps.credits += s_cr
				break

		if progressed:
			# Update current_stage_index to next uncompleted required stage
			var next_idx: int = stages.size()
			for i in range(stages.size()):
				var st: Resource = stages[i]
				if st != null and not bool(st.get("is_completed")) and not bool(st.get("is_optional")):
					next_idx = i
					break
			quest.set("current_stage_index", next_idx)

			if bus != null:
				bus.quest_updated.emit(qid, completed_stage_id)
				bus.combat_log_entry.emit("Quest Objective Updated: %s" % completed_stage_id, "quest")

			var finished: bool = false
			if quest.has_method("is_finished"):
				finished = bool(quest.call("is_finished"))
			if finished:
				gs.active_quests.erase(qid)
				if not (qid in gs.completed_quests):
					gs.completed_quests.append(qid)
				var q_xp: int = int(quest.get("reward_xp")) if "reward_xp" in quest else 0
				var q_cr: int = int(quest.get("reward_credits")) if "reward_credits" in quest else 0
				if ps != null:
					if q_xp > 0 and ps.has_method("add_xp"):
						ps.call("add_xp", q_xp)
					if q_cr > 0:
						ps.credits += q_cr
				if bus != null:
					var q_title: String = str(quest.get("title")) if "title" in quest else qid
					bus.combat_log_entry.emit("Quest Completed: %s (+%d XP, +%d Cr)" % [q_title, q_xp, q_cr], "quest")


func _on_enemy_killed(enemy_id: String) -> void:
	advance_objective(QuestStage.ObjectiveType.KILL, enemy_id)


func _on_item_picked_up(item: Resource, _quantity: int) -> void:
	if item == null:
		return
	var item_id: String = str(item.get("id")) if "id" in item else ""
	if not item_id.is_empty():
		advance_objective(QuestStage.ObjectiveType.FETCH, item_id)


func _on_minigame_completed(target_id: String, success: bool, _bonus_data: Dictionary) -> void:
	if success:
		advance_objective(QuestStage.ObjectiveType.HACK, target_id)


func _on_dialogue_topic_visited(npc_id: String, _topic_id: String) -> void:
	advance_objective(QuestStage.ObjectiveType.TALK, npc_id)
