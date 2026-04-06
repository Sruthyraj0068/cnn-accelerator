library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library work;
use work.cnn_pkg.all;

-- ----------------------------------------------------------------
-- tb_maxpool2d
-- Tests all cases for 2x2 max pooling.
--
-- Check timing: same as tb_quantize - check after rising edge
-- that registers the result (latency=1), before next edge.
--
-- Test cases:
--   1. All zeros              -> 0
--   2. All same value         -> that value
--   3. Max in top-left (p00)  -> p00
--   4. Max in top-right (p01) -> p01
--   5. Max in bot-left (p10)  -> p10
--   6. Max in bot-right (p11) -> p11
--   7. Realistic CNN values   -> correct max
--   8. Max = 127 (saturated)  -> 127
--   9. Back-to-back           -> throughput 1/cycle
-- ----------------------------------------------------------------

entity tb_maxpool2d is
end entity tb_maxpool2d;

architecture sim of tb_maxpool2d is

    constant CLK_PERIOD : time := 10 ns;

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal valid_in : std_logic := '0';
    signal p00      : signed(ACT_WIDTH-1 downto 0) := (others => '0');
    signal p01      : signed(ACT_WIDTH-1 downto 0) := (others => '0');
    signal p10      : signed(ACT_WIDTH-1 downto 0) := (others => '0');
    signal p11      : signed(ACT_WIDTH-1 downto 0) := (others => '0');
    signal valid_out: std_logic;
    signal max_out  : signed(ACT_WIDTH-1 downto 0);

begin

    clk_proc: process
    begin
        while true loop
            clk <= '0'; wait for CLK_PERIOD/2;
            clk <= '1'; wait for CLK_PERIOD/2;
        end loop;
    end process;

    dut: entity work.maxpool2d
        port map(clk=>clk, rst=>rst, valid_in=>valid_in,
                 p00=>p00, p01=>p01, p10=>p10, p11=>p11,
                 valid_out=>valid_out, max_out=>max_out);

    stim_proc: process

        procedure run_test(
            v00, v01, v10, v11 : in integer;
            expected           : in integer;
            tname              : in string
        ) is begin
            p00      <= to_signed(v00, ACT_WIDTH);
            p01      <= to_signed(v01, ACT_WIDTH);
            p10      <= to_signed(v10, ACT_WIDTH);
            p11      <= to_signed(v11, ACT_WIDTH);
            valid_in <= '1';
            wait until rising_edge(clk);
            wait for 0 ns; wait for 0 ns;
            valid_in <= '0';

            assert valid_out = '1'
                report tname & ": FAIL - valid_out not asserted"
                severity failure;
            assert max_out = to_signed(expected, ACT_WIDTH)
                report tname & ": FAIL  expected=" & integer'image(expected) &
                               "  got=" & integer'image(to_integer(max_out))
                severity failure;
            report tname & ": PASS  max=" & integer'image(expected);
        end procedure;

    begin
        rst <= '1';
        for i in 1 to 4 loop wait until rising_edge(clk); end loop;
        rst <= '0';
        wait until rising_edge(clk);

        -- T1: all zeros
        run_test(0, 0, 0, 0, 0, "T1_AllZero");

        -- T2: all same
        run_test(42, 42, 42, 42, 42, "T2_AllSame");

        -- T3: max in top-left
        run_test(99, 10, 20, 30, 99, "T3_MaxP00");

        -- T4: max in top-right
        run_test(10, 99, 20, 30, 99, "T4_MaxP01");

        -- T5: max in bot-left
        run_test(10, 20, 99, 30, 99, "T5_MaxP10");

        -- T6: max in bot-right
        run_test(10, 20, 30, 99, 99, "T6_MaxP11");

        -- T7: realistic CNN values (from conv_engine_ref output)
        -- pool1[0,0] for several filters had values like 13, 127, 98...
        run_test(13, 25, 127, 44, 127, "T7_Realistic");

        -- T8: saturated max = 127
        run_test(127, 100, 126, 125, 127, "T8_Max127");

        -- T9: back-to-back (3 consecutive windows)
        report "T9_BackToBack: start";
        p00<=to_signed(5,ACT_WIDTH); p01<=to_signed(3,ACT_WIDTH);
        p10<=to_signed(1,ACT_WIDTH); p11<=to_signed(4,ACT_WIDTH);
        valid_in <= '1'; wait until rising_edge(clk); wait for 0 ns; wait for 0 ns;
        assert max_out = to_signed(5, ACT_WIDTH)
            report "T9_BackToBack: FAIL s0 exp=5 got=" &
                   integer'image(to_integer(max_out)) severity failure;

        p00<=to_signed(10,ACT_WIDTH); p01<=to_signed(20,ACT_WIDTH);
        p10<=to_signed(30,ACT_WIDTH); p11<=to_signed(40,ACT_WIDTH);
        wait until rising_edge(clk); wait for 0 ns; wait for 0 ns;
        assert max_out = to_signed(40, ACT_WIDTH)
            report "T9_BackToBack: FAIL s1 exp=40 got=" &
                   integer'image(to_integer(max_out)) severity failure;

        p00<=to_signed(7,ACT_WIDTH); p01<=to_signed(7,ACT_WIDTH);
        p10<=to_signed(7,ACT_WIDTH); p11<=to_signed(7,ACT_WIDTH);
        wait until rising_edge(clk); wait for 0 ns; wait for 0 ns;
        assert max_out = to_signed(7, ACT_WIDTH)
            report "T9_BackToBack: FAIL s2 exp=7 got=" &
                   integer'image(to_integer(max_out)) severity failure;
        valid_in <= '0';
        report "T9_BackToBack: PASS  max=5,40,7";

        wait until rising_edge(clk);
        report "ALL TESTS PASSED";
        wait;
    end process;

end architecture sim;