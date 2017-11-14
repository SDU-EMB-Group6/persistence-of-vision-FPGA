----------------------------------------------------------------------------------
-- Company: University of Southern Denmark
-- Engineer: Anders Blaabjerg Lange
-- 
-- Create Date:    12:30:26 28/12/2011 
-- Design Name: 	 UART GAB-Link Datalink Layer
-- Module Name:    uart_gab_link_dl - structural 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: UART GAB-Link Datalink Layer
--
-- Dependencies: 
--
-- Rev:	Date:			Author:	Description:
-- 0.01	28/12/2011	ANLAN		File Created
-- 0.02	12/01/2012	ANLAN		C_UART_PARITY generic changed to C_UART_PARITY_EN
-- 0.03  23/01/2012  ANLAN    C_FULL_DL generic and logic added to enable 
--                            FULL / LITE version of the Datalink Layer.
-- 0.04	01/05/2012	ANLAN		filename changed to uart_gab_link_dl
-- 0.05
--
-- Additional Comments: 
--		
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity uart_gab_link_dl is
	generic (
		C_FULL_DL					: integer range 0 to 1	:= 1;		-- 1 = Full Datalink Layer, 0 = Lite Datalink Layer (No FIFO's, Checksum or error detection)
		C_RXFIFO_ADDR_WIDTH 		: positive := 7;						-- Must be able hold the largest incoming request packet
		C_TXFIFO_A_ADDR_WIDTH 	: positive := 8;						-- FIFO receiving response/publish data from the application layer
		C_TXFIFO_B_ADDR_WIDTH 	: positive := 4;						-- FIFO receiving error data from the datalink layer RxFSM
		C_UART_PARITY_EN			: natural 					:= 1;		-- uart parity enabled: 0 = DISABLED, >0 = ENABLED
		C_CHECKSUM					: integer range 0 to 2  := 2		-- checksum mode: 0 = NONE, 1 = BYTE WISE XOR, 2 = CRC-8-CCIT						
	);
	port ( 
		clk_i 						: in  std_logic;
		reset_i 						: in  std_logic;
		
		-- QRC (UART) Physical Layer interface
		
			-- Rx UART
			rx_uart_fifo_empty_i 	: in  std_logic;
			rx_uart_fifo_read_o 		: out std_logic;
			rx_uart_fifo_data_i 		: in  std_logic_vector (7 downto 0);
			rx_uart_fifo_reset_o		: out std_logic;
			
			rx_uart_parity_err_i 	: in  std_logic;
			rx_uart_framing_err_i 	: in  std_logic;
			rx_uart_overrun_err_i 	: in  std_logic;
			rx_uart_clear_errors_o 	: out std_logic;			
			
			-- Tx UART
			tx_uart_fifo_full_i 		: in  std_logic;
			tx_uart_fifo_write_o 	: out std_logic;
			tx_uart_fifo_data_o 		: out std_logic_vector (7 downto 0);
		
		-- QRC Application Layer interface
		
			-- RxFIFO
			rx_fifo_empty_o			: out std_logic;
			rx_fifo_rd_i				: in  std_logic;
			rx_fifo_data_o				: out std_logic_vector(8 downto 0);
			
			-- TxFIFO
			tx_fifo_full_o				: out std_logic;
			tx_fifo_wr_i				: in  std_logic;
			tx_fifo_data_i				: in  std_logic_vector(8 downto 0)
		);
end uart_gab_link_dl;

architecture structural of uart_gab_link_dl is
	
	-- RX UART <> ASCII Decoder signals
	signal rx_uart_fifo_datavalid_i : std_logic;
	
	-- ASCII Decoder <> RxFSM signals
	signal ascii_dec_rst : std_logic;
	signal rx_bin_vld 	: std_logic;
	signal rx_bin_pc	 	: std_logic;
	signal rx_bin_ac	 	: std_logic;
	signal rx_bin_ad	 	: std_logic;
	signal rx_bin_data 	: std_logic_vector(7 downto 0);
	signal rx_bin_rd 		: std_logic;
	signal clr_err			: std_logic;
	signal st_rd_ac		: std_logic;
	signal st_rd_ad		: std_logic;
	signal err_invd 		: std_logic;
	signal err_mdb 		: std_logic;

	-- RxFSM <> Dual FIFO FSM signals
	signal flush_rx_fifo			: std_logic;
	signal rxfifo_in_sel 		: std_logic;
	signal rxfifo_in_wr 			: std_logic;
	signal rxfifo_in_data_in	: std_logic_vector(8 downto 0);
	signal rxfifo_in_reset 		: std_logic;
	signal rxfifo_in_full 		: std_logic;
	signal rxfifo_out_sel 		: std_logic;
	signal rxfifo_out_empty 	: std_logic;
	
	-- RxFSM <> TxFIFO B signals
	signal txfifo_b_wr		: std_logic;
	signal txfifo_b_data_in	: std_logic_vector(7 downto 0);
	signal txfifo_b_full		: std_logic;	

	-- TxFIFO A <> TxFSM signals
	signal txfifo_a_rd 			: std_logic;
	signal txfifo_a_data_out 	: std_logic_vector(8 downto 0);
	signal txfifo_a_empty 		: std_logic;
	
	-- TxFIFO B <> TxFSM signals
	signal txfifo_b_rd 			: std_logic;
	signal txfifo_b_data_out 	: std_logic_vector(7 downto 0);
	signal txfifo_b_empty 		: std_logic;
	
	-- TxFSM <> ASCII encoder
	signal tx_bin_vld 			: std_logic;
	signal tx_bin_rd 				: std_logic;
	signal tx_bin_cmd 			: std_logic;
	signal tx_bin_data 			: std_logic_vector(7 downto 0);

	-- ASCII encoder <> TX UART signals
	signal tx_ascii_vld : std_logic;
	signal tx_ascii_rd : std_logic;

begin
	
	---------------------------------------------------
	-- RX line
	---------------------------------------------------
		rx_uart_fifo_datavalid_i <= not rx_uart_fifo_empty_i;
		ascii_dec_rst <= reset_i or flush_rx_fifo;	-- reset ascii decoder when flushing uart fifo's
	
		-- ASCII decoder
		uart_gab_link_dl_ascii_dec_inst : entity work.uart_gab_link_dl_ascii_dec
			port map ( 
				clk_i				=> clk_i,
				reset_i			=> ascii_dec_rst,

				ascii_vld_i		=> rx_uart_fifo_datavalid_i,		-- ascii data valid
				ascii_rd_o		=> rx_uart_fifo_read_o,				-- read
				ascii_i			=> rx_uart_fifo_data_i,				-- ascii data
						
				bin_vld_o		=> rx_bin_vld,		-- data valid
				bin_pc_o			=> rx_bin_pc,		-- packet command
				bin_ac_o			=> rx_bin_ac,		-- application command
				bin_ad_o			=> rx_bin_ad,		-- application data
				bin_o 			=> rx_bin_data,	-- bin data
				bin_rd_i			=> rx_bin_rd,		-- read data
				st_rd_ac_i		=> st_rd_ac,
				st_rd_ad_i		=> st_rd_ad,
				clr_err_i		=> clr_err,			-- Clear errors (necesarry for receiving additional data)
				err_invd_o		=> err_invd,		-- Error: invalid data
				err_mdb_o		=> err_mdb			-- Error: missing data byte (ascii) / nibble (bin)
				);			
		
		FULL_DL_RX_GEN:
		IF C_FULL_DL=1 GENERATE
			
			-- Rx FSM		
			uart_gab_link_dl_rx_fsm_inst : entity work.uart_gab_link_dl_rx_fsm(full)
				generic map (
					C_UART_PARITY_EN		=> C_UART_PARITY_EN,
					C_CHECKSUM				=> C_CHECKSUM
				)
				port map ( 
					clk_i 					=> clk_i,
					reset_i 					=> reset_i,
					
					-- RxUART interface
					parity_error_i			=> rx_uart_parity_err_i,
					framing_error_i		=> rx_uart_framing_err_i,
					overrun_error_i		=> rx_uart_overrun_err_i,
					clear_errors_o			=> rx_uart_clear_errors_o,
					flush_rx_fifo_o		=> flush_rx_fifo,
					
					-- ASCII Decoder interface
					bin_vld_i 				=> rx_bin_vld,
					bin_pc_i					=> rx_bin_pc,
					bin_ac_i					=> rx_bin_ac,
					bin_ad_i					=> rx_bin_ad,
					bin_data_i 				=> rx_bin_data,
					bin_rd_o 				=> rx_bin_rd,
					st_rd_ac_o				=> st_rd_ac,
					st_rd_ad_o				=> st_rd_ad,
					clr_err_o				=> clr_err,
					err_invd_i 				=> err_invd,
					err_mdb_i 				=> err_mdb,
					
					-- Dual FIFO MUX interface
					rxfifo_in_sel_o 		=> rxfifo_in_sel,
					rxfifo_in_wr_o 		=> rxfifo_in_wr,
					rxfifo_in_data_in_o 	=> rxfifo_in_data_in,
					rxfifo_in_reset_o 	=> rxfifo_in_reset,
					rxfifo_in_full_i 		=> rxfifo_in_full,
					
					rxfifo_out_sel_o 		=> rxfifo_out_sel,
					rxfifo_out_empty_i 	=> rxfifo_out_empty,
					
					-- TxFIFO B interface
					txfifo_b_wr_o 			=> txfifo_b_wr,
					txfifo_b_data_in_o 	=> txfifo_b_data_in,
					txfifo_b_full_i 		=> txfifo_b_full
					);
					
					rx_uart_fifo_reset_o <= flush_rx_fifo;
						
			-- DUAL FIFO Mux
			dual_rxfifo_mux_inst : entity work.dual_fifo_mux
				generic map (	
					C_ADDR_WIDTH		=> C_RXFIFO_ADDR_WIDTH,	-- Reg file address width / Fifo depth
					C_DATA_WIDTH		=> 9,							-- Data width
					C_PRE_LOAD			=> 0,							-- Write<>Read Ptr offset before deasserting empty signal (read logic)
					C_EN_WRT_ACK		=> 0  						-- Write acknowledge; 0 -> disabled, 1 -> enabled				
					)
				port map ( 
					clk_i 				=> clk_i,
					reset_i 				=> reset_i,
					sel_in_fifo_i		=> rxfifo_in_sel,
					sel_out_fifo_i 	=> rxfifo_out_sel,
					
					-- fifo input domain
					fifo_wr_i 			=> rxfifo_in_wr,
					fifo_data_in_i		=> rxfifo_in_data_in,
					fifo_reset_i 		=> rxfifo_in_reset,
					fifo_wr_ack_o 		=> open,
					fifo_full_o 		=> rxfifo_in_full,
					
					-- fifo output domain
					fifo_rd_i 			=> rx_fifo_rd_i,
					fifo_data_out_o 	=> rx_fifo_data_o,
					fifo_empty_o 		=> rxfifo_out_empty
					);
			
				rx_fifo_empty_o <= rxfifo_out_empty;					
		END GENERATE;
		
		LITE_DL_RX_GEN:
		IF C_FULL_DL=0 GENERATE
			
			-- Rx FSM		
			uart_gab_link_dl_rx_fsm_inst : entity work.uart_gab_link_dl_rx_fsm(lite)
				generic map (
					C_UART_PARITY_EN		=> 0,
					C_CHECKSUM				=> 0
				)
				port map ( 
					clk_i 					=> clk_i,
					reset_i 					=> reset_i,
					
					-- RxUART interface
					parity_error_i			=> rx_uart_parity_err_i,
					framing_error_i		=> rx_uart_framing_err_i,
					overrun_error_i		=> rx_uart_overrun_err_i,
					clear_errors_o			=> rx_uart_clear_errors_o,
					flush_rx_fifo_o		=> flush_rx_fifo,
					
					-- ASCII Decoder interface
					bin_vld_i 				=> rx_bin_vld,
					bin_pc_i					=> rx_bin_pc,
					bin_ac_i					=> rx_bin_ac,
					bin_ad_i					=> rx_bin_ad,
					bin_data_i 				=> rx_bin_data,
					bin_rd_o 				=> rx_bin_rd,
					st_rd_ac_o				=> st_rd_ac,
					st_rd_ad_o				=> st_rd_ad,
					clr_err_o				=> clr_err,
					err_invd_i 				=> err_invd,
					err_mdb_i 				=> err_mdb,
					
					-- Dual FIFO MUX interface
					rxfifo_in_sel_o 		=> rxfifo_in_sel,
					rxfifo_in_wr_o 		=> rxfifo_in_wr,
					rxfifo_in_data_in_o 	=> rxfifo_in_data_in,
					rxfifo_in_reset_o 	=> rxfifo_in_reset,
					rxfifo_in_full_i 		=> rxfifo_in_full,
					
					rxfifo_out_sel_o 		=> rxfifo_out_sel,
					rxfifo_out_empty_i 	=> rxfifo_out_empty,
					
					-- TxFIFO B interface
					txfifo_b_wr_o 			=> txfifo_b_wr,
					txfifo_b_data_in_o 	=> txfifo_b_data_in,
					txfifo_b_full_i 		=> txfifo_b_full
					);
					
					rx_uart_fifo_reset_o <= flush_rx_fifo;
					
				-- FIFO_Reg				
				fifo_reg_rx_inst : entity work.fifo_reg
					generic map(
						C_DATA_WIDTH		=> 9
					)
					port map( 
						clk_i					=> clk_i,
						reset_i				=> reset_i,
						wr_i 					=> rxfifo_in_wr,
						data_i 				=> rxfifo_in_data_in,
						full_o 				=> rxfifo_in_full,
						rd_i 					=> rx_fifo_rd_i,
						data_o 				=> rx_fifo_data_o,
						empty_o 				=> rxfifo_out_empty
						);				
				
					rx_fifo_empty_o <= rxfifo_out_empty;				
				
		END GENERATE;
			
	---------------------------------------------------
	
	---------------------------------------------------
	-- TX line
	---------------------------------------------------

		FULL_DL_TX_GEN:
		IF C_FULL_DL=1 GENERATE
			
			-- TxFIFO A
			txfifo_a_inst : entity work.fifo
				generic map (	
					ADDR_WIDTH	=> C_TXFIFO_A_ADDR_WIDTH,	-- Reg file address width / Fifo depth
					DATA_WIDTH	=> 9,								-- Data width
					MODE_ASYNC	=> 0,    						-- Fifo mode: 0 -> synchronous, 1 -> asynchronous
					SYNC_DEPTH	=> 2,								-- Synchronizer depth (asynch mode only)
					PRE_LOAD		=> 0,								-- Write<>Read Ptr offset before deasserting empty signal (read logic)
					EN_WRT_ACK	=> 0  							-- Write acknowledge; 0 -> disabled, 1 -> enabled				
					)
				port map (
					clk_i				=> clk_i,
					-- Input clock domain
					clkw_asynch_i	=> '0',
					wr_i				=> tx_fifo_wr_i,
					data_in_i 		=> tx_fifo_data_i,
					wr_ack_o 		=> open,
					full_o			=> tx_fifo_full_o,
					-- Output clock domain
					clkr_asynch_i	=> '0',
					rd_i				=> txfifo_a_rd,
					data_out_o 		=> txfifo_a_data_out,
					empty_o			=> txfifo_a_empty,
					-- Common inputs
					reset_i 			=> reset_i
					);		
			
			-- TxFIFO B
			txfifo_b_inst : entity work.fifo
				generic map (	
					ADDR_WIDTH	=> C_TXFIFO_B_ADDR_WIDTH,	-- Reg file address width / Fifo depth
					DATA_WIDTH	=> 8,								-- Data width
					MODE_ASYNC	=> 0,    						-- Fifo mode: 0 -> synchronous, 1 -> asynchronous
					SYNC_DEPTH	=> 2,								-- Synchronizer depth (asynch mode only)
					PRE_LOAD		=> 0,								-- Write<>Read Ptr offset before deasserting empty signal (read logic)
					EN_WRT_ACK	=> 0  							-- Write acknowledge; 0 -> disabled, 1 -> enabled				
					)
				port map (
					clk_i				=> clk_i,
					-- Input clock domain
					clkw_asynch_i	=> '0',
					wr_i				=> txfifo_b_wr,
					data_in_i 		=> txfifo_b_data_in,
					wr_ack_o 		=> open,
					full_o			=> txfifo_b_full,
					-- Output clock domain
					clkr_asynch_i	=> '0',
					rd_i				=> txfifo_b_rd,
					data_out_o 		=> txfifo_b_data_out,
					empty_o			=> txfifo_b_empty,
					-- Common inputs
					reset_i 			=> reset_i
					);		
					
		END GENERATE;
		
		LITE_DL_TX_GEN:
		IF C_FULL_DL=0 GENERATE
			
			-- TxFIFO A
			fifo_reg_txa_inst : entity work.fifo_reg
				generic map(
					C_DATA_WIDTH		=> 9
				)
				port map( 
					clk_i					=> clk_i,
					reset_i				=> reset_i,
					wr_i 					=> tx_fifo_wr_i,
					data_i 				=> tx_fifo_data_i,
					full_o 				=> tx_fifo_full_o,
					rd_i 					=> txfifo_a_rd,
					data_o 				=> txfifo_a_data_out,
					empty_o 				=> txfifo_a_empty
					);					
			
			-- TxFIFO B			
			fifo_reg_txb_inst : entity work.fifo_reg
				generic map(
					C_DATA_WIDTH		=> 8
				)
				port map( 
					clk_i					=> clk_i,
					reset_i				=> reset_i,
					wr_i 					=> txfifo_b_wr,
					data_i 				=> txfifo_b_data_in,
					full_o 				=> txfifo_b_full,
					rd_i 					=> txfifo_b_rd,
					data_o 				=> txfifo_b_data_out,
					empty_o 				=> txfifo_b_empty
					);						
					
		END GENERATE;		
		
		-- Tx FSM
		uart_gab_link_dl_tx_fsm_inst : entity work.uart_gab_link_dl_tx_fsm
			generic map (
				C_CHECKSUM				=> C_CHECKSUM
			)		
			port map ( 
				clk_i 					=> clk_i,
				reset_i 					=> reset_i,
				
				-- TxFIFO A interface
				txfifo_a_rd_o 			=> txfifo_a_rd,
				txfifo_a_data_out_i 	=> txfifo_a_data_out,
				txfifo_a_empty_i 		=> txfifo_a_empty,
				
				-- TxFIFO B interface
				txfifo_b_rd_o 			=> txfifo_b_rd,
				txfifo_b_data_out_i 	=> txfifo_b_data_out,
				txfifo_b_empty_i 		=> txfifo_b_empty,
				
				-- ASCII encoder interface
				bin_vld_o 				=> tx_bin_vld,
				bin_rd_i 				=> tx_bin_rd,
				bin_cmd_o 				=> tx_bin_cmd,
				bin_data_o 				=> tx_bin_data
				);

		-- ASCII encoder
		uart_gab_link_dl_ascii_enc_inst : entity work.uart_gab_link_dl_ascii_enc
			port map ( 
				clk_i				=> clk_i,
				reset_i			=> reset_i,
						
				bin_vld_i		=> tx_bin_vld,		-- bin data valid
				bin_rd_o			=> tx_bin_rd,		-- read
				bin_cmd_i		=> tx_bin_cmd,		-- command/data
				bin_i 			=> tx_bin_data,	-- bin data
									
				ascii_vld_o		=> tx_ascii_vld,			-- data valid
				ascii_o			=> tx_uart_fifo_data_o,	-- ascii data
				ascii_rd_i		=> tx_ascii_rd	   		-- read data
				);	
		
		tx_ascii_rd <= '1' when tx_ascii_vld='1' and tx_uart_fifo_full_i='0' else '0';
		
		tx_uart_fifo_write_o <= tx_ascii_rd;
	---------------------------------------------------
	
end structural;

