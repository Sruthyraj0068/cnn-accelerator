
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library work;
use work.cnn_pkg.all;
use work.weights_pkg.all;

entity cnn_top_tb is
end entity cnn_top_tb;

architecture sim of cnn_top_tb is

    constant CLK_PERIOD : time := 5 ns;  -- 200 MHz

    signal clk        : std_logic := '0';
    signal rst        : std_logic := '1';
    signal start      : std_logic := '0';
    signal done       : std_logic;
    signal pred_class : integer range 0 to 9;

begin

    -- ── Clock ─────────────────────────────────────────────────
    clk <= not clk after CLK_PERIOD/2;

    -- ── DUT ───────────────────────────────────────────────────
    DUT : entity work.cnn_top
        port map (
            clk        => clk,
            rst        => rst,
            start      => start,
            done       => done,
            pred_class => pred_class
        );

    -- ── Stimulus ──────────────────────────────────────────────
    process
    begin
        -- Reset
        rst   <= '1';
        start <= '0';
        wait for 20 ns;

        -- Release reset
        rst <= '0';
        wait for 10 ns;

        -- Start inference
        report "Starting CNN inference on TEST_IMAGE (digit 7)...";
        start <= '1';
        wait for CLK_PERIOD;
        start <= '0';

        -- Wait for done
        report "Waiting for inference to complete...";
        wait until done = '1';
        wait for CLK_PERIOD;

        -- Report result

        report "CNN Inference Complete";
        report "Predicted : " & integer'image(pred_class);
        report "Expected  : " & integer'image(EXPECTED_LABEL);


        if pred_class = EXPECTED_LABEL then
            report "RESULT: CORRECT " severity note;
        else
            report "RESULT: WRONG  got="
                   & integer'image(pred_class)
                   & " expected="
                   & integer'image(EXPECTED_LABEL)
                   severity error;
        end if;

        wait for 100 ns;
        report "Simulation complete";
        wait;
    end process;

end architecture sim;
