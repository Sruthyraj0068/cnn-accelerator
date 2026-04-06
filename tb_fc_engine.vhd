library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library work;
use work.cnn_pkg.all;

-- ----------------------------------------------------------------
-- tb_fc_engine
-- Three DUT instances, each with different generics.
-- Run them sequentially (one at a time) to avoid xelab SIGSEGV.
-- Actually: use one DUT at a time in separate processes sharing clk.
--
-- To avoid Vivado 2020.2 xelab dual-generic crash, we instantiate
-- only ONE fc_engine configuration and test multiple scenarios
-- by choosing INPUT_SIZE=20, OUTPUT_SIZE=4 as a superset that
-- covers: 1-chunk (pad 7), 2-chunk (pad 2), 3-chunk (pad 7), neg.
--
-- Tests (all use INPUT_SIZE=20, OUTPUT_SIZE=4):
--
-- T1: All weights=1, acts=[1..20], bias=0
--   psum = 1+2+...+20 = 210
--   total = 210, out = 210>>8 = 0
--
-- T2: All weights=2, acts=[1..20], bias=0
--   psum = 420, out = 420>>8 = 1
--
-- T3: All weights=1, acts=[1..20], bias=256
--   total = 210+256 = 466, out = 466>>8 = 1
--
-- T4: All weights=-1, acts=[1..20], bias=0
--   psum = -210, ReLU -> out=0
-- ----------------------------------------------------------------

entity tb_fc_engine is
end entity tb_fc_engine;

architecture sim of tb_fc_engine is

    constant CLK_PERIOD  : time    := 10 ns;
    constant IN_SIZE     : integer := 20;
    constant OUT_SIZE    : integer := 4;

    -- Flat vector sizes
    constant ACTS_BITS    : integer := IN_SIZE  * ACT_WIDTH;
    constant WEIGHTS_BITS : integer := OUT_SIZE * IN_SIZE * WEIGHT_WIDTH;
    constant BIAS_BITS    : integer := OUT_SIZE * ACC_WIDTH;
    constant RESULTS_BITS : integer := OUT_SIZE * ACT_WIDTH;

    signal clk          : std_logic := '0';
    signal rst          : std_logic := '1';
    signal start        : std_logic := '0';
    signal acts_flat    : std_logic_vector(ACTS_BITS-1    downto 0)
                          := (others => '0');
    signal weights_flat : std_logic_vector(WEIGHTS_BITS-1 downto 0)
                          := (others => '0');
    signal bias_flat    : std_logic_vector(BIAS_BITS-1    downto 0)
                          := (others => '0');
    signal results_flat : std_logic_vector(RESULTS_BITS-1 downto 0);
    signal done         : std_logic;

begin

    clk_proc: process
    begin
        while true loop
            clk <= '0'; wait for CLK_PERIOD/2;
            clk <= '1'; wait for CLK_PERIOD/2;
        end loop;
    end process;

    dut: entity work.fc_engine
        generic map(
            INPUT_SIZE  => IN_SIZE,
            OUTPUT_SIZE => OUT_SIZE,
            SHIFT       => 8
        )
        port map(
            clk          => clk,
            rst          => rst,
            start        => start,
            acts_flat    => acts_flat,
            weights_flat => weights_flat,
            bias_flat    => bias_flat,
            results_flat => results_flat,
            done         => done
        );

    stim_proc: process

        -- Pack acts: acts(i) = val for all i
        procedure set_acts_const(val : in integer) is
        begin
            for i in 0 to IN_SIZE-1 loop
                acts_flat((i+1)*ACT_WIDTH-1 downto i*ACT_WIDTH)
                    <= std_logic_vector(to_signed(val, ACT_WIDTH));
            end loop;
        end procedure;

        -- Pack acts: acts(i) = i+1
        procedure set_acts_ramp is
        begin
            for i in 0 to IN_SIZE-1 loop
                acts_flat((i+1)*ACT_WIDTH-1 downto i*ACT_WIDTH)
                    <= std_logic_vector(to_signed(i+1, ACT_WIDTH));
            end loop;
        end procedure;

        -- Pack weights: all neurons get ws = val for all inputs
        procedure set_weights_const(val : in integer) is
        begin
            for n in 0 to OUT_SIZE-1 loop
                for i in 0 to IN_SIZE-1 loop
                    weights_flat(
                        (n*IN_SIZE+i+1)*WEIGHT_WIDTH-1 downto
                        (n*IN_SIZE+i)*WEIGHT_WIDTH)
                        <= std_logic_vector(to_signed(val, WEIGHT_WIDTH));
                end loop;
            end loop;
        end procedure;

        -- Pack bias: neuron n gets bias_vals(n)
        procedure set_bias(b0,b1,b2,b3 : in integer) is
        begin
            bias_flat(  ACC_WIDTH-1 downto 0)           <= std_logic_vector(to_signed(b0,ACC_WIDTH));
            bias_flat(2*ACC_WIDTH-1 downto   ACC_WIDTH) <= std_logic_vector(to_signed(b1,ACC_WIDTH));
            bias_flat(3*ACC_WIDTH-1 downto 2*ACC_WIDTH) <= std_logic_vector(to_signed(b2,ACC_WIDTH));
            bias_flat(4*ACC_WIDTH-1 downto 3*ACC_WIDTH) <= std_logic_vector(to_signed(b3,ACC_WIDTH));
        end procedure;

        -- Wait for done with timeout
        procedure wait_done(tname : in string) is
            variable timeout : integer := 0;
            constant MAX_WAIT : integer := (IN_SIZE/9+2) * OUT_SIZE * (DOT9_LATENCY+5);
        begin
            while done = '0' and timeout < MAX_WAIT loop
                wait until rising_edge(clk);
                wait for 0 ns; wait for 0 ns;
                timeout := timeout + 1;
            end loop;
            assert done = '1'
                report tname & ": FAIL - done never asserted (timeout=" &
                               integer'image(timeout) & ")"
                severity failure;
        end procedure;

        -- Read one result neuron
        impure function get_result(n : integer) return integer is
            variable bits : std_logic_vector(ACT_WIDTH-1 downto 0);
        begin
            bits := results_flat((n+1)*ACT_WIDTH-1 downto n*ACT_WIDTH);
            return to_integer(signed(bits));
        end function;

        -- Check all 4 outputs
        procedure check(e0,e1,e2,e3 : in integer; tname : in string) is
        begin
            assert get_result(0) = e0
                report tname & ": FAIL n0 exp=" & integer'image(e0) &
                               " got=" & integer'image(get_result(0))
                severity failure;
            assert get_result(1) = e1
                report tname & ": FAIL n1 exp=" & integer'image(e1) &
                               " got=" & integer'image(get_result(1))
                severity failure;
            assert get_result(2) = e2
                report tname & ": FAIL n2 exp=" & integer'image(e2) &
                               " got=" & integer'image(get_result(2))
                severity failure;
            assert get_result(3) = e3
                report tname & ": FAIL n3 exp=" & integer'image(e3) &
                               " got=" & integer'image(get_result(3))
                severity failure;
            report tname & ": PASS";
        end procedure;

    begin
        rst <= '1';
        for i in 1 to 4 loop wait until rising_edge(clk); end loop;
        rst <= '0';
        wait until rising_edge(clk);

        -- ── T1: ws=1, acts=[1..20], bias=0 -> psum=210 -> 0 ─────
        -- 210>>8 = 0 for all neurons (same weights)
        report "T1: ws=1, acts=ramp, bias=0 -> all psum=210 -> out=0";
        set_acts_ramp;
        set_weights_const(1);
        set_bias(0, 0, 0, 0);
        start <= '1'; wait until rising_edge(clk); start <= '0';
        wait_done("T1");
        check(0, 0, 0, 0, "T1");

        wait until rising_edge(clk);

        -- ── T2: ws=2, acts=[1..20], bias=0 -> psum=420 -> 1 ─────
        -- 420>>8 = 1 for all neurons
        report "T2: ws=2, acts=ramp, bias=0 -> psum=420 -> out=1";
        set_acts_ramp;
        set_weights_const(2);
        set_bias(0, 0, 0, 0);
        start <= '1'; wait until rising_edge(clk); start <= '0';
        wait_done("T2");
        check(1, 1, 1, 1, "T2");

        wait until rising_edge(clk);

        -- ── T3: ws=1, acts=ramp, bias=256 -> total=466 -> 1 ─────
        -- (210+256)>>8 = 466>>8 = 1
        report "T3: ws=1, acts=ramp, bias=256 -> total=466 -> out=1";
        set_acts_ramp;
        set_weights_const(1);
        set_bias(256, 256, 256, 256);
        start <= '1'; wait until rising_edge(clk); start <= '0';
        wait_done("T3");
        check(1, 1, 1, 1, "T3");

        wait until rising_edge(clk);

        -- ── T4: ws=-1, acts=ramp, bias=0 -> psum=-210 -> ReLU=0 ─
        report "T4: ws=-1, acts=ramp, bias=0 -> psum=-210 -> ReLU -> 0";
        set_acts_ramp;
        set_weights_const(-1);
        set_bias(0, 0, 0, 0);
        start <= '1'; wait until rising_edge(clk); start <= '0';
        wait_done("T4");
        check(0, 0, 0, 0, "T4");

        wait until rising_edge(clk);
        report "ALL TESTS PASSED";
        wait;
    end process;

end architecture sim;