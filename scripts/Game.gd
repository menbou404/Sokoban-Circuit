extends Node2D

const CELL_SIZE := 48
const BOARD_ORIGIN := Vector2(32, 32)
const DIR_UP := Vector2i(0, -1)
const DIR_DOWN := Vector2i(0, 1)
const DIR_LEFT := Vector2i(-1, 0)
const DIR_RIGHT := Vector2i(1, 0)
const CARDINAL_DIRS := [DIR_UP, DIR_DOWN, DIR_LEFT, DIR_RIGHT]

const DEFAULT_LEVEL := [
	"#############",
	"#     L     #",
	"#     W     #",
	"# SWWW.WWWS #",
	"#     .     #",
	"#     A     #",
	"# O         #",
	"#     P     #",
	"#############",
]

var grid_width := 0
var grid_height := 0
var walls := {}
var wires := {}
var sources := {}
var lamps := {}
var powered_cells := {}
var blocks := []
var initial_blocks := []
var player_cell := Vector2i.ZERO
var initial_player_cell := Vector2i.ZERO
var move_count := 0
var is_clear := false
var circuit_iterations := 0
var circuit_warning := ""
var self_check_summary := ""


func _ready() -> void:
	self_check_summary = run_acceptance_self_checks()
	load_level(DEFAULT_LEVEL)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	var direction := Vector2i.ZERO
	match key_event.keycode:
		KEY_W, KEY_UP:
			direction = DIR_UP
		KEY_S, KEY_DOWN:
			direction = DIR_DOWN
		KEY_A, KEY_LEFT:
			direction = DIR_LEFT
		KEY_D, KEY_RIGHT:
			direction = DIR_RIGHT
		KEY_R:
			reset_level()
			get_viewport().set_input_as_handled()
			return

	if direction != Vector2i.ZERO:
		try_move_player(direction)
		get_viewport().set_input_as_handled()


func load_level(lines: Array) -> void:
	walls.clear()
	wires.clear()
	sources.clear()
	lamps.clear()
	powered_cells.clear()
	blocks.clear()
	initial_blocks.clear()
	player_cell = Vector2i.ZERO
	initial_player_cell = Vector2i.ZERO
	move_count = 0
	is_clear = false
	circuit_iterations = 0
	circuit_warning = ""

	grid_height = lines.size()
	grid_width = 0
	for line in lines:
		grid_width = max(grid_width, String(line).length())

	for y in range(grid_height):
		var line := String(lines[y])
		for x in range(grid_width):
			var cell := Vector2i(x, y)
			var symbol := " "
			if x < line.length():
				symbol = line.substr(x, 1)

			match symbol:
				"#":
					walls[cell] = true
				"S":
					sources[cell] = true
				"W":
					wires[cell] = true
				"L":
					lamps[cell] = true
				"P":
					player_cell = cell
					initial_player_cell = cell
				"A":
					blocks.append({"type": "AND", "cell": cell})
					initial_blocks.append({"type": "AND", "cell": cell})
				"O":
					blocks.append({"type": "OR", "cell": cell})
					initial_blocks.append({"type": "OR", "cell": cell})
				_:
					pass

	recalculate_signals()


func reset_level() -> void:
	player_cell = initial_player_cell
	blocks.clear()
	for block in initial_blocks:
		blocks.append({"type": block["type"], "cell": block["cell"]})

	move_count = 0
	is_clear = false
	recalculate_signals()
	queue_redraw()


func try_move_player(direction: Vector2i) -> bool:
	var target := player_cell + direction
	if not can_actor_enter(target):
		return false

	var block_index := get_block_index_at(target)
	if block_index != -1:
		var push_target := target + direction
		if not can_block_enter(push_target):
			return false

		blocks[block_index]["cell"] = push_target
		player_cell = target
	else:
		player_cell = target

	move_count += 1
	recalculate_signals()
	queue_redraw()
	return true


func can_actor_enter(cell: Vector2i) -> bool:
	return is_inside(cell) and not walls.has(cell)


func can_block_enter(cell: Vector2i) -> bool:
	return is_inside(cell) and not walls.has(cell) and get_block_index_at(cell) == -1


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_width and cell.y < grid_height


func get_block_index_at(cell: Vector2i) -> int:
	for index in range(blocks.size()):
		if blocks[index]["cell"] == cell:
			return index
	return -1


func recalculate_signals() -> void:
	powered_cells.clear()
	circuit_warning = ""
	circuit_iterations = 0

	for source_cell in sources.keys():
		powered_cells[source_cell] = true

	var max_iterations: int = max(1, grid_width * grid_height * 4)
	var changed := true
	while changed and circuit_iterations < max_iterations:
		changed = false
		circuit_iterations += 1

		if spread_power_to_wires_and_lamps():
			changed = true

		if evaluate_logic_blocks():
			changed = true

	if changed:
		circuit_warning = "Circuit iteration limit reached"
		print(circuit_warning)

	is_clear = false
	for lamp_cell in lamps.keys():
		if powered_cells.has(lamp_cell):
			is_clear = true
			break


func spread_power_to_wires_and_lamps() -> bool:
	var changed := false
	var current_powered := powered_cells.keys()
	for cell in current_powered:
		for direction in CARDINAL_DIRS:
			var neighbor = cell + direction
			if wires.has(neighbor) or lamps.has(neighbor):
				if set_powered(neighbor):
					changed = true
	return changed


func evaluate_logic_blocks() -> bool:
	var changed := false
	for block in blocks:
		var block_cell: Vector2i = block["cell"]
		var left_on := powered_cells.has(block_cell + DIR_LEFT)
		var right_on := powered_cells.has(block_cell + DIR_RIGHT)
		var should_output := false

		if block["type"] == "AND":
			should_output = left_on and right_on
		elif block["type"] == "OR":
			should_output = left_on or right_on

		if should_output:
			var output_cell := block_cell + DIR_UP
			if is_inside(output_cell) and not walls.has(output_cell):
				if set_powered(output_cell):
					changed = true
	return changed


func set_powered(cell: Vector2i) -> bool:
	if powered_cells.has(cell):
		return false
	powered_cells[cell] = true
	return true


func run_acceptance_self_checks() -> String:
	var results := []
	results.append(check_direct_wire_signal())
	results.append(check_and_outputs_only_with_both_inputs())
	results.append(check_or_outputs_with_either_input())
	results.append(check_default_level_movement_and_reset())

	for result in results:
		if not result["passed"]:
			print("Self check failed: " + result["name"])
			return "Self checks: FAIL"

	print("Self checks: PASS")
	return "Self checks: PASS"


func check_direct_wire_signal() -> Dictionary:
	load_level([
		"#####",
		"#SWL#",
		"#####",
	])
	return {"name": "source-wire-lamp", "passed": is_clear}


func check_and_outputs_only_with_both_inputs() -> Dictionary:
	load_level([
		"#######",
		"#  L  #",
		"#  W  #",
		"# SAS #",
		"#######",
	])
	var both_inputs_pass := is_clear

	load_level([
		"#######",
		"#  L  #",
		"#  W  #",
		"# SA  #",
		"#######",
	])
	var left_only_pass := not is_clear

	load_level([
		"#######",
		"#  L  #",
		"#  W  #",
		"#  AS #",
		"#######",
	])
	var right_only_pass := not is_clear

	return {
		"name": "AND truth table",
		"passed": both_inputs_pass and left_only_pass and right_only_pass,
	}


func check_or_outputs_with_either_input() -> Dictionary:
	load_level([
		"#######",
		"#  L  #",
		"#  W  #",
		"# SO  #",
		"#######",
	])
	var left_input_pass := is_clear

	load_level([
		"#######",
		"#  L  #",
		"#  W  #",
		"#  OS #",
		"#######",
	])
	var right_input_pass := is_clear

	load_level([
		"#######",
		"#  L  #",
		"#  W  #",
		"#  O  #",
		"#######",
	])
	var no_input_pass := not is_clear

	return {
		"name": "OR truth table",
		"passed": left_input_pass and right_input_pass and no_input_pass,
	}


func check_default_level_movement_and_reset() -> Dictionary:
	load_level(DEFAULT_LEVEL)
	var first_step := try_move_player(DIR_UP)
	var second_step := try_move_player(DIR_UP)
	var third_step := try_move_player(DIR_UP)
	var clear_after_push := is_clear
	reset_level()
	var reset_pass := player_cell == initial_player_cell and move_count == 0 and not is_clear

	return {
		"name": "movement-push-clear-reset",
		"passed": first_step and second_step and third_step and clear_after_push and reset_pass,
	}


func _draw() -> void:
	draw_board()
	draw_blocks()
	draw_player()
	draw_debug_panel()
	if is_clear:
		draw_clear_label()


func draw_board() -> void:
	for y in range(grid_height):
		for x in range(grid_width):
			var cell := Vector2i(x, y)
			var rect := cell_rect(cell)
			if walls.has(cell):
				draw_rect(rect, Color(0.35, 0.35, 0.37), true)
			else:
				draw_rect(rect, Color(0.10, 0.11, 0.13), true)

			if sources.has(cell):
				draw_rect(rect.grow(-5), Color(0.95, 0.78, 0.14), true)
				draw_cell_text(cell, "S", 20, Color(0.08, 0.08, 0.06))
			elif wires.has(cell):
				var wire_color := Color(0.95, 0.82, 0.18) if powered_cells.has(cell) else Color(0.34, 0.28, 0.08)
				draw_rect(rect.grow(-14), wire_color, true)
				draw_cell_text(cell, "W", 14, Color(0.05, 0.05, 0.04))
			elif lamps.has(cell):
				var lamp_color := Color(1.0, 0.18, 0.13) if powered_cells.has(cell) else Color(0.33, 0.05, 0.05)
				draw_circle(rect.position + rect.size * 0.5, CELL_SIZE * 0.30, lamp_color)
				draw_cell_text(cell, "L", 18, Color.WHITE)

			draw_rect(rect, Color(0.02, 0.02, 0.025), false, 1.0)


func draw_blocks() -> void:
	for block in blocks:
		var cell: Vector2i = block["cell"]
		var rect := cell_rect(cell).grow(-4)
		if block["type"] == "AND":
			draw_rect(rect, Color(0.18, 0.60, 0.30), true)
			draw_cell_text(cell, "AND", 16, Color.WHITE)
		else:
			draw_rect(rect, Color(0.48, 0.27, 0.78), true)
			draw_cell_text(cell, "OR", 18, Color.WHITE)


func draw_player() -> void:
	var rect := cell_rect(player_cell).grow(-8)
	draw_rect(rect, Color(0.12, 0.48, 0.88), true)
	draw_cell_text(player_cell, "P", 22, Color.WHITE)


func draw_debug_panel() -> void:
	var font := ThemeDB.fallback_font
	var font_size := 16
	var x := BOARD_ORIGIN.x
	var y := BOARD_ORIGIN.y + grid_height * CELL_SIZE + 28
	var lines := [
		"Moves: %d" % move_count,
		"Player: (%d, %d)" % [player_cell.x, player_cell.y],
		"Blocks: %d" % blocks.size(),
		"Powered cells: %d" % powered_cells.size(),
		"Clear: %s" % str(is_clear),
		self_check_summary,
		"R: reset / WASD or arrow keys: move",
	]
	if circuit_warning != "":
		lines.append(circuit_warning)

	for index in range(lines.size()):
		draw_string(font, Vector2(x, y + index * 20), lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.88, 0.90, 0.92))


func draw_clear_label() -> void:
	var font := ThemeDB.fallback_font
	var text := "CLEAR"
	var font_size := 56
	var board_width := grid_width * CELL_SIZE
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var position := BOARD_ORIGIN + Vector2((board_width - text_size.x) * 0.5, 42)
	draw_string(font, position + Vector2(3, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.65))
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.95, 0.25))


func draw_cell_text(cell: Vector2i, text: String, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var rect := cell_rect(cell)
	var y := rect.position.y + CELL_SIZE * 0.62
	draw_string(font, Vector2(rect.position.x, y), text, HORIZONTAL_ALIGNMENT_CENTER, CELL_SIZE, font_size, color)


func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(
		BOARD_ORIGIN + Vector2(cell.x * CELL_SIZE, cell.y * CELL_SIZE),
		Vector2(CELL_SIZE, CELL_SIZE)
	)
