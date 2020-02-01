-- doc about parallel api: http://www.computercraft.info/wiki/Parallel_(API)

f1 = function ()
    while true do
        turtle.turnLeft()
    end
end

f2 = function ()
    local t = 0
    while true do
        sleep(1)
        print(t)
        t = t + 1
    end
end

parallel.waitForAny(f1, f2)

