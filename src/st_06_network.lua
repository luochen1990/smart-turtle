-------------------------------- network utils ---------------------------------

_consoleLoggerBuilder = function(serviceName, protocol)
	return {
		verb = function(msg) end,
		info = function(msg) printC(colors.gray)("["..serviceName.."] "..msg) end,
		succ = function(msg) printC(colors.green)("["..serviceName.."] "..msg) end,
		fail = function(msg) printC(colors.yellow)("["..serviceName.."] "..msg) end,
		warn = function(msg) printC(colors.orange)("["..serviceName.."] "..msg) end,
	}
end

-- | build a server, returns an IO to start the server
-- , serviceName is for service lookup
-- , listenProtocol is for request receiving
-- , handler is a function like `function(unwrappedMsg) return requestValid, logicResultTable end`
_buildServer = function(serviceName, listenProtocol, handler, logger)
	handler = default(safeEval)(handler)
	logger = default(_consoleLoggerBuilder(serviceName, listenProtocol))(logger)

	return mkIO(function()
		local eventQueue = {}
		local listenCo = function()
			rednet.host(serviceName, "server")
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
					local requesterId, rawMsg = unpack(table.remove(eventQueue, 1))
					logger.info("exec cmd from " .. requesterId .. ": "..rawMsg)

					local resp, responseProtocol

					local ok1, parsed = safeEval(rawMsg)
					if not ok1 then
						resp = literal(false, "invalid request format")
						logger.warn("invalid request format (E1): "..literal({rawMsg = rawMsg, parsed = parsed}))
					else
						local proto, msg = unpack(parsed)
						local ok2 = ( type(proto) == "string" )
						ok2 = ok2 and ( string.sub(proto, 1, #listenProtocol) == listenProtocol )
						if not ok2 then
							resp = literal(false, "invalid request format")
							logger.warn("invalid request format (E2): proto = "..literal(proto))
						else
							responseProtocol = proto
							local ok3, res = handler(msg)
							if not ok3 then
								resp = literal(false, "bad request: "..literal(res))
								logger.fail("response to " .. requesterId .. ": (E3)" .. resp)
							else
								resp = literal(true, res)
								logger.succ("response to " .. requesterId .. ": " .. resp)
							end
						end
					end
					rednet.send(requesterId, resp, responseProtocol)
				end
			end
		end
		parallel.waitForAny(listenCo, handleCo)
		return true
	end)
end

_buildClient = function(serviceName, requestProtocol, knownServer)
	local _counter = math.random(0, 9999)
	local _knownServer = knownServer
	local _findServer = function() return rednet.lookup(serviceName) end

	-- | returns IO
	local _request = mkIOfn(function(msg, totalTimeout)
		totalTimeout = default(2)(totalTimeout)

		-- generate responseProtocol
		local responseProtocol = requestProtocol .. "_R" .. (_counter)
		_counter = (_counter + 1) % 10000

		local _req = mkIOfn(function(timeout)
			local serverId = _knownServer or _findServer()
			if not serverId then
				return false, "server not found: "..literal(serviceName)..", (protocol: "..requestProtocol..")"
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
						log.bug("[request] faild to parse response: ", literal({msg = msg, response = resp}))
						return false, "faild to parse response"
					end
				elseif not responserId then
					_knownServer = nil
					return false, "request timeout: "..literal({proto = responseProtocol, singleTimeout = timeout, totalTimeout = totalTimeout})
				else
					log.warn("[request] weird, send to "..serverId.." but got response from "..responserId..", are we under attack?")
				end
			end
		end)
		local ok, res = retryWithTimeout(totalTimeout)(_req)() --NOTE: only protocol level failure should be retried
		if not ok then
			return false, res
		else
			return unpack(res)
		end
	end)

	local _client = {}
	setmetatable(_client, {__index = function(t, k)
		local env = {
			request = _request,
			_counter = _counter,
			knownServer = _knownServer,
		}
		return env[k]
	end})
	return _client
end

