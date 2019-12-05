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

  signal real_pc: pc_t;
  signal eu_tx: eucontrol_tx_array_t;
  signal gprs: gprset_t;
  signal gprunification_update: gprunification_update_t(0 to 3);
  signal gprunification: gprunification_t(0 to 3);
  signal brunification: brunification_t(0 to 3);
  signal pc_update_toggle: std_logic;
  signal unified_gprs: gprset_t;
  signal unified_gpr_update: gprupdate_t;
  signal unified_br_state: brunification_item_t;

begin
  o_leds <= (0 => gprs(0)(0), others => '0');

  decode: stage_decode
    port map(
      i_clk => i_clk,
      i_real_pc => real_pc,
      i_pc_update_toggle => pc_update_toggle,
      o_eu_tx => eu_tx
    );

  unification: unification
    generic map(
      max_src => 3
    ),
    port map(
      i_clk => i_clk,
      i_src_update => gprunification_update,
      i_src => gprunification,
      i_br_state => brunification,
      i_pc_update_toggle => pc_update_toggle,
      o_result => unified_gprs,
      o_update => unified_gpr_update,
      o_br_state => unified_br_state
    );

  commit: stage_commit
    port map(
      i_clk => i_clk,
      i_gprs => unified_gprs,
      i_gpr_update => unified_gpr_update,
      i_br_state => unified_br_state,
      o_gprs => gprs,
      o_pc => real_pc,
      o_pc_update_toggle => pc_update_toggle
    );

  eu_0: execution_unit
    port map(
      i_clk => i_clk,
      i_work => eu_tx(0).work,
      i_inst => eu_tx(0).inst,
      i_gprs => gprs,
      i_pc_update_toggle => eu_tx
      o_gprs => gprunification(0),
      o_gpr_update => gprunification_update(0),
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

end architecture;
