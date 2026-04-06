library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_conv3x3_8filters is
-- Testbench has no ports
end tb_conv3x3_8filters;

architecture sim of tb_conv3x3_8filters is

    signal clk, rst : std_logic := '0';

    -- 9 input pixels (shared across all 8 filters)
    signal pixel0, pixel1, pixel2,
           pixel3, pixel4, pixel5,
           pixel6, pixel7, pixel8 : signed(7 downto 0) := (others => '0');

    -- Filter 0 weights
    signal w0_f0, w1_f0, w2_f0, w3_f0, w4_f0,
           w5_f0, w6_f0, w7_f0, w8_f0 : signed(7 downto 0) := (others => '0');

    -- Filter 1 weights
    signal w0_f1, w1_f1, w2_f1, w3_f1, w4_f1,
           w5_f1, w6_f1, w7_f1, w8_f1 : signed(7 downto 0) := (others => '0');

    -- Filter 2 weights
    signal w0_f2, w1_f2, w2_f2, w3_f2, w4_f2,
           w5_f2, w6_f2, w7_f2, w8_f2 : signed(7 downto 0) := (others => '0');

    -- Filter 3 weights
    signal w0_f3, w1_f3, w2_f3, w3_f3, w4_f3,
           w5_f3, w6_f3, w7_f3, w8_f3 : signed(7 downto 0) := (others => '0');

    -- Filter 4 weights
    signal w0_f4, w1_f4, w2_f4, w3_f4, w4_f4,
           w5_f4, w6_f4, w7_f4, w8_f4 : signed(7 downto 0) := (others => '0');

    -- Filter 5 weights
    signal w0_f5, w1_f5, w2_f5, w3_f5, w4_f5,
           w5_f5, w6_f5, w7_f5, w8_f5 : signed(7 downto 0) := (others => '0');

    -- Filter 6 weights
    signal w0_f6, w1_f6, w2_f6, w3_f6, w4_f6,
           w5_f6, w6_f6, w7_f6, w8_f6 : signed(7 downto 0) := (others => '0');

    -- Filter 7 weights
    signal w0_f7, w1_f7, w2_f7, w3_f7, w4_f7,
           w5_f7, w6_f7, w7_f7, w8_f7 : signed(7 downto 0) := (others => '0');

    -- 8 outputs (one per filter)
    signal out_f0, out_f1, out_f2, out_f3,
           out_f4, out_f5, out_f6, out_f7 : signed(31 downto 0);

begin

    ------------------------------------------------------------
    -- Instantiate DUT
    ------------------------------------------------------------
    uut: entity work.conv3x3_8filters
        port map(
            clk    => clk,    rst    => rst,
            pixel0 => pixel0, pixel1 => pixel1, pixel2 => pixel2,
            pixel3 => pixel3, pixel4 => pixel4, pixel5 => pixel5,
            pixel6 => pixel6, pixel7 => pixel7, pixel8 => pixel8,
            w0_f0=>w0_f0, w1_f0=>w1_f0, w2_f0=>w2_f0,
            w3_f0=>w3_f0, w4_f0=>w4_f0, w5_f0=>w5_f0,
            w6_f0=>w6_f0, w7_f0=>w7_f0, w8_f0=>w8_f0,
            w0_f1=>w0_f1, w1_f1=>w1_f1, w2_f1=>w2_f1,
            w3_f1=>w3_f1, w4_f1=>w4_f1, w5_f1=>w5_f1,
            w6_f1=>w6_f1, w7_f1=>w7_f1, w8_f1=>w8_f1,
            w0_f2=>w0_f2, w1_f2=>w1_f2, w2_f2=>w2_f2,
            w3_f2=>w3_f2, w4_f2=>w4_f2, w5_f2=>w5_f2,
            w6_f2=>w6_f2, w7_f2=>w7_f2, w8_f2=>w8_f2,
            w0_f3=>w0_f3, w1_f3=>w1_f3, w2_f3=>w2_f3,
            w3_f3=>w3_f3, w4_f3=>w4_f3, w5_f3=>w5_f3,
            w6_f3=>w6_f3, w7_f3=>w7_f3, w8_f3=>w8_f3,
            w0_f4=>w0_f4, w1_f4=>w1_f4, w2_f4=>w2_f4,
            w3_f4=>w3_f4, w4_f4=>w4_f4, w5_f4=>w5_f4,
            w6_f4=>w6_f4, w7_f4=>w7_f4, w8_f4=>w8_f4,
            w0_f5=>w0_f5, w1_f5=>w1_f5, w2_f5=>w2_f5,
            w3_f5=>w3_f5, w4_f5=>w4_f5, w5_f5=>w5_f5,
            w6_f5=>w6_f5, w7_f5=>w7_f5, w8_f5=>w8_f5,
            w0_f6=>w0_f6, w1_f6=>w1_f6, w2_f6=>w2_f6,
            w3_f6=>w3_f6, w4_f6=>w4_f6, w5_f6=>w5_f6,
            w6_f6=>w6_f6, w7_f6=>w7_f6, w8_f6=>w8_f6,
            w0_f7=>w0_f7, w1_f7=>w1_f7, w2_f7=>w2_f7,
            w3_f7=>w3_f7, w4_f7=>w4_f7, w5_f7=>w5_f7,
            w6_f7=>w6_f7, w7_f7=>w7_f7, w8_f7=>w8_f7,
            out_f0=>out_f0, out_f1=>out_f1,
            out_f2=>out_f2, out_f3=>out_f3,
            out_f4=>out_f4, out_f5=>out_f5,
            out_f6=>out_f6, out_f7=>out_f7
        );

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
    -- Stimulus
    --
    -- From Python (patch at row=5, col=4):
    --   patch9 = [0, 0, 0, 0, 0, 0, 0, 0, 84]
    --
    -- Expected outputs (real trained weights, pre-bias pre-ReLU):
    --   out_f0 =  2688
    --   out_f1 =  7644
    --   out_f2 = -8988
    --   out_f3 =  2100
    --   out_f4 =  5712
    --   out_f5 =  8988
    --   out_f6 = -3360
    --   out_f7 =  1260
    --
    -- Result valid after 9 clock cycles = 90 ns
    -- We wait 100 ns after inputs for safety
    -- Total: check waveform at t = 120 ns
    ------------------------------------------------------------
    stim_proc: process
    begin
        -- Reset
        rst <= '1';
        wait for 20 ns;
        rst <= '0';

        -- Pixels: patch9 = [0, 0, 0, 0, 0, 0, 0, 0, 84]
        pixel0 <= to_signed(0,  8);
        pixel1 <= to_signed(0,  8);
        pixel2 <= to_signed(0,  8);
        pixel3 <= to_signed(0,  8);
        pixel4 <= to_signed(0,  8);
        pixel5 <= to_signed(0,  8);
        pixel6 <= to_signed(0,  8);
        pixel7 <= to_signed(0,  8);
        pixel8 <= to_signed(84, 8);

        -- Filter 0: [83, -34, -35, 57, 23, 55, 100, 63, 32]
        -- Expected out_f0 = 2688   (84 * 32 = 2688)
        w0_f0 <= to_signed(83,  8);  w1_f0 <= to_signed(-34, 8);
        w2_f0 <= to_signed(-35, 8);  w3_f0 <= to_signed(57,  8);
        w4_f0 <= to_signed(23,  8);  w5_f0 <= to_signed(55,  8);
        w6_f0 <= to_signed(100, 8);  w7_f0 <= to_signed(63,  8);
        w8_f0 <= to_signed(32,  8);

        -- Filter 1: [33, 25, 78, 59, 93, 13, 85, 45, 91]
        -- Expected out_f1 = 7644   (84 * 91 = 7644)
        w0_f1 <= to_signed(33, 8);  w1_f1 <= to_signed(25, 8);
        w2_f1 <= to_signed(78, 8);  w3_f1 <= to_signed(59, 8);
        w4_f1 <= to_signed(93, 8);  w5_f1 <= to_signed(13, 8);
        w6_f1 <= to_signed(85, 8);  w7_f1 <= to_signed(45, 8);
        w8_f1 <= to_signed(91, 8);

        -- Filter 2: [78, 50, 86, 50, -10, 4, -18, -23, -107]
        -- Expected out_f2 = -8988  (84 * -107 = -8988)
        w0_f2 <= to_signed(78,   8);  w1_f2 <= to_signed(50,  8);
        w2_f2 <= to_signed(86,   8);  w3_f2 <= to_signed(50,  8);
        w4_f2 <= to_signed(-10,  8);  w5_f2 <= to_signed(4,   8);
        w6_f2 <= to_signed(-18,  8);  w7_f2 <= to_signed(-23, 8);
        w8_f2 <= to_signed(-107, 8);

        -- Filter 3: [25, 40, -108, 102, -30, -71, 78, 69, 25]
        -- Expected out_f3 = 2100   (84 * 25 = 2100)
        w0_f3 <= to_signed(25,   8);  w1_f3 <= to_signed(40,  8);
        w2_f3 <= to_signed(-108, 8);  w3_f3 <= to_signed(102, 8);
        w4_f3 <= to_signed(-30,  8);  w5_f3 <= to_signed(-71, 8);
        w6_f3 <= to_signed(78,   8);  w7_f3 <= to_signed(69,  8);
        w8_f3 <= to_signed(25,   8);

        -- Filter 4: [-27, -78, -104, 44, 13, 29, 93, 18, 68]
        -- Expected out_f4 = 5712   (84 * 68 = 5712)
        w0_f4 <= to_signed(-27,  8);  w1_f4 <= to_signed(-78, 8);
        w2_f4 <= to_signed(-104, 8);  w3_f4 <= to_signed(44,  8);
        w4_f4 <= to_signed(13,   8);  w5_f4 <= to_signed(29,  8);
        w6_f4 <= to_signed(93,   8);  w7_f4 <= to_signed(18,  8);
        w8_f4 <= to_signed(68,   8);

        -- Filter 5: [-18, -100, -74, 47, 35, 59, 37, 63, 107]
        -- Expected out_f5 = 8988   (84 * 107 = 8988)
        w0_f5 <= to_signed(-18,  8);  w1_f5 <= to_signed(-100, 8);
        w2_f5 <= to_signed(-74,  8);  w3_f5 <= to_signed(47,   8);
        w4_f5 <= to_signed(35,   8);  w5_f5 <= to_signed(59,   8);
        w6_f5 <= to_signed(37,   8);  w7_f5 <= to_signed(63,   8);
        w8_f5 <= to_signed(107,  8);

        -- Filter 6: [-21, 19, 113, -74, -127, -10, 108, -27, -40]
        -- Expected out_f6 = -3360  (84 * -40 = -3360)
        w0_f6 <= to_signed(-21,  8);  w1_f6 <= to_signed(19,   8);
        w2_f6 <= to_signed(113,  8);  w3_f6 <= to_signed(-74,  8);
        w4_f6 <= to_signed(-127, 8);  w5_f6 <= to_signed(-10,  8);
        w6_f6 <= to_signed(108,  8);  w7_f6 <= to_signed(-27,  8);
        w8_f6 <= to_signed(-40,  8);

        -- Filter 7: [72, 7, 94, 66, 101, 11, 9, 60, 15]
        -- Expected out_f7 = 1260   (84 * 15 = 1260)
        w0_f7 <= to_signed(72,  8);  w1_f7 <= to_signed(7,   8);
        w2_f7 <= to_signed(94,  8);  w3_f7 <= to_signed(66,  8);
        w4_f7 <= to_signed(101, 8);  w5_f7 <= to_signed(11,  8);
        w6_f7 <= to_signed(9,   8);  w7_f7 <= to_signed(60,  8);
        w8_f7 <= to_signed(15,  8);

        -- Wait 9 clock cycles + margin
        wait for 100 ns;

        -- Check all 8 outputs at t = 120 ns in Vivado waveform
        wait;
    end process;

end architecture sim;