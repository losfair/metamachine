library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use work.defs.all;

entity memory_sequencer is
  port (
    i_clk: in std_logic;
    i_work: in memory_work_array_t;
    o_result: out memory_result_array_t;

    i_backing_result: in memory_result_t;
    o_backing_work: out memory_work_t
  );
end memory_sequencer;

architecture impl of memory_sequencer is
  signal state: std_logic_vector(1 downto 0 ) := "00";
  signal out_index: natural range 0 to MAX_EU := 0;
  signal current_work: memory_work_t := EMPTY_MEMORY_WORK;
  signal result: memory_result_array_t := (others => EMPTY_MEMORY_RESULT);
begin
  o_backing_work <= current_work;
  o_result <= result;

  process (i_clk) is
    variable work_selected: std_logic;
  begin
    if rising_edge(i_clk) then
      case state is
        when "00" =>
          result(out_index) <= EMPTY_MEMORY_RESULT;
          work_selected := '0';
          for i in 0 to MAX_EU loop
            if work_selected = '1' then
              exit;
            end if;

            if i_work(i).work = '1' then
              -- report "Sequencer got task from " & integer'image(i);
              result(i).ack <= '1';
              out_index <= i;
              current_work <= i_work(i);
              state <= "01";
              work_selected := '1';
            end if;
          end loop;
        when "01" => 
          if i_backing_result.done = '1' then
            -- report "Task done from " & integer'image(out_index);
            result(out_index) <= i_backing_result;
            current_work <= EMPTY_MEMORY_WORK;
            state <= "00";
          end if;
        when others =>
      end case;
    end if;
  end process;

end architecture;
