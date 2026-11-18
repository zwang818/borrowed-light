extends Node2D
## Local cue for optional records and the return duct.
var record_clock := -1.0
var record_at := Vector2.ZERO
var sound: AudioStreamPlayer2D

func _ready() -> void:
	z_index = 24
	sound = AudioStreamPlayer2D.new()
	sound.volume_db = -18
	sound.max_distance = 650
	add_child(sound)

func tick(duration: float, at: Vector2) -> void:
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(int(22050*duration)*2)
	for i in range(data.size()/2):
		var t := float(i)/22050
		var value := int(sin(t*TAU*640)*5000*minf(1,t*120)*minf(1,(duration-t)*100))
		data.encode_s16(i*2,value)
	sound.position = at
	sound.stream = audio
	sound.play()

func _process(delta: float) -> void:
	if record_clock < 0:
		return
	var old := record_clock
	record_clock += delta
	for i in range(3):
		if old <= i*0.48 and record_clock > i*0.48:
			tick(0.5 if i==2 else 0.16,record_at)
	if record_clock > 1.8:
		record_clock = -1
	queue_redraw()

func _draw() -> void:
	if record_clock >= 0:
		var on := record_clock < 0.16 or (record_clock>=0.48 and record_clock<0.64) or (record_clock>=0.96 and record_clock<1.46)
		draw_rect(Rect2(record_at - Vector2(4,3),Vector2(8,6)), Color("a6e9da") if on else Color("48615d"))
		if on: draw_circle(record_at,8,Color(0.5,0.8,0.8,0.14))
