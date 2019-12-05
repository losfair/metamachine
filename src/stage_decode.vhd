library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use work.defs.all;

entity stage_decode is
  port (
    i_clk: in std_logic;
    i_real_pc: in pc_t;
    i_pc_update_toggle: in std_logic;
    o_eu_tx: out eucontrol_tx_array_t
  );
end stage_decode;

architecture impl of stage_decode is
  signal eu_tx: eucontrol_tx_array_t := (
    others => (
      work => '0',
      inst => (others => '0')
    )
  );
  signal pc: pc_t := 0;
  signal pc_update
  signal microcode: microcode_t := BUILTIN_MICROCODE_WORDS;
begin
  o_eu_tx <= eu_tx;

  process (i_clk) is begin
    if rising_edge(i_clk) then
      eu_tx(0).work <= '1';
      eu_tx(0).inst <= microcode(pc);
      if microcode(pc)(31) = '0' then
        pc <= pc + 1;
      else
        eu_tx(1).work <= '1';
        eu_tx(1).inst <= microcode(pc + 1);
        if microcode(pc + 1)(31) = '0' then
        pc <= pc + 2;
        else
        eu_tx(2).work <= '1';
        eu_tx(2).inst <= microcode(pc + 2);
        if microcode(pc + 2)(31) = '0' then
          pc <= pc + 3;
        else
          eu_tx(3).work <= '1';
          eu_tx(3).inst <= microcode(pc + 3);
          pc <= pc + 4;
        end if;
        end if;
      end if;
    end if;
  end process;
end architecture;

