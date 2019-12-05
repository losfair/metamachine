library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use work.defs.all;

entity unification is
  generic (
    max_src: natural
  );
  port (
    i_clk: in std_logic;
    i_src_update: in gprunification_update_t(0 to max_src);
    i_src: in gprunification_t(0 to max_src);
    i_br_state: in brunification_t(0 to max_src);
    i_pc_update_toggle: in std_logic;
    o_result: out gprset_t;
    o_update: out gprupdate_t;
    o_br_state: out brunification_item_t
  );
end unification;

architecture impl of unification is

  signal result: gprset_t := (others => (others => '0'));
  signal update: gprupdate_t := (modified => (others => '0'));
  signal br_state: brunification_item_t := (others => (br => br_none, br_target => 0, pc_update_toggle => '0'));

begin
  o_result <= result;
  o_update <= update;
  o_br_state <= br_state;

  process (i_clk) is
    variable local_update: gprupdate_t;
    variable local_br_state: brunification_item_t;
  begin
    if rising_edge(i_clk) then
      local_update := (modified => (others => '0'));
      local_br_state := (others => (br => br_none, br_target => 0, pc_update_toggle => i_pc_update_toggle));
      for i in 0 to max_src loop
        if i_pc_update_toggle = i_br_state(i).pc_update_toggle then
          for j in 0 to MAX_GPR loop
            if i_src_update(i).modified(j) = '1' then
              result(j) <= i_src(i)(j);
              local_update.modified(j) := '1';
            end if;
          end loop;
          case i_br_state(i).br is
            when br_none =>
            when br_absolute =>
              local_br_state.br <= br_absolute;
              local_br_state.br_target <= i_br_state(i).br_target;
          end case;
        end if;
      end loop;
      update <= local_update;
      br_state <= local_br_state;
    end if;
  end process;

end architecture;
