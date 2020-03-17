------------------------------- advaneced apis ---------------------------------

if turtle then

	cryForHelpMoving = markIOfn("cryForHelpMoving(beginPos, destPos)")(mkIOfn(function(beginPos, destPos)
		workState.cryingFor = "moving"
		log.cry("Cannot move from "..show(beginPos).." to "..show(destPos)..", please help")
		printC(colors.green)("Press Ctrl+G to continue...")
		_waitForKeyCombination(keys.leftCtrl, keys.g)
		workState.cryingFor = false
		move.to(destPos)
	end))

	turn.toward = markIOfn("turn.toward(destPos,dirFilter,ioCond)")(function(destPos, dirFilter, ioCond)
		return mkIO(function()
			local v, d0 = destPos - workState.pos, workState:aimingDir()
			local ok = false
			for _, d in ipairs(workState:preferDirections()) do
				if v:dot(d) > 0 and (not dirFilter or dirFilter(d, d0)) then
					ok = ok or (turn.to(d) * (ioCond or pure(true)))()
					if ok then break end
				end
			end
			return ok
		end)
	end)

	-- | attempt to approach destPos by one step
	move.toward = markIOfn("move.toward(destPos,dirFilter)")(function(destPos, dirFilter)
		return turn.toward(destPos, dirFilter, move)
	end)

	help.move.to = doc({
		signature = "move.to : Pos -> IO Bool",
		usage = "local succ = move.to(pos)()",
		desc = {
			"move to specified position, might detour when blocked",
		},
	})
	move.to = markIOfn("move.to(destPos)")(function(destPos)
		return mkIO(function()
			local beginPos = workState.pos

			-- auto refuel
			if not workState.isRefueling then
				refuelTo(destPos)()
			end
			-- refuel may change our pos

			local latestDetourPos
			while true do
				-- attempt to approach destPos
				markCallSite("approaching")(function()
					rep(move.toward(destPos))()
				end)
				local destVec = destPos - workState.pos
				local dis = vec.manhat(destVec)
				if dis <= 1 then return dis == 0 end
				if not workMode.detour then return false end
				if workState.pos == latestDetourPos then return false end
				-- begin detouring
				markCallSite("detouring")(function()
					workState.detouring = true
					local detourBeginPos = workState.pos
					local detourCost = 0 -- record detouring cost
					local targetDir
					for _, d in ipairs(workState:preferDirections()) do
						if destVec:dot(d) > 0 then targetDir = d; break end
					end
					-- targetDir decided
					local detourDir
					for _, d in ipairs(workState:preferDirections()) do
						if d ~= 'D' and targetDir:dot(d) == 0 then --NOTE: prefer not to go down
							local ok = (turn.to(d) * move)()
							if ok then detourDir = d; detourCost = detourCost + 1; break end
						end
					end
					if not detourDir then
						detourDir = lateralSide(targetDir)
						-- turn.to(detourDir) --TODO: not sure whether need this line
					end
					-- init detourDir decided
					local rot = dirRotationBetween(targetDir, detourDir)
					local detourDirs = {targetDir, detourDir, rot(detourDir), rot(rot(detourDir))}
					-- detourDirs (i.e. detour plane) decided
					log.verb("detouring via "..showDir(targetDir)..","..showDir(detourDir).." to "..tostring(destPos))
					-- begin detouring loop
					local detourRotateCount = 1
					local detourBeginDis = vec.manhat(destPos - detourBeginPos)
					repeat
						repeat
							for i = -1, 2 do --NOTE: from detourDir-1 to detourDir+2
								candidateDir = detourDirs[(detourRotateCount + i) % 4 + 1]
								local ok = (turn.to(candidateDir) * move)()
								if ok then
									detourRotateCount = detourRotateCount + i
									detourCost = detourCost + 1
									break
								end
							end
						until (vec.manhat(destPos - workState.pos) <= detourBeginDis) --NOTE: this condition is very important
					until (move.toward(destPos)())
					log.verb("cost "..detourCost.." from "..show(detourBeginPos).." to "..show(workState.pos))
					-- finish detouring
					latestDetourPos = detourBeginPos
					workState.detouring = false
				end)
			end
		end)
	end)

	help.move.go = doc({
		signature = "move.go : Vector -> IO Bool",
		usage = "local succ = move.go(vec)()",
		desc = {
			"move.go(vec) is alias of move.to(currentPos() + vec), (see move.to)",
		},
	})
	move.go = markIOfn("move.go(destVec)")(function(destVec)
		return mkIO(function()
			return move.to(workState.pos + destVec)()
		end)
	end)

	savePos = markIOfn("savePos(io)")(function(io)
		return mkIO(function()
			local saved_pos = workState.pos
			local r = {io()}
			move.to(saved_pos)()
			return unpack(r)
		end)
	end)

	-- | save pos and dir
	savePosd = function(io)
		return saveDir(savePos(io))
	end

	-- | save pos and posture
	savePosp = function(io)
		return savePosture(savePos(io))
	end

	-- recover saved pos and posture
	recoverPosp = markIOfn("recoverPosp(back)")(mkIOfn(function(back)
		move.to(back.pos)()
		turn.to(back.facing)()
		workState.aiming = back.aiming
	end))

	help.scan = doc({
		signature = "scan : (Area, Dir?, LayerFilter?) -> IO a -> IO Bool",
		usage = "scan(area, mainDir, layerFilter)(io)()",
		desc = {
			"scan over a 1d/2d/3d area, and perform specified io action at each position",
			"if mainDir is specified, it scans layer by layer toward the mainDir, you might want to choose your mainDir same as your digging dir, or opposite to your placing dir",
			"if layerFilter is specified, only part of layers will be scaned, a demo layerFilter is `function(i) return i % 3 == 0 end`, and can use number `3` for short",
		},
	})
	scan = markIOfn2("scan(area,mainDir,layerFilter)(io)")(function(area, mainDir, layerFilter)
		assert(area:volume() > 0, "[scan] area:volume() should > 0")
		local rank = vec.rank(area.diag)
		if type(layerFilter) == "number" then
			layerFilter = (function(n) return function(i) return i % n == 0 end end)(layerFilter)
		end
		assert(not layerFilter or type(layerFilter) == "function", "[scan] layerFilter should be number or function")
		if rank == 0 then
			return mkIOfn(function(io) savePosd(io)(); return 1 end)
		end
		-- rank >= 1
		return mkIOfn(function(io)
			local near = area:vertexNear(workState.pos)
			if mainDir then near = area:face(-mainDir):vertexNear(workState.pos) end
			local far = area.low + area.high - near
			local diag = far - near
			if not mainDir then -- mainDir specified by user
				local candidates = vec.unitComponents(diag)
				local c1 = function(d) return bool2int(rank == 2 and d.y ~= 0) end
				local c2 = function(d) return diag:dot(d) end
				table.sort(candidates, comparator(c1, c2))
				mainDir = candidates[1]
			end
			local projLen = diag:dot(mainDir)

			log.verb("[scan] "..show(near)..".."..show(far)..", "..rank.."d "..(projLen+1).." layers toward " .. showDir(mainDir))
			assert((near..far) == area, "(near..far) should eq area")
			if rank == 1 then
				local io1, n = try(savePosd(io)), vec.manhat(far - near)
				return (move.to(near) * turn.toward(far) * io1 * fmap(plus(1))((move * io1) ^ n))()
			else -- rank > 1
				local p, q = near, (far - mainDir * projLen)
				assert(area:contains(p) and area:contains(q), "p, q should inside area")
				local cnt = 0
				for i = 0, projLen do
					if not layerFilter or layerFilter(i) then
						assert(area:contains(p + mainDir * i) and area:contains(q + mainDir * i), "p[i], q[i] should inside area")
						cnt = cnt + (scan((p + mainDir * i) .. (q + mainDir * i))(io)() or 0)
					end
				end
				return cnt
			end
		end)
	end)

	visitStation = markIOfn("visitStation(station)")(mkIOfn(function(station)
		assert(station.pos and station.dir, "[visitStation] station.pos and station.dir is required!")
		return (move.to(station.pos) * turn.to(station.dir))()
	end))

	cryingVisitStation = markIOfn("cryingVisitStation(station)")(function(station)
		assert(station.pos and station.dir, "[cryingVisitStation] station.pos and station.dir is required!")
		local leavePos = workState.pos
		return visitStation(station) + cryForHelpMoving(leavePos, station.pos) * turn.to(station.dir)
	end)

	carry = markIOfn("carry(from,to,count,name)")(mkIOfn(function(from, to, count, name)
		local got = slot.count(name)
		local visit = function(st) return visitStation(st) * (isStation + -try(unregisterStation(st) / (turn.U * move ^ 3))) end
		return (visit(from) * try(suckExact(count - got, name)) * visit(to) * dropExact(count, name) / (turn.U * move ^ 3))()
	end))

	transportLine = markIOfn("transportLine(from, to)")(mkIOfn(function(from, to)
		if not workState.fuelStation then error("[transportLine] please set a fuel provider") end
		local fuelReservation = 2 * vec.manhat(to.pos - from.pos) + vec.manhat(to.pos - workState.fuelStation.pos) + vec.manhat(from.pos - workState.fuelStation.pos)
		local cnt = 0
		while true do
			refuel(fuelReservation)()
			;(cryingVisitStation(from) * rep(suck()) * cryingVisitStation(to) * rep(select(slot.isNonEmpty) * drop()))()
			cnt = cnt + 1
			if not slot._findThat(slot.isNonEmpty) then
				log.verb("[transportLine] finished "..cnt.." trips, now have a rest for 20 seconds...")
				sleep(20)
			else
				log.verb("[transportLine] the dest chest is full, waiting for space...")
				;(retry(select(slot.isNonEmpty) * drop()) * rep(select(slot.isNonEmpty) * drop()))()
			end
		end
	end))

end
