library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use work.defs.all;

entity stage_commit is
  port (
    i_clk: in std_logic;
    i_gprs: in gprset_t;
    i_gpr_update: in gprupdate_t;
    i_br_state: in brunification_item_t;
    o_gprs: out gprset_t;
    o_pc: out pc_t;
    o_pc_update_toggle: out std_logic
  );
end stage_commit;

architecture impl of stage_commit is

  signal gprs: gprset_t := (others => (others => '0'));
  signal pc: pc_t := 0;
  signal pc_update_toggle: std_logic := '0';
  signal exception_lockup: std_logic := '0';

begin
  o_gprs <= gprs;
  o_pc <= pc;
  o_pc_update_toggle <= pc_update_toggle;

  process (i_clk) is begin
    if rising_edge(i_clk) then
      if exception_lockup = '1' then
      elsif i_br_state.pc_update_toggle = pc_update_toggle then
        for i in 0 to MAX_GPR loop
          if i_gpr_update.modified(i) = '1' then
            gprs(i) <= i_gprs(i);
          end if;
        end loop;
        if i_br_state.br = br_absolute then
          pc_update_toggle <= not pc_update_toggle;
          pc <= i_br_state.br_target;
        elsif i_br_state.br = br_exception then
          report "EXCEPTION";
          exception_lockup <= '1';
        end if;
      end if;
    end if;
  end process;
end architecture;

