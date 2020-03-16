-------------------------------- network utils ---------------------------------

rpc = {}

rpc._consoleLoggerBuilder = function(protocol, hostname)
	return {
		verb = function(msg) end,
		info = function(msg) printM(colors.gray  )(os.time().." ["..protocol.."] "..msg) end,
		succ = function(msg) printM(colors.green )(os.time().." ["..protocol.."] "..msg) end,
		fail = function(msg) printM(colors.yellow)(os.time().." ["..protocol.."] "..msg) end,
		warn = function(msg) printM(colors.orange)(os.time().." ["..protocol.."] "..msg) end,
	}
end

rpc._nopeLogger = {
	verb = function() end,
	info = function() end,
	succ = function() end,
	fail = function() end,
	warn = function() end,
}

-- | build a server, returns an IO to start the server
-- , `listenProtocol` is used for both request receiving and service discovery
-- , `servingMode` is one of "queuing", "blocking", "aborting"
-- , `handler` is a function like `function(unwrappedMsg) return requestValid, logicResultTable end`
-- , about the response message:
-- , * the response message is serialised like `literal(ok, res)`
-- , * first is an extra boolean, means whether the request reaches the handler
-- , * second is packed values returned by the handler
rpc.buildServer = function(listenProtocol, servingMode, handler, logger)
	assert(type(listenProtocol) == "string", "[rpc.buildServer] listenProtocol must be string")
	assert(servingMode == "queuing" or servingMode == "blocking" or servingMode == "aborting", "[rpc.buildServer] servingMode must be queuing/blocking/aborting")

	local hostname = os.getComputerID()..":"..math.random(0,9999)
	handler = default(safeEval)(handler)
	logger = default(rpc._consoleLoggerBuilder(listenProtocol, hostname))(logger)

	local processEvent = function(requesterId, rawMsg)
		logger.info("from " .. requesterId .. ": "..rawMsg)

		local resp, responseProtocol, reqId

		local ok1, parsed = safeEval(rawMsg)
		if not ok1 then
			resp = literal(false, "invalid request format (E1)")
			logger.warn("to " .. requesterId .. ":" .. reqId .. ": " .. resp)
			--log.warn("protocol error (E1): "..literal({rawMsg = rawMsg, parseErr = parsed}))
		else
			local proto, msg = unpack(parsed)
			local ok2 = ( type(proto) == "string" )
			ok2 = ok2 and ( string.sub(proto, 1, #listenProtocol) == listenProtocol )
			if not ok2 then
				resp = literal(false, "invalid request format (E2)")
				logger.warn("to " .. requesterId .. ":" .. reqId .. ": " .. resp)
				--log.warn("protocol error (E2): proto = "..literal(proto))
			else
				responseProtocol = proto
				reqId = string.sub(proto, #listenProtocol + 2)
				local ok3, res = handler(msg)
				if not ok3 then
					resp = literal(false, "bad request (E3): "..literal(res))
					logger.fail("to " .. requesterId .. ":" .. reqId .. ": " .. resp)
				else
					local ok4, lit = pcall(literal, true, res)
					if not ok4 then
						resp = literal(false, "not serialisable result (E4): "..showLit(res))
						logger.fail("to " .. requesterId .. ":" .. reqId .. ": " .. resp)
					else
						resp = lit
						local ok, r = unpack(res)
						if ok then
							logger.succ("to " .. requesterId .. ":" .. reqId .. ": " .. literal(ok, r))
						else
							logger.fail("to " .. requesterId .. ":" .. reqId .. ": " .. literal(ok, r))
						end
					end
				end
			end
		end
		return requesterId, resp, responseProtocol
	end

	if servingMode == "queuing" then
		return mkIO(function()
			local eventQueue = {}
			local listenCo = function()
				rednet.host(listenProtocol, hostname)
				logger.info("start serving as "..literal(listenProtocol, hostname))
				while true do
					logger.verb("listening on "..literal(listenProtocol))
					local senderId, rawMsg, _ = rednet.receive(listenProtocol)
					logger.verb("received from " .. senderId .. ": " .. rawMsg)
					table.insert(eventQueue, {senderId, rawMsg})
				end
			end
			local handleCo = function()
				local sleepInterval = 1
				while true do
					if #eventQueue == 0 then
						sleepInterval = math.min(0.5, sleepInterval * 1.1)
						logger.verb("waiting "..sleepInterval)
						sleep(sleepInterval)
					else -- if #eventQueue > 0 then
						logger.verb("handling "..#eventQueue)
						sleepInterval = 0.02
						local requesterId, resp, responseProtocol = processEvent(unpack(table.remove(eventQueue, 1)))
						rednet.send(requesterId, resp, responseProtocol)
					end
				end
			end
			parallel.waitForAny(listenCo, handleCo)
			return true
		end)
	elseif servingMode == "blocking" then
		return mkIO(function()
			rednet.host(listenProtocol, hostname)
			logger.info("start serving as "..literal(listenProtocol, hostname))
			while true do
				local requesterId, rawMsg = rednet.receive(listenProtocol)
				local _, resp, responseProtocol = processEvent(requesterId, rawMsg)
				rednet.send(requesterId, resp, responseProtocol)
			end
		end)
	elseif servingMode == "aborting" then
		error("[rpc.buildServer] aborting mode not implemented yet")
	end
end

rpc.buildClient = function(requestProtocol, knownServer)
	local _counter = math.random(0, 9999)
	local _knownServer = knownServer
	local _findServer = function() return rednet.lookup(requestProtocol) end

	-- | returns IO
	local _request = function(msg, totalTimeout, specifiedServerId, allowRetry) return mkIO(function()
		-- generate responseProtocol
		local responseProtocol = requestProtocol .. "_r" .. (_counter)
		_counter = (_counter + 1) % 10000

		local _req = mkIOfn(function(timeout)
			local serverId = specifiedServerId --TODO: use isolate api for specifiedServerId
			if not serverId then
				serverId = _knownServer or _findServer()
			end
			if not serverId then
				return false, "server not found: "..literal(requestProtocol)
			end
			rednet.send(serverId, literal(responseProtocol, msg), requestProtocol)
			while true do
				--printC(colors.blue)("listening response from "..serverId.." proto = "..literal(responseProtocol).." timeout = "..literal(timeout))
				local responserId, resp = rednet.receive(responseProtocol, timeout) --TODO: reduce timeout in next loop?
				--printC(colors.blue)("got response from "..literal(responserId)..", resp = "..literal(resp))
				if responserId == serverId then
					local ok, res = safeEval(resp) -- parse response
					if ok then
						return true, res
					else
						log.bug("[request] failed to parse response: ", literal({msg = msg, response = resp}))
						return false, "failed to parse response"
					end
				elseif not responserId then
					_knownServer = nil
					return false, "request timeout: "..literal({proto = responseProtocol, singleTimeout = timeout, totalTimeout = totalTimeout, t = os.time()})
				else
					log.warn("[request] weird, send to "..serverId.." but got response from "..responserId..", are we under attack?")
				end
			end
		end)
		local ok, res
		if allowRetry then
			ok, res = retryWithTimeout(totalTimeout)(_req)() --NOTE: only protocol level failure should be retried
		else
			ok, res = _req(totalTimeout or nil)()
		end
		if not ok then
			return false, res
		else
			return unpack(res) --NOTE: fold the failure flag
		end
	end) end

	-- | returns IO
	local _broadcast = function(msg, totalTimeout)
		totalTimeout = default(5)(totalTimeout)

		-- generate responseProtocol
		local responseProtocol = requestProtocol .. "_r" .. (_counter)
		_counter = (_counter + 1) % 10000

		local _req = mkIO(function()
			rednet.broadcast(literal(responseProtocol, msg), requestProtocol)
			local resps = {}
			local endTime = os.clock() + totalTimeout
			while true do
				local timeout = endTime - os.clock()
				local responserId, resp = rednet.receive(responseProtocol, timeout) --TODO: reduce timeout in next loop?
				if responserId then
					table.insert(resps, {responserId, resp})
				else
					break
				end
			end
			local results = {}
			for _, item in ipairs(resps) do
				local responserId, resp = unpack(item)
				local ok, res = safeEval(resp) -- parse response
				if ok then
					table.insert(results, {responserId, unpack(res)})
				else
					log.bug("[request] failed to parse response: ", literal({msg = msg, response = resp}))
				end
			end
			return results
		end)
		return _req
	end

	local _client = {}
	setmetatable(_client, {__index = function(t, k)
		local env = {
			request = function(msg, tmout) return _request(msg, default(5)(tmout), nil, true) end,
			send = function(id, msg, tmout) return _request(msg, tmout or false, id, false) end,
			broadcast = _broadcast,
			_counter = _counter,
			knownServer = _knownServer,
		}
		return env[k]
	end})
	return _client
end

