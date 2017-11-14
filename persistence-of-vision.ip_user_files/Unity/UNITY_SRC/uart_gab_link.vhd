----------------------------------------------------------------------------------
-- Company: University Of Southern Denmark
-- Engineer: Anders Blaabjerg Lange
-- 
-- Create Date:    10:00:02 04/04/2012 
-- Design Name: 
-- Module Name:    uart_gab_link - structural 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: UART GAB link with Bus independent interface
--
-- Dependencies: 
--
-- Revision: 
-- 0.01	24/04/2012	ANLAN		File Created
-- 0.02  01/05/2012	ANLAN		filename changed to uart_gab_link
-- 0.03  
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.util_pkg.all;
use work.log_pkg.all;

entity uart_gab_link is
	generic (
		-- Physical Layer Configuration
		C_PL_TICKS_PR_BIT				: integer 				  	 := 16;			-- number of (baudrate generator) ticks for each bit. MUST BE AN EVEN NUMBER. default = 16
		C_PL_BAUD_RATE_DVSR  		: positive					 := 2;			-- BAUD rate divisor: C_BAUD_RATE_DVSR = clk_frq/(C_TICKS_PR_BIT*baud_rate)
		C_PL_RX_FIFO_ADDR_W			: positive				  	 := 2;			-- rx fifo depth = 2**C_RX_FIFO_ADDR_W
		C_PL_TX_FIFO_ADDR_W			: positive				  	 := 2;			-- tx fifo depth = 2**C_TX_FIFO_ADDR_W
		C_PL_STOPBITS					: integer range 1 to 2 	 := 1;			-- number of stopbits
		C_PL_PARITY						: integer range 0 to 4 	 := 0;			-- parity mode: 0 = NONE, 1 = ODD, 2 = EVEN, 3 = MARK, 4 = SPACE		
		-- Datalink Layer Configuration
		C_DL_FULL						: integer range 0 to 1	 := 1;			-- 1 = Full Datalink Layer, 0 = Lite Datalink Layer (No FIFO's, Checksum or error detection)
		C_DL_TXFIFO_A_ADDR_WIDTH	: positive 					 := 4;			-- FIFO receiving response/publish data from the application layer
		C_DL_TXFIFO_B_ADDR_WIDTH	: positive 					 := 2;			-- FIFO receiving error data from the datalink layer RxFSM
		C_DL_CHECKSUM					: integer range 0 to 2   := 2;			-- checksum mode: 0 = NONE, 1 = BYTE WISE XOR, 2 = CRC-8-CCIT		
		-- Application Layer Configuration
		C_AL_RLC_EN						: integer range 0 to 1	 := 1;			-- 0: Read Link Config command disabled, 1: Read Link Config command enabled
		C_AL_RM_SIZE					: integer range 0 to 255 := 32;			-- 0: RM disabled, 1-255: RM enabled (up to C_RM_SIZE reads allowed in one command RM)
		C_AL_PUB_MODE					: integer range 0 to 2 	 := 2;			-- 0: Publish mode disabled, 1: Prioritize incoming requests, 2: Prioritize Publish requests		
		C_AL_PUBLISH_BASE_FREQ		: positive					 := 1000;		-- Publish sync strobe base frequency [Hz]			
		C_AL_SUBMNGR_SGID_SIZE		: integer range 0 to 4   := 1;			-- Bitwidth of the Group ID port (controls the number of individual subscription groups)
		C_AL_SUBGRP_RATE_BYTE_CNT 	: integer range 1 to 4 	 := 2; 			-- Number of bytes in the RATE register of each subscription group
		C_AL_SUBGRP_ADDR_WIDTH 		: integer range 2 to 5	 := 4;			-- Size/depth of each subscription group = (2**C_AL_SUBGRP_ADDR_WIDTH) : RANGE=[4,8,16,32]		
		-- BUS Independent Interface (BII) Configuration
		C_BII_CLK_FREQ					: positive					 := 50000000;	-- BII clock frequency [Hz]
		C_BII_ADDR_WIDTH				: integer range 1 to 32  := 32;			-- BII bus address space/size
		C_BII_DATA_WIDTH				: integer range 8 to 32  := 32			-- BII bus data width: [8,16,32]
		);
	port (
		-- UART interface
		clk_uart_i	: in  std_logic;		-- Must be an integer multiple of the clock frequency of the USB<>UART bridge
		rx_uart_i	: in  std_logic;
		tx_uart_o	: out std_logic;
		
		-- BUS Independent interface (BII)
		clk_i			: in  std_logic;
		rst_i			: in  std_logic;		
		en_o			: out std_logic;													-- enable (keep high during a cycle/block)
		we_o			: out std_logic;													-- write enable: write=1, read=0 (must not change during a cycle/block)
		blk_o 		: out std_logic;													-- block mode: block=1, single=0
		nxt_o			: out std_logic;													-- has next (valid in block mode), set to 1 if current is not the last read/write in the block (update synchronous to clock when done=1)
		adr_o			: out std_logic_vector(C_BII_ADDR_WIDTH-1 downto 0);	-- address in	(clock synchronous update when done=1)
		dat_o			: out std_logic_vector(C_BII_DATA_WIDTH-1 downto 0);	-- data out (write) (update synchronous to clock when done=1)
		dat_i			: in  std_logic_vector(C_BII_DATA_WIDTH-1 downto 0);	-- data in (read)
		done_i		: in  std_logic;													-- done strobe	 (Success)
		err_i 		: in  std_logic													-- error strobe (Failure)		
		);
end uart_gab_link;

architecture structural of uart_gab_link is

	constant C_ADDR_BYTES : integer := byte_cnt(C_BII_ADDR_WIDTH);
	constant C_DATA_BYTES : integer := byte_cnt(C_BII_DATA_WIDTH);

	function max_inpacket_bytesize return integer is
		
		variable chks_bytes	: integer := 0;
		variable res			: integer := 0;		
		variable b				: integer := 0;
		
	begin
		if C_DL_CHECKSUM>0 then
			chks_bytes := 3;
		end if;
		
		-- max_sizeof(R)
		-- $R:[adr]]*[cs][cs]/n
		-- 4+C_ADDR_BYTES+C_CHKS_BYTES (no chks: min=5, max=8. with chks: min=8, max=11)
		b := 4+C_ADDR_BYTES+chks_bytes;
		res := max(b, res);
		
		-- max_sizeof(RM)
		-- $RM:[cnt]([adr]]))*[cs][cs]\n
		-- C_AL_RM_SIZE=0 -> 0
		-- C_AL_RM_SIZE>0 -> 6+C_CHKS_BYTES+C_ADDR_BYTES*C_AL_RM_SIZE (no chks: min=7, max=1026. with chks: min=10, max=1029)
		if C_AL_RM_SIZE>0 then
			b := 6+chks_bytes+C_ADDR_BYTES*C_AL_RM_SIZE;
			res := max(b, res);
		end if;
		
		-- max_sizeof(RSI)
		-- $RSI:[grp]*[cs][cs]\n
		-- C_AL_PUB_MODE=0 -> 0
		-- C_AL_PUB_MODE>0 -> 7+C_CHKS_BYTES (no chks: 7. with chks: 10)
		if C_AL_PUB_MODE>0 then
			b := 7+chks_bytes;
			res := max(b, res);
		end if;
		
		-- max_sizeof(W)
		-- $W:[add]][data]]*[cs][cs]\n
		-- 4+C_ADDR_BYTES+C_DATA_BYTES+C_CHKS_BYTES (no chks: min=6, max=12. with chks: min=9, max=15)
		b := 4+C_ADDR_BYTES+C_DATA_BYTES+chks_bytes;
		res := max(b, res);
		
		-- max_sizeof(WSR)
		-- $WSR:[grp][rate]]*[cs][cs]\n
		-- C_AL_PUB_MODE=0 -> 0
		-- C_AL_PUB_MODE>0 -> 7+C_AL_SUBGRP_RATE_BYTE_CNT+C_CHKS_BYTES (no chks: min=8, max=11. with chks: min=11, max=14)
		if C_AL_PUB_MODE>0 then
			b := 7+C_AL_SUBGRP_RATE_BYTE_CNT+chks_bytes;
			res := max(b, res);
		end if;
		
		-- max_sizeof: WSA
		-- $WSA:[grp][cnt]([adr]]))*[cs][cs]\n
		-- C_AL_PUB_MODE=0 -> 0
		-- C_AL_PUB_MODE>0 -> 7+(2**C_AL_SUBGRP_ADDR_WIDTH)*C_ADDR_BYTES+C_CHKS_BYTES (no chks: min=8, max=135. with chks: min=11, max=138)
		if C_AL_PUB_MODE>0 then
			b := 7+(2**C_AL_SUBGRP_ADDR_WIDTH)*C_ADDR_BYTES+chks_bytes;
			res := max(b, res);
		end if;
		
		-- max_sizeof: EPS
		-- $EPS*[cs][cs]\n
		-- C_AL_PUB_MODE=0 -> 0
		-- C_AL_PUB_MODE>0 -> 5+C_CHKS_BYTES | no chks: 8. with chks: 11
		
		-- max_sizeof: EPC
		-- $EPC*[cs][cs]\n
		-- C_AL_PUB_MODE=0 -> 0
		-- C_AL_PUB_MODE>0 -> 5+C_CHKS_BYTES | no chks: 8. with chks: 11

		-- max_sizeof: DPS
		-- $DPS*[cs][cs]\n
		-- C_AL_PUB_MODE=0 -> 0
		-- C_AL_PUB_MODE>0 -> 5+C_CHKS_BYTES | no chks: 8. with chks: 11		
		if C_AL_PUB_MODE>0 then
			b := 5+chks_bytes;
			res := max(b, res);
		end if;		
		
		return res;
	end max_inpacket_bytesize;
	
	constant C_DL_RXFIFO_ADDR_WIDTH : positive := log2c(max_inpacket_bytesize);

	-- UART <> UART GAB Link DL Layer signals
	signal rx_uart_fifo_empty 		: std_logic;
	signal rx_uart_fifo_read		: std_logic;		
	signal rx_uart_fifo_data		: std_logic_vector (7 downto 0);
	signal rx_uart_reset				: std_logic;
	
	signal lsr							: std_logic_vector (7 downto 0);
	signal rx_uart_parity_err 		: std_logic;
	signal rx_uart_framing_err 	: std_logic;
	signal rx_uart_overrun_err 	: std_logic;
	signal rx_uart_clear_errors	: std_logic;			
	signal tx_uart_fifo_full 		: std_logic;
	signal tx_uart_fifo_write		: std_logic;
	signal tx_uart_fifo_data 		: std_logic_vector (7 downto 0);
	
	-- UART GAB Link DL Layer <> GAB Link AL Layer signals
	signal rx_fifo_empty				: std_logic;
	signal rx_fifo_rd					: std_logic;
	signal rx_fifo_data				: std_logic_vector(8 downto 0);
	signal tx_fifo_full				: std_logic;
	signal tx_fifo_wr					: std_logic;
	signal tx_fifo_data				: std_logic_vector(8 downto 0);	
	
begin
	
	-- Physical Layer : UART
	uart_inst : entity work.uart_asynch
		generic map(
			C_ERROR_CNT_WIDTH	=> 0,								-- Bitwidth of the error counters (0 = counters disabled)
			C_BIT_TXRX_ORDER	=> 0,								-- databit tx/rx order: 0 = LSB, 1 = MSB		
			C_TICKS_PR_BIT		=> C_PL_TICKS_PR_BIT,		-- number of (baudrate generator) ticks for each bit. MUST BE AN EVEN NUMBER. default = 16
			C_BAUD_RATE_DVSR  => C_PL_BAUD_RATE_DVSR,		-- BAUD rate divisor: C_BAUD_RATE_DVSR = clk_frq/(C_TICKS_PR_BIT*baud_rate)
			C_RX_FIFO_ADDR_W	=> C_PL_RX_FIFO_ADDR_W,		-- rx fifo depth = 2**C_RX_FIFO_ADDR_W
			C_TX_FIFO_ADDR_W	=> C_PL_TX_FIFO_ADDR_W,		-- tx fifo depth = 2**C_TX_FIFO_ADDR_W
			C_DATABITS 			=> 8,								-- number of databits
			C_STOPBITS			=> C_PL_STOPBITS,				-- number of stopbits
			C_PARITY				=> C_PL_PARITY 				-- parity mode: 0 = NONE, 1 = ODD, 2 = EVEN, 3 = MARK, 4 = SPACE
			)
		port map ( 
			-- common io
			reset_i 				=> '0',
			reset_rx_i			=>	rx_uart_reset,
			reset_tx_i			=>	'0',	
			
			-- uart clock domain io
			uart_clk_i			=> clk_uart_i,
			
			rx_i 					=> rx_uart_i,
			tx_o 					=> tx_uart_o,
			
			-- user logic (fifo+uart status) clock domain io
			user_clk_i			=> clk_i,
			
			lsr_o 				=> lsr,
			clr_lsr_errors_i	=> rx_uart_clear_errors,			
			
			framing_err_cnt_o	=> open,
			parity_err_cnt_o	=> open,
			overrun_err_cnt_o	=> open,
			clr_err_cnt_i		=> "000",
			
			rx_fifo_empty_o 	=> rx_uart_fifo_empty,
			rx_fifo_read_i		=> rx_uart_fifo_read,
			rx_fifo_data_o 	=> rx_uart_fifo_data,
			
			tx_fifo_full_o 	=> tx_uart_fifo_full,
			tx_fifo_write_i	=> tx_uart_fifo_write,
			tx_fifo_data_i 	=> tx_uart_fifo_data
			);
			
		rx_uart_parity_err 	<= lsr(4);
		rx_uart_framing_err	<= lsr(5);
		rx_uart_overrun_err	<= lsr(3);		
	
	-- Datalink Layer
	uart_gab_link_dl_inst : entity work.uart_gab_link_dl
		generic map (
			C_FULL_DL					=> C_DL_FULL,
			C_RXFIFO_ADDR_WIDTH 		=> C_DL_RXFIFO_ADDR_WIDTH,
			C_TXFIFO_A_ADDR_WIDTH 	=> C_DL_TXFIFO_A_ADDR_WIDTH,
			C_TXFIFO_B_ADDR_WIDTH 	=> C_DL_TXFIFO_B_ADDR_WIDTH,
			C_UART_PARITY_EN			=> C_PL_PARITY,
			C_CHECKSUM					=> C_DL_CHECKSUM
		)
		port map ( 
			clk_i 						=> clk_i,
			reset_i 						=> rst_i,
			
			-- UART GAB Link Physical Layer interface
			
				-- Rx UART
				rx_uart_fifo_empty_i 	=> rx_uart_fifo_empty,
				rx_uart_fifo_read_o 		=> rx_uart_fifo_read,
				rx_uart_fifo_data_i 		=> rx_uart_fifo_data,
				rx_uart_fifo_reset_o		=> rx_uart_reset,
				
				rx_uart_parity_err_i 	=> rx_uart_parity_err,
				rx_uart_framing_err_i 	=> rx_uart_framing_err,
				rx_uart_overrun_err_i 	=> rx_uart_overrun_err,
				rx_uart_clear_errors_o 	=> rx_uart_clear_errors,
				
				-- Tx UART
				tx_uart_fifo_full_i 		=> tx_uart_fifo_full,
				tx_uart_fifo_write_o 	=> tx_uart_fifo_write,
				tx_uart_fifo_data_o 		=> tx_uart_fifo_data,
			
			-- GAB Link Application Layer interface
			
				-- RxFIFO
				rx_fifo_empty_o			=> rx_fifo_empty,
				rx_fifo_rd_i				=> rx_fifo_rd,
				rx_fifo_data_o				=> rx_fifo_data,
				
				-- TxFIFO
				tx_fifo_full_o				=> tx_fifo_full,
				tx_fifo_wr_i				=> tx_fifo_wr,
				tx_fifo_data_i				=> tx_fifo_data
			);						
	
	-- Application Layer
	gab_link_al_fsm_inst : entity work.gab_link_al_fsm
		generic map(
			C_RLC_EN						=> C_AL_RLC_EN,
			C_RM_SIZE					=> C_AL_RM_SIZE,			
			C_PUB_MODE					=> C_AL_PUB_MODE,			
			C_CLK_FREQ					=> C_BII_CLK_FREQ,
			C_PUBLISH_SYNC_FREQ		=> C_AL_PUBLISH_BASE_FREQ,
			C_SUBMNGR_SGID_SIZE		=> C_AL_SUBMNGR_SGID_SIZE,
			C_SUBGRP_RATE_BYTE_CNT 	=> C_AL_SUBGRP_RATE_BYTE_CNT,
			C_SUBGRP_ADDR_WIDTH 		=> C_AL_SUBGRP_ADDR_WIDTH,			
			C_BII_ADDR_WIDTH			=> C_BII_ADDR_WIDTH,
			C_BII_DATA_WIDTH			=> C_BII_DATA_WIDTH
		)
		port map( 
			clk_i 				=> clk_i,
			reset_i				=> rst_i,
			
			-- FIFO interface
			fifo_in_empty_i 	=> rx_fifo_empty,
			fifo_in_rd_o 		=> rx_fifo_rd,
			fifo_in_data_i 	=> rx_fifo_data,
			fifo_out_full_i 	=> tx_fifo_full,
			fifo_out_wr_o 		=> tx_fifo_wr,
			fifo_out_data_o 	=> tx_fifo_data,
			
			-- BUS Independent interface (BII)			
			en_o		=> en_o,
			we_o		=> we_o,
			blk_o 	=> blk_o,
			nxt_o		=> nxt_o,
			adr_o		=> adr_o,
			dat_o		=> dat_o,
			dat_i		=> dat_i,
			done_i	=> done_i,
			err_i 	=> err_i	
			);
		
end structural;


