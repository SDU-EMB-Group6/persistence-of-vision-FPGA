--------------------------------------------------------------------------------
--    	    University of Southern Denmark - Faculty of Engineering
--
--   										 Master Thesis
--
--                                   HartOS
--           Hardware implemented Advanced Real Time Operating System
--
--                (c) Copyright 2010, Anders Blaabjerg Lange
--                            All Rights Reserved
--
--
-- Architecture: 	Spartan 6, Xilinx MicroBlaze
--
-- Design Tool: 	Xilinx ISE 12.3
--
-- HDL-Standard: 	VHDL'93
--
-- Modulename: 	RegFile2.vhd
--
-- Description: 	Parameterized Register File (Dual-Port RAM with Asynchronous Read)
--						Default register depth: 8 (3 address bits)
--						Default data width: 4 bit
--
-- Dependencies: 	None
--
-- Change Log:
--------------------------------------------------------------------------------
-- Revision 		Date    		Id					Change
-- DD/MM/YYYY
-- ---------------------------------------------------------
-- Revision 0.01  08/04/2010  Anders Lange   File Created	
-- Revision 0.02  17/04/2010	Anders Lange	Output port dout_a removed (comment'd out) to avoid synthesis warnings
-- Revision 0.03 	10/05/2010	Anders Lange	Copyright conditions & disclamer added
-- Revision 1.00  12/06/2010	Anders Lange	Offical release
-- Revision 1.90	06/11/2010 	Anders Lange	New Header & Copyright added, old Copyright conditions & disclamer removed
-- Revision 1.91
--
-- Additional Comments: 
-- Based on rams09 (Dual-Port RAM With Asynchronous Read) Xilinx VHDL Coding Example v.9
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Libraries
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--------------------------------------------------------------------------------
-- Entity
--------------------------------------------------------------------------------
entity rams_09 is
	 generic(	ADDR_WIDTH: integer:=3;
	 				DATA_WIDTH: integer:=4);
	 port(clk_i : in std_logic;
			we_i : in std_logic;
	 		addr_a_i : in std_logic_vector(ADDR_WIDTH-1 downto 0);
	 		addr_b_i : in std_logic_vector(ADDR_WIDTH-1 downto 0);
	 		din_a_i : in std_logic_vector(DATA_WIDTH-1 downto 0);
	 		--dout_a_o : out std_logic_vector(DATA_WIDTH-1 downto 0);
	 		dout_b_o : out std_logic_vector(DATA_WIDTH-1 downto 0));
end rams_09;

--------------------------------------------------------------------------------
-- Architecture
--------------------------------------------------------------------------------
architecture syn of rams_09 is
	 type ram_type is array (((2**ADDR_WIDTH)-1) downto 0) of std_logic_vector (DATA_WIDTH-1 downto 0);
	 signal RAM : ram_type;
	 
begin
	 process (clk_i)
	 begin
	 		if (clk_i'event and clk_i = '1') then
				if (we_i = '1') then
					RAM(to_integer(unsigned(addr_a_i))) <= din_a_i;
				end if;
			end if;
	 end process;

	 --dout_a_o <= RAM(to_integer(unsigned(addr_a_i)));
	 dout_b_o <= RAM(to_integer(unsigned(addr_b_i)));
	 
end syn;

--------------------------------------------------------------------------------
-- End of file
--------------------------------------------------------------------------------