library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.defs.all;

entity cpu is
  port (
    i_clk: in std_logic
  );
end cpu;

architecture impl of cpu is

  component execution_unit is
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
  end component;

  signal microcode: microcode_t := (
    0 => (31 => '1', 25 => '1', others => '0'),
    others => (others => '0')
  );
  signal pc: natural range 0 to MAX_MICROCODE := 0;
  signal gprs: gprset_t := (others => (others => '0'));

  signal eu_tx: eucontrol_tx_array_t := (
    others => (
      work => '0',
      inst => (others => '0'),
      inline_data => (others => '0')
    )
  );
  signal eu_rx: eucontrol_rx_array_t;
  signal next_eu: natural range 0 to MAX_EU := 0;
  signal state: cpu_state_t := cpustate_exec;

begin
  eu_0: execution_unit
    port map(
      i_clk => i_clk,
      i_work => eu_tx(0).work,
      i_inst => eu_tx(0).inst,
      i_inline_data => eu_tx(0).inline_data,
      i_gprs => gprs,
      o_gprs => eu_rx(0).gprs,
      o_gpr_update => eu_rx(0).gpr_update,
      o_done => eu_rx(0).done,
      o_exception => eu_rx(0).exception,
      o_br => eu_rx(0).br,
      o_br_offset => eu_rx(0).br_offset
    );
  eu_1: execution_unit
    port map(
      i_clk => i_clk,
      i_work => eu_tx(1).work,
      i_inst => eu_tx(1).inst,
      i_inline_data => eu_tx(1).inline_data,
      i_gprs => gprs,
      o_gprs => eu_rx(1).gprs,
      o_gpr_update => eu_rx(1).gpr_update,
      o_done => eu_rx(1).done,
      o_exception => eu_rx(1).exception,
      o_br => eu_rx(1).br,
      o_br_offset => eu_rx(1).br_offset
    );
  eu_2: execution_unit
    port map(
      i_clk => i_clk,
      i_work => eu_tx(2).work,
      i_inst => eu_tx(2).inst,
      i_inline_data => eu_tx(2).inline_data,
      i_gprs => gprs,
      o_gprs => eu_rx(2).gprs,
      o_gpr_update => eu_rx(2).gpr_update,
      o_done => eu_rx(2).done,
      o_exception => eu_rx(2).exception,
      o_br => eu_rx(2).br,
      o_br_offset => eu_rx(2).br_offset
    );
  eu_3: execution_unit
    port map(
      i_clk => i_clk,
      i_work => eu_tx(3).work,
      i_inst => eu_tx(3).inst,
      i_inline_data => eu_tx(3).inline_data,
      i_gprs => gprs,
      o_gprs => eu_rx(3).gprs,
      o_gpr_update => eu_rx(3).gpr_update,
      o_done => eu_rx(3).done,
      o_exception => eu_rx(3).exception,
      o_br => eu_rx(3).br,
      o_br_offset => eu_rx(3).br_offset
    );
  process (i_clk) is begin
    if rising_edge(i_clk) then
      case state is
        when cpustate_exec =>
          eu_tx(next_eu).work <= '1';
          eu_tx(next_eu).inst <= microcode(pc);

          if microcode(pc)(30 downto 24) = "1110000" then
            eu_tx(next_eu).inline_data(31 downto 0) <= microcode(pc + 1);
            eu_tx(next_eu).inline_data(63 downto 32) <= (others => '0');
            pc <= pc + 2;
          elsif microcode(pc)(30 downto 24) = "1110001" then
            eu_tx(next_eu).inline_data(31 downto 0) <= microcode(pc + 1);
            eu_tx(next_eu).inline_data(63 downto 32) <= microcode(pc + 2);
            pc <= pc + 3;
          else
            pc <= pc + 1;
          end if;

          if microcode(pc)(31) = '0' or next_eu = MAX_EU then
            state <= cpustate_wait_for_completion;
          else
            next_eu <= next_eu + 1;
          end if;
        when cpustate_wait_for_completion =>
          if
            (eu_tx(0).work = '1' and eu_rx(0).done = '0') or
            (eu_tx(1).work = '1' and eu_rx(1).done = '0') or
            (eu_tx(2).work = '1' and eu_rx(2).done = '0') or
            (eu_tx(3).work = '1' and eu_rx(3).done = '0') then
          elsif eu_rx(0).exception /= exc_none then
            report "EXCEPTION on EU 0";
            state <= cpustate_halt;
          elsif eu_rx(1).exception /= exc_none then
            report "EXCEPTION on EU 1";
            state <= cpustate_halt;
          elsif eu_rx(2).exception /= exc_none then
            report "EXCEPTION on EU 2";
            state <= cpustate_halt;
          elsif eu_rx(3).exception /= exc_none then
            report "EXCEPTION on EU 3";
            state <= cpustate_halt;
          else
            for i in 0 to MAX_EU loop
              if eu_tx(i).work = '1' then
                for j in 0 to MAX_GPR loop
                  if eu_rx(i).gpr_update.modified(j) = '1' then
                    gprs(j) <= eu_rx(i).gprs(i);
                  end if;
                end loop;
                case eu_rx(i).br is
                  when br_none =>
                  when br_backward =>
                    pc <= pc - eu_rx(i).br_offset;
                  when br_forward => 
                    pc <= pc + eu_rx(i).br_offset;
                end case;
                eu_tx(i).work <= '0';
              end if;
            end loop;
            next_eu <= 0;
            state <= cpustate_exec;
          end if;
        when cpustate_halt =>
        when others =>
      end case;
    end if;
  end process;

end architecture;
