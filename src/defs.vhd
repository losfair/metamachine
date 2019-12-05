library IEEE;
use IEEE.std_logic_1164.all;

package defs is
    constant MAX_MICROCODE: natural := 16383;
    constant MAX_MICROCODE_INDEX_BIT: natural := 13; -- 13 downto 0
    constant MAX_GPR: natural := 63;
    constant MAX_GPR_INDEX_BIT: natural := 5; -- 5 downto 0
    constant MAX_GPR_SIZE_BIT: natural := 5; -- 5 downto 0
    constant MAX_EU: natural := 3;
    constant MAX_RAM: natural := 16383;
    constant MAX_RAM_INDEX_BIT: natural := 13;

    type microcode_t is array (0 to MAX_MICROCODE) of std_logic_vector(31 downto 0);
    subtype gpr_t is std_logic_vector(63 downto 0);
    type gprset_t is array (0 to MAX_GPR) of gpr_t;
    type gprupdate_t is record
        modified: std_logic_vector(0 to MAX_GPR);
    end record;
    type eu_state_t is (eu_state_none, eu_state_init, eu_state_ldr, eu_state_str, eu_state_done);
    type exception_t is (exc_none, exc_eu_internal, exc_div_by_zero, exc_invalid_inst, exc_memory_access);
    type branch_t is (br_none, br_absolute);
    type cpu_state_t is (cpustate_halt, cpustate_exec, cpustate_wait_for_completion);
    subtype opcode_t is std_logic_vector(5 downto 0);
    subtype gprindex_t is natural range 0 to MAX_GPR;
    subtype condition_t is std_logic_vector(3 downto 0);

    type eucontrol_tx_t is record
        work: std_logic;
        inst: std_logic_vector(31 downto 0);
    end record;
    type eucontrol_rx_t is record
        gprs: gprset_t;
        gpr_update: gprupdate_t;
        done: std_logic;
        exception: exception_t;
        br: branch_t;
        br_target: natural range 0 to MAX_MICROCODE;
    end record;
    type eucontrol_tx_array_t is array (0 to MAX_EU) of eucontrol_tx_t;
    type eucontrol_rx_array_t is array (0 to MAX_EU) of eucontrol_rx_t;
    subtype ramcell_t is std_logic_vector(7 downto 0);
    type ram_t is array (0 to MAX_RAM) of ramcell_t;

    type memory_work_t is record
        work: std_logic;
        m_write: std_logic;
        m_width: std_logic_vector(1 downto 0);
        addr: std_logic_vector(63 downto 0);
        data: std_logic_vector(63 downto 0);
    end record;
    type memory_result_t is record
        ack: std_logic;
        done: std_logic;
        exception: std_logic;
        data: std_logic_vector(63 downto 0);
    end record;
    type memory_work_array_t is array (0 to MAX_EU) of memory_work_t;
    type memory_result_array_t is array (0 to MAX_EU) of memory_result_t;

    constant EMPTY_MEMORY_WORK: memory_work_t := (
        work => '0',
        m_write => '0',
        m_width => "00",
        addr => (others => '0'),
        data => (others => '0')
    );
    constant EMPTY_MEMORY_RESULT: memory_result_t := (
        ack => '0',
        done => '0',
        exception => '0',
        data => (others => '0')
    );

    constant ALL_ZEROS: gpr_t := (others => '0');
    constant ALL_ONES: gpr_t := (others => '1');
    
end package defs;
