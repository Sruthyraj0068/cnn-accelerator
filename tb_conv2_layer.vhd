library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_conv2_layer is
end tb_conv2_layer;

architecture sim of tb_conv2_layer is
    signal clk   : std_logic := '0';
    signal rst   : std_logic := '1';
    signal start : std_logic := '0';
    signal done  : std_logic;

    signal pixel0,pixel1,pixel2,pixel3,
           pixel4,pixel5,pixel6,pixel7,
           pixel8 : signed(31 downto 0) := (others=>'0');

    signal w8_f0,w8_f1,w8_f2,w8_f3,
           w8_f4,w8_f5,w8_f6,w8_f7,
           w8_f8,w8_f9,w8_f10,w8_f11,
           w8_f12,w8_f13,w8_f14,w8_f15 : signed(7 downto 0) := (others=>'0');

    signal w0_f0,w0_f1,w0_f2,w0_f3,
           w0_f4,w0_f5,w0_f6,w0_f7,
           w0_f8,w0_f9,w0_f10,w0_f11,
           w0_f12,w0_f13,w0_f14,w0_f15 : signed(7 downto 0) := (others=>'0');

    signal bias_f0,bias_f1,bias_f2,bias_f3,
           bias_f4,bias_f5,bias_f6,bias_f7,
           bias_f8,bias_f9,bias_f10,bias_f11,
           bias_f12,bias_f13,bias_f14,bias_f15 : signed(7 downto 0) := (others=>'0');

    signal out_f0,out_f1,out_f2,out_f3,
           out_f4,out_f5,out_f6,out_f7,
           out_f8,out_f9,out_f10,out_f11,
           out_f12,out_f13,out_f14,out_f15 : signed(31 downto 0);

begin

    uut: entity work.conv2_layer
        port map(
            clk=>clk, rst=>rst, start=>start, done=>done,
            pixel0=>pixel0, pixel1=>pixel1, pixel2=>pixel2,
            pixel3=>pixel3, pixel4=>pixel4, pixel5=>pixel5,
            pixel6=>pixel6, pixel7=>pixel7, pixel8=>pixel8,
            w0_f0=>w0_f0,   w0_f1=>w0_f1,   w0_f2=>w0_f2,
            w0_f3=>w0_f3,   w0_f4=>w0_f4,   w0_f5=>w0_f5,
            w0_f6=>w0_f6,   w0_f7=>w0_f7,   w0_f8=>w0_f8,
            w0_f9=>w0_f9,   w0_f10=>w0_f10, w0_f11=>w0_f11,
            w0_f12=>w0_f12, w0_f13=>w0_f13, w0_f14=>w0_f14,
            w0_f15=>w0_f15,
            w1_f0=>(others=>'0'),  w1_f1=>(others=>'0'),
            w1_f2=>(others=>'0'),  w1_f3=>(others=>'0'),
            w1_f4=>(others=>'0'),  w1_f5=>(others=>'0'),
            w1_f6=>(others=>'0'),  w1_f7=>(others=>'0'),
            w1_f8=>(others=>'0'),  w1_f9=>(others=>'0'),
            w1_f10=>(others=>'0'), w1_f11=>(others=>'0'),
            w1_f12=>(others=>'0'), w1_f13=>(others=>'0'),
            w1_f14=>(others=>'0'), w1_f15=>(others=>'0'),
            w2_f0=>(others=>'0'),  w2_f1=>(others=>'0'),
            w2_f2=>(others=>'0'),  w2_f3=>(others=>'0'),
            w2_f4=>(others=>'0'),  w2_f5=>(others=>'0'),
            w2_f6=>(others=>'0'),  w2_f7=>(others=>'0'),
            w2_f8=>(others=>'0'),  w2_f9=>(others=>'0'),
            w2_f10=>(others=>'0'), w2_f11=>(others=>'0'),
            w2_f12=>(others=>'0'), w2_f13=>(others=>'0'),
            w2_f14=>(others=>'0'), w2_f15=>(others=>'0'),
            w3_f0=>(others=>'0'),  w3_f1=>(others=>'0'),
            w3_f2=>(others=>'0'),  w3_f3=>(others=>'0'),
            w3_f4=>(others=>'0'),  w3_f5=>(others=>'0'),
            w3_f6=>(others=>'0'),  w3_f7=>(others=>'0'),
            w3_f8=>(others=>'0'),  w3_f9=>(others=>'0'),
            w3_f10=>(others=>'0'), w3_f11=>(others=>'0'),
            w3_f12=>(others=>'0'), w3_f13=>(others=>'0'),
            w3_f14=>(others=>'0'), w3_f15=>(others=>'0'),
            w4_f0=>(others=>'0'),  w4_f1=>(others=>'0'),
            w4_f2=>(others=>'0'),  w4_f3=>(others=>'0'),
            w4_f4=>(others=>'0'),  w4_f5=>(others=>'0'),
            w4_f6=>(others=>'0'),  w4_f7=>(others=>'0'),
            w4_f8=>(others=>'0'),  w4_f9=>(others=>'0'),
            w4_f10=>(others=>'0'), w4_f11=>(others=>'0'),
            w4_f12=>(others=>'0'), w4_f13=>(others=>'0'),
            w4_f14=>(others=>'0'), w4_f15=>(others=>'0'),
            w5_f0=>(others=>'0'),  w5_f1=>(others=>'0'),
            w5_f2=>(others=>'0'),  w5_f3=>(others=>'0'),
            w5_f4=>(others=>'0'),  w5_f5=>(others=>'0'),
            w5_f6=>(others=>'0'),  w5_f7=>(others=>'0'),
            w5_f8=>(others=>'0'),  w5_f9=>(others=>'0'),
            w5_f10=>(others=>'0'), w5_f11=>(others=>'0'),
            w5_f12=>(others=>'0'), w5_f13=>(others=>'0'),
            w5_f14=>(others=>'0'), w5_f15=>(others=>'0'),
            w6_f0=>(others=>'0'),  w6_f1=>(others=>'0'),
            w6_f2=>(others=>'0'),  w6_f3=>(others=>'0'),
            w6_f4=>(others=>'0'),  w6_f5=>(others=>'0'),
            w6_f6=>(others=>'0'),  w6_f7=>(others=>'0'),
            w6_f8=>(others=>'0'),  w6_f9=>(others=>'0'),
            w6_f10=>(others=>'0'), w6_f11=>(others=>'0'),
            w6_f12=>(others=>'0'), w6_f13=>(others=>'0'),
            w6_f14=>(others=>'0'), w6_f15=>(others=>'0'),
            w7_f0=>(others=>'0'),  w7_f1=>(others=>'0'),
            w7_f2=>(others=>'0'),  w7_f3=>(others=>'0'),
            w7_f4=>(others=>'0'),  w7_f5=>(others=>'0'),
            w7_f6=>(others=>'0'),  w7_f7=>(others=>'0'),
            w7_f8=>(others=>'0'),  w7_f9=>(others=>'0'),
            w7_f10=>(others=>'0'), w7_f11=>(others=>'0'),
            w7_f12=>(others=>'0'), w7_f13=>(others=>'0'),
            w7_f14=>(others=>'0'), w7_f15=>(others=>'0'),
            w8_f0=>w8_f0,   w8_f1=>w8_f1,   w8_f2=>w8_f2,
            w8_f3=>w8_f3,   w8_f4=>w8_f4,   w8_f5=>w8_f5,
            w8_f6=>w8_f6,   w8_f7=>w8_f7,   w8_f8=>w8_f8,
            w8_f9=>w8_f9,   w8_f10=>w8_f10, w8_f11=>w8_f11,
            w8_f12=>w8_f12, w8_f13=>w8_f13, w8_f14=>w8_f14,
            w8_f15=>w8_f15,
            bias_f0=>bias_f0,   bias_f1=>bias_f1,
            bias_f2=>bias_f2,   bias_f3=>bias_f3,
            bias_f4=>bias_f4,   bias_f5=>bias_f5,
            bias_f6=>bias_f6,   bias_f7=>bias_f7,
            bias_f8=>bias_f8,   bias_f9=>bias_f9,
            bias_f10=>bias_f10, bias_f11=>bias_f11,
            bias_f12=>bias_f12, bias_f13=>bias_f13,
            bias_f14=>bias_f14, bias_f15=>bias_f15,
            out_f0=>out_f0,   out_f1=>out_f1,
            out_f2=>out_f2,   out_f3=>out_f3,
            out_f4=>out_f4,   out_f5=>out_f5,
            out_f6=>out_f6,   out_f7=>out_f7,
            out_f8=>out_f8,   out_f9=>out_f9,
            out_f10=>out_f10, out_f11=>out_f11,
            out_f12=>out_f12, out_f13=>out_f13,
            out_f14=>out_f14, out_f15=>out_f15
        );

    clk_process: process
    begin
        while true loop
            clk <= '0'; wait for 5 ns;
            clk <= '1'; wait for 5 ns;
        end loop;
    end process;

    stim_proc: process
    begin
        -- Reset for 4 clock cycles (clock-aligned)
        rst <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        rst <= '0';

        -- One idle cycle after reset
        wait until rising_edge(clk);

        -- CYCLE 0: start=1, channel 0 (pixel8=21070)
        pixel8<=to_signed(21070,32);
        w8_f0<=to_signed(44,8);  w8_f1<=to_signed(-64,8);
        w8_f2<=to_signed(23,8);  w8_f3<=to_signed(-54,8);
        w8_f4<=to_signed(-6,8);  w8_f5<=to_signed(41,8);
        w8_f6<=to_signed(18,8);  w8_f7<=to_signed(-35,8);
        w8_f8<=to_signed(27,8);  w8_f9<=to_signed(-11,8);
        w8_f10<=to_signed(50,8); w8_f11<=to_signed(30,8);
        w8_f12<=to_signed(-50,8);w8_f13<=to_signed(-26,8);
        w8_f14<=to_signed(61,8); w8_f15<=to_signed(37,8);
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';

        -- CYCLE 1: channel 1 (pixel8=16565)
        pixel8<=to_signed(16565,32);
        w8_f0<=to_signed(42,8);  w8_f1<=to_signed(15,8);
        w8_f2<=to_signed(-30,8); w8_f3<=to_signed(-8,8);
        w8_f4<=to_signed(-21,8); w8_f5<=to_signed(42,8);
        w8_f6<=to_signed(19,8);  w8_f7<=to_signed(45,8);
        w8_f8<=to_signed(-2,8);  w8_f9<=to_signed(-5,8);
        w8_f10<=to_signed(49,8); w8_f11<=to_signed(-62,8);
        w8_f12<=to_signed(-56,8);w8_f13<=to_signed(73,8);
        w8_f14<=to_signed(15,8); w8_f15<=to_signed(-19,8);
        wait until rising_edge(clk);

        -- CYCLE 2: channel 2 (pixel8=13786)
        pixel8<=to_signed(13786,32);
        w8_f0<=to_signed(48,8);  w8_f1<=to_signed(15,8);
        w8_f2<=to_signed(3,8);   w8_f3<=to_signed(31,8);
        w8_f4<=to_signed(-28,8); w8_f5<=to_signed(4,8);
        w8_f6<=to_signed(18,8);  w8_f7<=to_signed(-2,8);
        w8_f8<=to_signed(-5,8);  w8_f9<=to_signed(22,8);
        w8_f10<=to_signed(46,8); w8_f11<=to_signed(-30,8);
        w8_f12<=to_signed(5,8);  w8_f13<=to_signed(8,8);
        w8_f14<=to_signed(13,8); w8_f15<=to_signed(-36,8);
        wait until rising_edge(clk);

        -- CYCLE 3: channel 3 (pixel8=24847)
        pixel8<=to_signed(24847,32);
        w8_f0<=to_signed(10,8);  w8_f1<=to_signed(1,8);
        w8_f2<=to_signed(1,8);   w8_f3<=to_signed(34,8);
        w8_f4<=to_signed(-35,8); w8_f5<=to_signed(-53,8);
        w8_f6<=to_signed(64,8);  w8_f7<=to_signed(-43,8);
        w8_f8<=to_signed(66,8);  w8_f9<=to_signed(52,8);
        w8_f10<=to_signed(14,8); w8_f11<=to_signed(-88,8);
        w8_f12<=to_signed(51,8); w8_f13<=to_signed(-60,8);
        w8_f14<=to_signed(70,8); w8_f15<=to_signed(40,8);
        wait until rising_edge(clk);

        -- CYCLE 4: channel 4 (pixel8=14358)
        pixel8<=to_signed(14358,32);
        w8_f0<=to_signed(1,8);   w8_f1<=to_signed(25,8);
        w8_f2<=to_signed(-3,8);  w8_f3<=to_signed(8,8);
        w8_f4<=to_signed(5,8);   w8_f5<=to_signed(24,8);
        w8_f6<=to_signed(-11,8); w8_f7<=to_signed(10,8);
        w8_f8<=to_signed(-21,8); w8_f9<=to_signed(42,8);
        w8_f10<=to_signed(7,8);  w8_f11<=to_signed(-36,8);
        w8_f12<=to_signed(0,8);  w8_f13<=to_signed(6,8);
        w8_f14<=to_signed(-18,8);w8_f15<=to_signed(-67,8);
        wait until rising_edge(clk);

        -- CYCLE 5: channel 5 (pixel8=0)
        pixel8<=to_signed(0,32);
        w8_f0<=to_signed(-26,8); w8_f1<=to_signed(-1,8);
        w8_f2<=to_signed(8,8);   w8_f3<=to_signed(0,8);
        w8_f4<=to_signed(-32,8); w8_f5<=to_signed(-47,8);
        w8_f6<=to_signed(-41,8); w8_f7<=to_signed(-2,8);
        w8_f8<=to_signed(12,8);  w8_f9<=to_signed(61,8);
        w8_f10<=to_signed(-63,8);w8_f11<=to_signed(24,8);
        w8_f12<=to_signed(127,8);w8_f13<=to_signed(-39,8);
        w8_f14<=to_signed(53,8); w8_f15<=to_signed(-14,8);
        wait until rising_edge(clk);

        -- CYCLE 6: channel 6 (pixel8=9856)
        pixel8<=to_signed(9856,32);
        w8_f0<=to_signed(17,8);  w8_f1<=to_signed(22,8);
        w8_f2<=to_signed(33,8);  w8_f3<=to_signed(25,8);
        w8_f4<=to_signed(37,8);  w8_f5<=to_signed(11,8);
        w8_f6<=to_signed(-4,8);  w8_f7<=to_signed(18,8);
        w8_f8<=to_signed(16,8);  w8_f9<=to_signed(-15,8);
        w8_f10<=to_signed(33,8); w8_f11<=to_signed(19,8);
        w8_f12<=to_signed(-33,8);w8_f13<=to_signed(30,8);
        w8_f14<=to_signed(-25,8);w8_f15<=to_signed(-48,8);
        wait until rising_edge(clk);

        -- CYCLE 7: channel 7 (pixel8=2869)
        pixel8<=to_signed(2869,32);
        w8_f0<=to_signed(-11,8); w8_f1<=to_signed(20,8);
        w8_f2<=to_signed(22,8);  w8_f3<=to_signed(16,8);
        w8_f4<=to_signed(38,8);  w8_f5<=to_signed(25,8);
        w8_f6<=to_signed(-7,8);  w8_f7<=to_signed(20,8);
        w8_f8<=to_signed(17,8);  w8_f9<=to_signed(40,8);
        w8_f10<=to_signed(3,8);  w8_f11<=to_signed(14,8);
        w8_f12<=to_signed(-33,8);w8_f13<=to_signed(40,8);
        w8_f14<=to_signed(-13,8);w8_f15<=to_signed(-51,8);
        wait until rising_edge(clk);

        -- All 8 channels fed, now wait for done pulse
        wait until done = '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        -- Expected outputs (bias=0, ReLU applied):
        --   out_f0  = 2683359   out_f1  = 0
        --   out_f2  = 399157    out_f3  = 409032
        --   out_f4  = 0         out_f5  = 822586
        --   out_f6  = 2314906   out_f7  = 0
        --   out_f8  = 2011683   out_f9  = 1850697
        --   out_f10 = 3281560   out_f11 = 0
        --   out_f12 = 0         out_f13 = 0
        --   out_f14 = 2910112   out_f15 = 0

        wait;
    end process;

end architecture sim;
