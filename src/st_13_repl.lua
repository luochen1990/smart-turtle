----------------------------------- lua repl -----------------------------------

_replState = {
	running = true,
	latestCallStack = {},
	history = {}, -- repl input command history
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

-- | convert a value to string for printing
function show(value)
	local metatable = getmetatable( value )
	if type(metatable) == "table" and type(metatable.__tostring) == "function" then
		return tostring( value )
	else
		local ok, serialised = pcall( textutils.serialise, value )
		if ok then
			return serialised
		else
			return tostring( value )
		end
	end
end

function showTableAsTuple(t) --NOTE: `{1, nil, 2}` will print as `1` instead of `1, nil, 2`
	local s = "nil"
	for i, x in ipairs(t) do
		if i == 1 then s = show(x) else s = s..", "..show(x) end
	end
	return s
end

function _replCo()
	local _cleanLineCo = function()
		while true do
			_waitForKeyCombination(keys.leftCtrl, keys.u)
			term.clearLine()
			local c, l = term.getCursorPos()
			term.setCursorPos(#_replStyle.promptText + 1, l)
		end
	end
	local _cleanCo = function()
		while true do
			_waitForKeyCombination(keys.leftCtrl, keys.l)
			term.clear()
			term.setCursorPos(1,1)
		end
	end
	--parallel.waitForAll(_replMainCo, _cleanCo, _cleanLineCo)
	_replMainCo()
end

function _replMainCo()
	_replState.running = true
	local tCommandHistory = {}
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

	while _replState.running do
		writeC(_replStyle.promptColor)(_replStyle.promptText)

		local s = withColor(_replStyle.commandColor)(function() return read( nil, _replState.history,
			function( sLine )
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
		end)()
		if s:match("%S") and _replState.history[#_replState.history] ~= s then
			table.insert( _replState.history, s )
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
			withColor(_replStyle.runCommandDefaultColor)(function()
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
							printC(_replStyle.resultColor)( showTableAsTuple( res2 ) )
						else
							_printCallStack()
							printError( res2[1] )
						end
					else
						-- other case just simply print
						printC(_replStyle.resultColor)( showTableAsTuple( res1 ) )
					end
				else
					_printCallStack(10, nil, _replStyle.errorStackColor)
					printError( res1[1] )
				end
			end)()
		else
			printError( e )
		end

	end
end

