-- Copyright Centro Espacial ITA (Instituto Tecnológico de Aeronáutica).
-- This source describes Open Hardware and is licensed under the CERN-OHLS v2
-- You may redistribute and modify this documentation and make products
-- using it under the terms of the CERN-OHL-S v2 (https:/cern.ch/cern-ohl).
-- This documentation is distributed WITHOUT ANY EXPRESS OR IMPLIED
-- WARRANTY, INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY
-- AND FITNESS FOR A PARTICULAR PURPOSE. Please see the CERN-OHL-S v2
-- for applicable conditions.
-- Source location: https://github.com/vctrop/AMBA_playground
-- As per CERN-OHL-S v2 section 4, should You produce hardware based on
-- these sources, You must maintain the Source Location visible on any
-- product you make using this documentation.

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;
	--use ieee.math_real.ceil;
	--use ieee.math_real.log2;

-- 
use work.slv_array_pkg.all;

entity apb_requester is
	generic (
		-- Number of peripherals that the requester shall service manage
		NUM_PERIPH   : natural := NUM_PERIPH_pkg;
		-- Width of the data bus
		DATA_WIDTH   : natural := DATA_WIDTH_pkg;
		-- Width of the address bus
		ADDR_WIDTH   : natural := ADDR_WIDTH_pkg;
		-- AMBA version of each peripheral, indexed by the interruption priority encoder
		-- At index i, 1-value bit means AMBA 3 and 0-value bit means AMBA 2
		AMBA_VERSION : std_logic_vector(MAX_NUM_PERIPH_pkg-1 downto 0) := (others => '1')
	);
	port (
		clk  : in std_logic;          -- Clock
		rstn : in std_logic;          -- Reset (active low)
		
		-- APB3 REQUESTER SIGNALS
		paddr_o   : out std_logic_vector(ADDR_WIDTH-1 downto 0);
		psel_o    : out std_logic_vector(NUM_PERIPH-1 downto 0);
		penable_o : out std_logic;
		pwrite_o  : out std_logic;
		pwdata_o  : out std_logic_vector(DATA_WIDTH-1 downto 0);
		
		-- APB3 COMPLETER SIGNALS
		pready_i  : in std_logic_vector(NUM_PERIPH-1 downto 0);
		prdata_i  : in slv_array_t(NUM_PERIPH-1 downto 0);
		pslverr_i : in std_logic_vector(NUM_PERIPH-1 downto 0);
		
		-- Interrupt bus
		interrupt_i : in std_logic_vector(NUM_PERIPH-1 downto 0)
	);
end apb_requester;

architecture behavioral of apb_requester is
	-- Type declarations
	type fsm_state_t is (
	                     Sread_idle,               -- read transfer IDLE state, waiting for interrupt
	                     Sread_setup,              -- read transfer SETUP state
	                     Sread_access,             -- read transfer ACCESS state
	                     Swrite_idle,              -- write transfer IDLE state
	                     Swrite_setup,             -- write transfer SETUP state
	                     Swrite_access             -- write transfer ACCESS state
	);

	-- Output registers
	signal reg_pwdata  : std_logic_vector(DATA_WIDTH-1 downto 0);

	-- Input registers
	signal reg_prdata    : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal reg_interrupt : std_logic_vector(NUM_PERIPH-1 downto 0);

	-- FSM state register
	signal reg_state : fsm_state_t;

	-- Inverted version of the data read from peripheral
	signal prdata_inv_s : std_logic_vector(DATA_WIDTH-1 downto 0);

	-- Selector from the interrupt priority encoder
	signal int_sel : natural range 0 to NUM_PERIPH-1; 	
	
	--
	signal Sraccess_to_Swidle_s : std_logic_vector(NUM_PERIPH-1 downto 0);
	signal Sraccess_to_Sridle_s : std_logic_vector(NUM_PERIPH-1 downto 0);
	signal Swaccess_to_Sridle_s : std_logic_vector(NUM_PERIPH-1 downto 0);

  -- Configuration-specific constants
	-- CAUTION: MUST BE MODIFIED IN CASE OF MODIFYING GENERICS
	constant ADDRESS_PERIPHERAL0_C : std_logic_vector(DATA_WIDTH-1 downto 0) := x"00000001";
	constant ADDRESS_PERIPHERAL1_C : std_logic_vector(DATA_WIDTH-1 downto 0) := x"000000FF";
	constant AMBA_VERSION_C        : std_logic_vector(NUM_PERIPH-1 downto 0) := AMBA_VERSION(NUM_PERIPH-1 downto 0);
	
begin
	-- 
	CONTROL_FSM: process(clk)
	begin
		if rising_edge(clk) then
			if rstn = '0' then 
				reg_pwdata <= (others => '0');
				reg_state <= Sread_idle;
				
			else 
				case reg_state is
					-- APB3 READ TRANSACTION - IDLE STATE
					when Sread_idle =>
						-- Control signals
						-- Next state logic handles interrupts
						if unsigned(interrupt_i) /= 0 then
							reg_interrupt <= interrupt_i;
							reg_state <= Sread_setup;
						else
							reg_state <= Sread_idle;
						end if;

					-- APB3 READ TRANSACTION - SETUP STATE
					when Sread_setup =>
						-- Control signals
						-- Next state
						reg_state <= Sread_access;
	
					-- APB3 READ TRANSACTION - ACCESS STATE 
					when Sread_access =>
						-- Next state logic
						-- APB 3 considers pready and pslverr in the state transition, while APB 2 does not 
						if Sraccess_to_Swidle_s(int_sel) = '1' then
							reg_prdata <= prdata_i(int_sel);
							reg_state <= Swrite_idle;
						elsif Sraccess_to_Sridle_s(int_sel) = '1' then
							reg_state <= Sread_idle;
						else
							reg_state <= Sread_access;
						end if;

					-- APB3 WRITE TRANSACTION - IDLE STATE
					when Swrite_idle =>
						-- Output write data
						reg_pwdata <= not reg_prdata;
						-- Next state
						reg_state <= Swrite_setup;

					-- APB3 WRITE TRANSACTION - SETUP STATE
					when Swrite_setup =>
						-- Next state
						reg_state <= Swrite_access;

					-- APB3 WRITE TRANSACTION - ACCESS STATE
					when Swrite_access =>
						-- Next state logic
						if Swaccess_to_Sridle_s(int_sel) = '1' then
							reg_state <= Sread_idle;
						else
							reg_state <= Swrite_access;
						end if;

				end case;		
			end if;
		end if;
	end process;

	-- AMBA version handling:
	-- Bit i in AMBA_VERSION indicates the version of the i-th peripheral (0 for AMBA 2, 1 for AMBA 3)
	-- APB 3 considers pready in the state transition, while APB 2 does not 
	Sraccess_to_Swidle_s <= (not AMBA_VERSION_C) or (pready_i and (not pslverr_i)) when reg_state = Sread_access else (others => '0');
	Sraccess_to_Sridle_s <= AMBA_VERSION_C and pready_i and pslverr_i when reg_state = Sread_access else (others => '0');
	Swaccess_to_Sridle_s   <= (not AMBA_VERSION_C) or pready_i when reg_state = Swrite_access else (others => '0');

	-- Hardwired interrupt priority encoder
	-- TODO: implement generic solution (w/ NUM_PERIPH)
	int_sel <= 1 when reg_interrupt(1) = '1' else 0;
	
	-- Control outputs
	psel_o    <= (int_sel => '1', others => '0') when reg_state = Sread_setup or reg_state = Swrite_setup 
	                                               or reg_state = Sread_access or reg_state = Swrite_access else (others => '0');
	penable_o <= '1' when reg_state = Sread_access or reg_state = Swrite_access else '0';
	pwrite_o  <= '1' when reg_state = Swrite_setup or reg_state = Swrite_access else '0';
	
	-- Address (combinational and hardwired)
	paddr_o   <= ADDRESS_PERIPHERAL0_C when int_sel = 0 else ADDRESS_PERIPHERAL1_C;
	
	-- Registered outputs
	pwdata_o  <= reg_pwdata;

end behavioral;