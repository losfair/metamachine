library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.defs.all;
use work.builtin_microcode.all;

entity cpu is
  port (
    i_clk: in std_logic;
    o_leds: out std_logic_vector(31 downto 0)
  );
end cpu;

architecture impl of cpu is

  component execution_unit is
    port (
      i_clk: in std_logic;
      i_work: in std_logic;
      i_inst: in std_logic_vector(31 downto 0);
      i_gprs: in gprset_t;
      o_gprs: out gprset_t;
      o_gpr_update: out gprupdate_t;
      o_done: out std_logic;
      o_exception: out exception_t;
      o_br: out branch_t;
      o_br_target: out natural range 0 to MAX_MICROCODE
    );
  end component;

  signal microcode: microcode_t := BUILTIN_MICROCODE_WORDS;
  signal pc: natural range 0 to MAX_MICROCODE := 0;
  signal gprs: gprset_t := (others => (others => '0'));

  signal eu_tx: eucontrol_tx_array_t := (
    others => (
      work => '0',
      inst => (others => '0')
    )
  );
  signal eu_rx: eucontrol_rx_array_t;
  signal next_eu: natural range 0 to MAX_EU := 0;
  signal state: cpu_state_t := cpustate_exec;

begin
  o_leds <= (0 => gprs(0)(0), others => '0');
  eu_0: execution_unit
    port map(
      i_clk => i_clk,
      i_work => eu_tx(0).work,
      i_inst => eu_tx(0).inst,
      i_gprs => gprs,
      o_gprs => eu_rx(0).gprs,
      o_gpr_update => eu_rx(0).gpr_update,
      o_done => eu_rx(0).done,
      o_exception => eu_rx(0).exception,
      o_br => eu_rx(0).br,
      o_br_target => eu_rx(0).br_target
    );
  eu_1: execution_unit
    port map(
      i_clk => i_clk,
      i_work => eu_tx(1).work,
      i_inst => eu_tx(1).inst,
      i_gprs => gprs,
      o_gprs => eu_rx(1).gprs,
      o_gpr_update => eu_rx(1).gpr_update,
      o_done => eu_rx(1).done,
      o_exception => eu_rx(1).exception,
      o_br => eu_rx(1).br,
      o_br_target => eu_rx(1).br_target
    );
  eu_2: execution_unit
    port map(
      i_clk => i_clk,
      i_work => eu_tx(2).work,
      i_inst => eu_tx(2).inst,
      i_gprs => gprs,
      o_gprs => eu_rx(2).gprs,
      o_gpr_update => eu_rx(2).gpr_update,
      o_done => eu_rx(2).done,
      o_exception => eu_rx(2).exception,
      o_br => eu_rx(2).br,
      o_br_target => eu_rx(2).br_target
    );
  eu_3: execution_unit
    port map(
      i_clk => i_clk,
      i_work => eu_tx(3).work,
      i_inst => eu_tx(3).inst,
      i_gprs => gprs,
      o_gprs => eu_rx(3).gprs,
      o_gpr_update => eu_rx(3).gpr_update,
      o_done => eu_rx(3).done,
      o_exception => eu_rx(3).exception,
      o_br => eu_rx(3).br,
      o_br_target => eu_rx(3).br_target
    );
  eu_4: execution_unit
    port map(
      i_clk => i_clk,
      i_work => eu_tx(4).work,
      i_inst => eu_tx(4).inst,
      i_gprs => gprs,
      o_gprs => eu_rx(4).gprs,
      o_gpr_update => eu_rx(4).gpr_update,
      o_done => eu_rx(4).done,
      o_exception => eu_rx(4).exception,
      o_br => eu_rx(4).br,
      o_br_target => eu_rx(4).br_target
    );
  eu_5: execution_unit
    port map(
      i_clk => i_clk,
      i_work => eu_tx(5).work,
      i_inst => eu_tx(5).inst,
      i_gprs => gprs,
      o_gprs => eu_rx(5).gprs,
      o_gpr_update => eu_rx(5).gpr_update,
      o_done => eu_rx(5).done,
      o_exception => eu_rx(5).exception,
      o_br => eu_rx(5).br,
      o_br_target => eu_rx(5).br_target
    );

  process (i_clk) is
    variable v_stop_iter: std_logic;
  begin
    if rising_edge(i_clk) then
      case state is
        when cpustate_exec =>
          v_stop_iter := '0';

          for i in 0 to MAX_EU loop
            if v_stop_iter = '1' then
              exit;
            end if;
            eu_tx(i).work <= '1';
            eu_tx(i).inst <= microcode(pc + i);
            if microcode(pc + i)(31) = '0' or i = MAX_EU then
              pc <= pc + i + 1;
              v_stop_iter := '1';
              exit;
            end if;
          end loop;

          state <= cpustate_wait_for_completion;

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
          elsif eu_rx(4).exception /= exc_none then
            report "EXCEPTION on EU 4";
            state <= cpustate_halt;
          elsif eu_rx(5).exception /= exc_none then
            report "EXCEPTION on EU 5";
            state <= cpustate_halt;
          else
            for i in 0 to MAX_EU loop
              if eu_tx(i).work = '1' then
                for j in 0 to MAX_GPR loop
                  if eu_rx(i).gpr_update.modified(j) = '1' then
                    gprs(j) <= eu_rx(i).gprs(j);
                  end if;
                end loop;
                case eu_rx(i).br is
                  when br_none =>
                  when br_absolute =>
                    pc <= eu_rx(i).br_target;
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
