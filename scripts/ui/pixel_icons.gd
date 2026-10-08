## Tiny pixel-art icons for the boost cards, drawn from text grids so no image
## files are needed. Each grid is 12x12; letters map to PALETTE colors, "." is empty.
extends RefCounted

const PALETTE := {
	"k": Color("#1a1a22"),
	"w": Color("#f4f1e6"),
	"s": Color("#b8c2cc"),
	"r": Color("#e0484f"),
	"y": Color("#ffd23f"),
	"o": Color("#a8672e"),
	"g": Color("#5fcf6a"),
	"b": Color("#4fb8ff"),
}

const GRIDS := {
	"sword": [
		".........kk.",
		"........kwwk",
		".......kwwsk",
		"......kwwsk.",
		".....kwwsk..",
		"..k.kwwsk...",
		"..kkwwsk....",
		"...kysk.....",
		"..kyykkk....",
		".kook..k....",
		"kook........",
		"kkk.........",
	],
	"bolt": [
		"......kkkkk.",
		".....kyyyyk.",
		"....kyyyyk..",
		"...kyyyyk...",
		"..kyyyyykkk.",
		"..kkkkyyyyk.",
		".....kyyyk..",
		"....kyyyk...",
		"...kyyk.....",
		"..kyyk......",
		".kyk........",
		".kk.........",
	],
	"eye": [
		"............",
		"............",
		"....kkkk....",
		"..kkwwwwkk..",
		".kwwwbbwwwk.",
		"kwwwbkkbwwwk",
		"kwwwbkwbwwwk",
		".kwwwbbwwwk.",
		"..kkwwwwkk..",
		"....kkkk....",
		"............",
		"............",
	],
	"clover": [
		"............",
		"..kkk..kkk..",
		".kgggk.kgggk",
		".kgggkkgggk.",
		"..kkggggkk..",
		".kkkggggkkk.",
		"kgggkggkgggk",
		"kgggk..kgggk",
		".kkk.kk.kkk.",
		".....kgk....",
		"......kgk...",
		".......kk...",
	],
	"skull": [
		"...kkkkkk...",
		"..kwwwwwwk..",
		".kwwwwwwwwk.",
		".kwwwwwwwwk.",
		".kwkkwwkkwk.",
		".kwkrwwkrwk.",
		".kwwwkkwwwk.",
		"..kwwwwwwk..",
		"...kwkwkk...",
		"...kwwwwk...",
		"....kkkk....",
		"............",
	],
	"heart": [
		"............",
		"..kkk..kkk..",
		".krrrkkrrrk.",
		"krwwrrrrrrrk",
		"krwrrrrrrrrk",
		"krrrrrrrrrrk",
		".krrrrrrrrk.",
		"..krrrrrrk..",
		"...krrrrk...",
		"....krrk....",
		".....kk.....",
		"............",
	],
	"boot": [
		"............",
		"...kkkkk....",
		"...kooook...",
		"...kooook...",
		"...kooook...",
		"...kooook...",
		"...koooookk.",
		"..kooooooook",
		"..kooooooook",
		"..kkkkkkkkkk",
		"..w.w.......",
		".w.w........",
	],
	"regen": [
		"............",
		"....kkkk....",
		"....kggk....",
		"....kggk....",
		".kkkkggkkkk.",
		".kggggggggk.",
		".kggggggggk.",
		".kkkkggkkkk.",
		"....kggk....",
		"....kggk....",
		"....kkkk....",
		"............",
	],
}

static var _cache := {}


## Texture for icon `name` (cached); falls back to a blank square.
static func texture(name: String) -> ImageTexture:
	if _cache.has(name):
		return _cache[name]
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rows: Array = GRIDS.get(name, [])
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var c := row[x]
			if PALETTE.has(c):
				img.set_pixel(x, y, PALETTE[c])
	var tex := ImageTexture.create_from_image(img)
	_cache[name] = tex
	return tex


## A TextureRect showing the icon scaled up with crisp pixels.
static func rect(name: String, size: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = texture(name)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
