library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.cnn_pkg.all;

entity dot9 is
    port (
        clk   : in  std_logic;
        rst   : in  std_logic;
        start : in  std_logic;
        acts  : in  act_vec_t;
        ws    : in  weight_vec_t;
        valid : out std_logic;
        psum  : out signed(ACC_WIDTH-1 downto 0)
    );
end entity dot9;

architecture rtl of dot9 is

    constant PROD_WIDTH : integer := ACT_WIDTH + WEIGHT_WIDTH;
    constant LV1_WIDTH  : integer := PROD_WIDTH + 1;
    constant LV2_WIDTH  : integer := PROD_WIDTH + 2;
    constant LV3_WIDTH  : integer := PROD_WIDTH + 3;
    constant LV4_WIDTH  : integer := PROD_WIDTH + 4;

    signal acts_r : act_vec_t;
    signal ws_r   : weight_vec_t;

    -- ── Stage 1: Multipliers ──────────────────────────────────
    type prod_vec_t is array(0 to 8) of signed(PROD_WIDTH-1 downto 0);
    signal prod_c : prod_vec_t;
    signal prod_r : prod_vec_t;

    -- ── Stage 2: Adder Level 1 (9→5, 17-bit) ─────────────────
    type lv1_vec_t is array(0 to 4) of signed(LV1_WIDTH-1 downto 0);
    signal lv1_r : lv1_vec_t;

    -- ── Stage 3: Adder Level 2 (5→3, 18-bit) ─────────────────
    type lv2_vec_t is array(0 to 2) of signed(LV2_WIDTH-1 downto 0);
    signal lv2_r : lv2_vec_t;

    -- ── Stage 4: Adder Level 3 (3→2, 19-bit) ─────────────────
    type lv3_vec_t is array(0 to 1) of signed(LV3_WIDTH-1 downto 0);
    signal lv3_r : lv3_vec_t;

    -- ── Stage 5: Final sum ────────────────────────────────────
    signal psum_r   : signed(ACC_WIDTH-1 downto 0);
    signal valid_sr : std_logic_vector(DOT9_LATENCY downto 0)
                    := (others => '0');

    -- ✅ ALL signals declared above BEFORE attributes below
    attribute use_dsp : string;
    attribute use_dsp of prod_c : signal is "yes"; -- → DSP48E1
    attribute use_dsp of lv1_r  : signal is "no";  -- → LUT/CARRY4
    attribute use_dsp of lv2_r  : signal is "no";  -- → LUT/CARRY4
    attribute use_dsp of lv3_r  : signal is "no";  -- → LUT/CARRY4

begin

    -- ── Valid shift register ──────────────────────────────────
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                valid_sr <= (others => '0');
            else
                valid_sr <= valid_sr(DOT9_LATENCY-1 downto 0) & start;
            end if;
        end if;
    end process;

    valid <= valid_sr(DOT9_LATENCY);

    -- ── Stage 0: Input registers ─────────────────────────────
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                acts_r <= (others => (others => '0'));
                ws_r   <= (others => (others => '0'));
            elsif start = '1' then
                acts_r <= acts;
                ws_r   <= ws;
            end if;
        end if;
    end process;

    -- ── Stage 1: Combinational multiply (DSP48E1) ────────────
    gen_mult : for i in 0 to 8 generate
        prod_c(i) <= acts_r(i) * ws_r(i);
    end generate;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                prod_r <= (others => (others => '0'));
            else
                prod_r <= prod_c;
            end if;
        end if;
    end process;

    -- ── Stage 2: Adder level 1 (LUT/CARRY4) ──────────────────
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                lv1_r <= (others => (others => '0'));
            else
                lv1_r(0) <= resize(prod_r(0), LV1_WIDTH)
                           + resize(prod_r(1), LV1_WIDTH);
                lv1_r(1) <= resize(prod_r(2), LV1_WIDTH)
                           + resize(prod_r(3), LV1_WIDTH);
                lv1_r(2) <= resize(prod_r(4), LV1_WIDTH)
                           + resize(prod_r(5), LV1_WIDTH);
                lv1_r(3) <= resize(prod_r(6), LV1_WIDTH)
                           + resize(prod_r(7), LV1_WIDTH);
                lv1_r(4) <= resize(prod_r(8), LV1_WIDTH);
            end if;
        end if;
    end process;

    -- ── Stage 3: Adder level 2 (LUT/CARRY4) ──────────────────
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                lv2_r <= (others => (others => '0'));
            else
                lv2_r(0) <= resize(lv1_r(0), LV2_WIDTH)
                           + resize(lv1_r(1), LV2_WIDTH);
                lv2_r(1) <= resize(lv1_r(2), LV2_WIDTH)
                           + resize(lv1_r(3), LV2_WIDTH);
                lv2_r(2) <= resize(lv1_r(4), LV2_WIDTH);
            end if;
        end if;
    end process;

    -- ── Stage 4: Adder level 3 (LUT/CARRY4) ──────────────────
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                lv3_r <= (others => (others => '0'));
            else
                lv3_r(0) <= resize(lv2_r(0), LV3_WIDTH)
                           + resize(lv2_r(1), LV3_WIDTH);
                lv3_r(1) <= resize(lv2_r(2), LV3_WIDTH);
            end if;
        end if;
    end process;

    -- ── Stage 5: Final addition ───────────────────────────────
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                psum_r <= (others => '0');
            else
                psum_r <= resize(
                    resize(lv3_r(0), LV4_WIDTH) +
                    resize(lv3_r(1), LV4_WIDTH),
                    ACC_WIDTH);
            end if;
        end if;
    end process;

    psum <= psum_r;

end architecture rtl;