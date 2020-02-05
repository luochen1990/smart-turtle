----------------------- basic knowledge about the game -------------------------

const = {
	turtle = {
		needfuel = true,
		backpackSlotsNum = 16,
		baseAPIs = {
			"forward", "back", "up", "down", "turnLeft", "turnRight",
			"refuel", "getFuelLevel", "getFuelLimit",
			"select", "getSelectedSlot", "getItemCount", "getItemSpace", "getItemDetail", "transferTo",
			"compare", "compareUp", "compareDown", "compareTo",
			"suck", "suckUp", "suckDown", "drop", "dropUp", "dropDown",
			"dig", "digUp", "digDown", "place", "placeUp", "placeDown",
			"detect", "detectUp", "detectDown", "inspect", "inspectUp", "inspectDown",
			"attack", "attackUp", "attackDown", "equipLeft", "equipRight",
		},
	},
	cheapItems = {
		["minecraft:cobblestone"] = true,
		["minecraft:dirt"] = true,
		["minecraft:sand"] = true,
	},
	afterDig = {
		["minecraft:stone"] = "minecraft:cobblestone",
	},
	valuableItems = {
		"minecraft:diamond_ore",
		"minecraft:gold_ore",
		"minecraft:iron_ore",
		"minecraft:coal_ore",
		"minecraft:redstone_ore",
		"minecraft:lapis_ore",
	},
	turtleBlocks = {
		["minecraft:turtle_normal"] = true,
		["minecraft:turtle_advanced"] = true,
	},
	chestBlocks = {
		["minecraft:chest"] = true,
		["minecraft:shulker_box"] = true,
	},
	fuelHeatContent = {
		["minecraft:lava_bucket"] = 1000,
		["minecraft:charcoal"] = 80,
		["minecraft:coal"] = 80,
		["minecraft:oak_log"] = 15,
		["minecraft:light_gray_carpet"] = 3,
	},
}

const.ori = vec(0,0,0)
const.positiveDir = vec(1,1,1)
const.dir = {
	['E'] = vec(1,0,0), ['W'] = vec(-1,0,0),
	['U'] = vec(0,1,0), ['D'] = vec(0,-1,0),
	['S'] = vec(0,0,1), ['N'] = vec(0,0,-1),
}
const.directions = {"U", "E", "S", "W", "N", "D"}
const.rotate = {
	left = const.dir.N ^ const.dir.W,
	right = const.dir.N ^ const.dir.E,
}
for k, v in pairs(const.dir) do _ENV[k] = v -- define U/E/S/W/N/D

