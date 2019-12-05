library IEEE;
use IEEE.std_logic_1164.all;

package defs is
    constant MAX_MICROCODE: natural := 16383;
    constant MAX_MICROCODE_INDEX_BIT: natural := 13; -- 13 downto 0
    constant MAX_GPR: natural := 63;
    constant MAX_GPR_INDEX_BIT: natural := 5; -- 5 downto 0
    constant MAX_GPR_SIZE_BIT: natural := 5; -- 5 downto 0
    constant MAX_EU: natural := 3;

    type microcode_t is array (0 to MAX_MICROCODE) of std_logic_vector(31 downto 0);
    subtype pc_t is natural range 0 to MAX_MICROCODE;
    subtype gpr_t is std_logic_vector(63 downto 0);
    type gprset_t is array (0 to MAX_GPR) of gpr_t;
    type gprupdate_t is record
        modified: std_logic_vector(0 to MAX_GPR);
    end record;
    type gprunification_t is array (natural range <>) of gprset_t;
    type gprunification_update_t is array (natural range <>) of gprupdate_t;
    type eu_state_t is (eu_state_none, eu_state_init, eu_state_done);
    type exception_t is (exc_none, exc_eu_internal, exc_div_by_zero, exc_invalid_inst);
    type branch_t is (br_none, br_absolute, br_exception);
    type cpu_state_t is (cpustate_halt, cpustate_exec, cpustate_wait_for_completion);
    type brunification_item_t is record
        br: branch_t;
        br_target: pc_t;
        pc_update_toggle: std_logic;
    end record;
    type brunification_t is array (natural range <>) of brunification_item_t;
    subtype opcode_t is std_logic_vector(5 downto 0);
    subtype gprindex_t is natural range 0 to MAX_GPR;
    subtype condition_t is std_logic_vector(3 downto 0);

    type eucontrol_tx_t is record
        work: std_logic;
        inst: std_logic_vector(31 downto 0);
        pc_update_toggle: std_logic;
    end record;
    type eucontrol_tx_array_t is array (0 to MAX_EU) of eucontrol_tx_t;

    constant ALL_ZEROS: gpr_t := (others => '0');
    constant ALL_ONES: gpr_t := (others => '1');
    
end package defs;
