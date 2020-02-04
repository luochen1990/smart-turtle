Smart Turtle
============

This script provide high level APIs for turtle robot in [ComputerCraft mod for Minecraft](https://github.com/dan200/ComputerCraft).

You can access the [raw turtle APIs here](http://www.computercraft.info/wiki/Turtle_(API)).

Features
--------

* provide functional style monadic api to use
    - absolute coord based api
        * implementation ideas
            - maintains current pos and facing/aiming directions
            - get init pos via gps
        * basic concepts
            - turtle's workMode:
                * `workMode.destroy`: whether auto dig when move blocked
                * `workMode.violence`: whether auto attack when move blocked
                * `workMode.violence`: whether auto attack when move blocked
                * `workMode.retrySeconds`: when move blocked by other turtles
            - turtle's workState:
                * `workState.pos`: turtle's current gps position
                * `workState.facing`: turtle's current facing direction: E/S/W/N
                * `workState.aiming`: turtle's current aiming height: 1/0/-1
            - pos:
                * short for "position"
                * means a vector with three integer coord value
            - dir:
                * short for "direction"
                * means a unit vector parallel to one of the three axis
                * there are 4 horizontal directions: E/S/W/N and 2 vertical: U/D
                * all directions can be found in `const.dir`, e.g. `const.dir.U`
            - about the "tank model" of turtle's state
                * a tank can rotate it's body and it's gun, same as the turtle
                * a turtle's body can face to one of the four horizontal dir
                * a turtle's gun (just image it) can aim to up/front/down
                * the st apis will reference the facing and aiming state to work
        * usage description
            - `turn.to(d)`: turn to face/aim direction `d`
            - `move`: move toward the aiming direction
            - `dig`: dig toward the aiming direction
    - provide high level combinators to construct complex logic
        * usage description
            - `io1 .. io2`: seqentially execute `io1` and `io2`
            - `io1 * io2`: if `io1` succeed then execute `io2`
            - `io1 + io2`: if `io1` failed then execute `io2`
            - `io % t`: retry `io` for `t` seconds
            - `io ^ n`: replicate `io` for `n` times
            - `rep(io)`: repeat `io` until it succeed
            - `rep(-io)`: repeat `io` until it failed
    - advanced move apis which support obstacle avoidance
        * implementation idea
            - inspired by the wall-following algorithm for 2-dimensional maze
            - first, we attempt to approach the destPos until blocked
            - second, we choose a targetDir and a detourPlane for next step
            - then we run the wall-following algorithm until facing to targetDir
            - we repeat the above three steps until we arrive the destPos
        * usage description
            - `move.to(destPos)`: go to `destPos`
            - `move.go(destVec)`: go to `workState.pos + destVec`

Get the code
------------

```
git clone https://github.com/luochen1990/smart-turtle
cd smart-turtle
cat src/* > st.lua
```

The `st.lua` file is a standalone file which you can run on turtle directly.

