library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.cnn_pkg.all;

-- ----------------------------------------------------------------
-- conv_engine (v2 - shared engine)
--
-- Single reusable convolution engine for all conv layers.
-- Instantiates NUM_FILTERS dot9 units running in parallel.
-- num_channels is a runtime port (not a generic) so the FSM
-- can switch between Conv1 (1 channel) and Conv2 (8 channels)
-- without separate hardware instances.
--
-- Usage:
--   Conv1: num_channels=1, ws(0..7) = real weights, ws(8..15) = 0
--   Conv2: num_channels=8, ws(0..15) = real weights
--
-- DSP usage: NUM_FILTERS * 9 = 16 * 9 = 144 DSP48E1
-- (vs 220 with separate Conv1 + Conv2 + FC engines)
-- ----------------------------------------------------------------

entity conv_engine is
    generic (
        NUM_FILTERS  : integer := 16;
        MAX_CHANNELS : integer := 8
    );
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        start        : in  std_logic;
        num_channels : in  integer range 1 to 8;
        acts         : in  act_vec_t;
        ws           : in  ws_array_t;
        done         : out std_logic;
        psums        : out acc_array_t
    );
end entity conv_engine;

architecture rtl of conv_engine is

    type psum_array_t  is array(0 to NUM_FILTERS-1) of signed(ACC_WIDTH-1 downto 0);
    type valid_array_t is array(0 to NUM_FILTERS-1) of std_logic;

    signal dot9_psum  : psum_array_t;
    signal dot9_valid : valid_array_t;

    -- Channel counter sized for MAX_CHANNELS
    signal ch_cnt : integer range 0 to MAX_CHANNELS-1 := 0;

    signal first_ch_sr : std_logic_vector(DOT9_LATENCY downto 0) := (others => '0');
    signal last_ch_sr  : std_logic_vector(DOT9_LATENCY downto 0) := (others => '0');

    signal acc_r  : acc_array_t := (others => (others => '0'));
    signal done_r : std_logic := '0';

begin

    -- ── NUM_FILTERS dot9 instances ────────────────────────────────
    gen_dot9 : for f in 0 to NUM_FILTERS-1 generate
        inst : entity work.dot9
            port map (
                clk   => clk,
                rst   => rst,
                start => start,
                acts  => acts,
                ws    => ws(f),
                valid => dot9_valid(f),
                psum  => dot9_psum(f)
            );
    end generate;

    -- ── Channel counter (runtime num_channels) ────────────────────
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                ch_cnt <= 0;
            elsif start = '1' then
                if ch_cnt = num_channels - 1 then
                    ch_cnt <= 0;
                else
                    ch_cnt <= ch_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    -- ── Flag shift registers ──────────────────────────────────────
    process(clk)
        variable first_in : std_logic;
        variable last_in  : std_logic;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                first_ch_sr <= (others => '0');
                last_ch_sr  <= (others => '0');
            else
                if start = '1' and ch_cnt = 0 then
                    first_in := '1';
                else
                    first_in := '0';
                end if;

                if start = '1' and ch_cnt = num_channels - 1 then
                    last_in := '1';
                else
                    last_in := '0';
                end if;

                first_ch_sr <= first_ch_sr(DOT9_LATENCY-1 downto 0) & first_in;
                last_ch_sr  <= last_ch_sr(DOT9_LATENCY-1 downto 0)  & last_in;
            end if;
        end if;
    end process;

    -- ── Accumulator ───────────────────────────────────────────────
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                acc_r <= (others => (others => '0'));
            elsif dot9_valid(0) = '1' then
                for f in 0 to NUM_FILTERS-1 loop
                    if first_ch_sr(DOT9_LATENCY) = '1' then
                        acc_r(f) <= dot9_psum(f);
                    else
                        acc_r(f) <= acc_r(f) + dot9_psum(f);
                    end if;
                end loop;
            end if;
        end if;
    end process;

    -- ── Done ──────────────────────────────────────────────────────
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                done_r <= '0';
            else
                done_r <= dot9_valid(0) and last_ch_sr(DOT9_LATENCY);
            end if;
        end if;
    end process;

    done  <= done_r;
    psums <= acc_r;

end architecture rtl;