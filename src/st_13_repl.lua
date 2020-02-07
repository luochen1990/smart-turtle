----------------------------------- lua repl -----------------------------------

_latestCallStack = {} -- callStack of latest error
_history = {} -- repl input command history

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
    local bRunning = true
    local tCommandHistory = {}
    local tEnv = {
        ["exit"] = function()
            bRunning = false
        end,
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

    if term.isColour() then
        term.setTextColour( colours.yellow )
    end
    print( "Welcome to Smart Turtle REPL" )
    print( "Press Ctrl+T for 1 second to exit, Press Ctrl+P to print call stack" )
    term.setTextColour( colours.white )

    while bRunning do
        --if term.isColour() then
        --    term.setTextColour( colours.yellow )
        --end
        write( "st> " )
        --term.setTextColour( colours.white )

        local s = read( nil, tCommandHistory, function( sLine )
            if settings.get( "lua.autocomplete" ) then
                local nStartPos = string.find( sLine, "[a-zA-Z0-9_%.:]+$" )
                if nStartPos then
                    sLine = string.sub( sLine, nStartPos )
                end
                if #sLine > 0 then
                    return textutils.complete( sLine, tEnv )
                end
            end
            return nil
        end )
        if s:match("%S") and tCommandHistory[#tCommandHistory] ~= s then
            table.insert( tCommandHistory, s )
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
            local res1 = { pcall( func) }
            if table.remove(res1, 1) then
                if #res1 == 1 and type(res1[1]) == "table" and type(res1[1].run) == "function" then -- directly run a single IO monad
                    local res2 = { pcall(res1[1].run) }
                    if table.remove(res2, 1) then
                        print( showTableAsTuple( res2 ) )
                    else
                        printError( res2[1] )
                        _printCallStack()
                        _latestCallStack = _callStack
                        _callStack = {}
                    end
                else -- normal return values
                    print( showTableAsTuple( res1 ) )
                end
            else
                printError( res1[1] )
                _printCallStack()
                _latestCallStack = _callStack
                _callStack = {}
            end
        else
            printError( e )
        end

    end
end

