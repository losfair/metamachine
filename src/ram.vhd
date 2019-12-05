library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use work.defs.all;

entity ram is
  port (
    i_clk: in std_logic;
    i_work: in memory_work_t;
    o_result: out memory_result_t
  );
end ram;

architecture impl of ram is
  signal data: ram_t := (others => x"00");
  signal result: memory_result_t := EMPTY_MEMORY_RESULT;

  signal addr_in: natural range 0 to MAX_RAM := 0;

begin
  o_result <= result;
  addr_in <= to_integer(unsigned(i_work.addr(MAX_RAM_INDEX_BIT downto 0)));

  process (i_clk) is begin
    if rising_edge(i_clk) then
      if i_work.work = '1' then
        if i_work.m_write then
          case i_work.m_width is
            when "00" =>
              data(addr_in) <= i_work.data(7 downto 0);
            when "01" =>
              data(addr_in) <= i_work.data(7 downto 0);
              data(addr_in + 1) <= i_work.data(15 downto 8);
            when "10" =>
              data(addr_in) <= i_work.data(7 downto 0);
              data(addr_in + 1) <= i_work.data(15 downto 8);
              data(addr_in + 2) <= i_work.data(23 downto 16);
              data(addr_in + 3) <= i_work.data(31 downto 24);
            when "11" =>
              data(addr_in) <= i_work.data(7 downto 0);
              data(addr_in + 1) <= i_work.data(15 downto 8);
              data(addr_in + 2) <= i_work.data(23 downto 16);
              data(addr_in + 3) <= i_work.data(31 downto 24);
              data(addr_in + 4) <= i_work.data(39 downto 32);
              data(addr_in + 5) <= i_work.data(47 downto 40);
              data(addr_in + 6) <= i_work.data(55 downto 48);
              data(addr_in + 7) <= i_work.data(63 downto 56);
            when others =>
          end case;
        else
          case i_work.m_width is
            when "00" =>
              result.data(7 downto 0) <= data(addr_in);
            when "01" =>
              result.data(7 downto 0) <= data(addr_in);
              result.data(15 downto 8) <= data(addr_in + 1);
            when "10" =>
              result.data(7 downto 0) <= data(addr_in);
              result.data(15 downto 8) <= data(addr_in + 1);
              result.data(23 downto 16) <= data(addr_in + 2);
              result.data(31 downto 24) <= data(addr_in + 3);
            when "11" =>
              result.data(7 downto 0) <= data(addr_in);
              result.data(15 downto 8) <= data(addr_in + 1);
              result.data(23 downto 16) <= data(addr_in + 2);
              result.data(31 downto 24) <= data(addr_in + 3);
              result.data(39 downto 32) <= data(addr_in + 4);
              result.data(47 downto 40) <= data(addr_in + 5);
              result.data(55 downto 48) <= data(addr_in + 6);
              result.data(63 downto 56) <= data(addr_in + 7);
            when others =>
          end case;
        end if;
        result.done <= '1';
      else
        result <= EMPTY_MEMORY_RESULT;
      end if;
    end if;
  end process;
end architecture;
