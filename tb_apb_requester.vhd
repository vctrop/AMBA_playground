----------------------------------------------------------------------------------
-- Company: ITA Space Center (Instituto Tecnológico de Aeronáutica)
-- Engineer: Victor O. Costa
-- 
-- Create Date: 01.10.2023 15:56:43
-- Design Name: 
-- Module Name: apb_uart_tb - Behavioral
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

use work.slv_array_pkg.all;

entity tb_apb_requester is
end tb_apb_requester;

architecture behavioral of tb_apb_requester is

	-- 
	constant NUM_COMPLETERS : natural := 2;
	constant DATA_WIDTH : natural := 32;
	constant ADDR_WIDTH : natural := 32;
	--
	constant half_clk_period : time := 10 ns;
	constant clK_period : time := 2*half_clk_period;
	signal clk : std_logic := '0';
	--
	signal rstn : std_logic := '0';
	
	-- APB Requester signals
	signal pready_s    : std_logic_vector(NUM_COMPLETERS-1 downto 0) := (others => '0');
	signal pslverr_s   : std_logic_vector(NUM_COMPLETERS-1 downto 0) := (others => '0');
	signal prdata_s    : slv_array_t(NUM_COMPLETERS-1 downto 0);
	
	-- APB completer signals
	signal paddr_s   : std_logic_vector(ADDR_WIDTH-1 downto 0);
	signal psel_s    : std_logic_vector(NUM_COMPLETERS-1 downto 0);
	signal penable_s : std_logic;
	signal pwrite_s  : std_logic;
	signal pwdata_s  : std_logic_vector(DATA_WIDTH-1 downto 0);
	
	-- 
	signal data_s      : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
	signal interrupt_s : std_logic_vector(NUM_COMPLETERS-1 downto 0) := (others => '0');
	
begin

	DUV: entity work.apb_requester(behavioral)
	generic map(
		NUM_COMPLETERS => NUM_COMPLETERS,
		DATA_WIDTH => DATA_WIDTH,
		ADDR_WIDTH => ADDR_WIDTH
	)
	port map(
		clk  => clk,
	  rstn => rstn,
	  
	  -- APB3 REQUESTER SIGNALS
	  paddr_o   => paddr_s,
	  psel_o    => psel_s,
	  penable_o => penable_s,
	  pwrite_o  => pwrite_s,
	  pwdata_o  => pwdata_s,
	  
	  -- APB3 COMPLETER SIGNALS
    pready_i  => pready_s,
		prdata_i  => prdata_s,
    pslverr_i => pslverr_s,

    -- Interrupt
    interrupt_i => interrupt_s
	);
	
	
	-- We are using peripheral 1
	prdata_s(0) <= (others => '1');
	prdata_s(1) <= data_s;

	-- Clock and reset
	clk <= not clk after half_clk_period;
	rstn <= '1' after 5*clk_period;
	
	-- Does not work with generic NUM_COMPLETERS, DATA_WIDTH and ADDR_WIDTH
	process
	begin
	wait until rstn = '1';
	wait for clk_period;
	interrupt_s <= "10";
	
	wait for 2*clk_period;
	data_s <= x"AAAAAAAA";
	pready_s <= "10";
	interrupt_s <= "00";
	
	wait for clk_period;
	data_s <= x"00000000";
	pready_s <= "00";
	
	end process;
	
end behavioral;