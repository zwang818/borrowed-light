extends RefCounted
## Runtime-only cleanup: source PNGs remain intact. Keep the connected robot,
## discard neighbouring-frame fragments and low-alpha fringe pixels.

static func clean_frame(source: Image) -> Image:
	var width := source.get_width()
	var height := source.get_height()
	# Work on contiguous bytes instead of making Image.get_pixel calls and
	# allocating four Vector2 neighbours for every visited pixel.
	var rgba := source.duplicate() as Image
	rgba.convert(Image.FORMAT_RGBA8)
	var pixels := rgba.get_data()
	var total := width*height
	var opaque := PackedByteArray()
	opaque.resize(total)
	for i in range(total):
		opaque[i] = 1 if pixels[i*4+3] >= 128 else 0
	var queue := PackedInt32Array()
	queue.resize(total)
	var largest := PackedInt32Array()
	for start in range(total):
		if opaque[start] == 0:
			continue
		queue[0] = start
		opaque[start] = 0
		var read := 0
		var count := 1
		while read < count:
			var index := queue[read]
			read += 1
			var x := index % width
			if x > 0 and opaque[index-1] != 0:
				opaque[index-1] = 0
				queue[count] = index-1
				count += 1
			if x+1 < width and opaque[index+1] != 0:
				opaque[index+1] = 0
				queue[count] = index+1
				count += 1
			if index >= width and opaque[index-width] != 0:
				opaque[index-width] = 0
				queue[count] = index-width
				count += 1
			if index+width < total and opaque[index+width] != 0:
				opaque[index+width] = 0
				queue[count] = index+width
				count += 1
		if count > largest.size():
			largest = queue.slice(0,count)
	var output := PackedByteArray()
	output.resize(total*4)
	output.fill(255) # Match Color.TRANSPARENT's white RGB with zero alpha.
	for i in range(total):
		output[i*4+3] = 0
	for index in largest:
		var offset := index*4
		output[offset] = pixels[offset]
		output[offset+1] = pixels[offset+1]
		output[offset+2] = pixels[offset+2]
		output[offset+3] = 255
	return Image.create_from_data(width,height,false,Image.FORMAT_RGBA8,output)
