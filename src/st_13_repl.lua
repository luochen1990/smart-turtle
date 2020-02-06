------------------------------------- repl -------------------------------------

repl = function()
	os.run(_ENV, "/rom/programs/lua.lua")
end

v1 = vec(1,0,0)
v2 = vec(0,1,0)
v3 = vec(0,0,1)

initWorkState()

_testMove = savePosd(move.go(leftSide(workState.facing) * 2))
_testScan = savePosd(scan(O .. (O + (U + R + F) * 2), D)(turn.U * try(dig) * place))
_testScan2d = savePosd(_scan2d(O .. (O + (R + F) * 2))(turn.U * try(dig) * place))

if math.random() < 0.1 then _testMove() end
repl()
