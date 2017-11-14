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
-- Modulename: 	FifoCtrl.vhd
--
-- Description: 	Parameterized Asynchroneous FIFO control circuitry
--
--						Default generic config:
--						ADDR_WIDTH = 4 - Register depth: 16 (4 address bits)
--						MODE_ASYNC = 1 - Asynchronous Fifo mode
--						SYNC_DEPTH = 2 - Synchronizer depth: 2 levels
--						PRE_LOAD   = 2 - Pre load number: 2 words
--
-- Dependencies: 	FifoReadPort.vhd
--						FifoWritePort.vhd
--						Synchroniser.vhd
--
-- Change Log:
--------------------------------------------------------------------------------
-- Revision 		Date    		Id					Change
--                DD/MM/YYYY
-- ---------------------------------------------------------
-- Revision 0.01 	06/04/2010	Anders Lange 	File Created
-- Revision 0.02 	22/04/2010	Anders Lange	Error regarding clk assignement for the synchronisers corrected
-- Revision 0.03 	23/04/2010	Anders Lange	DEPTH generic changed to ADDR_WIDTH
-- Revision 0.04 	29/04/2010	Anders Lange	SYNC_DEPTH generic added, two_ff_n_sync.vhd replaced by synchroniser.vhd
-- Revision 0.05 	10/05/2010	Anders Lange	Copyright conditions & disclamer added.
-- Revision 0.06 	12/06/2010	Anders Lange	PRE_LOAD generic added.
-- Revision 1.00  12/06/2010	Anders Lange	Offical release
-- Revision 1.90	06/11/2010 	Anders Lange	MODE_ASYNC generic + conditional synthesis code added for support of synchronous and asynchronous fifo modes
-- Revision 1.91	06/11/2010 	Anders Lange	New Header & Copyright added, old Copyright conditions & disclamer removed
-- Revision 1.92 
--
-- Additional Comments: 
-- Based on listing 16.16 from "RTL Hardware Design using VHDL" by Pong P. Chu
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
entity fifo_ctrl is
   generic(ADDR_WIDTH: natural:=4;		--Address width (depth)
			  MODE_ASYNC: natural range 0 to 1 := 1;    -- Asynchronous Fifo mode
			  SYNC_DEPTH: natural:=2;		--Synchronizer depth
			  PRE_LOAD:   natural:=2);		-- Write<>Read Ptr offset before deasserting empty signal (read logic)			  
   port(
      clkw_i: in std_logic;
      resetw_i: in std_logic;
      wr_i: in std_logic;
      full_o: out std_logic;
      w_addr_o: out std_logic_vector (ADDR_WIDTH-1 downto 0);
      clkr_i: in std_logic;
      resetr_i: in std_logic;
      rd_i: in std_logic;
      empty_o: out std_logic;
      r_addr_o: out std_logic_vector (ADDR_WIDTH-1 downto 0)
   );
end fifo_ctrl;

--------------------------------------------------------------------------------
-- Architecture
--------------------------------------------------------------------------------
architecture str_arch of fifo_ctrl is
	 
	 -- Internal signals mapped to input ports
   signal clkw: std_logic;
   signal resetw: std_logic;
   signal wr: std_logic;
   signal full: std_logic;
   signal w_addr: std_logic_vector (ADDR_WIDTH-1 downto 0);
   signal clkr: std_logic;
   signal resetr: std_logic;
   signal rd: std_logic;
   signal empty: std_logic;
   signal r_addr: std_logic_vector (ADDR_WIDTH-1 downto 0);	
	
	 -- Signals for internal interconnect	
   signal r_ptr_in: std_logic_vector(ADDR_WIDTH downto 0);
   signal r_ptr_out: std_logic_vector(ADDR_WIDTH downto 0);
   signal w_ptr_in: std_logic_vector(ADDR_WIDTH downto 0);
   signal w_ptr_out: std_logic_vector(ADDR_WIDTH downto 0);
	signal w_ptr_async: std_logic_vector(ADDR_WIDTH downto 0);
	signal w_ptr_sync: std_logic_vector(ADDR_WIDTH downto 0);
	signal r_ptr_async: std_logic_vector(ADDR_WIDTH downto 0);
	signal r_ptr_sync: std_logic_vector(ADDR_WIDTH downto 0);

   -- Component declarations
   component fifo_read_ctrl
   		generic(N: natural;
					  PRE_LOAD: natural);
   		port(
      	 clkr_i: in std_logic;
      	 resetr_i: in std_logic;
      	 rd_i: in std_logic;      	 
      	 w_ptr_in_i: in std_logic_vector(N downto 0);
      	 empty_o: out std_logic;
      	 r_ptr_out_o: out std_logic_vector(N downto 0);
      	 r_addr_o: out std_logic_vector(N-1 downto 0)
   		);      
   end component;
   
   component fifo_write_ctrl      
   		generic(N: natural);
   		port(
      	 clkw_i: in std_logic;
      	 resetw_i: in std_logic;
      	 wr_i: in std_logic;
      	 r_ptr_in_i: in std_logic_vector(N downto 0);
      	 full_o: out std_logic;
      	 w_ptr_out_o: out std_logic_vector(N downto 0);
      	 w_addr_o: out std_logic_vector(N-1 downto 0)
	    );      
   end component;
	
	component synchronizer is
		generic(N: natural;	--N: number of bits in async IO
				  D: natural); --D: synchroniser depth
		port(
			clk_i: in std_logic;
			reset_i: in std_logic;
			in_async_i: in std_logic_vector(N-1 downto 0);
			out_sync_o: out std_logic_vector(N-1 downto 0)
		);
	end component;	
   
begin

	 -- Input
   clkw <= clkw_i;
   resetw <= resetw_i;
   wr <= wr_i;
   clkr <= clkr_i;
   resetr <= resetr_i;
   rd <= rd_i;     
	 
	 -- Component wiring
   read_ctrl: fifo_read_ctrl
      generic map(N=>ADDR_WIDTH,
						PRE_LOAD=>PRE_LOAD)
      port map (clkr_i		  =>	clkr, 
      			 resetr_i     =>	resetr, 
      			 rd_i			  =>	rd,       					
                w_ptr_in_i   =>	w_ptr_in,      					
                empty_o		  =>	empty,
                r_ptr_out_o  =>	r_ptr_out, 
                r_addr_o	  =>	r_addr);
                
   write_ctrl: fifo_write_ctrl
      generic map(N =>ADDR_WIDTH)
      port map (clkw_i			=>	clkw, 
      			 resetw_i		=>	resetw, 
      			 wr_i				=>	wr,
                r_ptr_in_i		=>	r_ptr_in, 
                full_o			=>	full,
                w_ptr_out_o	=>	w_ptr_out, 
                w_addr_o		=>	w_addr);

	
	w_ptr_async <= w_ptr_out when MODE_ASYNC = 1 else (others => '0');
	w_ptr_in <= w_ptr_sync when MODE_ASYNC = 1 else w_ptr_out;

	r_ptr_async <= r_ptr_out when MODE_ASYNC = 1 else (others => '0');
	r_ptr_in <= r_ptr_sync when MODE_ASYNC = 1 else r_ptr_out;

synchdepth_1:
   if (MODE_ASYNC = 1 and SYNC_DEPTH = 1) generate
      begin
	
		sync_w_ptr: entity work.synchronizer(synchdepth_1)
			generic map(N=>ADDR_WIDTH+1,
							D=>SYNC_DEPTH)
			port map (clk_i		=>	clkr, 
						 reset_i		=>	resetw,
						 in_async_i	=>	w_ptr_async, 
						 out_sync_o	=>	w_ptr_sync);
		

						
		sync_r_ptr: entity work.synchronizer(synchdepth_1)
			generic map(N=>ADDR_WIDTH+1,
							D=>SYNC_DEPTH)
			port map (clk_i		=>	clkw, 
						 reset_i		=>	resetr,
						 in_async_i	=>	r_ptr_async, 
						 out_sync_o =>	r_ptr_sync);
						 
   end generate;
	
synchdepth_2p:
   if (MODE_ASYNC = 1 and SYNC_DEPTH > 1) generate
      begin
	
		sync_w_ptr: entity work.synchronizer(synchdepth_2p)
			generic map(N=>ADDR_WIDTH+1,
							D=>SYNC_DEPTH)
			port map (clk_i		=>	clkr, 
						 reset_i		=>	resetw,
						 in_async_i	=>	w_ptr_async, 
						 out_sync_o	=>	w_ptr_sync);
		

						
		sync_r_ptr: entity work.synchronizer(synchdepth_2p)
			generic map(N=>ADDR_WIDTH+1,
							D=>SYNC_DEPTH)
			port map (clk_i		=>	clkw, 
						 reset_i		=>	resetr,
						 in_async_i	=>	r_ptr_async, 
						 out_sync_o =>	r_ptr_sync);
						 
   end generate;	
	
	 -- Output
   full_o <= full;
   w_addr_o <= w_addr;      
   empty_o <= empty;
   r_addr_o <= r_addr;	 
	                
end str_arch;

--------------------------------------------------------------------------------
-- End of file
--------------------------------------------------------------------------------