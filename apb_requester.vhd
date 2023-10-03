----------------------------------------------------------------------------------
-- Company: ITA Space Center (Instituto Tecnológico de Aeronáutica)
-- Engineer: Victor O. Costa
-- 
-- Create Date: 01.10.2023 16:17:40
-- Design Name: 
-- Module Name: apb_master - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
-- The design is still synthesizable, since IEEE.MATH_REAL is only used with generics 
--use IEEE.MATH_REAL.CEIL;
--use IEEE.MATH_REAL.LOG2;

-- 
use work.slv_array_pkg.all;

entity apb_requester is
	generic (
		NUM_COMPLETERS : natural := 2;                 -- Number of peripherals that the requester shall service manage
		DATA_WIDTH     : natural := DATA_WIDTH_pkg;    -- Width of the data bus
		ADDR_WIDTH     : natural := ADDR_WIDTH_pkg     -- Width of the address bus
	);
	port (
		clk  : in std_logic;          -- Clock
		rstn : in std_logic;          -- Reset (active low)
		
		-- APB3 REQUESTER SIGNALS
		paddr_o   : out std_logic_vector(ADDR_WIDTH-1 downto 0);
		psel_o    : out std_logic_vector(NUM_COMPLETERS-1 downto 0);
		penable_o : out std_logic;
		pwrite_o  : out std_logic;
		pwdata_o  : out std_logic_vector(DATA_WIDTH-1 downto 0);
		
		-- APB3 COMPLETER SIGNALS
		pready_i  : in std_logic_vector(NUM_COMPLETERS-1 downto 0);
		prdata_i  : in slv_array_t(NUM_COMPLETERS-1 downto 0);
		pslverr_i : in std_logic_vector(NUM_COMPLETERS-1 downto 0);
		
		-- Interrupt bus
		interrupt_i : in std_logic_vector(NUM_COMPLETERS-1 downto 0)
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
	signal reg_interrupt : std_logic_vector(NUM_COMPLETERS-1 downto 0);

	-- FSM state register
	signal reg_state : fsm_state_t;

	-- Inverted version of the data read from peripheral
	signal prdata_inv_s : std_logic_vector(DATA_WIDTH-1 downto 0);

	-- Interrupt priority encoder index
	signal interrupt_sel : natural range 0 to NUM_COMPLETERS-1; 	

	-- 
	constant ADDRESS_PERIPHERAL0 : std_logic_vector(DATA_WIDTH-1 downto 0) := x"00000001";
	constant ADDRESS_PERIPHERAL1 : std_logic_vector(DATA_WIDTH-1 downto 0) := x"000000FF";

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
						-- Read transactions take pslverr into acount
						if pready_i(interrupt_sel) = '1' and pslverr_i(interrupt_sel) = '0' then
						  reg_prdata <= prdata_i(interrupt_sel);
							reg_state <= Swrite_idle;
						elsif pready_i(interrupt_sel) = '1' and pslverr_i(interrupt_sel) = '1' then
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
						-- Write transactions ignore pslverr for now
						if pready_i(interrupt_sel) = '1' then
							reg_state <= Sread_idle;
						else
							reg_state <= Swrite_access;
						end if;

				end case;		
			end if;
		end if;
	end process;

	-- Hardwired interrupt priority encoder
	-- TODO: implement generic solution (w/ NUM_COMPLETERS)
	interrupt_sel <= 1 when reg_interrupt(1) = '1' else 0;
	
	-- Control outputs
	psel_o    <= (interrupt_sel => '1', others => '0') when reg_state = Sread_setup or reg_state = Swrite_setup 
	                                                     or reg_state = Sread_access or reg_state = Swrite_access else
	             (others => '0');
	penable_o <= '1' when reg_state = Sread_access or reg_state = Swrite_access else '0';
	pwrite_o  <= '1' when reg_state = Swrite_setup or reg_state = Swrite_access else '0';
	
	-- Address (combinational and hardwired)
	paddr_o   <= ADDRESS_PERIPHERAL0 when interrupt_sel = 0 else ADDRESS_PERIPHERAL1;
	
	-- Registered outputs
	pwdata_o  <= reg_pwdata;

end behavioral;