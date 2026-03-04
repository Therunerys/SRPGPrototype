# world_clock.gd
# Autoload singleton — the shared time system for the entire simulation.
# All time-dependent systems (need decay, aging, seasons) run off this.
# 1 real second = 1 game minute.

extends Node

# ─── CONFIGURATION ────────────────────────────────────────────────────────────

# How many real seconds equal one game minute.
# Change this to speed up or slow down time globally.
const REAL_SECONDS_PER_GAME_MINUTE: float = 1.0

const MINUTES_PER_HOUR: int = 60
const HOURS_PER_DAY: int = 24
const DAYS_PER_MONTH: int = 30
const MONTHS_PER_YEAR: int = 12

# ─── STATE ────────────────────────────────────────────────────────────────────

var minute: int = 0
var hour: int = 6        # World starts at 6am
var day: int = 1
var month: int = 1
var year: int = 1

# Accumulates real delta time until a game minute has passed.
var _tick_accumulator: float = 0.0

# Whether the clock is running. Can be paused (menus, cutscenes etc).
var is_running: bool = true

# ─── SIGNALS ──────────────────────────────────────────────────────────────────
# Systems subscribe to these instead of checking time every frame.
# Example: NeedDecaySystem connects to on_hour_passed to decay needs.

signal on_minute_passed
signal on_hour_passed
signal on_day_passed
signal on_month_passed
signal on_year_passed

# ─── PROCESS ──────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not is_running:
		return

	_tick_accumulator += delta

	# Each time enough real seconds pass, advance one game minute
	while _tick_accumulator >= REAL_SECONDS_PER_GAME_MINUTE:
		_tick_accumulator -= REAL_SECONDS_PER_GAME_MINUTE
		_advance_minute()

# ─── TIME ADVANCEMENT ─────────────────────────────────────────────────────────

func _advance_minute() -> void:
	minute += 1
	on_minute_passed.emit()

	if minute >= MINUTES_PER_HOUR:
		minute = 0
		_advance_hour()

func _advance_hour() -> void:
	hour += 1
	on_hour_passed.emit()

	if hour >= HOURS_PER_DAY:
		hour = 0
		_advance_day()

func _advance_day() -> void:
	day += 1
	on_day_passed.emit()

	if day > DAYS_PER_MONTH:
		day = 1
		_advance_month()

func _advance_month() -> void:
	month += 1
	on_month_passed.emit()

	if month > MONTHS_PER_YEAR:
		month = 1
		_advance_year()

func _advance_year() -> void:
	year += 1
	on_year_passed.emit()

# ─── UTILITIES ────────────────────────────────────────────────────────────────

# Returns the current season based on month.
# Spring: 3-5 | Summer: 6-8 | Autumn: 9-11 | Winter: 12, 1, 2
func get_season() -> String:
	match month:
		3, 4, 5:   return "Spring"
		6, 7, 8:   return "Summer"
		9, 10, 11: return "Autumn"
		_:         return "Winter"

# Returns a readable timestamp string. Useful for logs and debugging.
# Example: "Year 1, Month 3, Day 12 — 14:05"
func get_timestamp() -> String:
	return "Year %d, Month %d, Day %d — %02d:%02d" % [year, month, day, hour, minute]

# Pauses or resumes the clock.
func set_paused(paused: bool) -> void:
	is_running = not paused
