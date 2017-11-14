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
-- Modulename: 	Synchronizer.vhd
--
-- Description: 	Parameterized D level FF N bit Synchronizer
--						Default data width: 4 bit
--						Default synchronizer depth: 2
--
-- Dependencies: 	None
--
--
-- Change Log:
--------------------------------------------------------------------------------
-- Revision 		Date    		Id					Change
-- DD/MM/YYYY
-- ---------------------------------------------------------
-- Revision 0.01	23/04/2010	Anders Lange 	File Created	
-- Revision 0.02	10/05/2010	Anders Lange 	Copyright conditions & disclamer added
-- Revision 1.00  12/06/2010	Anders Lange	Offical release
-- Revision 1.90 	06/11/2010	Anders Lange	Additional architecture added to handle synch depth of 1 correct
-- Revision 1.91	06/11/2010	Anders Lange	New Header & Copyright added, old Copyright conditions & disclamer removed
-- Revision 1.92
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Libraries
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

--------------------------------------------------------------------------------
-- Entity
--------------------------------------------------------------------------------
entity synchronizer is
   generic(N: natural := 4;	--N: number of bits in async IO
   		  D: natural := 2);  --D: synchroniser depth
   port(
      clk_i: in std_logic;
      reset_i: in std_logic;
      in_async_i: in std_logic_vector(N-1 downto 0);
      out_sync_o: out std_logic_vector(N-1 downto 0)
   );
end synchronizer;

--------------------------------------------------------------------------------
-- Architecture 1
--------------------------------------------------------------------------------
architecture synchdepth_1 of synchronizer is
	 -- Internal signals mapped to input port
   signal clk: std_logic;
   signal reset: std_logic;
      	 
	 -- Internal signals to be used as registers
    signal sync_reg, sync_next: std_logic_vector(N-1 downto 0) := (others => '0');

begin
	 -- Input
	 clk <= clk_i;
	 reset <= reset_i;
	 sync_next <= in_async_i;
	
   process(clk,reset)
   begin
      if (reset='1') then
         sync_reg <= (others=>'0');
      elsif (clk'event and clk='1') then
         sync_reg <= sync_next;
      end if;
   end process;  
   
   -- Output
   out_sync_o <= sync_reg;
   
end synchdepth_1;

--------------------------------------------------------------------------------
-- Architecture 2
--------------------------------------------------------------------------------
architecture synchdepth_2p of synchronizer is
	 -- Internal signals mapped to input port
   signal clk: std_logic;
   signal reset: std_logic;
   signal in_async: std_logic_vector(N-1 downto 0);

	 -- type declaration
	 type vector_array is array(integer range <>) of std_logic_vector(N-1 downto 0);
      	 
	 -- Internal signals to be used as registers
    signal sync_reg, sync_next: vector_array(D-1 downto 0) := (others=>(others => '0'));

begin
	 -- Input
	 clk <= clk_i;
	 reset <= reset_i;
	 in_async <= in_async_i;

   -- Update the next "state" registers	
	sync_next <= sync_reg(D-2 downto 0) & in_async;
	
   process(clk,reset)
   begin
      if (reset='1') then
         sync_reg <= (others=>(others=>'0'));
      elsif (clk'event and clk='1') then
         sync_reg <= sync_next;
      end if;
   end process;  
   
   -- Output
   out_sync_o <= sync_reg(D-1);
   
end synchdepth_2p;

--------------------------------------------------------------------------------
-- End of file
--------------------------------------------------------------------------------