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
	-- use ieee.numeric_std.all;
	
package slv_array_pkg is

	-- 
	constant MAX_DATA_WIDTH_pkg : natural := 32;
	constant MAX_ADDR_WIDTH_pkg : natural := 32;
	constant MAX_NUM_PERIPH_pkg : natural := 16;
	-- 
	constant DATA_WIDTH_pkg : natural := 32;
	constant ADDR_WIDTH_pkg : natural := 32;
	constant NUM_PERIPH_pkg : natural := 2;

	type slv_array_t is array (natural range <>) of std_logic_vector(DATA_WIDTH_pkg-1 downto 0); 

end package slv_array_pkg;


package body slv_array_pkg is

end package body slv_array_pkg;