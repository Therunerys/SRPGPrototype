# debug_view.gd
# Standalone 2D debug scene for visualising the simulation.
# Shows all regions as labelled boxes with NPC dots inside.
# Click any dot to inspect that NPC in the side panel.
# Use the top bar to control simulation speed.
# Set this scene as the main scene in Project Settings while debugging.

extends Node

# ─── LAYOUT CONSTANTS ─────────────────────────────────────────────────────────

const WORLD_PADDING:    float = 40.0   # Padding around world bounds
const REGION_PADDING:   float = 8.0    # Padding inside region boxes
const NPC_DOT_RADIUS:   float = 4.0    # Radius of each NPC dot
const NPC_DOT_SPACING:  float = 11.0   # Grid spacing between dots inside region
const PANEL_WIDTH:      float = 280.0  # Right info panel width
const TOPBAR_HEIGHT:    float = 40.0   # Top time control bar height
const FONT_SIZE_SMALL:  int   = 11
const FONT_SIZE_NORMAL: int   = 13
const FONT_SIZE_HEADER: int   = 15

# ─── COLORS ───────────────────────────────────────────────────────────────────

const COLOR_BG:             Color = Color(0.10, 0.11, 0.13)
const COLOR_PANEL_BG:       Color = Color(0.13, 0.14, 0.17)
const COLOR_TOPBAR_BG:      Color = Color(0.11, 0.12, 0.15)
const COLOR_REGION_BG:      Color = Color(0.16, 0.18, 0.22)
const COLOR_REGION_BORDER:  Color = Color(0.30, 0.35, 0.45)
const COLOR_REGION_VILLAGE: Color = Color(0.20, 0.35, 0.25)
const COLOR_REGION_WILD:    Color = Color(0.25, 0.22, 0.18)
const COLOR_TEXT:           Color = Color(0.85, 0.87, 0.90)
const COLOR_TEXT_DIM:       Color = Color(0.50, 0.53, 0.58)
const COLOR_ACCENT:         Color = Color(0.40, 0.70, 0.55)
const COLOR_SEPARATOR:      Color = Color(0.25, 0.27, 0.32)

# NPC dot colors by state
const COLOR_NPC_OK:         Color = Color(0.35, 0.75, 0.45)   # All needs fine
const COLOR_NPC_WARNING:    Color = Color(0.85, 0.70, 0.25)   # A need dropping
const COLOR_NPC_CRITICAL:   Color = Color(0.85, 0.30, 0.25)   # Critical need
const COLOR_NPC_TRAVELLING: Color = Color(0.35, 0.55, 0.90)   # In transit
const COLOR_NPC_SELECTED:   Color = Color(1.00, 1.00, 1.00)   # Selected NPC

# Need bar colors
const COLOR_BAR_HUNGER:  Color = Color(0.85, 0.55, 0.25)
const COLOR_BAR_REST:    Color = Color(0.35, 0.55, 0.85)
const COLOR_BAR_SAFETY:  Color = Color(0.55, 0.80, 0.45)
const COLOR_BAR_SOCIAL:  Color = Color(0.75, 0.45, 0.85)
const COLOR_BAR_BG:      Color = Color(0.20, 0.22, 0.27)

# ─── STATE ────────────────────────────────────────────────────────────────────

var _selected_npc: NPCData = null
var _region_rects: Dictionary = {}      # region_id → Rect2 in screen space
var _npc_positions: Dictionary = {}     # npc_id → Vector2 in screen space
var _world_area: Rect2                  # The drawable area excluding panel/topbar
var _font: Font

# ─── NODES ────────────────────────────────────────────────────────────────────

var _canvas: Control          # World view (left side)
var _panel: Control           # Info panel (right side)
var _topbar: Control          # Time controls (top)

# ─── SETUP ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_font = ThemeDB.fallback_font

	# Boot the simulation
	RegionGenerator.generate_world(3, 5)

	# Set player position to first village for LOD purposes
	var villages := RegionManager.get_regions_by_type(RegionData.Type.VILLAGE)
	if not villages.is_empty():
		NPCTravelSystem.set_player_position(villages[0].world_position)

	_build_ui()
	WorldClock.on_minute_passed.connect(_on_simulation_tick)

# ─── UI CONSTRUCTION ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	var screen := get_viewport().get_visible_rect()

	# ── Top bar ───────────────────────────────────────────────────────────────
	_topbar = Control.new()
	_topbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_topbar.custom_minimum_size = Vector2(0, TOPBAR_HEIGHT)
	add_child(_topbar)
	_topbar.draw.connect(_draw_topbar)
	_topbar.gui_input.connect(_on_topbar_input)
	_topbar.mouse_filter = Control.MOUSE_FILTER_STOP

	# ── World canvas ──────────────────────────────────────────────────────────
	_canvas = Control.new()
	_canvas.position = Vector2(0, TOPBAR_HEIGHT)
	_canvas.size = Vector2(screen.size.x - PANEL_WIDTH, screen.size.y - TOPBAR_HEIGHT)
	add_child(_canvas)
	_canvas.draw.connect(_draw_world)
	_canvas.gui_input.connect(_on_canvas_input)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP

	# ── Info panel ────────────────────────────────────────────────────────────
	_panel = Control.new()
	_panel.position = Vector2(screen.size.x - PANEL_WIDTH, TOPBAR_HEIGHT)
	_panel.size = Vector2(PANEL_WIDTH, screen.size.y - TOPBAR_HEIGHT)
	add_child(_panel)
	_panel.draw.connect(_draw_panel)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_world_area = Rect2(Vector2.ZERO, _canvas.size)

# ─── SIMULATION TICK ──────────────────────────────────────────────────────────

func _on_simulation_tick() -> void:
	_recalculate_layout()
	_canvas.queue_redraw()
	_panel.queue_redraw()
	_topbar.queue_redraw()

# ─── LAYOUT CALCULATION ───────────────────────────────────────────────────────

# Maps simulation world coordinates to screen coordinates.
# Simulation world is 1000x1000, canvas varies by window size.
func _world_to_screen(world_pos: Vector2) -> Vector2:
	var usable := _world_area.size - Vector2(WORLD_PADDING * 2, WORLD_PADDING * 2)
	var ratio := usable / Vector2(1000.0, 1000.0)
	return Vector2(WORLD_PADDING, WORLD_PADDING) + world_pos * ratio

func _recalculate_layout() -> void:
	_region_rects.clear()
	_npc_positions.clear()

	for region in RegionManager.get_all_regions():
		var center := _world_to_screen(region.world_position)
		var pop: int = region.resident_ids.size()

		# Size box based on population
		var cols: int = max(3, int(ceil(sqrt(float(pop)))))
		var rows: int = max(3, int(ceil(float(pop) / float(cols))))
		var box_w: float = REGION_PADDING * 2 + cols * NPC_DOT_SPACING + 30.0
		var box_h: float = REGION_PADDING * 2 + rows * NPC_DOT_SPACING + 22.0

		var rect := Rect2(center - Vector2(box_w, box_h) / 2.0, Vector2(box_w, box_h))
		_region_rects[region.region_id] = rect

		# Place NPC dots in a grid inside the box
		var dot_area_start := rect.position + Vector2(REGION_PADDING, 22.0)
		var col := 0
		var row := 0
		for npc_id in region.resident_ids:
			var pos := dot_area_start + Vector2(
				col * NPC_DOT_SPACING + NPC_DOT_SPACING / 2.0,
				row * NPC_DOT_SPACING + NPC_DOT_SPACING / 2.0
			)
			_npc_positions[npc_id] = pos
			col += 1
			if col >= cols:
				col = 0
				row += 1

# ─── DRAWING ──────────────────────────────────────────────────────────────────

func _draw_topbar() -> void:
	var w: float = _topbar.size.x
	var h: float = _topbar.size.y

	# Background
	_topbar.draw_rect(Rect2(0, 0, w, h), COLOR_TOPBAR_BG)
	_topbar.draw_line(Vector2(0, h - 1), Vector2(w, h - 1), COLOR_SEPARATOR)

	# Timestamp
	var ts: String = WorldClock.get_timestamp()
	_topbar.draw_string(_font, Vector2(12, h / 2.0 + 5), ts,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_NORMAL, COLOR_ACCENT)

	# NPC count
	var npc_label := "NPCs: %d" % NPCManager.get_npc_count()
	_topbar.draw_string(_font, Vector2(280, h / 2.0 + 5), npc_label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_NORMAL, COLOR_TEXT_DIM)

	# Speed buttons
	var speeds := ["|| Pause", "1x", "5x", "10x"]
	var x: float = w - 20.0
	for i in range(speeds.size() - 1, -1, -1):
		var label: String = speeds[i]
		var text_w: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_NORMAL).x
		var btn_w: float = text_w + 16.0
		x -= btn_w + 6.0
		var is_active := _get_active_speed_index() == i
		var btn_rect := Rect2(x, 6, btn_w, h - 12)
		var btn_color := COLOR_ACCENT if is_active else COLOR_REGION_BORDER
		_topbar.draw_rect(btn_rect, btn_color, false, 1.0)
		if is_active:
			_topbar.draw_rect(btn_rect.grow(-1), Color(COLOR_ACCENT, 0.15))
		var text_color := COLOR_ACCENT if is_active else COLOR_TEXT_DIM
		_topbar.draw_string(_font, Vector2(x + 8, h / 2.0 + 5), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_NORMAL, text_color)

func _draw_world() -> void:
	# Background
	_canvas.draw_rect(_world_area, COLOR_BG)

	_recalculate_layout()

	# Draw regions
	for region in RegionManager.get_all_regions():
		_draw_region(region)

func _draw_region(region: RegionData) -> void:
	var rect: Rect2 = _region_rects.get(region.region_id, Rect2())
	if rect.size == Vector2.ZERO:
		return

	var is_village := region.region_type == RegionData.Type.VILLAGE
	var bg_color := COLOR_REGION_VILLAGE if is_village else COLOR_REGION_WILD

	# Box background and border
	_canvas.draw_rect(rect, bg_color)
	_canvas.draw_rect(rect, COLOR_REGION_BORDER, false, 1.0)

	# Region name
	_canvas.draw_string(_font,
		rect.position + Vector2(6, 14),
		region.region_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SMALL,
		COLOR_TEXT
	)

	# Population count
	var pop_label := "%d" % region.resident_ids.size()
	_canvas.draw_string(_font,
		rect.position + Vector2(rect.size.x - 20, 14),
		pop_label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SMALL,
		COLOR_TEXT_DIM
	)

	# NPC dots
	for npc_id in region.resident_ids:
		var pos: Vector2 = _npc_positions.get(npc_id, Vector2.ZERO)
		if pos == Vector2.ZERO:
			continue
		var npc := NPCManager.get_npc(npc_id)
		if npc == null:
			continue

		var is_selected := _selected_npc != null and _selected_npc.npc_id == npc_id
		var dot_color := _get_npc_color(npc)

		if is_selected:
			# Outer ring for selected NPC
			_canvas.draw_circle(pos, NPC_DOT_RADIUS + 3.0, Color(COLOR_NPC_SELECTED, 0.4))
			_canvas.draw_arc(pos, NPC_DOT_RADIUS + 2.0, 0, TAU, 12, COLOR_NPC_SELECTED, 1.0)

		_canvas.draw_circle(pos, NPC_DOT_RADIUS, dot_color)

func _draw_panel() -> void:
	var w: float = _panel.size.x
	var h: float = _panel.size.y

	# Background and left border
	_panel.draw_rect(Rect2(0, 0, w, h), COLOR_PANEL_BG)
	_panel.draw_line(Vector2(0, 0), Vector2(0, h), COLOR_SEPARATOR)

	if _selected_npc == null:
		_panel.draw_string(_font, Vector2(w / 2.0 - 60, h / 2.0),
			"Click an NPC to inspect",
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_NORMAL, COLOR_TEXT_DIM)
		return

	var npc := _selected_npc
	var y: float = 16.0
	var x_label: float = 12.0
	var x_value: float = 110.0
	var line_h: float = 18.0

	# ── Header ────────────────────────────────────────────────────────────────
	_panel.draw_string(_font, Vector2(x_label, y), npc.full_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_HEADER, COLOR_TEXT)
	y += 20.0

	var subtitle := "Age %d  ·  %s" % [npc.age, npc.profession.get_primary_name()]
	_panel.draw_string(_font, Vector2(x_label, y), subtitle,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SMALL, COLOR_ACCENT)
	y += 6.0

	_draw_separator(y) ; y += 14.0

	# ── Needs ─────────────────────────────────────────────────────────────────
	_draw_section_header("NEEDS", y) ; y += 18.0

	y = _draw_need_bar("Hunger", npc.need_hunger, COLOR_BAR_HUNGER, y)
	y = _draw_need_bar("Rest",   npc.need_rest,   COLOR_BAR_REST,   y)
	y = _draw_need_bar("Safety", npc.need_safety, COLOR_BAR_SAFETY, y)
	y = _draw_need_bar("Social", npc.need_social, COLOR_BAR_SOCIAL, y)

	# Mood
	var mood_label := "%.2f %s" % [npc.mood, "↑" if npc.mood >= 0 else "↓"]
	var mood_color := COLOR_BAR_SAFETY if npc.mood >= 0 else COLOR_NPC_CRITICAL
	_panel.draw_string(_font, Vector2(x_label, y), "Mood",
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SMALL, COLOR_TEXT_DIM)
	_panel.draw_string(_font, Vector2(x_value, y), mood_label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SMALL, mood_color)
	y += line_h

	_draw_separator(y) ; y += 14.0

	# ── Current state ─────────────────────────────────────────────────────────
	_draw_section_header("CURRENT", y) ; y += 18.0

	var poi := POIManager.get_poi(npc.location.current_poi_id)
	var location_str: String
	if npc.location.is_travelling():
		var dest := POIManager.get_poi(npc.location.destination_poi_id)
		location_str = "→ %s" % (dest.poi_name if dest else "Unknown")
	else:
		location_str = poi.poi_name if poi else "Unknown"

	_draw_label_value("Location", location_str, y) ; y += line_h
	_draw_label_value("Job", npc.profession.get_current_job_name(), y) ; y += line_h
	_draw_label_value("Employed", "Yes" if npc.profession.is_employed else "No", y) ; y += line_h
	_draw_label_value("LOD", NPCLocation.LODZone.keys()[npc.location.lod_zone], y) ; y += line_h

	_draw_separator(y) ; y += 14.0

	# ── Traits ────────────────────────────────────────────────────────────────
	_draw_section_header("TRAITS", y) ; y += 18.0

	y = _draw_trait_bar("Courage",    npc.trait_courage,    y)
	y = _draw_trait_bar("Greed",      npc.trait_greed,      y)
	y = _draw_trait_bar("Empathy",    npc.trait_empathy,    y)
	y = _draw_trait_bar("Aggression", npc.trait_aggression, y)
	y = _draw_trait_bar("Ambition",   npc.trait_ambition,   y)

	_draw_separator(y) ; y += 14.0

	# ── Skills ────────────────────────────────────────────────────────────────
	_draw_section_header("SKILLS", y) ; y += 18.0

	var summary := npc.skills.get_summary()
	for skill_name in summary:
		var level_name: String = summary[skill_name]
		_draw_label_value(skill_name.capitalize(), level_name, y)
		y += line_h

	_draw_separator(y) ; y += 14.0

	# ── Inventory ─────────────────────────────────────────────────────────────
	_draw_section_header("INVENTORY", y) ; y += 18.0

	var inv_summary := npc.inventory.get_summary()
	# Split by comma and draw each item on its own line
	var inv_items := inv_summary.split(", ")
	for item_str in inv_items:
		_panel.draw_string(_font, Vector2(x_label, y), item_str,
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SMALL, COLOR_TEXT)
		y += line_h

# ─── PANEL DRAW HELPERS ───────────────────────────────────────────────────────

func _draw_separator(y: float) -> void:
	_panel.draw_line(Vector2(12, y), Vector2(_panel.size.x - 12, y), COLOR_SEPARATOR)

func _draw_section_header(text: String, y: float) -> void:
	_panel.draw_string(_font, Vector2(12, y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SMALL, COLOR_ACCENT)

func _draw_label_value(label: String, value: String, y: float) -> void:
	_panel.draw_string(_font, Vector2(12, y), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SMALL, COLOR_TEXT_DIM)
	_panel.draw_string(_font, Vector2(110, y), value,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SMALL, COLOR_TEXT)

func _draw_need_bar(label: String, value: float, bar_color: Color, y: float) -> float:
	var bar_x: float = 80.0
	var bar_w: float = _panel.size.x - bar_x - 40.0
	var bar_h: float = 8.0
	var bar_y: float = y - bar_h

	_panel.draw_string(_font, Vector2(12, y), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SMALL, COLOR_TEXT_DIM)

	# Background track
	_panel.draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), COLOR_BAR_BG)
	# Filled portion
	_panel.draw_rect(Rect2(bar_x, bar_y, bar_w * value, bar_h), bar_color)

	# Numeric value
	var val_str := "%.2f" % value
	_panel.draw_string(_font, Vector2(_panel.size.x - 36, y), val_str,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SMALL, COLOR_TEXT_DIM)

	return y + 16.0

func _draw_trait_bar(label: String, value: float, y: float) -> float:
	# Traits range -1 to 1. Centre line at mid-point of bar.
	var bar_x: float = 100.0
	var bar_w: float = _panel.size.x - bar_x - 40.0
	var bar_h: float = 6.0
	var bar_y: float = y - bar_h
	var mid_x: float = bar_x + bar_w / 2.0

	_panel.draw_string(_font, Vector2(12, y), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SMALL, COLOR_TEXT_DIM)

	# Background track
	_panel.draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), COLOR_BAR_BG)

	# Filled from centre outward
	if value >= 0:
		var fill_w: float = (bar_w / 2.0) * value
		_panel.draw_rect(Rect2(mid_x, bar_y, fill_w, bar_h), COLOR_ACCENT)
	else:
		var fill_w: float = (bar_w / 2.0) * abs(value)
		_panel.draw_rect(Rect2(mid_x - fill_w, bar_y, fill_w, bar_h), COLOR_NPC_CRITICAL)

	# Centre tick
	_panel.draw_line(Vector2(mid_x, bar_y), Vector2(mid_x, bar_y + bar_h), COLOR_TEXT_DIM)

	# Numeric value
	var val_str := "%.2f" % value
	_panel.draw_string(_font, Vector2(_panel.size.x - 36, y), val_str,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SMALL, COLOR_TEXT_DIM)

	return y + 15.0

# ─── NPC STATE COLOR ──────────────────────────────────────────────────────────

func _get_npc_color(npc: NPCData) -> Color:
	if npc.location.is_travelling():
		return COLOR_NPC_TRAVELLING
	var min_need := minf(npc.need_hunger, minf(npc.need_rest, minf(npc.need_safety, npc.need_social)))
	if min_need <= 0.25:
		return COLOR_NPC_CRITICAL
	if min_need <= 0.60:
		return COLOR_NPC_WARNING
	return COLOR_NPC_OK

# ─── INPUT ────────────────────────────────────────────────────────────────────

func _on_canvas_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return

	# Find nearest NPC dot to click position
	var click_pos := mb.position
	var best_id := ""
	var best_dist := NPC_DOT_RADIUS * 2.5   # Click tolerance

	for npc_id in _npc_positions:
		var dist: float = click_pos.distance_to(_npc_positions[npc_id])
		if dist < best_dist:
			best_dist = dist
			best_id = npc_id

	_selected_npc = NPCManager.get_npc(best_id) if best_id != "" else null
	_panel.queue_redraw()
	_canvas.queue_redraw()

func _on_topbar_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return

	# Recalculate button positions to find which was clicked
	var speeds := ["|| Pause", "1x", "5x", "10x"]
	var speed_values := [0.0, 1.0, 5.0, 10.0]
	var x: float = _topbar.size.x - 20.0

	# Build rects right-to-left (same order as drawing)
	var btn_rects: Array[Rect2] = []
	for i in range(speeds.size() - 1, -1, -1):
		var label: String = speeds[i]
		var text_w: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_NORMAL).x
		var btn_w: float = text_w + 16.0
		x -= btn_w + 6.0
		btn_rects.push_front(Rect2(x, 6, btn_w, TOPBAR_HEIGHT - 12))

	for i in btn_rects.size():
		if btn_rects[i].has_point(mb.position):
			_set_speed(speed_values[i])
			_topbar.queue_redraw()
			break

# ─── TIME CONTROL ─────────────────────────────────────────────────────────────

func _set_speed(multiplier: float) -> void:
	if multiplier == 0.0:
		WorldClock.set_paused(true)
	else:
		WorldClock.set_paused(false)
		Engine.time_scale = multiplier

func _get_active_speed_index() -> int:
	if not WorldClock.is_running:
		return 0   # Paused
	match Engine.time_scale:
		1.0: return 1
		5.0: return 2
		10.0: return 3
	return 1
