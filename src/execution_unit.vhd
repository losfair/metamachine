library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.defs.all;

entity execution_unit is
  port (
    i_clk: in std_logic;
    i_work: in std_logic;
    i_inst: in std_logic_vector(31 downto 0);
    i_inline_data: in std_logic_vector(63 downto 0);
    i_gprs: in gprset_t;
    o_gprs: out gprset_t;
    o_gpr_update: out gprupdate_t;
    o_done: out std_logic;
    o_exception: out exception_t;
    o_br: out branch_t;
    o_br_offset: out natural range 0 to MAX_MICROCODE
  );
end execution_unit;

architecture impl of execution_unit is

  signal gprs: gprset_t := (others => (others => '0'));
  signal gpr_update: gprupdate_t := (modified => (others => '0'));
  signal exception: exception_t := exc_none;
  signal state: eu_state_t := eu_state_init;
  signal br: branch_t := br_none;
  signal br_offset: natural range 0 to MAX_MICROCODE := 0;

  procedure p_mov_with_width (
    signal s_width: in std_logic_vector(1 downto 0);
    signal s_dst: in std_logic_vector(MAX_GPR_INDEX_BIT downto 0);
    signal s_src: in std_logic_vector(MAX_GPR_INDEX_BIT downto 0);
    signal s_gprs_in: in gprset_t;
    signal s_gprs_out: out gprset_t;
    signal s_gpr_update: out gprupdate_t;
    signal s_exception: out exception_t
  ) is begin
    s_gpr_update.modified(to_integer(unsigned(s_dst))) <= '1';
    case s_width is
      when "00" => -- 8b
        s_gprs_out(to_integer(unsigned(s_dst)))(63 downto 8) <= (others => '0');
        s_gprs_out(to_integer(unsigned(s_dst)))(7 downto 0) <= s_gprs_in(to_integer(unsigned(s_src)))(7 downto 0);
      when "01" => -- 16b
        s_gprs_out(to_integer(unsigned(s_dst)))(63 downto 16) <= (others => '0');
        s_gprs_out(to_integer(unsigned(s_dst)))(15 downto 0) <= s_gprs_in(to_integer(unsigned(s_src)))(15 downto 0);
      when "10" => -- 32b
        s_gprs_out(to_integer(unsigned(s_dst)))(63 downto 32) <= (others => '0');
        s_gprs_out(to_integer(unsigned(s_dst)))(31 downto 0) <= s_gprs_in(to_integer(unsigned(s_src)))(31 downto 0);
      when "11" => -- 64b
        s_gprs_out(to_integer(unsigned(s_dst))) <= s_gprs_in(to_integer(unsigned(s_src)));
      when others =>
        s_exception <= exc_invalid_inst;
    end case;
  end p_mov_with_width;

begin

  o_gprs <= gprs;
  o_gpr_update <= gpr_update;
  o_done <= '1' when state = eu_state_done else '0';
  o_exception <= exception;
  o_br <= br;
  o_br_offset <= br_offset;

  process (i_clk) is begin
    if rising_edge(i_clk) then
      if i_work = '1' then
        case state is
          when eu_state_init =>
            case i_inst(30 downto 25) is
              when "000001" => -- nop
                state <= eu_state_done;
              when "000010" => -- mov
                if i_inst(24 downto 21) = "0000" or i_gprs(to_integer(unsigned(i_inst(5 downto 0))))(3 downto 0) = i_inst(24 downto 21) then
                  p_mov_with_width(i_inst(20 downto 19), i_inst(18 downto 13), i_inst(12 downto 7), i_gprs, gprs, gpr_update, exception);
                end if;
                state <= eu_state_done;
              when "111000" => -- ldconst
                -- bit 24 is used by dispatcher
                gprs(to_integer(unsigned(i_inst(23 downto 18)))) <= i_inline_data;
                state <= eu_state_done;
              when "000011" => -- add
                gprs(to_integer(unsigned(i_inst(24 downto 19)))) <= std_logic_vector(unsigned(i_gprs(to_integer(unsigned(i_inst(18 downto 13))))) + unsigned(i_gprs(to_integer(unsigned(i_inst(12 downto 7))))));
                gpr_update.modified(to_integer(unsigned(i_inst(24 downto 19)))) <= '1';
                state <= eu_state_done;
              when "000100" => -- sub
                gprs(to_integer(unsigned(i_inst(24 downto 19)))) <= std_logic_vector(unsigned(i_gprs(to_integer(unsigned(i_inst(18 downto 13))))) - unsigned(i_gprs(to_integer(unsigned(i_inst(12 downto 7))))));
                gpr_update.modified(to_integer(unsigned(i_inst(24 downto 19)))) <= '1';
                state <= eu_state_done;
              when "000101" => -- br
                if i_inst(24 downto 21) = "0000" or i_gprs(to_integer(unsigned(i_inst(5 downto 0))))(3 downto 0) = i_inst(24 downto 21) then
                  if i_inst(20) = '0' then -- branch forward
                    br <= br_forward;
                  else -- branch backward
                    br <= br_backward;
                  end if;
                  if i_inst(19) = '0' then -- direct branch
                    br_offset <= to_integer(unsigned(i_inst((7 + MAX_MICROCODE_INDEX_BIT) downto 7))); -- 12b operand
                  else -- indirect branch
                    br_offset <= to_integer(unsigned(i_gprs(to_integer(unsigned(i_inst(18 downto 13))))(MAX_MICROCODE_INDEX_BIT downto 0)));
                  end if;
                end if;
                state <= eu_state_done;
              when "111111" => -- debug print
                report "[debug] " & integer'image(to_integer(unsigned(gprs(to_integer(unsigned(i_inst(24 downto 19)))))));
                state <= eu_state_done;
              when others =>
                exception <= exc_invalid_inst;
                state <= eu_state_done;
            end case;
          when eu_state_done =>
          when others =>
              exception <= exc_eu_internal;
        end case;
      else
        state <= eu_state_init;
        exception <= exc_none;
        br <= br_none;
        gpr_update <= (modified => (others => '0'));
      end if;
    end if;
  end process;

end architecture;
