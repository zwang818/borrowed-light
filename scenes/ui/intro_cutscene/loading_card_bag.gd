extends RefCounted
## One process-wide shuffle bag shared by entry and room-transfer overlays.
const CARDS := [
	preload("res://assets/loading/abdomen_workshop.png"),
	preload("res://assets/loading/energy_spine.png"),
	preload("res://assets/loading/underground_duct.png"),
]
static var remaining: Array[int] = []
static var previous := -1
static var _random: RandomNumberGenerator

static func take() -> int:
	if remaining.is_empty():
		remaining.assign([0,1,2])
		if _random == null:
			_random = RandomNumberGenerator.new()
			_random.randomize()
		# Private shuffle randomness does not reseed gameplay AI or combat RNG.
		for i in range(remaining.size()-1,0,-1):
			var chosen := _random.randi_range(0,i)
			var item := remaining[i]
			remaining[i] = remaining[chosen]
			remaining[chosen] = item
		if remaining[0] == previous:
			var swap := remaining[0]
			remaining[0] = remaining[1]
			remaining[1] = swap
	var index: int = remaining.pop_front()
	previous = index
	return index
