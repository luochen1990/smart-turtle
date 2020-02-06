------------------------- backpack slots management ----------------------------

slot = {
	findThat = function(cond, beginSlot) -- find something after beginSlot which satisfy cond
		for i = default(1)(beginSlot), const.turtle.backpackSlotsNum do
			if cond(turtle.getItemDetail(i)) then return i end
		end
		return nil
	end,
	findLastThat = function(cond, beginSlot)
		for i = const.turtle.backpackSlotsNum, default(1)(beginSlot), -1 do
			if cond(turtle.getItemDetail(i)) then return i end
		end
		return nil
	end,
	find = function(name, beginSlot)
		return slot.findThat(function(det) return det and det.name == name end, beginSlot)
	end,
	findLast = function(name, beginSlot)
		return slot.findLastThat(function(det) return det and det.name == name end, beginSlot)
	end,
	findSame = function(sn, beginSlot)
		local det = turtle.getItemDetail(sn)
		if det then return slot.find(det.name, beginSlot) end
	end,
	findLastSame = function(sn, beginSlot)
		local det = turtle.getItemDetail(sn)
		if det then return slot.findLast(det.name, beginSlot) end
	end,
	findEmpty = function(beginSlot)
		return slot.findThat(function(det) return not det end, beginSlot)
	end,
	findLastEmpty = function(beginSlot)
		return slot.findLastThat(function(det) return not det end, beginSlot)
	end,
	findDroppable = function(beginSlot)
		return slot.findThat(function(det) return det and const.cheapItems[det.name] end, beginSlot)
	end,
	countAll = function(countSingleSlot)
		local cnt = 0
		for i = 1, const.turtle.backpackSlotsNum do
			n = countSingleSlot(turtle.getItemDetail(i))
			if n then cnt = cnt + n end
		end
		return cnt
	end,
	count = function(name)
		return slot.countAll(function(det) if det and det.name == name then return det.count else return 0 end end)
	end,
	countSame = function(sn)
		local det = turtle.getItemDetail(sn)
		if det then return slot.count(det.name) end
	end,
	fill = function(sn) -- use items in slots after sn to make slot sn as full as possible
		local saved_sn = turtle.getSelectedSlot()
		sn = default(saved_sn)(sn)
		local count = turtle.getItemCount(sn)
		local space = turtle.getItemSpace(sn)
		if count ~= 0 and space ~= 0 then
			turtle.select(sn)
			for i = const.turtle.backpackSlotsNum, sn + 1, -1 do
				if turtle.compareTo(i) then
					local got = turtle.getItemCount(i)
					turtle.select(i)
					turtle.transferTo(sn)
					if got >= space then break end
				end
			end
		end
		turtle.select(saved_sn)
		return count ~= 0
	end,
	tidy = function()
		for i = 1, const.turtle.backpackSlotsNum do slot.fill(i) end
	end,
	reserve = function()
	end,
}

