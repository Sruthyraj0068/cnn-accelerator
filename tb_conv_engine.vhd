-- ═══════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library work;
use work.cnn_pkg.all;

entity tb_conv_engine is
end entity tb_conv_engine;

architecture sim of tb_conv_engine is

    constant CLK_PERIOD : time := 10 ns;

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal start    : std_logic := '0';
    signal num_ch   : integer range 1 to 8 := 1; -- signal for port
    signal acts     : act_vec_t  := (others => (others => '0'));
    signal ws       : ws_array_t := (others => (others => (others => '0')));
    signal done     : std_logic;
    signal psums    : acc_array_t;

begin

    -- ── Clock ─────────────────────────────────────────────────
    clk_proc : process
    begin
        while true loop
            clk <= '0'; wait for CLK_PERIOD/2;
            clk <= '1'; wait for CLK_PERIOD/2;
        end loop;
    end process;

    -- ── DUT ───────────────────────────────────────────────────
    dut : entity work.conv_engine
        generic map (
            NUM_FILTERS  => 8,   -- only generics here
            MAX_CHANNELS => 3    -- only generics here
        )
        port map (
            clk          => clk,
            rst          => rst,
            start        => start,
            num_channels => num_ch,  -- port connected here
            acts         => acts,
            ws           => ws,
            done         => done,
            psums        => psums
        );

    -- ── Stimulus ──────────────────────────────────────────────
    stim_proc : process

        procedure set_acts(mult : in integer) is
        begin
            for k in 0 to 8 loop
                acts(k) <= to_signed(mult*(k+1), ACT_WIDTH);
            end loop;
        end procedure;

        procedure zero_acts is
        begin
            acts <= (others => (others => '0'));
        end procedure;

        procedure set_ws(c : in integer) is
        begin
            for f in 0 to 7 loop
                for k in 0 to 8 loop
                    ws(f)(k) <= to_signed(f+c+1, WEIGHT_WIDTH);
                end loop;
            end loop;
        end procedure;

        procedure zero_ws is
        begin
            ws <= (others => (others => (others => '0')));
        end procedure;

        procedure fire_start is
        begin
            start <= '1';
            wait until rising_edge(clk);
            start <= '0';
        end procedure;

        procedure wait_done(tname : in string) is
            variable timeout : integer := 0;
        begin
            while done = '0' and timeout < 50 loop
                wait until rising_edge(clk);
                wait for 1 ns;
                timeout := timeout + 1;
            end loop;
            assert done = '1'
                report tname & ": TIMEOUT - done never asserted"
                severity failure;
        end procedure;

        procedure check_psums(
            e0,e1,e2,e3,e4,e5,e6,e7 : in integer;
            tname                    : in string
        ) is
        begin
            assert psums(0) = to_signed(e0, ACC_WIDTH)
                report tname & " f0: exp=" & integer'image(e0)
                             & " got=" & integer'image(to_integer(psums(0)))
                severity failure;
            assert psums(1) = to_signed(e1, ACC_WIDTH)
                report tname & " f1: exp=" & integer'image(e1)
                             & " got=" & integer'image(to_integer(psums(1)))
                severity failure;
            assert psums(2) = to_signed(e2, ACC_WIDTH)
                report tname & " f2: exp=" & integer'image(e2)
                             & " got=" & integer'image(to_integer(psums(2)))
                severity failure;
            assert psums(3) = to_signed(e3, ACC_WIDTH)
                report tname & " f3: exp=" & integer'image(e3)
                             & " got=" & integer'image(to_integer(psums(3)))
                severity failure;
            assert psums(4) = to_signed(e4, ACC_WIDTH)
                report tname & " f4: exp=" & integer'image(e4)
                             & " got=" & integer'image(to_integer(psums(4)))
                severity failure;
            assert psums(5) = to_signed(e5, ACC_WIDTH)
                report tname & " f5: exp=" & integer'image(e5)
                             & " got=" & integer'image(to_integer(psums(5)))
                severity failure;
            assert psums(6) = to_signed(e6, ACC_WIDTH)
                report tname & " f6: exp=" & integer'image(e6)
                             & " got=" & integer'image(to_integer(psums(6)))
                severity failure;
            assert psums(7) = to_signed(e7, ACC_WIDTH)
                report tname & " f7: exp=" & integer'image(e7)
                             & " got=" & integer'image(to_integer(psums(7)))
                severity failure;
            report tname & ": PASS ";
        end procedure;

    begin

        -- ── Reset ─────────────────────────────────────────────
        rst <= '1';
        for i in 1 to 4 loop
            wait until rising_edge(clk);
        end loop;
        rst <= '0';
        wait until rising_edge(clk);

        -- ══════════════════════════════════════════════════════
        -- TEST 1: Conv1 (1 channel active)
        -- expected psum(f) = (f+1)*45
        -- ══════════════════════════════════════════════════════
        report "TEST 1: Conv1 behaviour (1 channel)";

        num_ch <= 1;                      -- set port signal
        wait until rising_edge(clk);

        set_acts(1);
        set_ws(0);
        wait until rising_edge(clk);
        fire_start;

        wait_done("Test1");
        check_psums(45,90,135,180,225,270,315,360, "Test1_Conv1");

        -- Flush
        zero_acts; zero_ws;
        for i in 1 to DOT9_LATENCY+4 loop
            wait until rising_edge(clk);
        end loop;

        -- ══════════════════════════════════════════════════════
        -- TEST 2: Conv2 (3 channels active)
        -- expected: 630,900,1170,1440,1710,1980,2250,2520
        -- ══════════════════════════════════════════════════════
        report "TEST 2: Conv2 behaviour (3 channels)";

        num_ch <= 3;                      -- set port signal
        wait until rising_edge(clk);

        set_acts(1); set_ws(0);
        wait until rising_edge(clk);
        fire_start;

        set_acts(2); set_ws(1);
        wait until rising_edge(clk);
        fire_start;

        set_acts(3); set_ws(2);
        wait until rising_edge(clk);
        fire_start;

        wait_done("Test2");
        check_psums(630,900,1170,1440,1710,1980,2250,2520, "Test2_Conv2");

        -- ══════════════════════════════════════════════════════
        report "ALL TESTS PASSED ";
        wait;

    end process;

end architecture sim;
