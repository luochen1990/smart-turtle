--------------------------------- debug tools ----------------------------------

DEBUG = true
__assert = assert
if DEBUG then assert = __assert else assert = function() end end
--assert = function(...) if DEBUG then __assert(...) end end

