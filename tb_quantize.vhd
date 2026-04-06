library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library work;
use work.cnn_pkg.all;

-- ----------------------------------------------------------------
-- tb_quantize
--
-- Timing:
--   Cycle N:   valid_in='1', acc/bias presented
--   Rising edge N: valid_r <= '1', act_r <= clipped   (registered)
--   After delta:   valid_out='1', act_out=result
--   CHECK HERE - before rising edge N+1
--   Cycle N+1: valid_in='0' already, valid_r <= '0'
--
-- All expected values (SHIFT=8):
--   biased = acc + bias
--   out    = min(max(biased,0) >> 8, 127)
-- ----------------------------------------------------------------

entity tb_quantize is
end entity tb_quantize;

architecture sim of tb_quantize is

    constant CLK_PERIOD : time := 10 ns;

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal valid_in : std_logic := '0';
    signal acc_in   : signed(ACC_WIDTH-1 downto 0) := (others => '0');
    signal bias_in  : signed(ACC_WIDTH-1 downto 0) := (others => '0');
    signal valid_out: std_logic;
    signal act_out  : signed(ACT_WIDTH-1 downto 0);

begin

    clk_proc: process
    begin
        while true loop
            clk <= '0'; wait for CLK_PERIOD/2;
            clk <= '1'; wait for CLK_PERIOD/2;
        end loop;
    end process;

    dut: entity work.quantize
        generic map(SHIFT => 8)
        port map(clk=>clk, rst=>rst, valid_in=>valid_in,
                 acc_in=>acc_in, bias_in=>bias_in,
                 valid_out=>valid_out, act_out=>act_out);

    stim_proc: process

        -- Apply inputs on cycle N, check output on same cycle N after delta.
        -- quantize latency = 1: output registered on same edge as valid_in.
        -- Check window: after rising edge N delta-settle, before rising edge N+1.
        procedure run_test(
            acc_val  : in integer;
            bias_val : in integer;
            expected : in integer;
            tname    : in string
        ) is begin
            acc_in   <= to_signed(acc_val,  ACC_WIDTH);
            bias_in  <= to_signed(bias_val, ACC_WIDTH);
            valid_in <= '1';
            wait until rising_edge(clk);    -- edge N: inputs registered
            wait for 0 ns; wait for 0 ns;  -- settle: valid_out='1', act_out=result
            valid_in <= '0';

            -- Check here - valid_out is '1', result is stable
            assert valid_out = '1'
                report tname & ": FAIL - valid_out not asserted"
                severity failure;
            assert act_out = to_signed(expected, ACT_WIDTH)
                report tname & ": FAIL  expected=" & integer'image(expected) &
                               "  got=" & integer'image(to_integer(act_out))
                severity failure;
            report tname & ": PASS  act_out=" & integer'image(expected);
        end procedure;

    begin
        rst <= '1';
        for i in 1 to 4 loop wait until rising_edge(clk); end loop;
        rst <= '0';
        wait until rising_edge(clk);

        -- T1: zero -> 0
        run_test(0, 0, 0, "T1_Zero");

        -- T2: bias=256 -> (0+256)>>8 = 1
        run_test(0, 256, 1, "T2_BiasOnly");

        -- T3: acc=512 -> 512>>8 = 2
        run_test(512, 0, 2, "T3_AccOnly");

        -- T4: acc=1024+bias=256 -> 1280>>8 = 5
        run_test(1024, 256, 5, "T4_AccPlusBias");

        -- T5: acc=-500 -> ReLU -> 0
        run_test(-500, 0, 0, "T5_NegAcc");

        -- T6: acc=-500+bias=100 -> -400 -> ReLU -> 0
        run_test(-500, 100, 0, "T6_NegSum");

        -- T7: acc=65536 -> 65536>>8=256 -> clip to 127
        run_test(65536, 0, 127, "T7_ClipTo127");

        -- T8: acc=32512 -> 32512>>8=127 exactly
        run_test(32512, 0, 127, "T8_Exact127");

        -- T9: realistic conv1 (acc=19, bias=19 -> 38>>8=0)
        run_test(19, 19, 0, "T9_RealisticConv1");

        -- T10: back-to-back (3 consecutive valid pulses)
        report "T10_BackToBack: start";
        acc_in   <= to_signed(256,  ACC_WIDTH); -- expect 1
        bias_in  <= to_signed(0,    ACC_WIDTH);
        valid_in <= '1'; wait until rising_edge(clk); wait for 0 ns; wait for 0 ns;
        assert act_out = to_signed(1, ACT_WIDTH)
            report "T10_BackToBack: FAIL s0 exp=1 got=" &
                   integer'image(to_integer(act_out)) severity failure;

        acc_in   <= to_signed(512,  ACC_WIDTH); -- expect 2
        bias_in  <= to_signed(0,    ACC_WIDTH);
        wait until rising_edge(clk); wait for 0 ns; wait for 0 ns;
        assert act_out = to_signed(2, ACT_WIDTH)
            report "T10_BackToBack: FAIL s1 exp=2 got=" &
                   integer'image(to_integer(act_out)) severity failure;

        acc_in   <= to_signed(1024, ACC_WIDTH); -- expect 4
        bias_in  <= to_signed(0,    ACC_WIDTH);
        wait until rising_edge(clk); wait for 0 ns; wait for 0 ns;
        assert act_out = to_signed(4, ACT_WIDTH)
            report "T10_BackToBack: FAIL s2 exp=4 got=" &
                   integer'image(to_integer(act_out)) severity failure;
        valid_in <= '0';
        report "T10_BackToBack: PASS  act_out=1,2,4";

        wait until rising_edge(clk);
        report "ALL TESTS PASSED";
        wait;
    end process;

end architecture sim;