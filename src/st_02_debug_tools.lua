--------------------------------- debug tools ----------------------------------

DEBUG = true
__assert = assert
assert = function(...) if DEBUG then __assert(...) end end

