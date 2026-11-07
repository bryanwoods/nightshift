extends Control
## Every compiled sprite sheet, tile and portrait on a grid at 4x, labeled with the text file
## it comes from in assets/px/. The characters page has one row a character: the first frame of
## each sheet and every portrait, labeled with its size. Each page is saved as screens/gallery_<page>.png.
## On screen, each page shows one character (or one screenful) at a time, as large as it fits.
## Left and right show the next page, up and down the next screen. With --screens it saves the
## pages and quits.

const SCALE := 4
const WIDTH := 1800
const GAP := 28
const LIGHTS: Array[String] = ["glow", "light_radial", "light_cone"]
const CHARACTERS: Array[String] = ["tadzio", "wick", "dad", "unbaker", "postman", "foreman", "dummy",
	"window_washer", "puddle_keeper", "no_job", "curfew"]

var _pages: Array[SubViewport] = []
var _items: Array = []
var _page: int = 0
var _screen: int = 0
var _box: Control
var _title: Label
var _font: Font


func _ready() -> void:
	var cast: Array = []
	for c in CHARACTERS:
		for sheet in [c, c + "_battle"]:
			if ResourceLoader.exists("res://assets/sprites/%s.png" % sheet):
				var size := FileAccess.get_file_as_string("res://assets/px/sprites/%s.txt" % sheet).get_slice("\n", 0).get_slice(" ", 2)
				var at := AtlasTexture.new()
				at.atlas = load("res://assets/sprites/%s.png" % sheet)
				at.region = Rect2(0, 0, size.get_slice("x", 0).to_int(), size.get_slice("x", 1).to_int())
				cast.append(["%s %s" % [sheet, size], at])
		cast.append([])
		for f in _pngs("res://assets/portraits/"):
			if f.begins_with(c + "_"):
				var tex: Texture2D = load("res://assets/portraits/" + f)
				cast.append(["%s %dx%d" % [f.get_basename(), tex.get_width(), tex.get_height()], tex])
		cast.append([])
	_add_page("characters", cast)
	var sprites: Array = []
	for f in _pngs("res://assets/sprites/"):
		if not f.get_basename() in LIGHTS:
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
			var tall := "res://assets/sprites/%s.png" % names[i]
			if ResourceLoader.exists(tall):
				tiles.append([names[i], load(tall)])
				continue
			var at := AtlasTexture.new()
			at.atlas = atlas
			at.region = Rect2((i % 8) * 16, (i / 8) * 16, 16, 16)
			tiles.append([names[i], at])
		_add_page("tiles_" + ts, tiles)
	var bg := ColorRect.new()
	bg.color = Game.color("ink")
	bg.size = Vector2(320, 180)
	add_child(bg)
	_box = Control.new()
	add_child(_box)
	_font = ThemeDB.get_project_theme().default_font
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
		if item.is_empty():
			x = GAP + WIDTH
			continue
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
	_items.append(items)


## The screens of one page. A run of items between two [] markers (the sheets or the portraits
## of one character) gets one screen at the largest scale from 4 down to 1 that fits it. A run
## that never fits is split into screens, and each of its items gets its own scale.
func _screens(items: Array) -> Array:
	var runs: Array = [[]]
	for it: Array in items:
		if it.is_empty():
			runs.append([])
		else:
			(runs[-1] as Array).append(it)
	var out: Array = []
	for run: Array in runs.filter(func(r: Array) -> bool: return not r.is_empty()):
		var fit: Array = []
		for s in [4, 3, 2, 1]:
			fit = _flow(run, s)
			if fit.size() == 1:
				break
		out.append_array(fit if fit.size() == 1 else _flow(run, 0))
	return out


## Lays items out in lines at scale s, or with s 0 at the largest scale up to 4 that fits each
## item alone. Each screen is a list of [label, texture, position, scale].
func _flow(items: Array, s: int) -> Array:
	var screens: Array = [[]]
	var x := 4.0
	var y := 16.0
	var line_h := 0.0
	for it: Array in items:
		var tex: Texture2D = it[1]
		var k := s if s > 0 else clampi(mini(312 / tex.get_width(), 148 / tex.get_height()), 1, 4)
		var size := Vector2(tex.get_width(), tex.get_height()) * k
		var w := maxf(size.x, minf(_font.get_string_size(str(it[0]).get_slice(" ", 0)).x, 72.0))
		if x + w > 316.0 and x > 4.0:
			x = 4.0
			y += line_h + 4.0
			line_h = 0.0
		if y + 14.0 + size.y > 178.0 and not (screens[-1] as Array).is_empty():
			screens.append([])
			x = 4.0
			y = 16.0
			line_h = 0.0
		(screens[-1] as Array).append([str(it[0]), tex, Vector2(x, y), k, w])
		x += w + 8.0
		line_h = maxf(line_h, 14.0 + size.y)
	return screens


func _show() -> void:
	var screens := _screens(_items[_page])
	_screen = clampi(_screen, 0, screens.size() - 1)
	for c in _box.get_children():
		c.queue_free()
	for cell: Array in screens[_screen]:
		var tex: Texture2D = cell[1]
		var label := Label.new()
		label.text = str(cell[0]).get_slice(" ", 0)
		label.position = cell[2]
		label.clip_text = true
		label.size = Vector2(float(cell[4]), 14.0)
		label.add_theme_color_override("font_color", Game.color("moon"))
		_box.add_child(label)
		var pic := TextureRect.new()
		pic.texture = tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_SCALE
		pic.position = (cell[2] as Vector2) + Vector2(0, 14)
		pic.size = Vector2(tex.get_width(), tex.get_height()) * int(cell[3])
		_box.add_child(pic)
	_title.text = "%s %d/%d  (%d/%d)  up/down: more  left/right: page" % [_pages[_page].name, _page + 1, _pages.size(), _screen + 1, screens.size()]


func _unhandled_input(event: InputEvent) -> void:
	if _pages.is_empty() or _box == null:
		return
	if event.is_action_pressed("move_right") or event.is_action_pressed("move_left"):
		_page = wrapi(_page + (1 if event.is_action_pressed("move_right") else -1), 0, _pages.size())
		_screen = 0
		_show()
	elif event.is_action_pressed("move_down") or event.is_action_pressed("move_up"):
		_screen += 1 if event.is_action_pressed("move_down") else -1
		_show()
