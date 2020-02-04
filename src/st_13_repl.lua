------------------------------------- repl -------------------------------------

repl = function()
	os.run(_ENV, "/rom/programs/lua.lua")
end

v1 = vec(1,0,0)
v2 = vec(0,1,0)
v3 = vec(0,0,1)

initWorkState()
testMove = saveDir(savePos(move.go(leftSide(workState.facing) * 2)))
print(math.random())
if math.random() < 0.5 then testMove() end
repl()
