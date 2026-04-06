library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.cnn_pkg.all;

-- ----------------------------------------------------------------
-- tb_dot9 - testbench for dot9
--
-- Timing model:
--   apply_inputs pulses start=1 for one cycle and returns.
--   After return we are positioned just after rising edge N.
--   We then wait DOT9_LATENCY rising edges to reach N+5.
--   After each clock wait we insert "wait for 0 ns" to allow
--   delta-cycle signal updates to settle before reading outputs.
--
-- Test vectors from dot9_ref.py.
-- ----------------------------------------------------------------

entity tb_dot9 is
end entity tb_dot9;

architecture sim of tb_dot9 is

    signal clk   : std_logic := '0';
    signal rst   : std_logic := '1';
    signal start : std_logic := '0';
    signal acts  : act_vec_t    := (others => (others => '0'));
    signal ws    : weight_vec_t := (others => (others => '0'));
    signal valid : std_logic;
    signal psum  : signed(ACC_WIDTH-1 downto 0);

    constant CLK_PERIOD : time := 10 ns;

begin

    clk_proc: process
    begin
        while true loop
            clk <= '0'; wait for CLK_PERIOD/2;
            clk <= '1'; wait for CLK_PERIOD/2;
        end loop;
    end process;

    uut: entity work.dot9
        port map(
            clk   => clk,
            rst   => rst,
            start => start,
            acts  => acts,
            ws    => ws,
            valid => valid,
            psum  => psum
        );

    stim_proc: process

        -- Pulse start=1 for one cycle and return.
        -- On return: after rising edge N where start was registered.
        procedure apply_inputs(
            a0,a1,a2,a3,a4,a5,a6,a7,a8 : in integer;
            w0,w1,w2,w3,w4,w5,w6,w7,w8 : in integer
        ) is
        begin
            acts(0) <= to_signed(a0, ACT_WIDTH);
            acts(1) <= to_signed(a1, ACT_WIDTH);
            acts(2) <= to_signed(a2, ACT_WIDTH);
            acts(3) <= to_signed(a3, ACT_WIDTH);
            acts(4) <= to_signed(a4, ACT_WIDTH);
            acts(5) <= to_signed(a5, ACT_WIDTH);
            acts(6) <= to_signed(a6, ACT_WIDTH);
            acts(7) <= to_signed(a7, ACT_WIDTH);
            acts(8) <= to_signed(a8, ACT_WIDTH);
            ws(0)   <= to_signed(w0, WEIGHT_WIDTH);
            ws(1)   <= to_signed(w1, WEIGHT_WIDTH);
            ws(2)   <= to_signed(w2, WEIGHT_WIDTH);
            ws(3)   <= to_signed(w3, WEIGHT_WIDTH);
            ws(4)   <= to_signed(w4, WEIGHT_WIDTH);
            ws(5)   <= to_signed(w5, WEIGHT_WIDTH);
            ws(6)   <= to_signed(w6, WEIGHT_WIDTH);
            ws(7)   <= to_signed(w7, WEIGHT_WIDTH);
            ws(8)   <= to_signed(w8, WEIGHT_WIDTH);
            start   <= '1';
            wait until rising_edge(clk);
            start   <= '0';
        end procedure;

        -- Wait DOT9_LATENCY cycles then check valid and psum.
        -- "wait for 0 ns" after each clock edge lets delta-cycle
        -- updates settle before reading signal values.
        procedure check_psum(
            expected  : in integer;
            test_name : in string
        ) is
        begin
            for i in 1 to DOT9_LATENCY loop
                wait until rising_edge(clk);
                wait for 0 ns; wait for 0 ns;
            end loop;
            assert valid = '1'
                report test_name & ": FAIL - valid not asserted"
                severity failure;
            assert psum = to_signed(expected, ACC_WIDTH)
                report test_name & ": FAIL - expected " &
                       integer'image(expected) & " got " &
                       integer'image(to_integer(psum))
                severity failure;
            report test_name & ": PASS  psum=" &
                   integer'image(to_integer(psum));
            -- Flush pipeline before next test
            for i in 1 to DOT9_LATENCY loop
                wait until rising_edge(clk);
            end loop;
        end procedure;

    begin
        -- Reset
        rst   <= '1';
        start <= '0';
        for i in 1 to 4 loop
            wait until rising_edge(clk);
        end loop;
        rst <= '0';
        wait until rising_edge(clk);

        -- ── Test 1: Timing check ──────────────────────────────────
        -- valid must stay 0 for cycles N+1..N+4, then 1 at N+5
        report "Test 1: Timing check";
        apply_inputs(1,1,1,1,1,1,1,1,1,
                     1,1,1,1,1,1,1,1,1);
        for i in 1 to DOT9_LATENCY-1 loop
            wait until rising_edge(clk);
            wait for 0 ns; wait for 0 ns;
            assert valid = '0'
                report "Test 1: FAIL - valid fired too early at N+" &
                       integer'image(i)
                severity failure;
        end loop;
        wait until rising_edge(clk);  -- N+5
        wait for 0 ns; wait for 0 ns;
        assert valid = '1'
            report "Test 1: FAIL - valid did not fire at N+5"
            severity failure;
        assert psum = to_signed(9, ACC_WIDTH)
            report "Test 1: FAIL - psum wrong, got " &
                   integer'image(to_integer(psum))
            severity failure;
        report "Test 1: PASS  valid at N+5, psum=9";
        for i in 1 to DOT9_LATENCY loop
            wait until rising_edge(clk);
        end loop;

        -- ── Test 2: All zeros, expected psum=0 ───────────────────
        report "Test 2: All zeros";
        apply_inputs(0,0,0,0,0,0,0,0,0,
                     0,0,0,0,0,0,0,0,0);
        check_psum(0, "Test2_AllZeros");

        -- ── Test 3: All ones, expected psum=9 ────────────────────
        report "Test 3: All ones";
        apply_inputs(1,1,1,1,1,1,1,1,1,
                     1,1,1,1,1,1,1,1,1);
        check_psum(9, "Test3_AllOnes");

        -- ── Test 4: Max positive, expected psum=145161 ───────────
        report "Test 4: Max positive";
        apply_inputs(127,127,127,127,127,127,127,127,127,
                     127,127,127,127,127,127,127,127,127);
        check_psum(145161, "Test4_MaxPositive");

        -- ── Test 5: Mixed signed, expected psum=-250 ─────────────
        report "Test 5: Mixed signed";
        apply_inputs( 10, 20, 30, 40, 50,-10,-20,-30,-40,
                       1,  2,  3,  4,  5,  6,  7,  8,  9);
        check_psum(-250, "Test5_MixedSigned");

        -- ── Test 6: Realistic CNN, expected psum=466 ─────────────
        report "Test 6: Realistic CNN values";
        apply_inputs( 45, 23, 67, 12, 89,  5, 34, 78, 56,
                      44,-64, 23,-54, -6, 41, 18,-35, 27);
        check_psum(466, "Test6_RealisticCNN");

        -- ── Test 7: Back-to-back pipeline ─────────────────────────
        -- Three consecutive starts at C, C+1, C+2.
        -- Results emerge at C+5, C+6, C+7: psum=45, 450, -450.
        report "Test 7: Back-to-back pipeline";
        apply_inputs(  1,  2,  3,  4,  5,  6,  7,  8,  9,
                       1,  1,  1,  1,  1,  1,  1,  1,  1);  -- C
        apply_inputs( 10, 20, 30, 40, 50, 60, 70, 80, 90,
                       1,  1,  1,  1,  1,  1,  1,  1,  1);  -- C+1
        apply_inputs(-10,-20,-30,-40,-50,-60,-70,-80,-90,
                      1,  1,  1,  1,  1,  1,  1,  1,  1);   -- C+2
        -- After C+2, wait 3 more edges to reach C+5
        for i in 1 to DOT9_LATENCY-2 loop
            wait until rising_edge(clk);
            wait for 0 ns; wait for 0 ns;
        end loop;
        -- C+5: start0 result
        assert valid = '1'
            report "Test7 s0: FAIL - valid not asserted" severity failure;
        assert psum = to_signed(45, ACC_WIDTH)
            report "Test7 s0: FAIL - expected 45 got " &
                   integer'image(to_integer(psum)) severity failure;
        report "Test7 s0: PASS  psum=45";
        wait until rising_edge(clk); wait for 0 ns; wait for 0 ns;
        -- C+6: start1 result
        assert valid = '1'
            report "Test7 s1: FAIL - valid not asserted" severity failure;
        assert psum = to_signed(450, ACC_WIDTH)
            report "Test7 s1: FAIL - expected 450 got " &
                   integer'image(to_integer(psum)) severity failure;
        report "Test7 s1: PASS  psum=450";
        wait until rising_edge(clk); wait for 0 ns; wait for 0 ns;
        -- C+7: start2 result
        assert valid = '1'
            report "Test7 s2: FAIL - valid not asserted" severity failure;
        assert psum = to_signed(-450, ACC_WIDTH)
            report "Test7 s2: FAIL - expected -450 got " &
                   integer'image(to_integer(psum)) severity failure;
        report "Test7 s2: PASS  psum=-450";
        for i in 1 to DOT9_LATENCY loop
            wait until rising_edge(clk);
        end loop;

        -- ── Test 8: Max negative, expected psum=-146304 ──────────
        report "Test 8: Max negative";
        apply_inputs(-128,-128,-128,-128,-128,-128,-128,-128,-128,
                      127, 127, 127, 127, 127, 127, 127, 127, 127);
        check_psum(-146304, "Test8_MaxNegative");

        report "ALL TESTS PASSED";
        wait;

    end process;

end architecture sim;