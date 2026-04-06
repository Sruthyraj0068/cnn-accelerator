library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ----------------------------------------------------------------
-- mac_dsp48
-- Single multiply-accumulate operation targeting DSP48E1 slice.
--
-- Operation (registered, 1 cycle latency):
--   acc_out <= resize(a_in * b_in, P_WIDTH) + acc_in
--
-- Generics:
--   A_WIDTH : width of a_in  (default 8)
--   B_WIDTH : width of b_in  (default 8)
--   P_WIDTH : width of acc_in and acc_out (default 32)
--
-- In dot9, this is instantiated as:
--   generic map(A_WIDTH=>8, B_WIDTH=>8, P_WIDTH=>32)
--
-- For the adder tree in dot9, acc_in is tied to zero on mac0
-- and to the previous stage output on mac1..mac8.
--
-- Latency: 1 clock cycle
-- ----------------------------------------------------------------

entity mac_dsp48 is
    generic (
        A_WIDTH : integer := 8;
        B_WIDTH : integer := 8;
        P_WIDTH : integer := 32
    );
    port (
        clk     : in  std_logic;
        rst     : in  std_logic;
        a_in    : in  signed(A_WIDTH-1 downto 0);
        b_in    : in  signed(B_WIDTH-1 downto 0);
        acc_in  : in  signed(P_WIDTH-1 downto 0);
        acc_out : out signed(P_WIDTH-1 downto 0)
    );
end entity mac_dsp48;

architecture rtl of mac_dsp48 is

    signal mult_res : signed(A_WIDTH + B_WIDTH - 1 downto 0);
    signal add_res  : signed(P_WIDTH - 1 downto 0);

begin

    -- Combinational multiply
    mult_res <= a_in * b_in;

    -- Combinational accumulate
    add_res <= resize(mult_res, P_WIDTH) + acc_in;

    -- Registered output (1 pipeline stage)
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                acc_out <= (others => '0');
            else
                acc_out <= add_res;
            end if;
        end if;
    end process;

end architecture rtl;