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
		["minecraft:grass_block"] = "minecraft:dirt",
	},
	valuableItems = {
		"*:diamond*",
		"*:gold_*",
		"*:redstone*",
		"*:emerald*",
		"*:lapis*",
		"*:*_ore",
	},
	toolItems = {
		["computercraft:wireless_modem"] = "modem",
		["computercraft:wireless_modem_advanced"] = "modem",
	},
	turtleBlocks = {
		["computercraft:turtle_normal"] = true,
		["computercraft:turtle_advanced"] = true,
	},
	chestBlocks = {
		["minecraft:chest"] = true,
		["minecraft:trapped_chest"] = true,
		["minecraft:shulker_box"] = true,
	},
	containerBlocks = { -- containers other than turtle or chest
	},
	fuelHeatContent = {
		["minecraft:lava_bucket"] = 1000,
		["minecraft:charcoal"] = 80,
		["minecraft:coal"] = 80,
		["minecraft:oak_log"] = 15,
		["minecraft:white_carpet"] = 3,
		["minecraft:light_gray_carpet"] = 3,
		["minecraft:blue_carpet"] = 3,
	},
}

const.dir = {
	['E'] = vec.axis.X, ['W'] = -vec.axis.X,
	['U'] = vec.axis.Y, ['D'] = -vec.axis.Y,
	['S'] = vec.axis.Z, ['N'] = -vec.axis.Z,
}
const.directions = {"U", "E", "S", "W", "N", "D"}
const.rotate = { left = const.dir.D, right = const.dir.U, }
for k, v in pairs(const.dir) do _ENV[k] = v end -- define U/E/S/W/N/D

showDir = function(d)
	for k, v in pairs(const.dir) do if d == v then return k end end
end

