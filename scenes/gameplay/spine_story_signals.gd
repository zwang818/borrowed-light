extends Node2D
## Small local lights. All world timing pauses with the room.
var flow: Node
var clock := 0.0
var played := -1
var record_clock := -1.0
var sound: AudioStreamPlayer2D
var record_at := Vector2.ZERO

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
	if flow == null or not flow.story_ready: return
	var previous_clock := clock
	clock += delta
	if record_clock >= 0:
		var old := record_clock
		record_clock += delta
		for i in range(3):
			if old <= i*0.48 and record_clock > i*0.48:
				tick(0.5 if i==2 else 0.16,record_at)
		if record_clock > 1.8: record_clock = -1
	if flow.hero().global_position.distance_to(flow.anchor("ProtocolObservation")) < 370:
		var phase := fposmod(clock,5.0)
		var old_phase := fposmod(previous_clock,5.0)
		for i in range(3):
			var start: float = [0.35,0.78,1.58][i]
			if phase >= start and (old_phase < start or phase < old_phase):
				tick(0.55 if i==1 else 0.18,flow.anchor("ProtocolDemoReader"))
	queue_redraw()

func lit(phase: float, pattern: Array = [false,true,false]) -> bool:
	for i in range(3):
		var t: float = phase-[0.35,0.78,1.58][i]
		if t >= 0 and t < (0.55 if pattern[i] else 0.18): return true
	return false

func _lamp(at: Vector2, on: bool) -> void:
	draw_rect(Rect2(at-Vector2(4,3),Vector2(8,6)), Color("a6e9da") if on else Color("48615d"))
	if on: draw_circle(at,8,Color(0.5,0.85,0.8,0.14))

func _draw() -> void:
	if flow == null or not flow.story_ready: return
	var unit = flow.demo_cleaner
	var phase := fposmod(clock,5.0)
	if is_instance_valid(unit) and unit.health > 0:
		_lamp(unit.global_position+Vector2(-12,-17),lit(phase))
	_lamp(flow.anchor("ProtocolDemoReader")+Vector2(0,-7),lit(phase-2.25))
	_lamp(flow.hero().global_position+Vector2(1,-18),flow.hero().has_protocol and lit(phase))
	_lamp(flow.anchor("ProtocolGateReader"),flow.gate_receipting or flow.authorized_gate.is_open)
	if record_clock >= 0:
		var on := record_clock < 0.16 or (record_clock>=0.48 and record_clock<0.64) or (record_clock>=0.96 and record_clock<1.46)
		_lamp(record_at,on)
