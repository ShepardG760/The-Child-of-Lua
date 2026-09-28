extends Control

const BG := Color("#080b13")
const PANEL := Color("#101827")
const PANEL_2 := Color("#151f31")
const LINE := Color("#26344b")
const TEXT := Color("#dce8f7")
const MUTED := Color("#7f91aa")
const CYAN := Color("#53d8d2")
const GOLD := Color("#f3bd67")
const RED := Color("#e57373")

var font: Font
var selected := 0
var hovered := -1
var mission_live := false
var mission_countdown := -1.0
var view_mode := "overview"
var selected_mission := 0
var unlocked_missions := 1
var completed_missions := {}
var chart_zoom := 0.34
var target_chart_zoom := 0.34
var moon_pan := Vector2.ZERO
var overview_handoff_pending := false
var left_pan_active := false
var left_pan_last := Vector2.ZERO
var moon_asset_container: SubViewportContainer
var moon_asset_camera: Camera3D
var pulse := 0.0
var toast := ""
var toast_time := 0.0

var worlds := [
    {"name": "LUA", "subtitle": "fractured moon", "pos": Vector2(0.34, 0.34), "color": Color("#62d1c8"), "level": "01 - 04", "nodes": 4, "state": "ONLINE"},
    {"name": "VIREL", "subtitle": "red desert", "pos": Vector2(0.56, 0.23), "color": Color("#ed9a67"), "level": "04 - 08", "nodes": 6, "state": "ONLINE"},
    {"name": "ORISON", "subtitle": "ice giant", "pos": Vector2(0.72, 0.47), "color": Color("#93bde1"), "level": "08 - 12", "nodes": 5, "state": "LOCKED"},
    {"name": "NADIR", "subtitle": "black ocean", "pos": Vector2(0.51, 0.67), "color": Color("#b78ce8"), "level": "12 - 16", "nodes": 8, "state": "LOCKED"},
    {"name": "KHEPRI", "subtitle": "sunken archive", "pos": Vector2(0.24, 0.72), "color": Color("#e6d17e"), "level": "16 - 20", "nodes": 3, "state": "LOCKED"}
]

func _ready() -> void:
    font = ThemeDB.fallback_font
    setup_moon_asset()
    queue_redraw()

func _process(delta: float) -> void:
    pulse += delta
    chart_zoom = lerpf(chart_zoom, target_chart_zoom, minf(delta * 7.0, 1.0))
    if moon_asset_container:
        update_moon_asset_transform()
    if mission_countdown > 0.0:
        mission_countdown -= delta
        if mission_countdown <= 0.0:
            mission_countdown = -1.0
            mission_live = true
            if not completed_missions.has(selected_mission):
                completed_missions[selected_mission] = true
            if selected_mission == unlocked_missions - 1 and unlocked_missions < 7:
                unlocked_missions += 1
            toast = "MISSION" + str(selected_mission + 1) + " // DROP CONFIRMED"
            toast_time = 2.8
    if toast_time > 0.0:
        toast_time -= delta
        if toast_time <= 0.0:
            toast = ""
    queue_redraw()

func _draw() -> void:
    var size := get_viewport_rect().size
    draw_rect(Rect2(Vector2.ZERO, size), Color(BG, 0.72))
    draw_background(size)
    draw_header(size)
    draw_sidebar(size)
    draw_chart(size)
    draw_footer(size)
    if toast != "":
        draw_toast(size)

func setup_moon_asset() -> void:
    var asset_scene := load("res://blender/lua_moon.glb") as PackedScene
    if not asset_scene:
        return
    moon_asset_container = SubViewportContainer.new()
    moon_asset_container.name = "LuaMoonAssetLayer"
    moon_asset_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
    moon_asset_container.size = Vector2(1536, 864)
    moon_asset_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
    moon_asset_container.show_behind_parent = true
    moon_asset_container.z_index = -1
    moon_asset_container.visible = true
    add_child(moon_asset_container)
    var viewport := SubViewport.new()
    viewport.name = "LuaMoonViewport"
    viewport.size = Vector2i(1536, 864)
    viewport.transparent_bg = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    moon_asset_container.add_child(viewport)
    var asset := asset_scene.instantiate()
    viewport.add_child(asset)
    moon_asset_camera = find_moon_camera(asset)
    if not moon_asset_camera:
        moon_asset_camera = Camera3D.new()
        moon_asset_camera.name = "Generated Lua camera"
        viewport.add_child(moon_asset_camera)
        moon_asset_camera.position = Vector3(0.0, -8.5, 0.4)
        moon_asset_camera.look_at(Vector3.ZERO, Vector3.UP)
    if not find_moon_light(asset):
        var light := DirectionalLight3D.new()
        light.name = "Generated Lua sunlight"
        light.rotation_degrees = Vector3(-28.0, -24.0, -38.0)
        light.light_energy = 1.4
        viewport.add_child(light)
    if moon_asset_camera:
        moon_asset_camera.current = true
        moon_asset_camera.far = 1000.0

func find_moon_light(node: Node) -> DirectionalLight3D:
    if node is DirectionalLight3D:
        return node as DirectionalLight3D
    for child in node.get_children():
        var light := find_moon_light(child)
        if light:
            return light
    return null

func update_moon_asset_transform() -> void:
    if not moon_asset_container or not moon_asset_camera:
        return
    var size := get_viewport_rect().size
    var focus := clampf(inverse_lerp(0.34, 1.0, chart_zoom), 0.0, 1.0)
    var body_scale := lerpf(0.14, chart_zoom, focus)
    var lua_point := get_lua_screen_point(size)
    var viewport_size := Vector2(1536, 864)
    moon_asset_container.position = lua_point - viewport_size * 0.5
    moon_asset_container.visible = true
    var camera_distance := 8.5 / maxf(body_scale, 0.08)
    moon_asset_camera.position = Vector3(0.0, -camera_distance, camera_distance * 0.047)
    moon_asset_camera.look_at(Vector3.ZERO, Vector3.UP)

func find_moon_camera(node: Node) -> Camera3D:
    if node is Camera3D:
        return node as Camera3D
    for child in node.get_children():
        var camera := find_moon_camera(child)
        if camera:
            return camera
    return null

func draw_background(size: Vector2) -> void:
    for i in range(18):
        var x := fmod(float(i * 137 + 41), size.x)
        var y := fmod(float(i * 83 + 29), size.y)
        var a := 0.22 + 0.12 * sin(pulse * 0.8 + i)
        draw_circle(Vector2(x, y), 1.5 if i % 3 else 2.5, Color(0.45, 0.65, 0.78, a))
    draw_circle(Vector2(size.x * 0.57, size.y * 0.43), 260.0, Color(0.06, 0.14, 0.20, 0.19))
    draw_circle(Vector2(size.x * 0.57, size.y * 0.43), 150.0, Color(0.04, 0.20, 0.22, 0.13))

func draw_header(size: Vector2) -> void:
    draw_rect(Rect2(0, 0, size.x, 72), Color("#0c121e"))
    draw_line(Vector2(0, 71), Vector2(size.x, 71), LINE, 1)
    draw_string(font, Vector2(30, 31), "A S T R A L   C H A R T", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT)
    draw_string(font, Vector2(30, 52), "NAVIGATION / SYSTEMS ONLINE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MUTED)
    draw_string(font, Vector2(size.x - 250, 31), "OPERATIVE  //  LUMEN-07", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT)
    draw_circle(Vector2(size.x - 268, 27), 4, CYAN)
    draw_string(font, Vector2(size.x - 250, 51), "RANK 04     1,280 CREDITS", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, GOLD)

func draw_sidebar(size: Vector2) -> void:
    var rect := Rect2(22, 95, 238, size.y - 150)
    draw_rect(rect, PANEL, true)
    draw_rect(rect, LINE, false, 1)
    draw_string(font, Vector2(42, 127), "CURRENT LOADOUT", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
    draw_string(font, Vector2(42, 161), "NOMAD FRAME", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, TEXT)
    draw_string(font, Vector2(42, 182), "adaptive exoshell / v.4", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, CYAN)
    draw_rect(Rect2(42, 205, 198, 90), Color("#0b111c"), true)
    draw_circle(Vector2(141, 247), 29, Color("#1d4150"))
    draw_circle(Vector2(141, 247), 20, Color("#182b3e"))
    draw_line(Vector2(123, 252), Vector2(159, 252), CYAN, 2)
    draw_line(Vector2(132, 230), Vector2(125, 267), Color("#7fe3db"), 2)
    draw_line(Vector2(150, 230), Vector2(157, 267), Color("#7fe3db"), 2)
    draw_string(font, Vector2(42, 326), "VITALITY", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MUTED)
    draw_stat_bar(Vector2(42, 339), 198, 0.82, CYAN, "820 / 1000")
    draw_string(font, Vector2(42, 374), "SHIELD", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MUTED)
    draw_stat_bar(Vector2(42, 387), 198, 0.64, Color("#81aef2"), "640 / 1000")
    draw_line(Vector2(42, 422), Vector2(240, 422), LINE, 1)
    draw_string(font, Vector2(42, 452), "SYSTEM STATUS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
    draw_string(font, Vector2(42, 483), "+  RELAY LINK", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT)
    draw_string(font, Vector2(190, 483), "STABLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, CYAN)
    draw_string(font, Vector2(42, 511), "+  SIGNAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT)
    draw_string(font, Vector2(190, 511), "SYNCED", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, CYAN)
    draw_string(font, Vector2(42, 539), "+  ALERTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT)
    draw_string(font, Vector2(190, 539), "02", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, GOLD)

func draw_stat_bar(pos: Vector2, width: float, amount: float, color: Color, label: String) -> void:
    draw_rect(Rect2(pos, Vector2(width, 5)), Color("#263247"), true)
    draw_rect(Rect2(pos, Vector2(width * amount, 5)), color, true)
    draw_string(font, pos + Vector2(0, 22), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, TEXT)

func draw_chart(size: Vector2) -> void:
    var origin := Vector2(290, 96)
    var chart_size := Vector2(size.x - 320, size.y - 165)
    var focus := clampf(inverse_lerp(0.34, 1.0, chart_zoom), 0.0, 1.0)
    var focal_point := get_moon_center(size)
    draw_string(font, origin + Vector2(24, 27), "SECTOR 01", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
    draw_string(font, origin + Vector2(24, 55), "THE QUIET EXPANSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, TEXT)
    draw_string(font, origin + Vector2(24, 77), "Five known systems / begin at Lua", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
    draw_system_sun(get_sun_screen_point(size))
    var points: Array[Vector2] = []
    for world in worlds:
        var overview_point := origin + Vector2(chart_size.x * world.pos.x, chart_size.y * world.pos.y) + Vector2(0, 42)
        var lua_point := origin + Vector2(chart_size.x * worlds[0].pos.x, chart_size.y * worlds[0].pos.y) + Vector2(0, 42)
        var focused_point := focal_point + (overview_point - lua_point) * lerpf(1.0, 5.0, focus)
        points.append(overview_point.lerp(focused_point, focus))
    for i in range(points.size() - 1):
        draw_dashed_line(points[i], points[i + 1], Color(0.24, 0.46, 0.56, 0.55), 1, 7, 5)
    draw_line(points[0], points[2], Color(0.24, 0.46, 0.56, 0.25), 1)
    for i in range(worlds.size()):
        if i != 0 or not moon_asset_container:
            draw_planet(worlds[i], points[i], i)
    if focus >= 0.12:
        var body_scale := lerpf(0.14, chart_zoom, focus)
        var lua_screen_point := points[0]
        if not moon_asset_container or not moon_asset_container.visible:
            draw_moon_body(lua_screen_point, body_scale)
        draw_string(font, lua_screen_point + Vector2(-24, 8), "LUA", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#edf3f2"))
        draw_mission_web(lua_screen_point, lerpf(0.14, chart_zoom, focus))
        if mission_countdown > 0.0 or mission_live:
            draw_mission_timer(lua_screen_point, body_scale)
    if focus > 0.7:
        draw_mission_panel(size)
    draw_string(font, origin + Vector2(24, chart_size.y + 34), "WHEEL: ZOOM   LEFT DRAG: PAN", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MUTED)

func get_sun_screen_point(size: Vector2) -> Vector2:
    var origin := Vector2(290, 96)
    var chart_size := Vector2(size.x - 320, size.y - 165)
    var lua_overview := origin + Vector2(chart_size.x * worlds[0].pos.x, chart_size.y * worlds[0].pos.y) + Vector2(0, 42)
    var sun_overview := Vector2(size.x * 0.57, size.y * 0.43)
    var focus := clampf(inverse_lerp(0.34, 1.0, chart_zoom), 0.0, 1.0)
    var focused_sun := get_moon_center(size) + (sun_overview - lua_overview) * lerpf(1.0, 5.0, focus)
    return sun_overview.lerp(focused_sun, focus)

func draw_system_sun(center: Vector2) -> void:
    var breathe := 1.0 + sin(pulse * 0.7) * 0.035
    for glow in range(9, 0, -1):
        var glow_radius := float(glow) * 30.0 * breathe
        var glow_alpha := 0.008 + float(9 - glow) * 0.006
        draw_circle(center, glow_radius, Color(0.10, 0.52, 1.0, glow_alpha))
    draw_arc(center, 78.0 * breathe, pulse * 0.08, TAU + pulse * 0.08, 64, Color(0.15, 0.61, 1.0, 0.20), 1.0)
    draw_arc(center, 58.0 * breathe, -pulse * 0.06, TAU - pulse * 0.06, 64, Color(0.32, 0.78, 1.0, 0.26), 1.2)
    for ray in range(10):
        var angle := float(ray) * TAU / 10.0 + pulse * 0.018
        var inner := center + Vector2(cos(angle), sin(angle)) * 20.0
        var outer := center + Vector2(cos(angle), sin(angle)) * (42.0 + float(ray % 3) * 8.0) * breathe
        draw_line(inner, outer, Color(0.22, 0.68, 1.0, 0.13), 1.0)
    draw_circle(center, 18.0 * breathe, Color(0.12, 0.49, 0.90, 0.18))
    draw_circle(center, 7.0 * breathe, Color(0.62, 0.90, 1.0, 0.58))

func draw_mission_timer(center: Vector2, body_scale: float) -> void:
    var timer_text := str(ceil(mission_countdown)) if mission_countdown > 0.0 else "GO"
    var timer_color := GOLD if mission_countdown > 0.0 else CYAN
    var timer_radius := 34.0 * maxf(body_scale, 0.5)
    draw_circle(center, timer_radius, Color(0.02, 0.06, 0.09, 0.88))
    draw_arc(center, timer_radius, -PI * 0.5, TAU * (1.0 - maxf(mission_countdown, 0.0) / 5.0) - PI * 0.5, 40, timer_color, 4.0)
    draw_string(font, center + Vector2(-12 if timer_text.length() == 1 else -17, 7), timer_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, timer_color)

func draw_moon_map(size: Vector2) -> void:
    var center := get_moon_center(size)
    draw_string(font, Vector2(310, 123), "LUA / ORBITAL MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
    draw_string(font, Vector2(310, 153), "THE PALE ARCHIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, TEXT)
    draw_string(font, Vector2(310, 176), "Select a mission node to inspect its route", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
    draw_moon_body(center, chart_zoom)
    draw_string(font, center + Vector2(-24, 8), "LUA", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#edf3f2"))
    var mission_points := get_mission_points(center, chart_zoom)
    for i in range(mission_points.size() - 1):
        draw_dashed_line(mission_points[i], mission_points[i + 1], Color(0.43, 0.70, 0.71, 0.72), 2.5, 8, 5)
    for i in range(mission_points.size()):
        draw_mission_node(mission_points[i], i)
    draw_mission_panel(size)
    draw_string(font, Vector2(310, size.y - 93), "WHEEL: ZOOM   [ESC] RETURN TO SECTOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MUTED)

func get_moon_center(size: Vector2) -> Vector2:
    return Vector2(size.x * 0.64, size.y * 0.52) + moon_pan

func get_lua_screen_point(size: Vector2) -> Vector2:
    var origin := Vector2(290, 96)
    var chart_size := Vector2(size.x - 320, size.y - 165)
    var lua_point := origin + Vector2(chart_size.x * worlds[0].pos.x, chart_size.y * worlds[0].pos.y) + Vector2(0, 42)
    var focus := clampf(inverse_lerp(0.34, 1.0, chart_zoom), 0.0, 1.0)
    return lua_point.lerp(get_moon_center(size), focus)

func draw_moon_body(center: Vector2, body_scale: float) -> void:
    var radius := 150.0 * body_scale
    var light_direction := Vector2(-0.34, -0.42)
    draw_circle(center + Vector2(8, 12) * body_scale, radius + 5.0 * body_scale, Color(0.01, 0.02, 0.04, 0.75))
    draw_circle(center, radius, Color("#596171"))
    draw_circle(center + light_direction * 20.0 * body_scale, radius * 0.96, Color("#737b89"))
    draw_circle(center + Vector2(34, 42) * body_scale, radius * 0.82, Color(0.12, 0.15, 0.20, 0.28))
    var surface_dots := [
        Vector2(-0.63, -0.18), Vector2(-0.48, 0.42), Vector2(-0.24, -0.54), Vector2(0.12, -0.72),
        Vector2(0.38, -0.36), Vector2(0.56, 0.12), Vector2(0.42, 0.55), Vector2(-0.08, 0.68),
        Vector2(-0.76, 0.18), Vector2(0.72, -0.28), Vector2(-0.18, 0.08), Vector2(0.18, 0.30)
    ]
    for i in range(surface_dots.size()):
        var dot: Vector2 = center + surface_dots[i] * radius
        var dot_radius := (2.0 + float((i * 7) % 5)) * body_scale
        draw_circle(dot, dot_radius, Color(0.24, 0.27, 0.32, 0.22))
    var craters := [
        {"p": Vector2(-0.46, -0.30), "r": 0.13}, {"p": Vector2(-0.08, -0.50), "r": 0.09},
        {"p": Vector2(0.30, -0.28), "r": 0.16}, {"p": Vector2(0.52, 0.20), "r": 0.10},
        {"p": Vector2(0.18, 0.48), "r": 0.14}, {"p": Vector2(-0.34, 0.52), "r": 0.08},
        {"p": Vector2(-0.66, 0.12), "r": 0.07}, {"p": Vector2(0.02, 0.12), "r": 0.055}
    ]
    for crater in craters:
        var crater_pos: Vector2 = center + crater.p * radius
        var crater_radius: float = crater.r * radius
        var rim_offset := Vector2(-0.20, -0.24) * crater_radius
        draw_circle(crater_pos + rim_offset, crater_radius * 1.12, Color(0.79, 0.82, 0.85, 0.24))
        draw_circle(crater_pos + Vector2(0.14, 0.18) * crater_radius, crater_radius, Color(0.16, 0.19, 0.24, 0.72))
        draw_circle(crater_pos + Vector2(-0.10, -0.12) * crater_radius, crater_radius * 0.68, Color(0.32, 0.35, 0.40, 0.55))
        draw_arc(crater_pos + rim_offset, crater_radius * 1.12, 0.15, PI * 1.25, 16, Color(0.86, 0.88, 0.90, 0.40), maxf(body_scale, 1.0))
    draw_arc(center, radius, 0.25, PI * 1.55, 64, Color("#d6dbe0"), 2.5 * body_scale)
    draw_arc(center, radius, PI * 1.55, TAU - 0.25, 64, Color(0.05, 0.07, 0.10, 0.70), 4.0 * body_scale)

func draw_mission_web(center: Vector2, web_scale: float) -> void:
    var mission_points := get_mission_points(center, web_scale)
    for i in range(mission_points.size() - 1):
        draw_dashed_line(mission_points[i], mission_points[i + 1], Color(0.43, 0.70, 0.71, 0.72), 2.5 * web_scale, 8, 5)
    for i in range(mission_points.size()):
        if web_scale > 0.35:
            draw_mission_node(mission_points[i], i)

func get_mission_points(center: Vector2, web_scale: float = 1.0) -> Array[Vector2]:
    var local_points := [Vector2(-104, 24), Vector2(-68, -92), Vector2(8, -120), Vector2(82, -62), Vector2(102, 30), Vector2(45, 100), Vector2(-54, 82)]
    var points: Array[Vector2] = []
    for point in local_points:
        points.append(center + point * web_scale)
    return points

func draw_mission_node(pos: Vector2, index: int) -> void:
    var active := index == selected_mission
    var available := index < unlocked_missions
    var node_color := GOLD if active else CYAN
    if not available:
        node_color = Color("#4a5565")
    if active:
        draw_arc(pos, 25.0 + sin(pulse * 2.0) * 2.0, 0, TAU, 40, Color(node_color, 0.65), 2.0)
    draw_circle(pos, 14.0 if available else 11.0, Color("#0d1720"))
    draw_circle(pos, 9.0 if available else 6.0, node_color)
    var label_color := TEXT if available else MUTED
    draw_string(font, pos + Vector2(20, 5), "Mission" + str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, label_color)
    draw_string(font, pos + Vector2(20, 21), "AVAILABLE" if available else "LOCKED", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, node_color)

func draw_mission_panel(size: Vector2) -> void:
    var panel := Rect2(size.x - 285, 112, 245, 165)
    draw_rect(panel, PANEL, true)
    draw_rect(panel, Color("#3b5367"), false, 1)
    var available := selected_mission < unlocked_missions
    draw_string(font, panel.position + Vector2(18, 28), "MISSION" + str(selected_mission + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, TEXT)
    draw_string(font, panel.position + Vector2(18, 49), "LUA / ARCHIVE RIM", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, CYAN)
    draw_string(font, panel.position + Vector2(18, 78), "LEVEL 01 - 04", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
    draw_string(font, panel.position + Vector2(18, 99), "SECURITY: LOW", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
    draw_string(font, panel.position + Vector2(18, 120), "REWARD: 320 CREDITS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GOLD)
    var status := "ROUTE LOCKED"
    var status_color := MUTED
    if available:
        status = "MATCHMAKING IN " + str(ceil(mission_countdown)) if mission_countdown > 0.0 else "CLICK NODE TO BEGIN"
        status_color = GOLD if mission_countdown <= 0.0 else CYAN
    draw_string(font, panel.position + Vector2(18, 150), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, status_color)

func draw_planet(world: Dictionary, pos: Vector2, index: int) -> void:
    var active := index == selected
    var locked: bool = world.state == "LOCKED"
    var radius := 13.0 if not active else 18.0
    if active:
        draw_arc(pos, 29.0 + sin(pulse * 2.0) * 2.0, 0, TAU, 40, Color(world.color, 0.48), 1.5)
        draw_arc(pos, 23.0, 0, TAU, 40, Color(world.color, 0.28), 1)
    if locked:
        draw_circle(pos, radius + 4, Color("#202838"))
        draw_circle(pos, radius, Color("#30394b"))
        draw_string(font, pos + Vector2(-4, 5), "x", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
    else:
        draw_circle(pos + Vector2(2, 3), radius + 2, Color(0.01, 0.02, 0.04, 0.75))
        draw_circle(pos, radius, Color(world.color, 0.72))
        draw_circle(pos - Vector2(radius * 0.25, radius * 0.28), radius * 0.76, Color(world.color, 0.92))
        draw_circle(pos - Vector2(radius * 0.34, radius * 0.38), radius * 0.22, Color(1, 1, 1, 0.34))
        draw_arc(pos, radius * 0.96, 0.2, PI * 1.45, 24, Color(0.04, 0.06, 0.09, 0.56), 1.5)
        for detail in range(3):
            var detail_pos: Vector2 = pos + Vector2(cos(float(detail) * 2.1), sin(float(detail) * 2.1)) * radius * 0.42
            draw_circle(detail_pos, radius * 0.12, Color(0.08, 0.11, 0.14, 0.22))
    var label_pos := pos + Vector2(27, 5)
    draw_string(font, label_pos, world.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TEXT if not locked else MUTED)
    draw_string(font, label_pos + Vector2(0, 17), world.subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MUTED)

func draw_footer(size: Vector2) -> void:
    var y := size.y - 55
    draw_line(Vector2(22, y), Vector2(size.x - 22, y), LINE, 1)
    draw_string(font, Vector2(30, y + 31), "[TAB] LOADOUT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MUTED)
    draw_string(font, Vector2(153, y + 31), "[M] MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, CYAN)
    draw_string(font, Vector2(260, y + 31), "[ESC] BACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MUTED)
    if view_mode != "overview" and mission_live:
        draw_string(font, Vector2(size.x - 240, y + 31), "MISSION IN PROGRESS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, CYAN)

func draw_toast(size: Vector2) -> void:
    var width := 310.0
    var pos := Vector2(size.x - width - 28, 90)
    draw_rect(Rect2(pos, Vector2(width, 44)), Color("#1a2e37"), true)
    draw_rect(Rect2(pos, Vector2(3, 44)), CYAN, true)
    draw_string(font, pos + Vector2(18, 27), toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT)

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        hovered = get_mission_at(event.position) if view_mode != "overview" else get_world_at(event.position)
        queue_redraw()
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if view_mode != "overview" or chart_zoom > 0.45:
            handle_moon_click(event.position)
            return
        var index := get_world_at(event.position)
        if index >= 0:
            selected = index
            var world: Dictionary = worlds[selected]
            if world.state == "LOCKED":
                toast = "ROUTE LOCKED // COMPLETE PRIOR SYSTEMS"
                toast_time = 2.8
            else:
                mission_live = false
                toast = world.name + " // SYSTEM SELECTED"
                toast_time = 1.8
                if selected == 0:
                    view_mode = "moon"
                    selected_mission = 0
                    chart_zoom = 0.34
                    target_chart_zoom = 1.0
                    moon_pan = Vector2.ZERO
                    toast = "LUA // ORBITAL MAP OPEN"
            queue_redraw()

func get_world_at(mouse_pos: Vector2) -> int:
    var size := get_viewport_rect().size
    var origin := Vector2(290, 96)
    var chart_size := Vector2(size.x - 320, size.y - 165)
    for i in range(worlds.size()):
        var world: Dictionary = worlds[i]
        var pos := origin + Vector2(chart_size.x * world.pos.x, chart_size.y * world.pos.y) + Vector2(0, 42)
        if mouse_pos.distance_to(pos) < 34.0:
            return i
    return -1

func handle_moon_click(mouse_pos: Vector2) -> void:
    var size := get_viewport_rect().size
    var center := get_moon_center(size)
    var mission_index := get_mission_at(mouse_pos)
    if mission_index >= 0:
        selected_mission = mission_index
        var available := selected_mission < unlocked_missions
        if available:
            mission_live = false
            mission_countdown = 5.0
            toast = "MISSION" + str(selected_mission + 1) + " // MATCHMAKING STARTED"
        else:
            toast = "MISSION" + str(selected_mission + 1) + " // ROUTE LOCKED"
        toast_time = 1.8
    elif mouse_pos.distance_to(center) < 165.0:
        toast = "LUA // SELECT A MISSION NODE"
        toast_time = 1.8
    queue_redraw()

func get_mission_at(mouse_pos: Vector2) -> int:
    var size := get_viewport_rect().size
    var center := get_lua_screen_point(size)
    var web_scale := lerpf(0.14, chart_zoom, clampf(inverse_lerp(0.34, 1.0, chart_zoom), 0.0, 1.0))
    var points := get_mission_points(center, web_scale)
    for i in range(points.size()):
        if mouse_pos.distance_to(points[i]) < 32.0:
            return i
    return -1

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_M:
            view_mode = "overview"
            target_chart_zoom = 0.34
            moon_pan = Vector2.ZERO
            toast = "MAP OVERVIEW // YOU ARE HERE"
            toast_time = 1.8
        elif event.keycode == KEY_ESCAPE:
            if view_mode != "overview":
                view_mode = "overview"
                target_chart_zoom = 0.34
                moon_pan = Vector2.ZERO
                toast = "SECTOR OVERVIEW // LUA SELECTED"
            else:
                toast = "NAVIGATION PAUSED"
            toast_time = 1.8
        elif event.keycode == KEY_TAB:
            toast = "LOADOUT // NOMAD FRAME READY"
            toast_time = 1.8
        queue_redraw()

func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            left_pan_active = event.pressed and chart_zoom > 0.34
            left_pan_last = event.position
        elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
            var direction := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
            zoom_moon_at(event.position, direction)
            queue_redraw()
    elif event is InputEventMouseMotion and left_pan_active and chart_zoom > 0.34:
        moon_pan += event.position - left_pan_last
        left_pan_last = event.position
        queue_redraw()

func zoom_moon_at(mouse_pos: Vector2, direction: float) -> void:
    var old_zoom := target_chart_zoom
    var new_zoom := clampf(old_zoom + direction * 0.07, 0.34, 2.25)
    if is_equal_approx(old_zoom, new_zoom):
        return
    target_chart_zoom = new_zoom
    if direction < 0.0 and new_zoom <= 0.36:
        view_mode = "overview"
        overview_handoff_pending = false
        toast = "SECTOR OVERVIEW // ALL SYSTEMS VISIBLE"
        toast_time = 1.8
