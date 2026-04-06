library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library work;
use work.cnn_pkg.all;

-- ----------------------------------------------------------------
-- fc_engine (v2 - LUT multipliers)
--
-- Uses dot9_lut instead of dot9 to avoid consuming DSP48E1 slices.
-- FC layers represent only 0.5% of total MACs, so LUT multipliers
-- are the correct engineering tradeoff. This frees 9 DSPs for the
-- conv_engine.
--
-- All other behavior identical to v1.
-- ----------------------------------------------------------------

entity fc_engine is
    generic (
        SHIFT : integer := 8
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        chunk_valid : in  std_logic;
        last_chunk  : in  std_logic;
        acts_chunk  : in  act_vec_t;
        ws_chunk    : in  weight_vec_t;
        bias_in     : in  signed(ACC_WIDTH-1 downto 0);
        done        : out std_logic;
        result      : out signed(ACT_WIDTH-1 downto 0)
    );
end entity fc_engine;

architecture rtl of fc_engine is

    signal dot9_valid : std_logic;
    signal dot9_psum  : signed(ACC_WIDTH-1 downto 0);
    signal acc        : signed(ACC_WIDTH-1 downto 0) := (others => '0');
    signal done_r     : std_logic := '0';
    signal result_r   : signed(ACT_WIDTH-1 downto 0) := (others => '0');
    signal last_sr    : std_logic_vector(DOT9_LATENCY downto 0) := (others => '0');
    signal first_sr   : std_logic_vector(DOT9_LATENCY downto 0) := (others => '0');
    signal is_first   : std_logic := '1';

    function relu_shift_clip(x : signed; shift : integer)
        return signed is
        variable b : signed(ACC_WIDTH downto 0);
        variable s : signed(ACC_WIDTH downto 0);
    begin
        b := resize(x, ACC_WIDTH+1);
        if b < 0 then
            return to_signed(0, ACT_WIDTH);
        end if;
        s := shift_right(b, shift);
        if s > to_signed(127, ACC_WIDTH+1) then
            return to_signed(127, ACT_WIDTH);
        end if;
        return signed(s(ACT_WIDTH-1 downto 0));
    end function;

begin

    -- Use dot9_lut: LUT-based multipliers, 0 DSPs
    u_dot9: entity work.dot9_lut
        port map(clk=>clk, rst=>rst, start=>chunk_valid,
                 acts=>acts_chunk, ws=>ws_chunk,
                 valid=>dot9_valid, psum=>dot9_psum);

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                last_sr  <= (others => '0');
                first_sr <= (others => '0');
                is_first <= '1';
            else
                last_sr  <= last_sr(DOT9_LATENCY-1 downto 0)
                            & (chunk_valid and last_chunk);
                first_sr <= first_sr(DOT9_LATENCY-1 downto 0)
                            & (chunk_valid and is_first);
                if chunk_valid = '1' then
                    if last_chunk = '1' then
                        is_first <= '1';
                    else
                        is_first <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                acc      <= (others => '0');
                done_r   <= '0';
                result_r <= (others => '0');
            else
                done_r <= '0';
                if dot9_valid = '1' then
                    if last_sr(DOT9_LATENCY) = '1' then
                        if first_sr(DOT9_LATENCY) = '1' then
                            result_r <= relu_shift_clip(
                                dot9_psum + bias_in, SHIFT);
                        else
                            result_r <= relu_shift_clip(
                                acc + dot9_psum + bias_in, SHIFT);
                        end if;
                        done_r <= '1';
                    elsif first_sr(DOT9_LATENCY) = '1' then
                        acc <= dot9_psum;
                    else
                        acc <= acc + dot9_psum;
                    end if;
                end if;
            end if;
        end if;
    end process;

    done   <= done_r;
    result <= result_r;

end architecture rtl;