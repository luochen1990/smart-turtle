----------------------------------- lua repl -----------------------------------

_replState = {
	running = true,
	latestCallStack = {},
	history = readLines("/.st_repl_history") or {}, -- repl input command history
	historyLimit = 100,
}
_replStyle = {
	helloText = "Welcome to Smart Turtle",
	helloColor = colors.lime,
	tipsText = "(This is a REPL, long press Ctrl+T to exit, press Ctrl+P to print call stack)",
	helpText = [[
	Long press Ctrl+T -- exit this REPL
	Ctrl+C -- abort running command
	Ctrl+P -- print current call stack
	Ctrl+L -- clean screen
	Ctrl+U -- clean current line
	]],
	tipsColor = colors.gray,
	promptText = "st> ",
	promptColor = colors.blue,
	commandColor = colors.lightBlue,
	resultColor = colors.white,
	errorStackColor = colors.gray,
	runCommandDefaultColor = colors.lightGray,
}

function _replMainCo()
	_replState.running = true
	local tEnv = {
		["exit"] = mkIO(function() _replState.running = false end),
		["help"] = mkIO(function() print(_replStyle.helpText) end),
	}
	setmetatable( tEnv, { __index = _ST } )

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
	printC(_replStyle.helloColor)(_replStyle.helloText)
	printC(_replStyle.tipsColor)(_replStyle.tipsText)

	local replReadLine = withColor(_replStyle.commandColor)(function()
		writeC(_replStyle.promptColor)(_replStyle.promptText)
		return read( nil, _replState.history, function( sLine )
			if settings.get( "lua.autocomplete" ) then
				local nStartPos = string.find( sLine, "[a-zA-Z0-9_%.:]+$" )
				if nStartPos then
					sLine = string.sub( sLine, nStartPos )
				end
				if #sLine > 0 then
					-- modified for IO monad
					local t = {}
					for _, s in ipairs( textutils.complete( sLine, tEnv ) ) do
						local r = s
						if string.sub(s, #s) == "." then
							for _, s2 in ipairs( textutils.complete( sLine .. s, tEnv ) ) do
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

	while _replState.running do
		local s = replReadLineWithHotkeys()
		if #s > 0 then
			if s:match("%S") and _replState.history[#_replState.history] ~= s then
				table.insert(_replState.history, s)
				if #_replState.history > _replState.historyLimit then
					table.remove(_replState.history, 1)
				end
				writeLines("/.st_repl_history", _replState.history)
			end

			local co1 = withColor(_replStyle.runCommandDefaultColor)(function() return eval(s, tEnv) end)
			local co2 = delay(_waitForKeyCombination, keys.leftCtrl, keys.c)
			local raceWinner, ok, res = race(co1, co2)
			if raceWinner == 1 then
				if ok then
					printC(_replStyle.resultColor)(show(unpack(res)))
				else
					_replState.latestCallStack = res.stack
					if res.stack then _printCallStack(10, nil, _replStyle.errorStackColor, res.stack) end
					printError(res.msg)
				end
			end
		end
	end
end

