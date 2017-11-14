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
-- Modulename: 	FifoWritePort.vhd
--
-- Description: 	Parameterized FIFO write port
--
--						Default generic config:
--						N = 3 - Address width: 3 bits
--
-- Dependencies: 	None
--
-- Change Log:
--------------------------------------------------------------------------------
-- Revision 		Date    		Id					Change
--                DD/MM/YYYY
-- ---------------------------------------------------------
-- Revision: 
-- Revision 0.01  04/04/2010  Anders Lange   File Created
-- Revision 0.02  17/04/2010  Anders Lange   Initial/startup values assigned to all internal signals.
-- Revision 0.03  10/05/2010  Anders Lange   Copyright conditions & disclamer added.
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
entity fifo_write_ctrl is
   generic(N: natural:=3); --N: number of bits in address
   port(
      clkw_i: in std_logic;
      resetw_i: in std_logic;
      wr_i: in std_logic;
      r_ptr_in_i: in std_logic_vector(N downto 0);
      full_o: out std_logic;
      w_ptr_out_o: out std_logic_vector(N downto 0);
      w_addr_o: out std_logic_vector(N-1 downto 0)
   );
end fifo_write_ctrl;

--------------------------------------------------------------------------------
-- Architecture
--------------------------------------------------------------------------------
architecture gray_arch of fifo_write_ctrl is
	 -- Internal signals mapped to input ports
   signal clkw: std_logic;
   signal resetw: std_logic;
   signal wr: std_logic;
   signal r_ptr_in: std_logic_vector(N downto 0);

   -- Signals for implementing registers, counters and flags
   signal w_ptr_reg, w_ptr_next: std_logic_vector(N downto 0) := (others => '0');
   signal gray1, bin, bin1: std_logic_vector(N downto 0) := (others => '0');
   signal waddr_all, raddr_all: std_logic_vector(N-1 downto 0) := (others => '0');
   signal waddr_msb, raddr_msb: std_logic := '0';
   signal full_flag: std_logic := '0';
begin
	 -- Input
	 clkw <= clkw_i;
	 resetw <= resetw_i;
	 wr <= wr_i;
	 r_ptr_in <= r_ptr_in_i;

   -- Update write ptr register
   process(clkw,resetw)
   begin
      if (resetw='1') then
          w_ptr_reg <= (others=>'0');
      elsif (clkw'event and clkw='1') then
         w_ptr_reg <= w_ptr_next;
      end if;
   end process;
   
   -- (N+1)-bit Gray counter
   bin <= w_ptr_reg xor ('0' & bin(N downto 1));  -- Gray to Bin
   bin1 <= std_logic_vector(unsigned(bin) + 1);   -- Bin increment
   gray1 <= bin1 xor ('0' & bin1(N downto 1));    -- Bin to Gray
     
   -- Update write pointer
   w_ptr_next <= gray1 when wr='1' and full_flag='0' else
                 w_ptr_reg;
                 
   -- N-bit Gray counter
   waddr_msb <= w_ptr_reg(N) xor w_ptr_reg(N-1);   
   waddr_all <= waddr_msb & w_ptr_reg(N-2 downto 0);
   
   -- Check for FIFO full
   raddr_msb <= r_ptr_in(N) xor r_ptr_in(N-1);
   raddr_all <= raddr_msb & r_ptr_in(N-2 downto 0);
   
   full_flag <= '1' when ((r_ptr_in(N) /= w_ptr_reg(N)) and (raddr_all = waddr_all))
                 else '0';
   
   -- Output
   w_addr_o <= waddr_all;
   w_ptr_out_o <= w_ptr_reg;
   full_o <= full_flag;
   
end gray_arch;

--------------------------------------------------------------------------------
-- End of file
--------------------------------------------------------------------------------