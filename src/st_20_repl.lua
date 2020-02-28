----------------------------------- lua repl -----------------------------------

_replState = {
	running = true,
	latestCallStack = {},
	history = readLines("/history") or {}, -- repl input command history
	historyLimit = 100,
}
_replStyle = {
	helloText = "Welcome to Smart Turtle",
	helloColor = colors.lime,
	tipsText = "(This is a REPL, long press Ctrl+T to exit, press Ctrl+P to print call stack)",
	tipsColor = colors.gray,
	promptText = "st> ",
	promptColor = colors.blue,
	commandColor = colors.lightBlue,
	resultColor = colors.white,
	errorStackColor = colors.gray,
	runCommandDefaultColor = colors.lightGray,
}

function abortableRun(io)
	parallel.waitForAny(function() io() end, function() _waitForKeyCombination(keys.leftCtrl, keys.c) end)
end

function _replCo()
	_replMainCo()
end

function _replMainCo()
	_replState.running = true
	local tEnv = {
		["exit"] = mkIO(function()
			_replState.running = false
		end),
		["help"] = mkIO(function()
			return _replStyle.tipsText
		end),
		["_echo"] = function( ... )
			return ...
		end,
	}
	setmetatable( tEnv, { __index = _ENV } )

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
			repeat parallel.waitForAny(_readLineCo, _cleanScreenCo, _cleanLineCo) until (_gotLine)
			return _gotLine
		end
	end)()

	local replLoopBody = function()
		local s = replReadLineWithHotkeys()
		if s:match("%S") and _replState.history[#_replState.history] ~= s then
			table.insert( _replState.history, s )
			if #_replState.history > _replState.historyLimit then
				table.remove(_replState.history, 1)
			end
			writeLines("/history", _replState.history)
		end

		local nForcePrint = 0
		local func, e = load( s, "=lua", "t", tEnv )
		local func2 = load( "return _echo(" .. s .. ");", "=lua", "t", tEnv )
		if not func then
			if func2 then
				func = func2
				e = nil
				nForcePrint = 1
			end
		else
			if func2 then
				func = func2
			end
		end

		if func then
			abortableRun(withColor(_replStyle.runCommandDefaultColor)(function()
				_replState.callStack = _callStack
				_callStack = {}
				local res1 = { pcall( func ) }
				if table.remove(res1, 1) then
					if #res1 == 1 and type(res1[1]) == "table" and type(res1[1].run) == "function" then
						-- directly run a single IO monad
						_replState.latestCallStack = _callStack
						_callStack = {}
						local res2 = { pcall( res1[1].run ) }
						if table.remove(res2, 1) then
							printC(_replStyle.resultColor)( showFields( unpack(res2) ) )
						else
							_printCallStack(10, nil, _replStyle.errorStackColor)
							printError( res2[1] )
						end
					else
						-- other case just simply print
						printC(_replStyle.resultColor)( showFields( unpack(res1) ) )
					end
				else
					_printCallStack(10, nil, _replStyle.errorStackColor)
					printError( res1[1] )
				end
			end))
		else
			printError( e )
		end
	end

	while _replState.running do
		replLoopBody()
	end
end

