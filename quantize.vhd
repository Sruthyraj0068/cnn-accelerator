library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.cnn_pkg.all;

-- ----------------------------------------------------------------
-- quantize
-- Post-convolution ReLU + bias add + requantize to 8-bit.
--
-- Operation (one pipeline stage, latency = 1):
--
--   Cycle N:   acc_in, bias_in presented, valid_in='1'
--   Cycle N+1: act_out valid, valid_out='1'
--
-- Steps performed in combinational logic, registered on rising edge:
--   1. biased = acc_in + bias_in          (32-bit signed)
--   2. relu   = max(biased, 0)            (clip negatives to 0)
--   3. shift  = relu >> SHIFT             (right shift = divide by 2^SHIFT)
--   4. clip   = min(shift, 127)           (clip to 8-bit unsigned max)
--   5. act_out = clip[ACT_WIDTH-1:0]      (8-bit output)
--
-- Generic SHIFT:
--   Chosen to match the weight quantization scale factor.
--   scale_conv1 ≈ 217 ≈ 2^7.76 → SHIFT=8 (divides by 256)
--   scale_conv2 ≈ 203 ≈ 2^7.66 → SHIFT=8
--   Default: SHIFT=8 works for both conv layers with these weights.
--
-- Output range:
--   act_out is always in [0, 127] (unsigned 8-bit after ReLU+clip).
--   Stored as signed(7:0) = signed positive values only post-ReLU.
--
-- This module is instantiated once per filter output, or as an
-- array of NUM_FILTERS instances driven from conv_engine psums.
-- ----------------------------------------------------------------

entity quantize is
    generic (
        SHIFT : integer := 8    -- right shift for requantization
    );
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        valid_in : in  std_logic;
        acc_in   : in  signed(ACC_WIDTH-1 downto 0);   -- 32-bit accumulator
        bias_in  : in  signed(ACC_WIDTH-1 downto 0);   -- 32-bit bias
        valid_out: out std_logic;
        act_out  : out signed(ACT_WIDTH-1 downto 0)    -- 8-bit output
    );
end entity quantize;

architecture rtl of quantize is

    -- Pipeline registers
    signal valid_r : std_logic := '0';
    signal act_r   : signed(ACT_WIDTH-1 downto 0) := (others => '0');

    -- Intermediate combinational signals
    signal biased  : signed(ACC_WIDTH downto 0);       -- 33-bit (no overflow)
    signal shifted : signed(ACC_WIDTH downto 0);       -- after right shift
    signal clipped : signed(ACT_WIDTH-1 downto 0);     -- clipped to 8-bit

begin

    -- ── Combinational path ────────────────────────────────────────
    -- Step 1: add bias (sign-extend both to 33 bits to avoid overflow)
    biased <= resize(acc_in, ACC_WIDTH+1) + resize(bias_in, ACC_WIDTH+1);

    -- Step 2+3: ReLU + right shift
    -- If biased < 0: output 0 (ReLU)
    -- If biased >= 0: shift right by SHIFT bits
    shifted <= shift_right(biased, SHIFT) when biased >= 0
               else (others => '0');

    -- Step 4: clip to [0, 127]
    -- If shifted > 127: output 127
    -- Otherwise: output shifted[7:0]
    clipped <= to_signed(127, ACT_WIDTH)
               when shifted > to_signed(127, ACC_WIDTH+1)
               else signed(shifted(ACT_WIDTH-1 downto 0));

    -- ── Pipeline register ─────────────────────────────────────────
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                valid_r <= '0';
                act_r   <= (others => '0');
            else
                valid_r <= valid_in;
                if valid_in = '1' then
                    act_r <= clipped;
                else
                    act_r <= (others => '0');    
                end if;
            end if;
        end if;
    end process;

    valid_out <= valid_r;
    act_out   <= act_r;

end architecture rtl;