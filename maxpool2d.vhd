library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.cnn_pkg.all;

-- ----------------------------------------------------------------
-- maxpool2d
-- 2x2 max pooling, stride 2. One pipeline stage (latency = 1).
--
-- Takes the four pixels of a 2x2 window simultaneously and outputs
-- the maximum. Row buffering and window extraction are handled by
-- the caller (cnn_top).
--
-- Operation:
--   Cycle N:   p00,p01,p10,p11 presented, valid_in='1'
--   Cycle N+1: max_out valid, valid_out='1'
--
-- max_out = max(p00, p01, p10, p11)
--
-- Inputs are signed(7:0) but values are always in [0,127]
-- after ReLU+quantize. The signed comparison is still correct
-- because all values are non-negative.
--
-- In the CNN:
--   After Conv1+quantize: 26x26x8 int8 -> pool -> 13x13x8 int8
--   After Conv2+quantize: 11x11x16 int8 -> pool -> 5x5x16 int8
-- ----------------------------------------------------------------

entity maxpool2d is
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        valid_in : in  std_logic;
        p00      : in  signed(ACT_WIDTH-1 downto 0);   -- row0, col0
        p01      : in  signed(ACT_WIDTH-1 downto 0);   -- row0, col1
        p10      : in  signed(ACT_WIDTH-1 downto 0);   -- row1, col0
        p11      : in  signed(ACT_WIDTH-1 downto 0);   -- row1, col1
        valid_out: out std_logic;
        max_out  : out signed(ACT_WIDTH-1 downto 0)
    );
end entity maxpool2d;

architecture rtl of maxpool2d is

    signal valid_r : std_logic := '0';
    signal max_r   : signed(ACT_WIDTH-1 downto 0) := (others => '0');

    -- Combinational max tree
    signal max_top : signed(ACT_WIDTH-1 downto 0);  -- max(p00, p01)
    signal max_bot : signed(ACT_WIDTH-1 downto 0);  -- max(p10, p11)
    signal max_all : signed(ACT_WIDTH-1 downto 0);  -- max of all four

begin

    -- ── Combinational max tree (3 comparisons) ────────────────────
    max_top <= p00 when p00 >= p01 else p01;
    max_bot <= p10 when p10 >= p11 else p11;
    max_all <= max_top when max_top >= max_bot else max_bot;

    -- ── Pipeline register ─────────────────────────────────────────
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                valid_r <= '0';
                max_r   <= (others => '0');
            else
                valid_r <= valid_in;
                if valid_in = '1' then
                    max_r <= max_all;
                end if;
            end if;
        end if;
    end process;

    valid_out <= valid_r;
    max_out   <= max_r;

end architecture rtl;