library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
Library UNISIM;
use UNISIM.vcomponents.all;
use work.defs.all;
use work.builtin_microcode.all;

entity cpu is
  port (
    i_clk: in std_logic;
    o_leds: out std_logic_vector(0 downto 0)
  );
end cpu;

architecture impl of cpu is

  component execution_unit is
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
  end component;

  component memory_sequencer is
  generic (
    max_work_index: natural range 0 to MAX_EU
  );
  port (
    i_clk: in std_logic;
    i_work: in memory_work_array_t(0 to max_work_index);
    o_result: out memory_result_array_t(0 to max_work_index);
    
    i_backing_result: in memory_result_t;
    o_backing_work: out memory_work_t
  );
  end component;

    component blk_mem_user_0 IS
      PORT (
        clka : IN STD_LOGIC;
        ena : IN STD_LOGIC;
        wea : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        addra : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
        dina : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
        douta : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
        clkb : IN STD_LOGIC;
        enb : IN STD_LOGIC;
        web : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        addrb : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
        dinb : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
        doutb : OUT STD_LOGIC_VECTOR(63 DOWNTO 0)
      );
    END component;

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

  signal memory_work: memory_work_array_t(0 to MAX_EU) := (others => EMPTY_MEMORY_WORK);
  signal memory_result: memory_result_array_t(0 to MAX_EU) := (others => EMPTY_MEMORY_RESULT);

  signal sequential_memory_work_a: memory_work_t;
  signal sequential_memory_result_a: memory_result_t;

  signal sequential_memory_work_b: memory_work_t;
  signal sequential_memory_result_b: memory_result_t;
  
  signal pll_clkout0: std_logic;
  signal pll_clkout1: std_logic;
  signal pll_clkout2: std_logic;
  signal pll_clkout3: std_logic;
  signal pll_clkout4: std_logic;
  signal pll_clkout5: std_logic;
  signal pll_clkfb: std_logic;
  signal pll_locked: std_logic;
  signal pll_pwrdwn: std_logic := '0';
  signal pll_rst: std_logic := '0';
  
begin
  o_leds <= (0 => gprs(0)(0), others => '0');
  
     PLLE2_BASE_inst : PLLE2_BASE
   generic map (
      BANDWIDTH => "OPTIMIZED",  -- OPTIMIZED, HIGH, LOW
      CLKFBOUT_MULT => 16,        -- Multiply value for all CLKOUT, (2-64)
      CLKFBOUT_PHASE => 0.0,     -- Phase offset in degrees of CLKFB, (-360.000-360.000).
      CLKIN1_PERIOD => 20.0,      -- Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
      -- CLKOUT0_DIVIDE - CLKOUT5_DIVIDE: Divide amount for each CLKOUT (1-128)
      CLKOUT0_DIVIDE => 12,
      CLKOUT1_DIVIDE => 1,
      CLKOUT2_DIVIDE => 1,
      CLKOUT3_DIVIDE => 1,
      CLKOUT4_DIVIDE => 1,
      CLKOUT5_DIVIDE => 1,
      -- CLKOUT0_DUTY_CYCLE - CLKOUT5_DUTY_CYCLE: Duty cycle for each CLKOUT (0.001-0.999).
      CLKOUT0_DUTY_CYCLE => 0.5,
      CLKOUT1_DUTY_CYCLE => 0.5,
      CLKOUT2_DUTY_CYCLE => 0.5,
      CLKOUT3_DUTY_CYCLE => 0.5,
      CLKOUT4_DUTY_CYCLE => 0.5,
      CLKOUT5_DUTY_CYCLE => 0.5,
      -- CLKOUT0_PHASE - CLKOUT5_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
      CLKOUT0_PHASE => 0.0,
      CLKOUT1_PHASE => 0.0,
      CLKOUT2_PHASE => 0.0,
      CLKOUT3_PHASE => 0.0,
      CLKOUT4_PHASE => 0.0,
      CLKOUT5_PHASE => 0.0,
      DIVCLK_DIVIDE => 1,        -- Master division value, (1-56)
      REF_JITTER1 => 0.0,        -- Reference input jitter in UI, (0.000-0.999).
      STARTUP_WAIT => "FALSE"    -- Delay DONE until PLL Locks, ("TRUE"/"FALSE")
   )
   port map (
      -- Clock Outputs: 1-bit (each) output: User configurable clock outputs
      CLKOUT0 => pll_clkout0,
      CLKOUT1 => pll_clkout1,   -- 1-bit output: CLKOUT1
      CLKOUT2 => pll_clkout2,   -- 1-bit output: CLKOUT2
      CLKOUT3 => pll_clkout3,   -- 1-bit output: CLKOUT3
      CLKOUT4 => pll_clkout4,   -- 1-bit output: CLKOUT4
      CLKOUT5 => pll_clkout5,   -- 1-bit output: CLKOUT5
      -- Feedback Clocks: 1-bit (each) output: Clock feedback ports
      CLKFBOUT => pll_clkfb, -- 1-bit output: Feedback clock
      LOCKED => pll_locked,     -- 1-bit output: LOCK
      CLKIN1 => i_clk,     -- 1-bit input: Input clock
      -- Control Ports: 1-bit (each) input: PLL control ports
      PWRDWN => pll_pwrdwn,     -- 1-bit input: Power-down
      RST => pll_rst,           -- 1-bit input: Reset
      -- Feedback Clocks: 1-bit (each) input: Clock feedback ports
      CLKFBIN => pll_clkfb    -- 1-bit input: Feedback clock
   );

  mseq_a: memory_sequencer
    generic map(
      max_work_index => 1
    )
    port map(
      i_clk => pll_clkout0,
      i_work => memory_work(0 to 1),
      o_result => memory_result(0 to 1),
      i_backing_result => sequential_memory_result_a,
      o_backing_work => sequential_memory_work_a
    );
  mseq_b: memory_sequencer
    generic map(
      max_work_index => 1
    )
    port map(
      i_clk => pll_clkout0,
      i_work => memory_work(2 to MAX_EU),
      o_result => memory_result(2 to MAX_EU),
      i_backing_result => sequential_memory_result_b,
      o_backing_work => sequential_memory_work_b
    );
  blockram: blk_mem_user_0
    port map(
      clka => pll_clkout0,
      ena => sequential_memory_work_a.m_en,
      wea => sequential_memory_work_a.m_we,
      addra => sequential_memory_work_a.m_addr,
      dina => sequential_memory_work_a.m_din,
      douta => sequential_memory_result_a.m_dout,
      clkb => pll_clkout0,
      enb => sequential_memory_work_b.m_en,
      web => sequential_memory_work_b.m_we,
      addrb => sequential_memory_work_b.m_addr,
      dinb => sequential_memory_work_b.m_din,
      doutb => sequential_memory_result_b.m_dout
    );
  
  eu_0: execution_unit
    port map(
      i_clk => pll_clkout0,
      i_work => eu_tx(0).work,
      i_inst => eu_tx(0).inst,
      i_gprs => gprs,
      i_memory_result => memory_result(0),
      o_gprs => eu_rx(0).gprs,
      o_gpr_update => eu_rx(0).gpr_update,
      o_done => eu_rx(0).done,
      o_exception => eu_rx(0).exception,
      o_br => eu_rx(0).br,
      o_br_target => eu_rx(0).br_target,
      o_memory_work => memory_work(0)
    );
  eu_1: execution_unit
    port map(
      i_clk => pll_clkout0,
      i_work => eu_tx(1).work,
      i_inst => eu_tx(1).inst,
      i_gprs => gprs,
      i_memory_result => memory_result(1),
      o_gprs => eu_rx(1).gprs,
      o_gpr_update => eu_rx(1).gpr_update,
      o_done => eu_rx(1).done,
      o_exception => eu_rx(1).exception,
      o_br => eu_rx(1).br,
      o_br_target => eu_rx(1).br_target,
      o_memory_work => memory_work(1)
    );
  eu_2: execution_unit
    port map(
      i_clk => pll_clkout0,
      i_work => eu_tx(2).work,
      i_inst => eu_tx(2).inst,
      i_gprs => gprs,
      i_memory_result => memory_result(2),
      o_gprs => eu_rx(2).gprs,
      o_gpr_update => eu_rx(2).gpr_update,
      o_done => eu_rx(2).done,
      o_exception => eu_rx(2).exception,
      o_br => eu_rx(2).br,
      o_br_target => eu_rx(2).br_target,
      o_memory_work => memory_work(2)
    );
  eu_3: execution_unit
    port map(
      i_clk => pll_clkout0,
      i_work => eu_tx(3).work,
      i_inst => eu_tx(3).inst,
      i_gprs => gprs,
      i_memory_result => memory_result(3),
      o_gprs => eu_rx(3).gprs,
      o_gpr_update => eu_rx(3).gpr_update,
      o_done => eu_rx(3).done,
      o_exception => eu_rx(3).exception,
      o_br => eu_rx(3).br,
      o_br_target => eu_rx(3).br_target,
      o_memory_work => memory_work(3)
    );

  process (pll_clkout0) is
    variable v_stop_iter: std_logic;
  begin
    if rising_edge(pll_clkout0) then
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
