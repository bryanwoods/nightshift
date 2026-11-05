extends Control
## Every compiled sprite sheet, tile and portrait on a grid at 4x, labeled with the text file
## it comes from in assets/px/. Each page is saved as screens/gallery_<page>.png.
## Left and right show the next page. With --screens it saves the pages and quits.

const SCALE := 4
const WIDTH := 1800
const GAP := 28
const LIGHTS: Array[String] = ["glow", "light_radial", "light_cone"]
const CHARACTERS: Array[String] = ["tadzio", "wick", "dad", "unbaker", "unbaker_battle", "postman", "foreman",
	"dummy", "dummy_battle", "window_washer", "window_washer_battle", "puddle_keeper", "puddle_keeper_battle",
	"no_job", "no_job_battle", "curfew", "curfew_battle"]

var _pages: Array[SubViewport] = []
var _page: int = 0
var _view: TextureRect
var _title: Label


func _ready() -> void:
	var cast: Array = []
	for c in CHARACTERS:
		cast.append([c, load("res://assets/sprites/%s.png" % c)])
	_add_page("characters", cast)
	var sprites: Array = []
	for f in _pngs("res://assets/sprites/"):
		if not f.get_basename() in LIGHTS and not f.get_basename() in CHARACTERS:
			sprites.append([f.get_basename(), load("res://assets/sprites/" + f)])
	_add_page("sprites", sprites)
	var portraits: Array = []
	for f in _pngs("res://assets/portraits/"):
		portraits.append([f.get_basename(), load("res://assets/portraits/" + f)])
	_add_page("portraits", portraits)
	for ts: String in Game.tilesets:
		var atlas: Texture2D = load(str(Game.tilesets[ts]["png"]))
		var tiles: Array = []
		var names: Array = Game.tilesets[ts]["tiles"]
		for i in names.size():
			var at := AtlasTexture.new()
			at.atlas = atlas
			at.region = Rect2((i % 8) * 16, (i / 8) * 16, 16, 16)
			tiles.append([names[i], at])
		_add_page("tiles_" + ts, tiles)
	var bg := ColorRect.new()
	bg.color = Game.color("ink")
	bg.size = Vector2(320, 180)
	add_child(bg)
	_view = TextureRect.new()
	_view.position = Vector2(0, 14)
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_view.size = Vector2(320, 166)
	add_child(_view)
	_title = Label.new()
	add_child(_title)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(Game.SCREENS)
	for vp in _pages:
		vp.get_texture().get_image().save_png(Game.SCREENS + "gallery_" + vp.name + ".png")
		print("gallery ", vp.name)
	if "--screens" in OS.get_cmdline_user_args() or "--screens" in OS.get_cmdline_args():
		get_tree().quit()
	_show()


func _pngs(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".png"):
			out.append(f)
	return out


## One page: a label and the picture at 4x for each item, in rows that wrap at WIDTH.
func _add_page(page: String, items: Array) -> void:
	var vp := SubViewport.new()
	vp.name = page
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var root := Control.new()
	vp.add_child(root)
	var bg := ColorRect.new()
	bg.color = Game.color("dusk")
	root.add_child(bg)
	var font := ThemeDB.get_project_theme().default_font
	var head := Label.new()
	head.text = "assets/px/%s/" % page.replace("tiles_", "tiles/").replace("characters", "sprites")
	head.add_theme_font_size_override("font_size", 48)
	head.add_theme_color_override("font_color", Game.color("lamp"))
	head.position = Vector2(GAP, GAP / 2.0)
	root.add_child(head)
	var x := GAP
	var y := GAP + 56
	var row_h := 0
	for item: Array in items:
		var tex: Texture2D = item[1]
		var label := Label.new()
		label.text = str(item[0])
		label.add_theme_font_size_override("font_size", 32)
		label.add_theme_color_override("font_color", Game.color("moon"))
		var w := maxi(int(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x), tex.get_width() * SCALE)
		var h := 34 + tex.get_height() * SCALE
		if x + w > WIDTH - GAP and x > GAP:
			x = GAP
			y += row_h + GAP
			row_h = 0
		label.position = Vector2(x, y)
		root.add_child(label)
		var pic := TextureRect.new()
		pic.texture = tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_SCALE
		pic.position = Vector2(x, y + 34)
		pic.size = Vector2(tex.get_width(), tex.get_height()) * SCALE
		root.add_child(pic)
		x += w + GAP
		row_h = maxi(row_h, h)
	vp.size = Vector2i(WIDTH, y + row_h + GAP)
	bg.size = Vector2(vp.size)
	add_child(vp)
	_pages.append(vp)


func _show() -> void:
	_view.texture = _pages[_page].get_texture()
	_title.text = "%s  (%d/%d)  left/right: page   saved in screens/" % [_pages[_page].name, _page + 1, _pages.size()]


func _unhandled_input(event: InputEvent) -> void:
	if _pages.is_empty() or _view == null:
		return
	if event.is_action_pressed("move_right") or event.is_action_pressed("move_left"):
		_page = wrapi(_page + (1 if event.is_action_pressed("move_right") else -1), 0, _pages.size())
		_show()
