--lua
os.loadAPI('rom/luo/api') ; for k , v in pairs(api) do loadstring(string.format("%s = api.%s" , k , k))() end ;

local tArgs = { ... }
if #tArgs > 0 then
	if term.isColour() then
		term.setTextColour( colours.yellow )
	end
	print( "This is an interactive Lua prompt with luo's api preloaded." )
	print( "To run a lua program, just type its name." )
	term.setTextColour( colours.white )
	return
end

local bRunning = true
local tCommandHistory = {}
local tEnv = {
	["exit"] = function()
		bRunning = false
	end,
	["help"] = function(x)
		if x == nil then
			for k , v in pairs(api) do
				io.write(k) ;
				io.write(' ') ;
				print () ;
			end
		else
			print(string.format('useage %s: %s' , x , useage[x])) ;
		end
	end,
}
setmetatable( tEnv, { __index = getfenv() } )

if term.isColour() then
	term.setTextColour( colours.yellow )
end
math.randomseed(os.time())
local startSentences = {
	"Hello Turle !" ,
	"Good Luck !" ,
} ;
local selectStartSentence = math.random(#startSentences) ;
print(startSentences[selectStartSentence]) ;
print( "--  call exit() to exit." )
print( "--  call help() to list apis from luo." )
term.setTextColour( colours.white )

while bRunning do
	selectStartSentence = math.random(#startSentences) ;
	if term.isColour() then
		term.setTextColour( colours.blue )
	end
	write( "luo> " )
	term.setTextColour( colours.white )
	
	local s = read( nil, tCommandHistory )
	table.insert( tCommandHistory, s )
	
	local nForcePrint = 0
	local func, e = loadstring( s, "lua" )
	local func2, e2 = loadstring( "return "..s, "lua" )
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
        setfenv( func, tEnv )
        local tResults = { pcall( function() return func() end ) }
        if tResults[1] then
        	local n = 1
        	while (tResults[n + 1] ~= nil) or (n <= nForcePrint) do
        		print( tostring( tResults[n + 1] ) )
        		n = n + 1
        	end
        else
        	printError( tResults[2] )
        end
    else
    	printError( e )
    end
    
end
