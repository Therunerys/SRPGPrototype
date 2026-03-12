# debug_view.gd
# Standalone 2D debug scene for visualising the simulation.
# Shows Voronoi territories per region with organic noisy borders.
# Villages have tight territories surrounded by wilderness.
# Each wilderness region has a unique brown shade so borders are visible.
# Small info boxes float over each region showing name and NPC dots.
# Travelling NPCs appear as dots moving between regions.
# Click any NPC dot to inspect them in the side panel.
# Use the top bar to control simulation speed.

extends Node

# ─── LAYOUT CONSTANTS ─────────────────────────────────────────────────────────

const WORLD_PADDING:    float = 40.0   # Padding around world bounds
const REGION_PADDING:   float = 8.0    # Padding inside region info boxes
const NPC_DOT_RADIUS:   float = 4.0    # Radius of each NPC dot
const NPC_DOT_SPACING:  float = 11.0   # Grid spacing between dots in box
const PANEL_WIDTH:      float = 280.0  # Right info panel width
const TOPBAR_HEIGHT:    float = 40.0   # Top time control bar height
const FONT_SIZE_SMALL:  int   = 11
const FONT_SIZE_NORMAL: int   = 13
const FONT_SIZE_HEADER: int   = 15

# ─── VORONOI CONSTANTS ────────────────────────────────────────────────────────

# Resolution of the Voronoi image. Lower = faster, blockier. Higher = sharper.
const VORONOI_RESOLUTION: int = 300

# Village territory is capped by placing suppressor seeds around each village.
# These seeds are coloured as the nearest wilderness, shrinking the village zone.
const VILLAGE_TERRITORY_RADIUS: float = 60.0   # World units — tune to taste
const SUPPRESSOR_COUNT:         int   = 8       # Points evenly around village

# ─── COLORS ───────────────────────────────────────────────────────────────────

const COLOR_BG:             Color = Color(0.10, 0.11, 0.13)
const COLOR_PANEL_BG:       Color = Color(0.13, 0.14, 0.17)
const COLOR_TOPBAR_BG:      Color = Color(0.11, 0.12, 0.15)
const COLOR_REGION_BORDER:  Color = Color(0.30, 0.35, 0.45)
const COLOR_TEXT:           Color = Color(0.85, 0.87, 0.90)
const COLOR_TEXT_DIM:       Color = Color(0.50, 0.53, 0.58)
const COLOR_ACCENT:         Color = Color(0.40, 0.70, 0.55)
const COLOR_SEPARATOR:      Color = Color(0.25, 0.27, 0.32)

# Villages are always green. Wilderness colors are randomised per region.
const COLOR_REGION_VILLAGE: Color = Color(0.20, 0.35, 0.25, 0.85)

# Info box colors
const COLOR_BOX_BG:       Color = Color(0.13, 0.15, 0.18, 0.92)
const COLOR_BOX_BORDER_V: Color = Color(0.30, 0.55, 0.38)   # Village
const COLOR_BOX_BORDER_W: Color = Color(0.45, 0.38, 0.28)   # Wilderness

# NPC dot colors by state
const COLOR_NPC_OK:         Color = Color(0.35, 0.75, 0.45)
const COLOR_NPC_WARNING:    Color = Color(0.85, 0.70, 0.25)
const COLOR_NPC_CRITICAL:   Color = Color(0.85, 0.30, 0.25)
const COLOR_NPC_TRAVELLING: Color = Color(0.35, 0.55, 0.90)
const COLOR_NPC_SELECTED:   Color = Color(1.00, 1.00, 1.00)

# Need bar colors
const COLOR_BAR_HUNGER: Color = Color(0.85, 0.55, 0.25)
const COLOR_BAR_REST:   Color = Color(0.35, 0.55, 0.85)
const COLOR_BAR_SAFETY: Color = Color(0.55, 0.80, 0.45)
const COLOR_BAR_SOCIAL: Color = Color(0.75, 0.45, 0.85)
const COLOR_BAR_BG:     Color = Color(0.20, 0.22, 0.27)

# ─── STATE ────────────────────────────────────────────────────────────────────

var _selected_npc: NPCData = null
var _region_box_rects: Dictionary = {}   # region_id → Rect2 (info box in screen space)
var _npc_positions: Dictionary = {}      # npc_id → Vector2 (screen position)
var _region_colors: Dictionary = {}      # region_id → Color (unique per wilderness region)
var _world_area: Rect2
var _font: Font

# Voronoi background — generated once on world generation, reused every tick.
var _voronoi_texture: ImageTexture = null

# ─── NODES ────────────────────────────────────────────────────────────────────

var _canvas: Control
var _panel:  Control
var _topbar: Control

# ─── SETUP ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_font = ThemeDB.fallback_font

	RegionGenerator.generate_world(3, 5)

	var villages := RegionManager.get_regions_by_type(RegionData.Type.VILLAGE)
	if not villages.is_empty():
		NPCTravelSystem.set_player_position(villages[0].world_position)

	_build_ui()

	# Voronoi must be built after UI so canvas size is known
	_rebuild_voronoi()

	WorldClock.on_minute_passed.connect(_on_simulation_tick)
	
	# Force first draw immediately without waiting for the first tick
	_recalculate_layout()
	_canvas.queue_redraw()
	_panel.queue_redraw()
	_topbar.queue_redraw()

# ─── UI CONSTRUCTION ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	var screen := get_viewport().get_visible_rect()

	_topbar = Control.new()
	_topbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_topbar.custom_minimum_size = Vector2(0, TOPBAR_HEIGHT)
	add_child(_topbar)
	_topbar.draw.connect(_draw_topbar)
	_topbar.gui_input.connect(_on_topbar_input)
	_topbar.mouse_filter = Control.MOUSE_FILTER_STOP

	_canvas = Control.new()
	_canvas.position = Vector2(0, TOPBAR_HEIGHT)
	_canvas.size = Vector2(screen.size.x - PANEL_WIDTH, screen.size.y - TOPBAR_HEIGHT)
	add_child(_canvas)
	_canvas.draw.connect(_draw_world)
	_canvas.gui_input.connect(_on_canvas_input)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP

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

# ─── COORDINATE MAPPING ───────────────────────────────────────────────────────

func _world_to_screen(world_pos: Vector2) -> Vector2:
	var usable := _world_area.size - Vector2(WORLD_PADDING * 2, WORLD_PADDING * 2)
	var ratio   := usable / Vector2(1000.0, 1000.0)
	return Vector2(WORLD_PADDING, WORLD_PADDING) + world_pos * ratio

# ─── VORONOI GENERATION ───────────────────────────────────────────────────────

# Builds the Voronoi territory image. Called once after world generation.
# Two noise layers are combined for organic large-scale shapes with fine
# jagged detail on borders — similar to real geographic borders.
# Village territory is capped using suppressor seeds around each village.
func _rebuild_voronoi() -> void:
	var regions := RegionManager.get_all_regions()
	if regions.is_empty():
		return

	# ── Assign unique colors per region ───────────────────────────────────────
	_region_colors.clear()
	for region in regions:
		if region.region_type == RegionData.Type.VILLAGE:
			_region_colors[region.region_id] = COLOR_REGION_VILLAGE
		else:
			# Each wilderness region gets a distinct randomised brown shade
			var r: float = randf_range(0.20, 0.38)
			var g: float = randf_range(0.15, 0.25)
			var b: float = randf_range(0.10, 0.18)
			_region_colors[region.region_id] = Color(r, g, b, 0.85)

	# ── Build village suppressor points ───────────────────────────────────────
	# Suppressors are fake wilderness seeds placed in a ring around each village.
	# They inherit the color of the nearest wilderness region, effectively
	# capping the village Voronoi cell to a small area around its seed point.
	var suppressor_points: Array[Vector2] = []
	var suppressor_colors: Array[Color]   = []

	for region in regions:
		if region.region_type != RegionData.Type.VILLAGE:
			continue

		# Find nearest wilderness region to inherit its color
		var nearest_wild_color := COLOR_BG
		var nearest_dist := INF
		for other in regions:
			if other.region_type == RegionData.Type.WILDERNESS:
				var d: float = region.world_position.distance_to(other.world_position)
				if d < nearest_dist:
					nearest_dist = d
					nearest_wild_color = _region_colors.get(other.region_id, COLOR_BG)

		# Place suppressor seeds evenly around the village
		for s in SUPPRESSOR_COUNT:
			var angle: float = (TAU / SUPPRESSOR_COUNT) * s
			var offset := Vector2(cos(angle), sin(angle)) * VILLAGE_TERRITORY_RADIUS
			suppressor_points.append(region.world_position + offset)
			suppressor_colors.append(nearest_wild_color)

	# ── Set up layered noise ───────────────────────────────────────────────────
	# Layer 1: low frequency — large sweeping border shapes
	var noise1 := FastNoiseLite.new()
	noise1.seed = randi()
	noise1.frequency = 0.008

	# Layer 2: higher frequency — fine jagged detail on edges
	var noise2 := FastNoiseLite.new()
	noise2.seed = randi()
	noise2.frequency = 0.04

	# ── Generate pixels ───────────────────────────────────────────────────────
	var img := Image.create(VORONOI_RESOLUTION, VORONOI_RESOLUTION, false, Image.FORMAT_RGBA8)

	for py in VORONOI_RESOLUTION:
		for px in VORONOI_RESOLUTION:
			var nx: float = float(px) / float(VORONOI_RESOLUTION)
			var ny: float = float(py) / float(VORONOI_RESOLUTION)

			# Combine two noise layers for organic + jagged borders
			var offset_x: float = noise1.get_noise_2d(px, py) * 40.0 \
								+ noise2.get_noise_2d(px, py) * 12.0
			var offset_y: float = noise1.get_noise_2d(px + 500.0, py + 500.0) * 40.0 \
								+ noise2.get_noise_2d(px + 500.0, py + 500.0) * 12.0

			# Convert to simulation world space (0–1000)
			var world_x: float = nx * 1000.0 + offset_x
			var world_y: float = ny * 1000.0 + offset_y
			var world_pt := Vector2(world_x, world_y)

			# Find closest seed — check both regions and suppressors
			var closest_color := COLOR_BG
			var closest_dist  := INF

			for region in regions:
				var dist: float = world_pt.distance_to(region.world_position)
				if dist < closest_dist:
					closest_dist  = dist
					closest_color = _region_colors.get(region.region_id, COLOR_BG)

			for s in suppressor_points.size():
				var dist: float = world_pt.distance_to(suppressor_points[s])
				if dist < closest_dist:
					closest_dist  = dist
					closest_color = suppressor_colors[s]

			img.set_pixel(px, py, closest_color)

	_voronoi_texture = ImageTexture.create_from_image(img)

# ─── LAYOUT CALCULATION ───────────────────────────────────────────────────────

func _recalculate_layout() -> void:
	_region_box_rects.clear()
	_npc_positions.clear()

	var placed_boxes: Array[Rect2] = []

	for region in RegionManager.get_all_regions():
		var center := _world_to_screen(region.world_position)
		var pop: int = region.resident_ids.size()

		var cols: int = max(3, int(ceil(sqrt(float(pop)))))
		var rows: int = max(3, int(ceil(float(pop) / float(cols))))
		var box_w: float = REGION_PADDING * 2 + cols * NPC_DOT_SPACING + 30.0
		var box_h: float = REGION_PADDING * 2 + rows * NPC_DOT_SPACING + 22.0

		var rect := Rect2(center - Vector2(box_w, box_h) / 2.0, Vector2(box_w, box_h))

		# Nudge box away from any already placed boxes
		rect = _resolve_box_overlap(rect, placed_boxes)
		placed_boxes.append(rect)
		_region_box_rects[region.region_id] = rect

		# Place resident NPC dots in a grid inside the box
		var dot_start := rect.position + Vector2(REGION_PADDING, 22.0)
		var col := 0
		var row := 0
		for npc_id in region.resident_ids:
			var npc: NPCData = NPCManager.get_npc(npc_id)
			if npc == null:
				continue

			# Only interpolate position if travelling to a DIFFERENT region
			var is_inter_region_travel: bool = npc.location.is_travelling() and \
				npc.location.destination_region_id != npc.location.current_region_id

			if is_inter_region_travel:
				_npc_positions[npc_id] = _get_travel_position(npc)
				continue

			# All other NPCs — including same-region travellers — stay in the box grid
			var pos := dot_start + Vector2(
				col * NPC_DOT_SPACING + NPC_DOT_SPACING / 2.0,
				row * NPC_DOT_SPACING + NPC_DOT_SPACING / 2.0
			)
			_npc_positions[npc_id] = pos
			col += 1
			if col >= cols:
				col = 0
				row += 1

# Nudges a rect away from overlapping boxes by pushing in the least-overlap direction.
# Iterates up to MAX_ITERATIONS times until no overlap remains.
func _resolve_box_overlap(rect: Rect2, placed: Array[Rect2]) -> Rect2:
	const MARGIN: float       = 6.0
	const MAX_ITERATIONS: int = 10

	for i in MAX_ITERATIONS:
		var overlap_found := false
		for other in placed:
			if rect.intersects(other.grow(MARGIN)):
				var push := rect.get_center() - other.get_center()
				if push == Vector2.ZERO:
					push = Vector2(1.0, 0.0)
				rect.position += push.normalized() * (MARGIN + 2.0)
				overlap_found = true
				break
		if not overlap_found:
			break

	return rect

# Returns the interpolated screen position for a travelling NPC.
# Lerps between origin and destination region centers using travel_progress.
func _get_travel_position(npc: NPCData) -> Vector2:
	var origin_region := RegionManager.get_region(npc.location.current_region_id)
	var dest_poi      := POIManager.get_poi(npc.location.destination_poi_id)

	if origin_region == null or dest_poi == null:
		if origin_region != null:
			return _world_to_screen(origin_region.world_position)
		return Vector2.ZERO

	var dest_region := RegionManager.get_region(dest_poi.region_id)
	if dest_region == null:
		return _world_to_screen(origin_region.world_position)

	return _world_to_screen(origin_region.world_position).lerp(
		_world_to_screen(dest_region.world_position),
		npc.location.travel_progress
	)

# ─── DRAWING ──────────────────────────────────────────────────────────────────

func _draw_topbar() -> void:
	var w: float = _topbar.size.x
	var h: float = _topbar.size.y

	_topbar.draw_rect(Rect2(0, 0, w, h), COLOR_TOPBAR_BG)
	_topbar.draw_line(Vector2(0, h - 1), Vector2(w, h - 1), COLOR_SEPARATOR)

	_topbar.draw_string(_font, Vector2(12, h / 2.0 + 5),
		WorldClock.get_timestamp(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_NORMAL, COLOR_ACCENT)

	_topbar.draw_string(_font, Vector2(280, h / 2.0 + 5),
		"NPCs: %d" % NPCManager.get_npc_count(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_NORMAL, COLOR_TEXT_DIM)

	var speeds := ["|| Pause", "1x", "5x", "10x"]
	var x: float = w - 20.0
	for i in range(speeds.size() - 1, -1, -1):
		var label: String = speeds[i]
		var text_w: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_NORMAL).x
		var btn_w:  float = text_w + 16.0
		x -= btn_w + 6.0
		var is_active: bool = _get_active_speed_index() == i
		var btn_rect        := Rect2(x, 6, btn_w, h - 12)
		var btn_color       := COLOR_ACCENT if is_active else COLOR_REGION_BORDER
		_topbar.draw_rect(btn_rect, btn_color, false, 1.0)
		if is_active:
			_topbar.draw_rect(btn_rect.grow(-1), Color(COLOR_ACCENT, 0.15))
		_topbar.draw_string(_font, Vector2(x + 8, h / 2.0 + 5), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_NORMAL,
			COLOR_ACCENT if is_active else COLOR_TEXT_DIM)

func _draw_world() -> void:
	_canvas.draw_rect(_world_area, COLOR_BG)

	if _voronoi_texture != null:
		_canvas.draw_texture_rect(_voronoi_texture, _world_area, false)

	_recalculate_layout()

	for region in RegionManager.get_all_regions():
		_draw_region_box(region)

	_draw_all_npc_dots()

func _draw_region_box(region: RegionData) -> void:
	var rect: Rect2 = _region_box_rects.get(region.region_id, Rect2())
	if rect.size == Vector2.ZERO:
		return

	var is_village: bool = region.region_type == RegionData.Type.VILLAGE
	var border_col       := COLOR_BOX_BORDER_V if is_village else COLOR_BOX_BORDER_W

	_canvas.draw_rect(rect, COLOR_BOX_BG)
	_canvas.draw_rect(rect, border_col, false, 1.0)

	_canvas.draw_string(_font, rect.position + Vector2(6, 14),
		region.region_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SMALL, COLOR_TEXT)

	_canvas.draw_string(_font, rect.position + Vector2(rect.size.x - 20, 14),
		"%d" % region.resident_ids.size(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SMALL, COLOR_TEXT_DIM)

func _draw_all_npc_dots() -> void:
	for npc_id in _npc_positions:
		var pos: Vector2 = _npc_positions[npc_id]
		if pos == Vector2.ZERO:
			continue

		var npc: NPCData = NPCManager.get_npc(npc_id)
		if npc == null:
			continue

		var is_selected: bool = _selected_npc != null and _selected_npc.npc_id == npc_id
		var dot_color         := _get_npc_color(npc)

		if is_selected:
			_canvas.draw_circle(pos, NPC_DOT_RADIUS + 3.0, Color(COLOR_NPC_SELECTED, 0.4))
			_canvas.draw_arc(pos, NPC_DOT_RADIUS + 2.0, 0, TAU, 12, COLOR_NPC_SELECTED, 1.0)

		_canvas.draw_circle(pos, NPC_DOT_RADIUS, dot_color)

# ─── PANEL DRAWING ────────────────────────────────────────────────────────────

func _draw_panel() -> void:
	var w: float = _panel.size.x
	var h: float = _panel.size.y

	_panel.draw_rect(Rect2(0, 0, w, h), COLOR_PANEL_BG)
	_panel.draw_line(Vector2(0, 0), Vector2(0, h), COLOR_SEPARATOR)

	if _selected_npc == null:
		_panel.draw_string(_font, Vector2(w / 2.0 - 60, h / 2.0),
			"Click an NPC to inspect",
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_NORMAL, COLOR_TEXT_DIM)
		return

	var npc    := _selected_npc
	var y      := 16.0
	var line_h := 18.0

	_panel.draw_string(_font, Vector2(12, y), npc.full_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_HEADER, COLOR_TEXT)
	y += 20.0

	_panel.draw_string(_font, Vector2(12, y),
		"Age %d  ·  %s" % [npc.age, npc.profession.get_primary_name()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SMALL, COLOR_ACCENT)
	y += 6.0

	_draw_separator(y) ; y += 14.0

	_draw_section_header("LOCATION", y) ; y += 18.0
	var poi := POIManager.get_poi(npc.location.current_poi_id)
	var location_str: String = poi.poi_name if poi else "Travelling"
	if npc.location.is_travelling():
		location_str = "→ %.0f%%" % (npc.location.travel_progress * 100.0)
	_draw_label_value("At:",  location_str, y) ; y += line_h
	_draw_label_value("LOD:", NPCLocation.LODZone.keys()[npc.location.lod_zone], y) ; y += line_h

	_draw_separator(y) ; y += 14.0

	_draw_section_header("NEEDS", y) ; y += 18.0
	y = _draw_need_bar("Hunger", npc.need_hunger, COLOR_BAR_HUNGER, y)
	y = _draw_need_bar("Rest",   npc.need_rest,   COLOR_BAR_REST,   y)
	y = _draw_need_bar("Safety", npc.need_safety, COLOR_BAR_SAFETY, y)
	y = _draw_need_bar("Social", npc.need_social, COLOR_BAR_SOCIAL, y)

	_draw_label_value("Mood:", "%.2f %s" % [npc.mood, "↑" if npc.mood >= 0 else "↓"], y)
	y += line_h

	_draw_separator(y) ; y += 14.0

	_draw_section_header("TRAITS", y) ; y += 18.0
	y = _draw_trait_bar("Courage",    npc.trait_courage,    y)
	y = _draw_trait_bar("Greed",      npc.trait_greed,      y)
	y = _draw_trait_bar("Empathy",    npc.trait_empathy,    y)
	y = _draw_trait_bar("Aggression", npc.trait_aggression, y)
	y = _draw_trait_bar("Ambition",   npc.trait_ambition,   y)

	_draw_separator(y) ; y += 14.0

	_draw_section_header("INVENTORY", y) ; y += 18.0
	for item_str in npc.inventory.get_summary().split(", "):
		_panel.draw_string(_font, Vector2(12, y), item_str,
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SMALL, COLOR_TEXT)
		y += line_h

# ─── PANEL HELPERS ────────────────────────────────────────────────────────────

func _draw_separator(y: float) -> void:
	_panel.draw_line(Vector2(12, y), Vector2(_panel.size.x - 12, y), COLOR_SEPARATOR)

func _draw_section_header(text: String, y: float) -> void:
	_panel.draw_string(_font, Vector2(12, y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SMALL, COLOR_ACCENT)

func _draw_label_value(label: String, value: String, y: float) -> void:
	_panel.draw_string(_font, Vector2(12,  y), label,
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
	_panel.draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), COLOR_BAR_BG)
	_panel.draw_rect(Rect2(bar_x, bar_y, bar_w * value, bar_h), bar_color)
	_panel.draw_string(_font, Vector2(_panel.size.x - 36, y), "%.2f" % value,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SMALL, COLOR_TEXT_DIM)

	return y + 16.0

func _draw_trait_bar(label: String, value: float, y: float) -> float:
	var bar_x: float = 100.0
	var bar_w: float = _panel.size.x - bar_x - 40.0
	var bar_h: float = 6.0
	var bar_y: float = y - bar_h
	var mid_x: float = bar_x + bar_w / 2.0

	_panel.draw_string(_font, Vector2(12, y), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SMALL, COLOR_TEXT_DIM)
	_panel.draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), COLOR_BAR_BG)

	if value >= 0.0:
		_panel.draw_rect(Rect2(mid_x, bar_y, (bar_w / 2.0) * value, bar_h), COLOR_ACCENT)
	else:
		var fill_w: float = (bar_w / 2.0) * abs(value)
		_panel.draw_rect(Rect2(mid_x - fill_w, bar_y, fill_w, bar_h), COLOR_NPC_CRITICAL)

	_panel.draw_line(Vector2(mid_x, bar_y), Vector2(mid_x, bar_y + bar_h), COLOR_TEXT_DIM)
	_panel.draw_string(_font, Vector2(_panel.size.x - 36, y), "%.2f" % value,
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

	var best_id:   String = ""
	var best_dist: float  = NPC_DOT_RADIUS * 2.5

	for npc_id in _npc_positions:
		var dist: float = mb.position.distance_to(_npc_positions[npc_id])
		if dist < best_dist:
			best_dist = dist
			best_id   = npc_id

	_selected_npc = NPCManager.get_npc(best_id) if best_id != "" else null
	_panel.queue_redraw()
	_canvas.queue_redraw()

func _on_topbar_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return

	var speeds:       Array       = ["|| Pause", "1x", "5x", "10x"]
	var speed_values: Array       = [0.0, 1.0, 5.0, 10.0]
	var x: float                  = _topbar.size.x - 20.0
	var btn_rects: Array[Rect2]   = []

	for i in range(speeds.size() - 1, -1, -1):
		var text_w: float = _font.get_string_size(speeds[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_NORMAL).x
		var btn_w:  float = text_w + 16.0
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
		return 0
	match Engine.time_scale:
		1.0:  return 1
		5.0:  return 2
		10.0: return 3
	return 1
