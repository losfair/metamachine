library IEEE;
use IEEE.std_logic_1164.all;

package defs is
    constant MAX_MICROCODE: natural := 511;
    constant MAX_MICROCODE_INDEX_BIT: natural := 8; -- 8 downto 0
    constant MAX_GPR: natural := 63;
    constant MAX_GPR_INDEX_BIT: natural := 5; -- 5 downto 0
    constant MAX_EU: natural := 3;

    type microcode_t is array (0 to MAX_MICROCODE) of std_logic_vector(31 downto 0);
    type gprset_t is array (0 to MAX_GPR) of std_logic_vector(63 downto 0);
    type gprupdate_t is record
        modified: std_logic_vector(0 to MAX_GPR);
    end record;
    type eu_state_t is (eu_state_none, eu_state_init, eu_state_done);
    type exception_t is (exc_none, exc_eu_internal, exc_div_by_zero, exc_invalid_inst);
    type branch_t is (br_none, br_backward, br_forward);
    type cpu_state_t is (cpustate_halt, cpustate_exec, cpustate_wait_for_completion);

    type eucontrol_tx_t is record
        work: std_logic;
        inst: std_logic_vector(31 downto 0);
        inline_data: std_logic_vector(63 downto 0);
    end record;
    type eucontrol_rx_t is record
        gprs: gprset_t;
        gpr_update: gprupdate_t;
        done: std_logic;
        exception: exception_t;
        br: branch_t;
        br_offset: natural range 0 to MAX_MICROCODE;
    end record;
    type eucontrol_tx_array_t is array (0 to MAX_EU) of eucontrol_tx_t;
    type eucontrol_rx_array_t is array (0 to MAX_EU) of eucontrol_rx_t;
    
end package defs;
