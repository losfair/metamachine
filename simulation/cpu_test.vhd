library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity cpu_test is
end cpu_test;

architecture impl of cpu_test is
    component cpu is
        port (
            i_clk : in std_logic
        );
    end component;
    signal clk : std_logic;
begin
    dut: cpu port map(clk);
    process begin
        clk <= '1';
        wait for 5 ns;
        clk <= '0';
        wait for 5 ns;
    end process;
end impl;
