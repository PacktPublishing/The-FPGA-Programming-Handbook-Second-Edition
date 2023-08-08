-- util_pkg.vhd
-- ------------------------------------
-- VHDL utility package
-- ------------------------------------
-- Author : Frank Bruno, Guy Eschemann

library ieee;
use ieee.math_real.all;

package util_pkg is

  -- Equivalent to the Verilog $clog2 function
  function clog2(N : positive) return positive;

end package util_pkg;

package body util_pkg is

  function clog2(N : positive) return positive is
  begin
    return positive(ceil(log2(real(N))));
  end function;

end package body util_pkg;
