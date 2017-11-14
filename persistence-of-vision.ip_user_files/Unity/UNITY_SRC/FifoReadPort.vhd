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
-- Modulename: 	FifoReadPort.vhd
--
-- Description: 	Parameterized FIFO read port
--
--						Default generic config:
--						N = 3 - Address width: 3 bits
--						PRE_LOAD = 2 - Pre load number: 2 words
--
-- Dependencies: 	None
--
-- Change Log:
--------------------------------------------------------------------------------
-- Revision 		Date    		Id					Change
--                DD/MM/YYYY
-- ---------------------------------------------------------
-- Revision: 
-- Revision 0.01  06/04/2010  Anders Lange   File Created
-- Revision 0.02  17/04/2010  Anders Lange   Initial/startup values assigned to all internal signals.
-- Revision 0.03  10/05/2010  Anders Lange   Copyright conditions & disclamer added.
-- Revision 0.04  12/06/2010  Anders Lange   PRE_LOAD generic and functionality added to prevent false empty signal 
--          						               in the event that metastability causes the synchronizer to register the wrong writepointer.
-- Revision 0.05  12/06/2010  Anders Lange   Calculation of pre_load limit changed to prevent glitch.
-- Revision 1.00  12/06/2010	Anders Lange	Offical release
-- Revision 1.01	11/11/2010 	Anders Lange	New Header & Copyright added, old Copyright conditions & disclamer removed
-- Revision 1.02   
--
-- Additional Comments: 
-- Based on listing 16.14 from "RTL Hardware Design using VHDL" by Pong P. Chu
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
entity fifo_read_ctrl is
   generic(N: natural:=3; 					-- N: number of bits in address (2**3 = 8)
			  PRE_LOAD: natural:=2);		-- Write<>Read Ptr offset before deasserting empty signal (read logic)	
   port(
      clkr_i: in std_logic;
      resetr_i: in std_logic;
      rd_i: in std_logic;      
      w_ptr_in_i: in std_logic_vector(N downto 0);
      empty_o: out std_logic;
      r_ptr_out_o: out std_logic_vector(N downto 0);
      r_addr_o: out std_logic_vector(N-1 downto 0)
   );
end fifo_read_ctrl;

--------------------------------------------------------------------------------
-- Architecture
--------------------------------------------------------------------------------
architecture gray_arch of fifo_read_ctrl is
   -- Internal signals mapped to input ports
   signal clkr: std_logic;
   signal resetr: std_logic;
   signal w_ptr_in: std_logic_vector(N downto 0);
   signal rd: std_logic;

   -- Signals for implementing registers, counters and flags
   signal r_ptr_reg, r_ptr_next: std_logic_vector(N downto 0) := (others => '0');
   signal gray1, bin, bin1: std_logic_vector(N downto 0) := (others => '0');
   signal raddr_all, waddr_all: std_logic_vector(N-1 downto 0) := (others => '0');
   signal raddr_msb, waddr_msb: std_logic := '0';
   signal empty_flag: std_logic := '0';
	
	signal empty_flag_reg: std_logic := '1';
	signal wbin: std_logic_vector(N downto 0) := (others => '0');
	
begin
	 -- Input
	 clkr <= clkr_i;
	 resetr <= resetr_i;
	 w_ptr_in <= w_ptr_in_i;
	 rd <= rd_i;

   -- Update read ptr register
   process(clkr,resetr)
   begin
      if (resetr='1') then
         r_ptr_reg <= (others=>'0');
      elsif (clkr'event and clkr='1') then
         r_ptr_reg <= r_ptr_next;
			empty_flag_reg <= empty_flag;
      end if;
   end process;
   
   -- (N+1)-bit Gray counter
   bin <= r_ptr_reg xor ('0' & bin(N downto 1));  -- Gray to Bin
   bin1 <= std_logic_vector(unsigned(bin) + 1);   -- Bin increment
   gray1 <= bin1 xor ('0' & bin1(N downto 1));    -- Bin to Gray
   
   -- Update read pointer
   r_ptr_next <= gray1 when rd='1' and empty_flag='0' else
                 r_ptr_reg;
                 
   -- N-bit Gray counter
   raddr_msb <= r_ptr_reg(N) xor r_ptr_reg(N-1);
   raddr_all <= raddr_msb & r_ptr_reg(N-2 downto 0);  
   
   -- Check for FIFO empty
   waddr_msb <= w_ptr_in(N) xor w_ptr_in(N-1);
   waddr_all <= waddr_msb & w_ptr_in(N-2 downto 0);
	
		-- Keep empty signal high until w_ptr_in is PRE_LOAD words ahead of r_ptr_reg
		wbin <= w_ptr_in xor ('0' & wbin(N downto 1));	-- w_ptr_in Gray to Bin
		
   
   empty_flag <= '1' when ((w_ptr_in(N) = r_ptr_reg(N)) and (raddr_all = waddr_all)) else
					  '1' when (empty_flag_reg = '1' and ((unsigned(wbin)-unsigned(bin)) <= PRE_LOAD) )
   								else '0';
      
    -- Output
    r_addr_o <= raddr_all;
    r_ptr_out_o <= r_ptr_reg;
    empty_o <= empty_flag;
    
end gray_arch;

--------------------------------------------------------------------------------
-- End of file
--------------------------------------------------------------------------------