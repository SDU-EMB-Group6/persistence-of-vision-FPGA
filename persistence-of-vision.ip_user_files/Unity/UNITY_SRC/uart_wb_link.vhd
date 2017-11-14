----------------------------------------------------------------------------------
-- Company: University Of Southern Denmark
-- Engineer: Anders Blaabjerg Lange
-- 
-- Create Date:    13:20:02 01/05/2012 
-- Design Name: 
-- Module Name:    uart_wb_link - structural 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: UART Wishbone Link
--
-- Dependencies: 
--
-- Revision: 
-- 0.01	01/05/2012	ANLAN		File Created
-- 0.02  
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.wb_classic_interface.all;
use work.util_pkg.all;
use work.log_pkg.all;

entity uart_wb_link is
	generic (
		-- Physical Layer Configuration
		C_PL_TICKS_PR_BIT				: integer 				  	 := 16;			-- number of (baudrate generator) ticks for each bit. MUST BE AN EVEN NUMBER. default = 16
		C_PL_BAUD_RATE_DVSR  		: positive					 := 2;			-- BAUD rate divisor: C_BAUD_RATE_DVSR = clk_frq/(C_TICKS_PR_BIT*baud_rate)
		C_PL_STOPBITS					: integer range 1 to 2 	 := 1;			-- number of stopbits
		C_PL_PARITY						: integer range 0 to 4 	 := 0;			-- parity mode: 0 = NONE, 1 = ODD, 2 = EVEN, 3 = MARK, 4 = SPACE		
		-- Datalink Layer Configuration
		C_DL_FULL						: integer range 0 to 1	 := 1;			-- 1 = Full Datalink Layer, 0 = Lite Datalink Layer (No FIFO's, Checksum or error detection)
		C_DL_CHECKSUM					: integer range 0 to 2   := 2;			-- checksum mode: 0 = NONE, 1 = BYTE WISE XOR, 2 = CRC-8-CCIT		
		-- Application Layer Configuration
		C_AL_RLC_EN						: integer range 0 to 1	 := 1;			-- 0: Read Link Config command disabled, 1: Read Link Config command enabled
		C_AL_RM_SIZE					: integer range 0 to 255 := 32;			-- 0: RM disabled, 1-255: RM enabled (up to C_RM_SIZE reads allowed in one command RM)
		C_AL_PUB_MODE					: integer range 0 to 2 	 := 2;			-- 0: Publish mode disabled, 1: Prioritize incoming requests, 2: Prioritize Publish requests		
		C_AL_PUBLISH_BASE_FREQ		: positive					 := 1000;		-- Publish sync strobe base frequency [Hz]			
		C_AL_SUBMNGR_SGID_SIZE		: integer range 0 to 4   := 1;			-- Bitwidth of the Group ID port (controls the number of individual subscription groups)
		C_AL_SUBGRP_RATE_BYTE_CNT 	: integer range 1 to 4 	 := 2; 			-- Number of bytes in the RATE register of each subscription group
		C_AL_SUBGRP_ADDR_WIDTH 		: integer range 2 to 5	 := 4;			-- Size/depth of each subscription group = (2**C_AL_SUBGRP_ADDR_WIDTH) : RANGE=[4,8,16,32]		
		-- Wishbone Interface Configuration
		C_WB_CLK_FREQ					: positive					 := 50000000;	-- Wishbone clock frequency [Hz]
		C_WB_ADDR_WIDTH				: integer range 1 to 32  := 32;			-- Wishbone bus address space/size
		C_WB_DATA_WIDTH				: integer range 8 to 32  := 32			-- Wishbone bus data width: [8,16,32]
		);
	port (
		-- UART interface
		clk_uart_i 			: in  std_logic;		-- Must be an integer multiple of the clock frequency of the USB<>UART bridge
		rx_uart_i			: in  std_logic;
		tx_uart_o			: out std_logic;
		
		-- WB syscon interface
		clk_i					: in  std_logic;
		rst_i					: in  std_logic;
		
		-- WB master interface
		wb_o 					: out wb_ad32sb_if;
		wb_i 					: in  wb_d32ae_if
		
		);
end uart_wb_link;

architecture structural of uart_wb_link is

	-- BII <> WB Master signals
	signal mst_en_i 	: std_logic;														-- enable (keep high during a cycle/block)
	signal mst_we_i	: std_logic;														-- write enable: write=1, read=0 (must not change during a cycle/block)
	signal mst_blk_i 	: std_logic;														-- block mode: block=1, single=0
	signal mst_nxt_i	: std_logic;														-- has next (valid in block mode), set to 1 if current is not the last read/write in the block (update synchronous to clock when done=1)
	signal mst_adr_i	: std_logic_vector(C_WB_ADDR_WIDTH-1 downto 0);			-- address in	(clock synchronous update when done=1)
	signal mst_dat_i	: std_logic_vector(C_WB_DATA_WIDTH-1 downto 0);			-- data in (write) (update synchronous to clock when done=1)
	signal mst_dat_o	: std_logic_vector(C_WB_DATA_WIDTH-1 downto 0);			-- data out (read) (update synchronous to clock when done=1)
	signal mst_done_o	: std_logic;														-- done strobe	 (Success)
	signal mst_err_o 	: std_logic;														-- error strobe (Failure)	
	
begin

	uart_gab_link_inst : entity work.uart_gab_link
		generic map(
			-- Physical Layer Configuration
			C_PL_TICKS_PR_BIT				=> C_PL_TICKS_PR_BIT,
			C_PL_BAUD_RATE_DVSR  		=> C_PL_BAUD_RATE_DVSR,
			C_PL_RX_FIFO_ADDR_W			=> 2,
			C_PL_TX_FIFO_ADDR_W			=> 2,
			C_PL_STOPBITS					=> C_PL_STOPBITS,
			C_PL_PARITY						=> C_PL_PARITY,
			-- Datalink Layer Configuration
			C_DL_FULL						=> C_DL_FULL,
			C_DL_TXFIFO_A_ADDR_WIDTH	=> 4,
			C_DL_TXFIFO_B_ADDR_WIDTH	=> 2,
			C_DL_CHECKSUM					=> C_DL_CHECKSUM,
			-- Application Layer Configuration
			C_AL_RLC_EN						=> C_AL_RLC_EN,
			C_AL_RM_SIZE					=> C_AL_RM_SIZE,
			C_AL_PUB_MODE					=> C_AL_PUB_MODE,
			C_AL_PUBLISH_BASE_FREQ		=> C_AL_PUBLISH_BASE_FREQ,
			C_AL_SUBMNGR_SGID_SIZE		=> C_AL_SUBMNGR_SGID_SIZE,
			C_AL_SUBGRP_RATE_BYTE_CNT 	=> C_AL_SUBGRP_RATE_BYTE_CNT,
			C_AL_SUBGRP_ADDR_WIDTH 		=> C_AL_SUBGRP_ADDR_WIDTH,
			-- BUS Independent Interface (BII) Configuration
			C_BII_CLK_FREQ					=> C_WB_CLK_FREQ,
			C_BII_ADDR_WIDTH				=> C_WB_ADDR_WIDTH,
			C_BII_DATA_WIDTH				=> C_WB_DATA_WIDTH
			)
		port map(
			-- UART interface
			clk_uart_i	=> clk_uart_i,
			rx_uart_i	=> rx_uart_i,
			tx_uart_o	=> tx_uart_o,
			
			-- BUS Independent interface (BII)
			clk_i			=> clk_i,
			rst_i			=> rst_i,
			en_o			=> mst_en_i,
			we_o			=> mst_we_i,
			blk_o 		=> mst_blk_i,
			nxt_o			=> mst_nxt_i,
			adr_o			=> mst_adr_i,
			dat_o			=> mst_dat_i,
			dat_i			=> mst_dat_o,
			done_i		=> mst_done_o,
			err_i 		=> mst_err_o
			);
	
	-- Wishbone Master FSM
	wb_mst_ctrl_inst : entity work.wb_mst_ctrl
		generic map(
			C_ADDR_WIDTH 		=> C_WB_ADDR_WIDTH,
			C_DATA_WIDTH 		=> C_WB_DATA_WIDTH
		)
		port map( 
			-- wb syscon interface	
			clk_i => clk_i,
			rst_i => rst_i,
			
			-- wb master interface
			wb_o 	=> wb_o,
			wb_i 	=> wb_i,
			
			-- user logic interface
			en_i		=> mst_en_i,
			we_i		=> mst_we_i,
			blk_i 	=> mst_blk_i,
			nxt_i		=> mst_nxt_i,
			adr_i		=> mst_adr_i,
			dat_i		=> mst_dat_i,
			dat_o		=> mst_dat_o,
			done_o	=> mst_done_o,
			err_o 	=> mst_err_o
		);
		
end structural;


