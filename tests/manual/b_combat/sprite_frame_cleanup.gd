extends RefCounted
## Runtime-only cleanup: source PNGs remain intact. Keep the connected robot,
## discard neighbouring-frame fragments and low-alpha fringe pixels.

static func clean_frame(source: Image) -> Image:
	var width := source.get_width()
	var height := source.get_height()
	var visited := PackedByteArray()
	visited.resize(width * height)
	var largest := PackedInt32Array()
	for y in range(height):
		for x in range(width):
			var start := y * width + x
			if visited[start] != 0 or source.get_pixel(x, y).a < 0.5:
				continue
			var component := PackedInt32Array([start])
			visited[start] = 1
			var cursor := 0
			while cursor < component.size():
				var index := component[cursor]
				cursor += 1
				var px := index % width
				var py := index / width
				for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var nx: int = px + offset.x
					var ny: int = py + offset.y
					if nx < 0 or nx >= width or ny < 0 or ny >= height:
						continue
					var next := ny * width + nx
					if visited[next] == 0 and source.get_pixel(nx, ny).a >= 0.5:
						visited[next] = 1
						component.append(next)
			if component.size() > largest.size():
				largest = component
	var output := Image.create(width, height, false, Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT)
	for index in largest:
		var x := index % width
		var y := index / width
		var color := source.get_pixel(x, y)
		color.a = 1.0
		output.set_pixel(x, y, color)
	return output
