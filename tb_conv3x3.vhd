library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_conv3x3 is
-- Testbench has no ports
end tb_conv3x3;

architecture sim of tb_conv3x3 is

    signal clk, rst : std_logic := '0';

    -- 3x3 input pixels (signed 8-bit)
    signal pixel0, pixel1, pixel2,
           pixel3, pixel4, pixel5,
           pixel6, pixel7, pixel8 : signed(7 downto 0) := (others => '0');

    -- 3x3 filter weights (signed 8-bit)
    signal weight0, weight1, weight2,
           weight3, weight4, weight5,
           weight6, weight7, weight8 : signed(7 downto 0) := (others => '0');

    -- Accumulator chain wires
    signal acc0, acc1, acc2, acc3,
           acc4, acc5, acc6, acc7 : signed(31 downto 0);

    -- Final output
    signal conv_output : signed(31 downto 0);

begin

    ------------------------------------------------------------
    -- Clock: 10 ns period
    ------------------------------------------------------------
    clk_process: process
    begin
        while true loop
            clk <= '0'; wait for 5 ns;
            clk <= '1'; wait for 5 ns;
        end loop;
    end process;

    ------------------------------------------------------------
    -- 9 MACs chained structurally
    -- All inputs stable → valid result after 9 clock cycles
    -- No timing issue here: wires connect directly (no signal read)
    ------------------------------------------------------------
    mac0: entity work.mac_dsp48 port map(clk=>clk, rst=>rst, a_in=>pixel0, b_in=>weight0, acc_in=>(others=>'0'), acc_out=>acc0);
    mac1: entity work.mac_dsp48 port map(clk=>clk, rst=>rst, a_in=>pixel1, b_in=>weight1, acc_in=>acc0,          acc_out=>acc1);
    mac2: entity work.mac_dsp48 port map(clk=>clk, rst=>rst, a_in=>pixel2, b_in=>weight2, acc_in=>acc1,          acc_out=>acc2);
    mac3: entity work.mac_dsp48 port map(clk=>clk, rst=>rst, a_in=>pixel3, b_in=>weight3, acc_in=>acc2,          acc_out=>acc3);
    mac4: entity work.mac_dsp48 port map(clk=>clk, rst=>rst, a_in=>pixel4, b_in=>weight4, acc_in=>acc3,          acc_out=>acc4);
    mac5: entity work.mac_dsp48 port map(clk=>clk, rst=>rst, a_in=>pixel5, b_in=>weight5, acc_in=>acc4,          acc_out=>acc5);
    mac6: entity work.mac_dsp48 port map(clk=>clk, rst=>rst, a_in=>pixel6, b_in=>weight6, acc_in=>acc5,          acc_out=>acc6);
    mac7: entity work.mac_dsp48 port map(clk=>clk, rst=>rst, a_in=>pixel7, b_in=>weight7, acc_in=>acc6,          acc_out=>acc7);
    mac8: entity work.mac_dsp48 port map(clk=>clk, rst=>rst, a_in=>pixel8, b_in=>weight8, acc_in=>acc7,          acc_out=>conv_output);

    ------------------------------------------------------------
    -- Stimulus
    -- Python patch9  = [0, 0, 0, 0, 0, 0, 0, 0, 84]
    -- Python w9      = [-3, 34, 36, 60, 97, 84, 67, -30, -30]
    -- Expected result = 84 x (-30) = -2520
    -- Read conv_output after 9 clock cycles = 90 ns
    -- We wait 100 ns after inputs to be safe
    ------------------------------------------------------------
    stim_proc: process
    begin
        rst <= '1';
        wait for 20 ns;
        rst <= '0';

        -- Apply pixels
        pixel0 <= to_signed(0,  8);
        pixel1 <= to_signed(0,  8);
        pixel2 <= to_signed(0,  8);
        pixel3 <= to_signed(0,  8);
        pixel4 <= to_signed(0,  8);
        pixel5 <= to_signed(0,  8);
        pixel6 <= to_signed(0,  8);
        pixel7 <= to_signed(0,  8);
        pixel8 <= to_signed(84, 8);

        -- Apply weights (filter 0 from Python)
        weight0 <= to_signed(-3,  8);
        weight1 <= to_signed(34,  8);
        weight2 <= to_signed(36,  8);
        weight3 <= to_signed(60,  8);
        weight4 <= to_signed(97,  8);
        weight5 <= to_signed(84,  8);
        weight6 <= to_signed(67,  8);
        weight7 <= to_signed(-30, 8);
        weight8 <= to_signed(-30, 8);

        -- Wait 9 cycles + margin for full chain propagation
        wait for 100 ns;

        -- conv_output must equal -2520 here
        -- Verify this in the Vivado waveform

        wait;
    end process;

end architecture sim;