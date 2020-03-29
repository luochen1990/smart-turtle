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
			refuel.prepareMoveTo(destPos)() --NOTE: refuel.prepareMoveTo() may change our pos

			while true do
				-- attempt to approach destPos
				markCallSite("approaching")(function()
					rep(move.toward(destPos))()
				end)
				local destVec = destPos - workState.pos
				local dis = vec.manhat(destVec)
				if dis == 0 then return true elseif dis == 1 then return false, "destPos unreachable" end
				if not workMode.detour then return false, "workMode.detour is switched off" end
				-- begin detouring
				workState.detouring = true
				local detourBeginPos = workState.pos
				local detourCost = 0 -- record detouring cost
				local targetDir
				for _, d in ipairs(workState:preferDirections()) do
					if destVec:dot(d) > 0 then targetDir = d; break end
				end
				-- targetDir decided
				local detourDir, firstMove
				for _, d in ipairs(workState:preferDirections()) do
					if d ~= 'D' and targetDir:dot(d) == 0 then --NOTE: prefer not to go down
						local ok = (turn.to(d) * move)()
						if ok then detourDir = d; firstMove = d; detourCost = detourCost + 1; break end
					end
				end
				if not detourDir then
					detourDir = lateralSide(targetDir)
				end
				-- init detourDir decided
				local rot = dirRotationBetween(targetDir, detourDir)
				local detourDirs = {targetDir, detourDir, rot(detourDir), rot(rot(detourDir))}
				-- detourDirs (i.e. detour plane) decided here
				local detourBeginDis = vec.manhat(destPos - detourBeginPos)
				log.verb("[move.to] (dist = "..detourBeginDis..", pos = "..show(workState.pos)..") detouring via "..showDir(targetDir)..","..showDir(detourDir).." to "..tostring(destPos))
				-- begin detouring loop
				local detourRotateCount = 1
				repeat
					-- go to next same-distance pos
					repeat
						local moved = false
						for i = -1, 2 do --NOTE: from detourDir-1 to detourDir+2
							local candidateDir = detourDirs[(detourRotateCount + i) % 4 + 1]
							moved = (turn.to(candidateDir) * move)()
							if moved then -- moved one step here
								detourRotateCount = detourRotateCount + i
								detourCost = detourCost + 1
								local latestMove = candidateDir
								if not firstMove then
									firstMove = latestMove
								else
									if workState.pos == detourBeginPos + firstMove and latestMove == firstMove then
										return false, "dead loop detected"
									end
								end
								break
							end
						end
						if not moved then return false, "no direction to move, seems map have changed after detour plane choosed" end
					until (vec.manhat(destPos - workState.pos) <= detourBeginDis) --NOTE: this condition is very important
					-- arrived next same-distance pos
				until (move.toward(destPos)()) -- approach one step
				-- finish detouring
				log.verb("[move.to] (dist = "..(detourBeginDis-1)..", pos = "..show(workState.pos)..") cost "..detourCost.." from "..show(detourBeginPos))
				workState.detouring = false
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

	-- | recover saved pos and posture and sn
	-- , fails when move.to(back.pos) fail
	recover = markIOfn("recover(back)")(mkIOfn(function(back)
		local ok = move.to(back.pos)()
		if ok then
			if back.facing and back.aiming then
				turn.to(back.facing)()
				workState.aiming = back.aiming
			elseif back.dir then
				turn.to(back.dir)()
			end
			if back.selected then
				turtle.select(back.selected)
			end
		end
		return ok
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

			-- auto refuel
			refuel.prepareMoveTo(near, area:volume() + vec.manhat(far - workState.pos) * const.fuelReserveRatio)()
			--NOTE: refuel.prepareMoveTo() may change our pos

			log.verb("[scan] "..show(near)..".."..show(far)..", "..rank.."d "..(projLen+1).." layers toward " .. showDir(mainDir))
			assert((near..far) == area, "(near..far) should eq area")
			--assert((near..far) == area, "(near..far) should eq area: ".. showLit({near = near, far = far, area = area}))
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

	visitDepot = markIOfn("visitDepot(depot)")(mkIOfn(function(depot)
		assert(depot.pos and depot.dir, "[visitDepot] depot.pos and depot.dir is required!")
		return (move.to(depot.pos) * turn.to(depot.dir))()
	end))

	cryingVisitDepot = markIOfn("cryingVisitDepot(depot)")(function(depot)
		assert(depot.pos and depot.dir, "[cryingVisitDepot] depot.pos and depot.dir is required!")
		local leavePos = workState.pos
		return visitDepot(depot) + cryForHelpMoving(leavePos, depot.pos) * turn.to(depot.dir)
	end)

	-- | a tool to visit station robustly
	-- , will unregister bad stations and try to get next
	-- , will wait for user help when there is no more station available
	-- , will wait for manually move when cannot reach a station
	-- , argument: { reqStation, beforeLeave, beforeRetry, beforeWait, waitForUserHelp }
	_visitStation = function(opts)
		local gotoStation, station
		gotoStation = function(triedTimes, singleTripCost)
			local ok, res = opts.reqStation(triedTimes, singleTripCost)
			if not ok then
				return false, triedTimes, singleTripCost
			end
			station = res
			-- got fresh station here
			opts.beforeLeave(triedTimes, singleTripCost, station)
			local leavePos, fuelBeforeLeave = workState.pos, turtle.getFuelLevel()
			with({workArea = false, destroy = 1})(cryingVisitDepot(station))()
			-- arrived station here
			local cost = math.max(0, fuelBeforeLeave - turtle.getFuelLevel())
			local singleTripCost_ = singleTripCost + cost
			if not isStation() then -- the station is not available
				opts.beforeRetry(triedTimes, singleTripCost, station, cost)
				unregisterStation(station)
				return gotoStation(triedTimes + 1, singleTripCost_)
			else
				return true, triedTimes, singleTripCost_
			end
		end
		local succ, triedTimes, singleTripCost = gotoStation(0, 0)
		if not succ then -- tried all station arrivable, but still failed
			opts.beforeWait(triedTimes, singleTripCost, station)
			race_(retry(delay(gotoStation, triedTimes, singleTripCost)), delay(opts.waitForUserHelp, triedTimes, singleTripCost, station))()
		end
		return true, triedTimes, singleTripCost, station
	end

	carry = markIOfn("carry(from,to,count,name)")(mkIOfn(function(from, to, count, name)
		local got = slot.count(name)
		local visit = function(st) return visitDepot(st) * (isStation + -try(unregisterStation(st) / (turn.U * move ^ 3))) end
		return (visit(from) * try(suck.exact(count - got, name)) * visit(to) * drop.exact(count, name) / (turn.U * move ^ 3))()
	end))

end
