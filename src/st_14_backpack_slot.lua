------------------------- backpack slots management ----------------------------

if turtle then

	slot = {
		isEmpty = function(sn) return turtle.getItemCount(sn) == 0 end,
		isNonEmpty = function(sn) return turtle.getItemCount(sn) > 0 end,
		isDroppable = function(sn)
			local det = turtle.getItemDetail(sn)
			return det and const.cheapItems[det.name]
		end,
		isFuel = function(sn)
			local det = turtle.getItemDetail(sn)
			if workMode.asFuel then
				return det and det.name == workMode.asFuel and const.fuelHeatContent[det.name]
			else
				return det and const.fuelHeatContent[det.name]
			end
		end,
		-- find a specific slot sn, return nil when not find
		findThat = function(cond, beginSlot) -- find something after beginSlot which satisfy cond
			for sn = default(1)(beginSlot), const.turtle.backpackSlotsNum do
				if cond(sn) then return sn end
			end
		end,
		findLastThat = function(cond, beginSlot)
			for sn = const.turtle.backpackSlotsNum, default(1)(beginSlot), -1 do
				if cond(sn) then return sn end
			end
		end,
		find = function(name, beginSlot)
			return slot.findThat(function(sn)
				local det = turtle.getItemDetail(sn)
				return det == name or (det and det.name == name)
			end, beginSlot)
		end,
		findLast = function(name, beginSlot)
			return slot.findLastThat(function(sn)
				local det = turtle.getItemDetail(sn)
				return det == name or (det and det.name == name)
			end, beginSlot)
		end,

		-- count item number in the backpack
		countVia = function(countSingleSlot)
			local cnt = 0
			for sn = 1, const.turtle.backpackSlotsNum do
				local n = countSingleSlot(sn)
				if n then cnt = cnt + n end
			end
			return cnt
		end,
		count = function(name)
			return slot.countVia(function(sn)
				local det = turtle.getItemDetail(sn)
				if det and det.name == name then return det.count else return 0 end
			end)
		end,

		-- tidy slot
		fill = function(sn) -- use items in slots after sn to make slot sn as full as possible
			local saved_sn = turtle.getSelectedSlot()
			sn = default(saved_sn)(sn)
			local count = turtle.getItemCount(sn)
			local space = turtle.getItemSpace(sn)
			if count ~= 0 and space ~= 0 then
				for i = const.turtle.backpackSlotsNum, sn + 1, -1 do
					turtle.select(i)
					if turtle.compareTo(sn) then
						local got = turtle.getItemCount(i)
						turtle.transferTo(sn)
						space = space - got
						if space <= 0 then break end
					end
				end
			end
			turtle.select(saved_sn)
			return count ~= 0
		end,
		tidy = function()
			for sn = 1, const.turtle.backpackSlotsNum do slot.fill(sn) end
		end,
	}

end
