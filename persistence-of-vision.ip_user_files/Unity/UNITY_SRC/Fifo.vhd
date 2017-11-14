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
-- Modulename: 	Fifo.vhd
--
-- Description: 	Parameterized Asynchroneous FIFO
--
--						Default generic config:
--						ADDR_WIDTH = 4 - Register depth: 16 (4 address bits)
--						DATA_WIDTH = 4 - Data width: 4 bit
--						MODE_ASYNC = 1 - Asynchronous Fifo mode (enable/disable)
--						SYNC_DEPTH = 2 - Synchronizer depth: 2 levels
--						PRE_LOAD   = 2 - Pre load number: 2 words
--						EN_WRT_ACK = 0 - Write acknowledge (enable/disable)
--
-- Dependencies: 	FifoCtrl.vhd
--						Regfile2.vhd
--
-- Change Log:
--------------------------------------------------------------------------------
-- Revision 		Date    		Id					Change
--                DD/MM/YYYY
-- ---------------------------------------------------------
-- Revision 0.01 	06/04/2010	Anders Lange	File Created
-- Revision 0.02 	17/04/2010	Anders Lange	Logic added to prevent write to the ram when the fifo is full
--						 									and to make the fifo output 0's if the fifo is empty.
-- Revision 0.03 	23/04/2010	Anders Lange	SYNC_DEPTH generic added and fifo_ctrl component declaration and instantiation updated.
-- Revision 0.04 	10/05/2010	Anders Lange	Copyright conditions & disclamer added.
-- Revision 0.05 	01/06/2010	Anders Lange	wr_ack_o functionality added.
-- Revision 0.06 	12/06/2010	Anders Lange	PRE_LOAD generic added.
-- Revision 1.00  12/06/2010	Anders Lange	Offical release
-- Revision 1.90	06/11/2010 	Anders Lange	MODE_ASYNC generic + conditional synthesis code added for support of synchronous and asynchronous fifo modes
-- Revision 1.91	06/11/2010 	Anders Lange	New Header & Copyright added, old Copyright conditions & disclamer removed
-- Revision 1.92 
--
-- Additional Comments: 
-- 
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
entity fifo is
   generic(	ADDR_WIDTH: positive:=4;						-- Reg file address width / Fifo depth
				DATA_WIDTH: positive:=33;					   -- Data width
				MODE_ASYNC: natural range 0 to 1 := 1;    -- Fifo mode: 0 -> synchronous, 1 -> asynchronous
				SYNC_DEPTH: natural range 1 to 8 := 2;		-- Synchronizer depth (asynch mode only)
				PRE_LOAD: 	natural:=0;						   -- Write<>Read Ptr offset before deasserting empty signal (read logic)
				EN_WRT_ACK: natural range 0 to 1 := 0);   -- Write acknowledge; 0 -> disabled, 1 -> enabled				
   
   port(
		clk_i: in std_logic;
   	-- Input clock domain
      clkw_asynch_i: in std_logic;
      wr_i: in std_logic;
      data_in_i : in std_logic_vector(DATA_WIDTH-1 downto 0);
      wr_ack_o : out std_logic;
		full_o: out std_logic;
      -- Output clock domain
      clkr_asynch_i: in std_logic;
      rd_i: in std_logic;
      data_out_o : out std_logic_vector(DATA_WIDTH-1 downto 0);
      empty_o: out std_logic;
      -- Common inputs
      reset_i : in std_logic);
end fifo;

--------------------------------------------------------------------------------
-- Architecture
--------------------------------------------------------------------------------
architecture str_arch of fifo is
   	-- Internal signals mapped to IO ports
      signal clkw: std_logic;
      signal wr, ramwr: std_logic;
      signal data_in : std_logic_vector(DATA_WIDTH-1 downto 0);
      signal wr_ack: std_logic;
		signal full: std_logic;
      signal clkr: std_logic;
      signal rd: std_logic;
      signal data_out : std_logic_vector(DATA_WIDTH-1 downto 0);
      signal empty: std_logic;
      signal reset: std_logic;
      
      -- Signals for internal interconnect
      signal w_addr, r_addr: std_logic_vector(ADDR_WIDTH-1 downto 0);
      
      -- Component declarations
			component fifo_ctrl is
				generic(ADDR_WIDTH: natural;		--Address width (depth)
						  SYNC_DEPTH: natural;		--Synchronizer depth
						  MODE_ASYNC: natural;
						  PRE_LOAD: natural);		--Pre load number
			   port(	clkw_i: in std_logic;
						resetw_i: in std_logic;
						wr_i: in std_logic;
						full_o: out std_logic;
						w_addr_o: out std_logic_vector (ADDR_WIDTH-1 downto 0);
						clkr_i: in std_logic;
						resetr_i: in std_logic;
						rd_i: in std_logic;
						empty_o: out std_logic;
						r_addr_o: out std_logic_vector (ADDR_WIDTH-1 downto 0));
			end component;
			
			component rams_09 is
				 generic(	ADDR_WIDTH: integer;
				 				DATA_WIDTH: integer);
				 port ( 	clk_i : in std_logic;
							we_i : in std_logic;
				 			addr_a_i : in std_logic_vector(ADDR_WIDTH-1 downto 0);
				 			addr_b_i : in std_logic_vector(ADDR_WIDTH-1 downto 0);
				 			din_a_i : in std_logic_vector(DATA_WIDTH-1 downto 0);
				 			dout_b_o : out std_logic_vector(DATA_WIDTH-1 downto 0));
			end component;			

begin

		-- Input
		clkw <= clkw_asynch_i when MODE_ASYNC = 1 else clk_i;
		clkr <= clkr_asynch_i when MODE_ASYNC = 1 else clk_i;
		
		wr <= wr_i;
		ramwr <= wr when full='0' else '0';
		data_in <= data_in_i;
				
		rd <= rd_i;
		reset <= reset_i;
		
		-- Component instantiation and wiring
		fifo_ctrl_inst: fifo_ctrl
			 generic map(	ADDR_WIDTH => ADDR_WIDTH,
								SYNC_DEPTH => SYNC_DEPTH,
								MODE_ASYNC => MODE_ASYNC,
								PRE_LOAD   => PRE_LOAD)						
			 port map(		clkw_i => clkw,
			 					resetw_i => reset,
			 					wr_i => wr,
			 					full_o => full,
			 					w_addr_o => w_addr,
			 					clkr_i => clkr,
			 					resetr_i => reset,
			 					rd_i => rd,
			 					empty_o => empty,
			 					r_addr_o => r_addr);
			 
		regfile: rams_09
			 generic map(	ADDR_WIDTH => ADDR_WIDTH,
	 							DATA_WIDTH => DATA_WIDTH)
			 port map(		clk_i => clkw,
								we_i => ramwr,
			 					addr_a_i => w_addr,
			 					addr_b_i => r_addr,
			 					din_a_i => data_in,
			 					dout_b_o => data_out);			 
		
		-- Write acknowledge process
		process(clkw)
		begin
			if(clkw'event and clkw='1') then
				wr_ack <= '0'; -- reset
				if(wr='1') then -- write enable
					if(full='0') then 	
						wr_ack <= '1';
					end if;
				end if;
			end if;
		end process;
		
		-- Output
		wr_ack_o <= wr_ack when EN_WRT_ACK = 1 else '0';
		full_o <= full;
		empty_o <= empty;
		data_out_o <= data_out when empty='0' else (others=>'0');

end str_arch;

--------------------------------------------------------------------------------
-- End of file
--------------------------------------------------------------------------------