------------------------------------- repl -------------------------------------

repl = function()
	os.run(_ENV, "/rom/programs/lua.lua")
end

v1 = vec(1,0,0)
v2 = vec(0,1,0)
v3 = vec(0,0,1)

initWorkState()
saveTurning(move.go(vec(-2,0,0)) .. move.to(vec(203,69,-76)))()
repl()
