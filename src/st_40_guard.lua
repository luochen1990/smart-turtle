------------------------------------ guard -------------------------------------

telnetFollowMeCo = function()
	local p0 = gpsPos()
	local sended_p = p0
	while true do
		sleep(0.02)
		local p1 = gpsPos()
		if (p1 ~= sended_p) then
			local v = p1 - p0
			rednet.broadcast("move.to(O + vec("..v.x..","..v.y..","..v.z.."))()", "telnet")
			printC(colors.gray)("move.to(O + vec("..v.x..","..v.y..","..v.z.."))()")
			sended_p = p1
		end
	end
end

followYouCo2 = function(guardRelativePos, ignoreDeposit)
	ignoreDeposit = default(true)(ignoreDeposit)
	local eventQueue = {}
	local listenCo = function()
		while true do
			--printC(colors.gray)("[follow] listening")
			local senderId, msg, _ = rednet.receive("follow")
			--printC(colors.gray)("[follow] received from " .. senderId .. ": " .. msg)
			local queueTail = #eventQueue + 1
			if ignoreDeposit then queueTail = 1 end
			eventQueue[queueTail] = {senderId, msg}
		end
	end
	local execCo = function()
		local sleepInterval = 1
		while true do
			if #eventQueue == 0 then
				sleepInterval = math.min(0.5, sleepInterval * 1.1)
				--printC(colors.gray)("[follow] waiting "..sleepInterval)
				sleep(sleepInterval)
			else -- if #eventQueue > 0 then
				--printC(colors.gray)("[follow] executing "..#eventQueue)
				sleepInterval = 0.02
				local sender, msg = unpack(table.remove(eventQueue, 1))
				printC(colors.gray)("[follow] " .. sender .. ": " .. msg)
				if msg == "exit" then break end
				func, err = load("return "..msg, "telnet_cmd", "t", _ENV)
				if func then
					ok, res = pcall(func)
					if ok then
						if guardRelativePos == nil then
							guardRelativePos = gpsPos() - res
						else
							local succ = with({detour = false})(move.to(res + guardRelativePos))()
							if succ then
								printC(colors.green)(res + guardRelativePos)
							else
								printC(colors.yellow)("failed to follow to "..tostring(res))
							end
						end
					else
						printC(colors.yellow)(res)
					end
				else
					printC(colors.orange)(err)
				end
			end
		end
	end
	parallel.waitForAny(listenCo, execCo)
end

followMeCo2 = function()
	local p0 = gpsPos()
	local sended_p = p0
	while true do
		sleep(0.02)
		local p = gpsPos()
		if (p ~= sended_p) then
			local v = p - p0
			rednet.broadcast("vec("..p.x..","..p.y..","..p.z..")", "follow")
			printC(colors.gray)(tostring(p))
			sended_p = p
		end
	end
end

followYouCo = function(guardRelativePos)
	local beginPos = workState.pos
	local targetPos = nil
	local listenCo = function()
		while true do
			--printC(colors.gray)("[follow] listening")
			local senderId, msg, _ = rednet.receive("follow")
			--printC(colors.gray)("[follow] received from " .. senderId .. ": " .. msg)
			if msg == "exit" then
				return move.to(beginPos)
			else
				getRes, err = load("return "..msg, "telnet_msg", "t", _ENV)
				assert(getRes, "[follow] failed to parse msg: "..tostring(err))
				targetPos = getRes() + guardRelativePos
			end
		end
	end
	local execCo = function()
		local sleepInterval = 0.5
		while true do
			if targetPos == nil or workState.pos == targetPos then
				sleepInterval = math.min(0.5, sleepInterval * 1.1)
				--printC(colors.gray)("[follow] waiting "..sleepInterval)
				sleep(sleepInterval)
			else
				--printC(colors.gray)("[follow] executing "..#eventQueue)
				sleepInterval = 0.02
				move.toward(targetPos)()
			end
		end
	end
	parallel.waitForAny(listenCo, execCo)
end

activeVec = function(p)
	local center = p:round()
	local v = p - vec.floor(p)
	local x, y, z = 0, 0, 0
	if v.x < 0.19 then x = -1 elseif v.x > 0.81 then x = 1 end
	if v.z < 0.19 then z = -1 elseif v.z > 0.81 then z = 1 end
	if v.y < 0.5 then y = -1 elseif v.y > 0.62 then y = 1 end
	return vec(x, y, z)
end

nextStep = function(av0, av1)
	local x, y, z = 0, 0, 0
	if (av0.x == 0 and av1.x ~= 0) then x = av1.x end
	if (av0.y == 0 and av1.y ~= 0) then y = av1.y end
	if (av0.z == 0 and av1.z ~= 0) then z = av1.z end
	return vec(x, y, z)
end

followMeCo = function()
	local p0 = gpsLocate()
	local av0 = activeVec(p0)
	while true do
		sleep(0.02)
		local p1 = gpsLocate()
		if (p1 ~= p0) then
			local av1 = activeVec(p1)
			local v = nextStep(av0, av1)
			if vec.manhat(v) > 0 then
				local p = vec.floor(p1) + D + v
				rednet.broadcast("vec("..p.x..","..p.y..","..p.z..")", "follow")
				printC(colors.gray)(tostring(p))
			end
			p0, av0 = p1, av1
		end
	end
end

