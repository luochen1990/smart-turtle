----------------------------------- repl tool ----------------------------------

replTool = {}

replTool.echoInputHandler = function(input, env) return true, {input} end

replTool.defaultReplStyle = {
	helloText = "Welcome to REPL",
	helloColor = colors.lime,
	tipsText = "(This is a REPL, long press Ctrl+T to exit, input 'help' for more help)",
	helpText = [[
	help -- print this help text
	exit -- exit this REPL
	Ctrl+L -- clean screen
	Ctrl+U -- clean current line
	]],
	tipsColor = colors.gray,
	promptText = "> ",
	promptColor = colors.blue,
	commandColor = colors.lightBlue,
	resultColor = colors.white,
	errorStackColor = colors.gray,
	runCommandDefaultColor = colors.lightGray,
}

-- | inputHandler is used like: `local ok, res = inputHandler(input, env)`
replTool.buildRepl = function(config)
	config = defaultDict({
		inputHandler = replTool.echoInputHandler,
		abortHandler = nil,
		readOnlyEnv = nil,
		historyFilePath = false,
		historyLimit = 100,
	})(config)

	local style = defaultDict(replTool.defaultReplStyle)(config.style)

	local state = {
		isExiting = false,
		isRunningCommand = false,
		latestCallStack = {},
		history = (config.historyFilePath and readLines(config.historyFilePath)) or {}, -- repl input command history
	}

	local internalCommands = {
		["exit"] = mkIO(function() state.isExiting = true end),
		["help"] = mkIO(function() print(style.helpText) end),
	}

	local _start = function()
		state.isExiting = false
		local modifiableEnv = {["exit"] = false} --NOTE: a placeholder for autocomplete
		setmetatable( modifiableEnv, { __index = config.readOnlyEnv } )

		-- Replace our package.path, so that it loads from the current directory, rather
		-- than from /rom/programs. This makes it a little more friendly to use and
		-- closer to what you'd expect.
		do
			local dir = shell.dir()
			if dir:sub(1, 1) ~= "/" then dir = "/" .. dir end
			if dir:sub(-1) ~= "/" then dir = dir .. "/" end

			local strip_path = "?;?.lua;?/init.lua;"
			local path = package.path
			if path:sub(1, #strip_path) == strip_path then
				path = path:sub(#strip_path + 1)
			end

			package.path = dir .. "?;" .. dir .. "?.lua;" .. dir .. "?/init.lua;" .. path
		end

		--term.clear(); term.setCursorPos(1,1)
		printC(style.helloColor)(style.helloText)
		printC(style.tipsColor)(style.tipsText)

		local replReadLine = withColor(style.commandColor)(function()
			writeC(style.promptColor)(style.promptText)
			return read( nil, state.history, function( sLine )
				if settings.get( "lua.autocomplete" ) then
					local nStartPos = string.find( sLine, "[a-zA-Z0-9_%.:]+$" )
					if nStartPos then
						sLine = string.sub( sLine, nStartPos )
					end
					if #sLine > 0 then
						-- modified for IO monad
						local t = {}
						for _, s in ipairs( textutils.complete( sLine, modifiableEnv ) ) do
							local r = s
							if string.sub(s, #s) == "." then
								for _, s2 in ipairs( textutils.complete( sLine .. s, modifiableEnv ) ) do
									if s2 == "run(" then
										r = string.sub(s, 1, #s - 1)
									end
								end
							end
							t[#t + 1] = r
						end
						return t
						--
					end
				end
				return nil
			end)
		end)

		local replReadLineWithHotkeys = (function()
			local _gotLine, _cleanLineCo, _cleanScreenCo, _readLineCo
			_cleanLineCo = function()
				_waitForKeyCombination(keys.leftCtrl, keys.u)
				term.clearLine()
				local c, l = term.getCursorPos()
				term.setCursorPos(1, l)
			end
			_cleanScreenCo = function()
				_waitForKeyCombination(keys.leftCtrl, keys.l)
				term.clear()
				term.setCursorPos(1, 1)
			end
			_readLineCo = function()
				_gotLine = replReadLine()
			end
			return function()
				_gotLine = nil
				repeat parallel.waitForAny(_readLineCo, _cleanScreenCo, _cleanLineCo) until (_gotLine)
				return _gotLine
			end
		end)()

		while not state.isExiting do
			state.isRunningCommand = false
			local input = replReadLineWithHotkeys()
			if #input > 0 then
				if input:match("%S") and state.history[#state.history] ~= input then
					table.insert(state.history, input)
					if #state.history > (config.historyLimit or 100) then
						table.remove(state.history, 1)
					end
					if config.historyFilePath then
						writeLines(config.historyFilePath, state.history)
					end
				end

				local co1 = withColor(style.runCommandDefaultColor)(function()
					local cmd = internalCommands[input]
					if cmd then
						return true, cmd()
					else
						return false, config.inputHandler(input, modifiableEnv)
					end
				end)
				local co2 = delay(_waitForKeyCombination, keys.leftCtrl, keys.c)

				state.isRunningCommand = true
				local winner, isInternalCmd, ok, res = race(co1, co2)()
				if winner == 1 then
					if not isInternalCmd then
						if ok then
							printC(style.resultColor)(show(unpack(res)))
						else
							state.latestCallStack = res.stack
							if res.stack then _printCallStack(nil, nil, style.errorStackColor, res.stack) end
							printError(res.msg)
						end
					end
				else -- winner == 2
					if config.abortHandler then
						config.abortHandler(modifiableEnv)
					end
				end
			end
		end
	end

	return {
		start = _start,
		env = modifiableEnv,
		config = config,
		state = state,
		style = style,
	}
end

