----------------------- basic knowledge about the game -------------------------

const = {
	activeRadius = 100, -- this will decide default refuel level 
	fuelReserveRatio = 2, -- reserve some extra fuel for detouring
	greedyRefuelRatio = 10, -- greedy refuel ratio
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
		"minecraft:cobblestone",
		"minecraft:dirt",
		"minecraft:gravel",
	},
	valuableItems = {
		"*:diamond*",
		"*:gold_*",
		"*:redstone*",
		"*:emerald*",
		"*:lapis*",
		"*:*_ore",
		"*:resource", -- for ic2
	},
	afterDig = {
		["minecraft:stone"] = "minecraft:cobblestone",
		["minecraft:grass_block"] = "minecraft:dirt",
		["minecraft:grass"] = "minecraft:dirt",
	},
	groundBlocks = {
		"minecraft:dirt",
		"minecraft:grass_block", -- 1.15
		"minecraft:grass", -- 1.12
		"minecraft:stone",
		"minecraft:cobblestone",
		"minecraft:sand",
		"minecraft:end_stone",
		"minecraft:netherrack",
	},
	unstableBlocks = {
		"minecraft:leaves",
	},
	chestBlocks = {
		"minecraft:chest",
		"minecraft:trapped_chest",
		"minecraft:shulker_box",
	},
	otherContainerBlocks = { -- containers other than turtle or chest
		"minecraft:lit_furnace",
		"minecraft:hopper",
	},
	fuelHeatContent = {
		["minecraft:lava_bucket"] = 1000,
		["minecraft:charcoal"] = 80,
		["minecraft:coal"] = 80,
		["minecraft:stick"] = 5,
		--["minecraft:*log"] = 15,
		["minecraft:*planks"] = 15,
		["minecraft:*carpet"] = 3,
	},
}

------------------------------ about mc directions -----------------------------

const.dir = {
	['E'] = vec.axis.X, ['W'] = -vec.axis.X,
	['U'] = vec.axis.Y, ['D'] = -vec.axis.Y,
	['S'] = vec.axis.Z, ['N'] = -vec.axis.Z,
}
const.relativeDirectionNames = {"F", "B", "L", "R"}
const.absoluteDirectionNames = {"E", "S", "W", "N"}
const.preferDirections = {const.dir.U, const.dir.E, const.dir.S, const.dir.W, const.dir.N, const.dir.D}
const.rotate = { left = const.dir.D, right = const.dir.U, }
U = const.dir.U
D = const.dir.D
if not turtle then
	E = const.dir.E
	S = const.dir.S
	W = const.dir.W
	N = const.dir.N
end

showDir = function(d)
	for k, v in pairs(const.dir) do if d == v then return k end end
end

-------------------------------- about mc items --------------------------------

_item = {
	isTurtle = glob("computercraft:turtle_*"),
	isModem = glob("computercraft:*modem*"),
	isChest = glob(const.chestBlocks),
	isContainer = (function()
		local p = glob(const.otherContainerBlocks)
		return function(name) return _item.isChest(name) or p(name) end
	end)(),
	isCheap = glob(const.cheapItems),
	isValuable = glob(const.valuableItems),
	isNotValuable = combine(function(b) return not b end)(glob(const.valuableItems)),
	fuelHeatContent = globDict(const.fuelHeatContent),
	afterDig = function(name)
		return const.afterDig[name] or name
	end,
}

-------------------------------- about mc chunk --------------------------------

entireChunkOf = function(p)
	local p1 = vec(math.floor(p.x / 16) * 16, 0, math.floor(p.z / 16) * 16)
	return p1 .. p1 + (vec.axis.X + vec.axis.Z) * 15 + U * 256
end

chunkPartOf = function(p)
	local p1 = vec(math.floor(p.x / 16) * 16, math.floor(p.y / 16) * 16, math.floor(p.z / 16) * 16)
	return p1 .. p1 + vec.one * 15
end

regionIdOf = function(p)
	return math.floor(p.x / 512), math.floor(p.z / 512)
end

