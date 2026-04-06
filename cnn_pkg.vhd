library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ----------------------------------------------------------------
-- cnn_pkg: Project-wide constants and array types
-- All modules in this project use this package.
-- ----------------------------------------------------------------

package cnn_pkg is

    -- ----------------------------------------------------------------
    -- Fixed precision widths
    -- ----------------------------------------------------------------
    constant ACT_WIDTH    : integer := 8;
    constant WEIGHT_WIDTH : integer := 8;
    constant ACC_WIDTH    : integer := 32;

    -- ----------------------------------------------------------------
    -- dot9 pipeline latency
    -- start='1' on cycle N -> valid='1' on cycle N+DOT9_LATENCY
    --   N+0 : inputs sampled
    --   N+1 : 9 multiplications
    --   N+2 : adder level 1 (5 sums, 17-bit)
    --   N+3 : adder level 2 (3 sums, 18-bit)
    --   N+4 : adder level 3 (2 sums, 19-bit)
    --   N+5 : adder level 4 -> psum_r, valid=1
    -- ----------------------------------------------------------------
    constant DOT9_LATENCY : integer := 6;

    -- ----------------------------------------------------------------
    -- Maximum filter count (Conv2 = 16, the largest layer)
    -- Used to define fixed-size port arrays for conv_engine
    -- ----------------------------------------------------------------
    constant MAX_FILTERS : integer := 16;

    -- ----------------------------------------------------------------
    -- dot9 port types
    -- ----------------------------------------------------------------
    type act_vec_t    is array(0 to 8) of signed(ACT_WIDTH-1    downto 0);
    type weight_vec_t is array(0 to 8) of signed(WEIGHT_WIDTH-1 downto 0);

    -- ----------------------------------------------------------------
    -- conv_engine port types
    -- ws_array_t  : one weight_vec_t per filter (up to MAX_FILTERS)
    -- acc_array_t : one 32-bit accumulator per filter
    -- ----------------------------------------------------------------
    type ws_array_t  is array(0 to MAX_FILTERS-1) of weight_vec_t;
    type acc_array_t is array(0 to MAX_FILTERS-1) of signed(ACC_WIDTH-1 downto 0);

end package cnn_pkg;

package body cnn_pkg is
end package body cnn_pkg;