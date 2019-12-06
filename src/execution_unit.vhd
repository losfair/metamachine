library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use work.defs.all;

entity execution_unit is
  port (
    i_clk: in std_logic;
    i_work: in std_logic;
    i_inst: in std_logic_vector(31 downto 0);
    i_gprs: in gprset_t;
    i_memory_result: in memory_result_t;
    o_gprs: out gprset_t;
    o_gpr_update: out gprupdate_t;
    o_done: out std_logic;
    o_exception: out exception_t;
    o_br: out branch_t;
    o_br_target: out natural range 0 to MAX_MICROCODE;
    o_memory_work: out memory_work_t
  );
end execution_unit;

architecture impl of execution_unit is

  signal gprs: gprset_t := (others => (others => '0'));
  signal gpr_update: gprupdate_t := (modified => (others => '0'));
  signal exception: exception_t := exc_none;
  signal state: eu_state_t := eu_state_init;
  signal br: branch_t := br_none;
  signal br_target: natural range 0 to MAX_MICROCODE := 0;
  signal memory_work: memory_work_t := EMPTY_MEMORY_WORK;

  signal s_zero: gpr_t := (others => '0');
  signal s_one: gpr_t := (others => '1');

  signal s_ins_opcode: opcode_t;
  signal s_ins_opcode_condmask: condition_t;
  signal s_ins_opcode_16b_0: std_logic_vector(15 downto 0);
  signal s_ins_ldconst_dst: gprindex_t;
  signal s_ins_arith_dst: gprindex_t;
  signal s_ins_arith_src1: gprindex_t;
  signal s_ins_arith_src2: gprindex_t;
  signal s_ins_arith_width: std_logic_vector(1 downto 0);
  signal s_ins_arith_signed: std_logic;
  signal s_ins_memory_gpr: gprindex_t;
  signal s_ins_memory_addrreg: gprindex_t;
  signal s_ins_memory_width: std_logic_vector(1 downto 0);
  signal s_ins_memory_offset: std_logic_vector(10 downto 0);

  signal s_reg_opcode_cond: condition_t;
  signal s_reg_cond_match: std_logic;
  signal s_reg_arith_src1: gpr_t;
  signal s_reg_arith_src2: gpr_t;
  signal s_reg_arith_src1_sext: gpr_t;
  signal s_reg_arith_src2_sext: gpr_t;
  signal s_reg_arith_add: gpr_t;
  signal s_reg_arith_sub: gpr_t;
  signal s_reg_arith_xor: gpr_t;
  signal s_reg_arith_and: gpr_t;
  signal s_reg_arith_or: gpr_t;
  signal s_reg_arith_eq: std_logic;
  signal s_reg_arith_lt_s: std_logic;
  signal s_reg_arith_lt_u: std_logic;
  signal s_reg_arith_gt_s: std_logic;
  signal s_reg_arith_gt_u: std_logic;
  signal s_reg_arith_cmp_s: condition_t;
  signal s_reg_arith_cmp_u: condition_t;
  signal s_reg_arith_cmp: condition_t;
  signal s_reg_arith_shl: gpr_t;
  signal s_reg_arith_shr_u: gpr_t;
  signal s_reg_arith_shr_s: gpr_t;
  signal s_reg_arith_shr: gpr_t;
  signal s_reg_memory_addr: gpr_t;

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
    end case;
  end p_mov_with_width;

  procedure sext(
    signal s_dst: in gprindex_t;
    signal s_src: in gpr_t;
    signal s_width: in std_logic_vector(1 downto 0);
    signal s_gprs_out: out gprset_t;
    signal s_gpr_update: out gprupdate_t
  ) is begin
    s_gpr_update.modified(s_dst) <= '1';
    case s_width is
      when "00" => -- 8b
        if s_src(7) = '1' then
          s_gprs_out(s_dst) <= ALL_ONES(63 downto 8) & s_src(7 downto 0);
        else
          s_gprs_out(s_dst) <= ALL_ZEROS(63 downto 8) & s_src(7 downto 0);
        end if;
      when "01" => -- 16b
        if s_src(15) = '1' then
          s_gprs_out(s_dst) <= ALL_ONES(63 downto 16) & s_src(15 downto 0);
        else
          s_gprs_out(s_dst) <= ALL_ZEROS(63 downto 16) & s_src(15 downto 0);
        end if;
      when "10" => -- 32b
        if s_src(31) = '1' then
          s_gprs_out(s_dst) <= ALL_ONES(63 downto 32) & s_src(31 downto 0);
        else
          s_gprs_out(s_dst) <= ALL_ZEROS(63 downto 32) & s_src(31 downto 0);
        end if;
      when "11" => -- 64b
        s_gprs_out(s_dst) <= s_src;
      when others =>
    end case;
  end sext;

begin

  o_gprs <= gprs;
  o_gpr_update <= gpr_update;
  o_done <= '1' when state = eu_state_done else '0';
  o_exception <= exception;
  o_br <= br;
  o_br_target <= br_target;
  o_memory_work <= memory_work;

  s_ins_opcode <= i_inst(30 downto 25);
  s_ins_opcode_condmask <= i_inst(24 downto 21);
  s_ins_opcode_16b_0 <= i_inst(15 downto 0);
  s_ins_ldconst_dst <= to_integer(unsigned(i_inst(22 downto 17)));
  s_ins_arith_dst <= to_integer(unsigned(i_inst(24 downto 19)));
  s_ins_arith_src1 <= to_integer(unsigned(i_inst(18 downto 13)));
  s_ins_arith_src2 <= to_integer(unsigned(i_inst(12 downto 7)));
  s_ins_arith_signed <= i_inst(6);
  s_ins_arith_width <= i_inst(5 downto 4);
  s_ins_memory_gpr <= to_integer(unsigned(i_inst(24 downto 19)));
  s_ins_memory_addrreg <= to_integer(unsigned(i_inst(18 downto 13)));
  s_ins_memory_width <= i_inst(12 downto 11);
  s_ins_memory_offset <= i_inst(10 downto 0);
  
  s_reg_opcode_cond <= i_gprs(to_integer(unsigned(i_inst(5 downto 0))))(3 downto 0);
  s_reg_cond_match <= '1' when s_ins_opcode_condmask = "0000" else
    '1' when (s_reg_opcode_cond and s_ins_opcode_condmask) /= "0000" else
    '0';
  s_reg_arith_src1 <= i_gprs(s_ins_arith_src1);
  s_reg_arith_src2 <= i_gprs(s_ins_arith_src2);
  s_reg_arith_src1_sext <=
    s_reg_arith_src1 when s_ins_arith_width = "11" else
    ALL_ZEROS(63 downto 32) & s_reg_arith_src1(31 downto 0) when (s_ins_arith_width = "10" and s_reg_arith_src1(31) = '0') else
    ALL_ONES(63 downto 32) & s_reg_arith_src1(31 downto 0) when (s_ins_arith_width = "10" and s_reg_arith_src1(31) = '1') else
    ALL_ZEROS(63 downto 16) & s_reg_arith_src1(15 downto 0) when (s_ins_arith_width = "01" and s_reg_arith_src1(15) = '0') else
    ALL_ONES(63 downto 16) & s_reg_arith_src1(15 downto 0) when (s_ins_arith_width = "01" and s_reg_arith_src1(15) = '1') else
    ALL_ZEROS(63 downto 8) & s_reg_arith_src1(7 downto 0) when (s_ins_arith_width = "00" and s_reg_arith_src1(7) = '0') else
    ALL_ONES(63 downto 8) & s_reg_arith_src1(7 downto 0) when (s_ins_arith_width = "00" and s_reg_arith_src1(7) = '1');

  s_reg_arith_src2_sext <=
    s_reg_arith_src2 when s_ins_arith_width = "11" else
    ALL_ZEROS(63 downto 32) & s_reg_arith_src2(31 downto 0) when (s_ins_arith_width = "10" and s_reg_arith_src2(31) = '0') else
    ALL_ONES(63 downto 32) & s_reg_arith_src2(31 downto 0) when (s_ins_arith_width = "10" and s_reg_arith_src2(31) = '1') else
    ALL_ZEROS(63 downto 16) & s_reg_arith_src2(15 downto 0) when (s_ins_arith_width = "01" and s_reg_arith_src2(15) = '0') else
    ALL_ONES(63 downto 16) & s_reg_arith_src2(15 downto 0) when (s_ins_arith_width = "01" and s_reg_arith_src2(15) = '1') else
    ALL_ZEROS(63 downto 8) & s_reg_arith_src2(7 downto 0) when (s_ins_arith_width = "00" and s_reg_arith_src2(7) = '0') else
    ALL_ONES(63 downto 8) & s_reg_arith_src2(7 downto 0) when (s_ins_arith_width = "00" and s_reg_arith_src2(7) = '1');

  s_reg_arith_add <= std_logic_vector(unsigned(s_reg_arith_src1_sext) + unsigned(s_reg_arith_src2_sext));
  s_reg_arith_sub <= std_logic_vector(unsigned(s_reg_arith_src1_sext) - unsigned(s_reg_arith_src2_sext));
  s_reg_arith_xor <= s_reg_arith_src1_sext xor s_reg_arith_src2_sext;
  s_reg_arith_and <= s_reg_arith_src1_sext and s_reg_arith_src2_sext;
  s_reg_arith_or <= s_reg_arith_src1_sext or s_reg_arith_src2_sext;
  s_reg_arith_eq <= '1' when unsigned(s_reg_arith_src1_sext) = unsigned(s_reg_arith_src2_sext) else '0';
  s_reg_arith_lt_s <= '1' when signed(s_reg_arith_src1_sext) < signed(s_reg_arith_src2_sext) else '0';
  s_reg_arith_lt_u <= '1' when unsigned(s_reg_arith_src1_sext) < unsigned(s_reg_arith_src2_sext) else '0';
  s_reg_arith_gt_s <= '1' when signed(s_reg_arith_src1_sext) > signed(s_reg_arith_src2_sext) else '0';
  s_reg_arith_gt_u <= '1' when unsigned(s_reg_arith_src1_sext) > unsigned(s_reg_arith_src2_sext) else '0';
  s_reg_arith_cmp_s <= (
    0 => s_reg_arith_eq,
    1 => s_reg_arith_lt_s,
    2 => s_reg_arith_gt_s,
    others => '0'
  );
  s_reg_arith_cmp_u <= (
    0 => s_reg_arith_eq,
    1 => s_reg_arith_lt_u,
    2 => s_reg_arith_gt_u,
    others => '0'
  );
  s_reg_arith_cmp <= s_reg_arith_cmp_s when s_ins_arith_signed = '1' else s_reg_arith_cmp_u;

  s_reg_arith_shl <= (others => '0');
  s_reg_arith_shr_u <= (others => '0');
  s_reg_arith_shr_s <= (others => '0');
  s_reg_arith_shr <= s_reg_arith_shr_s when s_ins_arith_signed = '1' else s_reg_arith_shr_u;

  s_reg_memory_addr <= std_logic_vector(
    unsigned(i_gprs(s_ins_memory_addrreg)) + resize(unsigned(s_ins_memory_offset(10 downto 0)), 64)
  );
  
  process (i_clk) is begin
    if rising_edge(i_clk) then
      if i_work = '1' then
        case state is
          when eu_state_init =>
            -- report "EU got work: " & to_hstring(i_inst);
            case s_ins_opcode is
              when "000001" => -- nop
                state <= eu_state_done;
              when "000010" => -- mov
                if s_reg_cond_match = '1' then
                  p_mov_with_width(i_inst(20 downto 19), i_inst(18 downto 13), i_inst(12 downto 7), i_gprs, gprs, gpr_update, exception);
                end if;
                state <= eu_state_done;
              when "111000" => -- ldconst16
                case i_inst(24 downto 23) is
                  when "00" =>
                    gprs(s_ins_ldconst_dst)(15 downto 0) <= s_ins_opcode_16b_0;
                  when "01" =>
                    gprs(s_ins_ldconst_dst)(31 downto 16) <= s_ins_opcode_16b_0;
                  when "10" =>
                    gprs(s_ins_ldconst_dst)(47 downto 32) <= s_ins_opcode_16b_0;
                  when "11" =>
                    gprs(s_ins_ldconst_dst)(63 downto 48) <= s_ins_opcode_16b_0;
                  when others =>
                end case;
                gpr_update.modified(s_ins_ldconst_dst) <= '1';
                state <= eu_state_done;

              when "000011" => -- add
                sext(s_ins_arith_dst, s_reg_arith_add, s_ins_arith_width, gprs, gpr_update);
                state <= eu_state_done;
              when "000100" => -- sub
                sext(s_ins_arith_dst, s_reg_arith_sub, s_ins_arith_width, gprs, gpr_update);
                state <= eu_state_done;
              when "000101" => -- xor
                sext(s_ins_arith_dst, s_reg_arith_xor, s_ins_arith_width, gprs, gpr_update);
                state <= eu_state_done;
              when "000110" => -- and
                sext(s_ins_arith_dst, s_reg_arith_and, s_ins_arith_width, gprs, gpr_update);
                state <= eu_state_done;
              when "000111" => -- or
                sext(s_ins_arith_dst, s_reg_arith_or, s_ins_arith_width, gprs, gpr_update);
                state <= eu_state_done;
              when "001000" => -- shl
                sext(s_ins_arith_dst, s_reg_arith_shl, s_ins_arith_width, gprs, gpr_update);
                state <= eu_state_done;
              when "001001" => -- shr
                sext(s_ins_arith_dst, s_reg_arith_shr_s, s_ins_arith_width, gprs, gpr_update);
                state <= eu_state_done;

              when "010000" => -- cmp
                gprs(s_ins_arith_dst)(63 downto 4) <= (others => '0');
                gprs(s_ins_arith_dst)(3 downto 0) <= s_reg_arith_cmp;
                gpr_update.modified(s_ins_arith_dst) <= '1';
                state <= eu_state_done;
                
              when "010100" => -- br
                if s_reg_cond_match = '1' then
                  br <= br_absolute;
                  br_target <= to_integer(unsigned(i_inst((6 + MAX_MICROCODE_INDEX_BIT) downto 6)));
                end if;
                state <= eu_state_done;
              when "010101" => -- br_indirect
                if s_reg_cond_match = '1' then
                  br <= br_absolute;
                  br_target <= to_integer(unsigned(i_gprs(to_integer(unsigned(i_inst(20 downto 15))))(MAX_MICROCODE_INDEX_BIT downto 0)));
                end if;
                state <= eu_state_done;

              when "100000" => -- ldr
                state <= eu_state_ldr;

              when "100001" => -- str
                state <= eu_state_str;
                
              when "111111" => -- debug print
                report "[debug] " &
                  integer'image(to_integer(unsigned(i_inst(24 downto 17)))) & "/" &
                  integer'image(to_integer(unsigned(i_inst(16 downto 11)))) & ": " &
                  integer'image(to_integer(unsigned(i_gprs(to_integer(unsigned(i_inst(16 downto 11)))))));
                state <= eu_state_done;
              when others =>
                exception <= exc_invalid_inst;
                state <= eu_state_done;
            end case;
          when eu_state_ldr =>
          when eu_state_str =>
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
