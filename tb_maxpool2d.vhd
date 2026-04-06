library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_maxpool2d is
end tb_maxpool2d;

architecture sim of tb_maxpool2d is
    signal clk     : std_logic := '0';
    signal rst     : std_logic := '1';
    signal in00    : signed(31 downto 0) := (others => '0');
    signal in01    : signed(31 downto 0) := (others => '0');
    signal in10    : signed(31 downto 0) := (others => '0');
    signal in11    : signed(31 downto 0) := (others => '0');
    signal max_out : signed(31 downto 0);
begin

    uut: entity work.maxpool2d
        port map(clk=>clk, rst=>rst,
                 in00=>in00, in01=>in01,
                 in10=>in10, in11=>in11,
                 max_out=>max_out);

    clk_process: process
    begin
        while true loop
            clk <= '0'; wait for 5 ns;
            clk <= '1'; wait for 5 ns;
        end loop;
    end process;

    stim_proc: process
    begin
        rst <= '1'; wait for 20 ns;
        rst <= '0'; wait for 10 ns;

        -- Test 1: max = 100 (top-left)
        in00<=to_signed(100,32); in01<=to_signed(20,32);
        in10<=to_signed(30,32);  in11<=to_signed(10,32);
        wait for 20 ns;

        -- Test 2: max = 200 (top-right)
        in00<=to_signed(50,32);  in01<=to_signed(200,32);
        in10<=to_signed(30,32);  in11<=to_signed(10,32);
        wait for 20 ns;

        -- Test 3: max = 300 (bottom-left)
        in00<=to_signed(50,32);  in01<=to_signed(20,32);
        in10<=to_signed(300,32); in11<=to_signed(10,32);
        wait for 20 ns;

        -- Test 4: max = 400 (bottom-right)
        in00<=to_signed(50,32);  in01<=to_signed(20,32);
        in10<=to_signed(30,32);  in11<=to_signed(400,32);
        wait for 20 ns;

        -- Test 5: all negative → max = -10
        in00<=to_signed(-100,32); in01<=to_signed(-50,32);
        in10<=to_signed(-200,32); in11<=to_signed(-10,32);
        wait for 20 ns;

        -- Test 6: all equal → max = 42
        in00<=to_signed(42,32); in01<=to_signed(42,32);
        in10<=to_signed(42,32); in11<=to_signed(42,32);
        wait for 20 ns;

        -- Test 7: real Conv1 values → max = 3200
        in00<=to_signed(2688,32); in01<=to_signed(3200,32);
        in10<=to_signed(1500,32); in11<=to_signed(2900,32);
        wait for 20 ns;

        -- Test 8: large vs negative → max = 8988
        in00<=to_signed(-8988,32); in01<=to_signed(8988,32);
        in10<=to_signed(-3360,32); in11<=to_signed(1260,32);
        wait for 20 ns;

        wait;
    end process;
end architecture sim;