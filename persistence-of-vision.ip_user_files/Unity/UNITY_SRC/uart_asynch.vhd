----------------------------------------------------------------------------------
-- Company: University of Southern Denmark
-- Engineer: Anders Blaabjerg Lange
-- 
-- Create Date:    12:36:05 23/12/2011 
-- Design Name: 
-- Module Name:    uart - structural 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
--	Line Status Register (LSR):
--		Bit 7	Empty transmitter (Tx) shift register
--		Bit 6	Empty transmitter (Tx) FIFO
--		Bit 5	Rx data framing Error
--		Bit 4	Rx data parity Error
--		Bit 3	Rx data overrun Error
--		Bit 2	RxFIFO full (overrun eminent!)
--		Bit 1	Data Ready in the RxFiFO
--		Bit 0	Receiving (Rx) data
--
-- Dependencies: 
--
-- Rev:	Date:			Author:	Description:
-- 0.01	23/12/2011	ANLAN		File Created
-- 0.02	04/01/2012	ANLAN		RX/TX specific resets added
-- 0.03	10/01/2012	ANLAN		Parity + Framing error logic updated 
--										to use rx_done_tick to avoid sporious 
--										(false) parity errors!
-- 0.04
--
-- Additional Comments: 
--
-- For best results the uart clock frequency (uart_clk_i) must be an integer 
-- multiple of that of the UART in the opposite end of the RS232 (Rx/Tx) lines.
--
--		------------------------------------------------------------------------------
-- 	|         UART         | native clock |   recommended clock  | Max BAUD Rate |
-- 	-----------------------|------------------------------------------------------
-- 	| FTDI FT232R USB UART |     48 MHz   |  48, (96) or 192 MHz |    3 MBaud    |
-- 	-----------------------|------------------------------------------------------
-- 	|    SILABS CP2102     |     48 MHz   |  (48), 96 or 192 MHz |   500 KBaud   |
-- 	-----------------------|------------------------------------------------------
-- 	|                      |              |                      |               |
-- 	-----------------------|------------------------------------------------------
--     note: recommended clock in paranteses () is the default tested clock
--		
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.log_pkg.all;

entity uart_asynch is
	generic (
		C_ERROR_CNT_WIDTH	: integer range 0 to 32	:= 8;		-- Bitwidth of the error counters (0 = counters disabled)
		C_BIT_TXRX_ORDER	: integer range 0 to 1 	:= 0;		-- databit tx/rx order: 0 = LSB, 1 = MSB		
		C_TICKS_PR_BIT		: integer 				  	:= 16;	-- number of (baudrate generator) ticks for each bit. MUST BE AN EVEN NUMBER. default = 16
		C_BAUD_RATE_DVSR  : positive					:= 2;		-- BAUD rate divisor: C_BAUD_RATE_DVSR = clk_frq/(C_TICKS_PR_BIT*baud_rate)
		C_RX_FIFO_ADDR_W	: positive				  	:= 4;		-- rx fifo depth = 2**C_RX_FIFO_ADDR_W
		C_TX_FIFO_ADDR_W	: positive				  	:= 4;		-- tx fifo depth = 2**C_TX_FIFO_ADDR_W
		C_DATABITS 			: integer range 7 to 9 	:= 8;		-- number of databits
		C_STOPBITS			: integer range 1 to 2 	:= 1;		-- number of stopbits
		C_PARITY				: integer range 0 to 4 	:= 1 		-- parity mode: 0 = NONE, 1 = ODD, 2 = EVEN, 3 = MARK, 4 = SPACE
	);
	port ( 
		-- common io
		reset_i 				: in  std_logic;
		reset_rx_i			: in  std_logic;
		reset_tx_i			: in  std_logic;
		
		-- uart clock domain io
		uart_clk_i			: in  std_logic;	
		
		rx_i 					: in  std_logic;
		tx_o 					: out std_logic;
		
		-- user logic (fifo+uart status) clock domain io
		user_clk_i			: in  std_logic;
				
		lsr_o 				: out std_logic_vector (7 downto 0);
		clr_lsr_errors_i	: in  std_logic;	
		
		framing_err_cnt_o	: out std_logic_vector (C_ERROR_CNT_WIDTH-1 downto 0);		
		parity_err_cnt_o	: out std_logic_vector (C_ERROR_CNT_WIDTH-1 downto 0);		
		overrun_err_cnt_o	: out std_logic_vector (C_ERROR_CNT_WIDTH-1 downto 0);
		clr_err_cnt_i		: in  std_logic_vector (2 downto 0);							-- (0)=>overrun, (1)=>parity, (2)=>framing
		
		rx_fifo_empty_o 	: out std_logic;
		rx_fifo_read_i		: in  std_logic;		
		rx_fifo_data_o 	: out std_logic_vector (C_DATABITS-1 downto 0);
		
		tx_fifo_full_o 	: out std_logic;
		tx_fifo_write_i	: in  std_logic;
		tx_fifo_data_i 	: in  std_logic_vector (C_DATABITS-1 downto 0)	
		);
end uart_asynch;

architecture structural of uart_asynch is

	signal reset_rx	: std_logic;
	signal reset_tx	: std_logic;

	-- Baud Rate Generator signals
	signal  tick : std_logic;	
	
	-- UART RX unit signals
	signal rx_done_tick	: std_logic;
	signal p_err_tick		: std_logic;
	signal f_err_tick		: std_logic;
	signal rx_data			: std_logic_vector(C_DATABITS-1 downto 0);

	-- RX FIFO unit signals
	signal rx_fifo_empty : std_logic;
	signal rx_fifo_wr		: std_logic;
	signal rx_fifo_full	: std_logic;
	signal rx_receiving	: std_logic;
	
	-- UART TX unit signals
	signal tx_start 		: std_logic;
	signal tx_done_tick 	: std_logic;
	signal tx_data 		: std_logic_vector(C_DATABITS-1 downto 0);
	
	-- TX FIFO unit signals
	signal tx_fifo_empty 	: std_logic;
	signal tx_transmitting 	: std_logic;
	
	-- LSR registers and signals
	signal lsr_empty_tx_shiftreg	: std_logic;
	signal lsr_empty_tx_fifo		: std_logic;
	
	signal lsr_rx_framing_err_reg	: std_logic := '0';
	signal lsr_rx_framing_err_nxt	: std_logic;

	signal lsr_rx_parity_err_reg	: std_logic := '0';
	signal lsr_rx_parity_err_nxt	: std_logic;

	signal lsr_rx_overrun_err_reg	: std_logic := '0';
	signal lsr_rx_overrun_err_nxt	: std_logic;
	
	signal lsr_rx_fifo_full			: std_logic;
	signal lsr_rx_data_ready 		: std_logic;
	signal lsr_rx_receiving 		: std_logic;

	-- Error counter register
	signal framing_err_cnt_reg	: unsigned(C_ERROR_CNT_WIDTH-1 downto 0) := (others=>'0');
	signal framing_err_cnt_nxt : unsigned(C_ERROR_CNT_WIDTH-1 downto 0);	
	
	signal parity_err_cnt_reg	: unsigned(C_ERROR_CNT_WIDTH-1 downto 0) := (others=>'0');
	signal parity_err_cnt_nxt 	: unsigned(C_ERROR_CNT_WIDTH-1 downto 0);
	
	signal overrun_err_cnt_reg	: unsigned(C_ERROR_CNT_WIDTH-1 downto 0) := (others=>'0');
	signal overrun_err_cnt_nxt : unsigned(C_ERROR_CNT_WIDTH-1 downto 0);

begin
	
	-------------------------------------------------------------------
	-- Reset logic
	-------------------------------------------------------------------
		reset_rx <= reset_rx_i or reset_i;
		reset_tx <= reset_tx_i or reset_i;
	-------------------------------------------------------------------
	
	-------------------------------------------------------------------
	-- BAUD rate generator instance
	-------------------------------------------------------------------
		baudrate_gen_inst : entity work.mod_m_counter(behavioral)
			generic map(
				C_WIDTH 	=> log2r(C_BAUD_RATE_DVSR),
				C_MOD		=> C_BAUD_RATE_DVSR
				)
			port map( 
				clk_i 		=> uart_clk_i,
				reset_i 		=> reset_i,
				count_o 		=> open,
				max_count_o => tick
				);
	-------------------------------------------------------------------
	
	-------------------------------------------------------------------
	-- UART RX unit instance
	-------------------------------------------------------------------
		uart_rx_inst : entity work.uart_rx(behavioral)
			generic map(
				C_BIT_RX_ORDER		=> C_BIT_TXRX_ORDER,
				C_TICKS_PR_BIT		=> C_TICKS_PR_BIT,
				C_DATABITS 			=> C_DATABITS,			
				C_STOPBITS			=> C_STOPBITS,
				C_PARITY				=> C_PARITY
				)
			port map( 
				clk_i 				=> uart_clk_i,
				reset_i 				=> reset_rx,
				tick_i 				=> tick,
				rx_i 					=> rx_i,
				rx_done_tick_o 	=> rx_done_tick,
				p_err_tick_o 		=> p_err_tick,
				f_err_tick_o		=> f_err_tick,
				data_o 				=> rx_data,
				receiving_o			=> rx_receiving
				);	
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- RX Fifo instance
	-------------------------------------------------------------------
		rx_fifo_wr <= rx_done_tick when p_err_tick='0' and f_err_tick='0' else '0';
		
		rx_fifo_inst : entity work.fifo(str_arch)
			generic map(	
				ADDR_WIDTH  => C_RX_FIFO_ADDR_W,	-- Reg file address width / Fifo depth
				DATA_WIDTH	=> C_DATABITS,			-- Data width
				MODE_ASYNC	=> 1,						-- synchronous mode
				SYNC_DEPTH	=> 2, 					-- synchronizer depth (asynchronous mode only)
				PRE_LOAD		=> 0, 					-- no data preload (buffering)
				EN_WRT_ACK	=> 0  					-- no write ackonowledge
				)			
			port map(
				clk_i				=> '0',
				-- Input clock domain
				clkw_asynch_i	=> uart_clk_i,
				wr_i				=> rx_fifo_wr,
				data_in_i 		=> rx_data,
				wr_ack_o 		=> open,
				full_o			=> rx_fifo_full,
				-- Output clock domain
				clkr_asynch_i	=> user_clk_i,
				rd_i				=> rx_fifo_read_i,
				data_out_o 		=> rx_fifo_data_o,
				empty_o			=> rx_fifo_empty,
				-- Common inputs
				reset_i 			=> reset_rx
				);	
				
				rx_fifo_empty_o <= rx_fifo_empty;
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- TX Fifo instance
	-------------------------------------------------------------------	
		tx_fifo_inst : entity work.fifo(str_arch)
			generic map(	
				ADDR_WIDTH  => C_TX_FIFO_ADDR_W,	-- Reg file address width / Fifo depth
				DATA_WIDTH	=> C_DATABITS,			-- Data width
				MODE_ASYNC	=> 1,						-- synchronous mode
				SYNC_DEPTH	=> 2, 					-- synchronizer depth (asynchronous mode only)
				PRE_LOAD		=> 0, 					-- no data preload (buffering)
				EN_WRT_ACK	=> 0  					-- no write ackonowledge
				)			
			port map(
				clk_i				=> '0',
				-- Input clock domain
				clkw_asynch_i	=> user_clk_i,
				wr_i				=> tx_fifo_write_i,
				data_in_i 		=> tx_fifo_data_i,
				wr_ack_o 		=> open,
				full_o			=> tx_fifo_full_o,
				-- Output clock domain
				clkr_asynch_i	=> uart_clk_i,
				rd_i				=> tx_done_tick,
				data_out_o 		=> tx_data,
				empty_o			=> tx_fifo_empty,
				-- Common inputs
				reset_i 			=> reset_tx
				);	
				
		tx_start <= not tx_fifo_empty;
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- UART TX unit instance
	-------------------------------------------------------------------
		uart_tx_inst : entity work.uart_tx(behavioral)
			generic map(
				C_BIT_TX_ORDER	=> C_BIT_TXRX_ORDER,
				C_DATABITS 		=> C_DATABITS,
				C_TICKS_PR_BIT	=> C_TICKS_PR_BIT,
				C_STOPBITS		=> C_STOPBITS,
				C_PARITY			=> C_PARITY
				)
			port map( 
				clk_i 			=> uart_clk_i,
				reset_i 			=> reset_tx,
				tx_start_i 		=> tx_start,
				tick_i 			=> tick,
				data_i 			=> tx_data,
				tx_done_tick_o => tx_done_tick,
				tx_o 				=> tx_o,
				transmitting_o => tx_transmitting
				);	
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- Line Status Register (LSR) register
	-------------------------------------------------------------------
		lsr_prc :	
		process(uart_clk_i)
		begin
			if rising_edge(uart_clk_i) then
				if reset_i='1' then
					IF C_ERROR_CNT_WIDTH>0 THEN
						framing_err_cnt_reg		<= (others=>'0');
						parity_err_cnt_reg		<= (others=>'0');
						overrun_err_cnt_reg		<= (others=>'0');
					END IF;
					
					lsr_rx_framing_err_reg <= '0';
					lsr_rx_parity_err_reg  <= '0';
					lsr_rx_overrun_err_reg <= '0';
				else
					IF C_ERROR_CNT_WIDTH>0 THEN
						framing_err_cnt_reg		<= framing_err_cnt_nxt;
						parity_err_cnt_reg		<= parity_err_cnt_nxt;
						overrun_err_cnt_reg		<= overrun_err_cnt_nxt;
					END IF;
					
					lsr_rx_framing_err_reg <= lsr_rx_framing_err_nxt;
					lsr_rx_parity_err_reg  <= lsr_rx_parity_err_nxt;
					lsr_rx_overrun_err_reg <= lsr_rx_overrun_err_nxt;				
				end if;
			end if;
		end process;
	-------------------------------------------------------------------
	
	-------------------------------------------------------------------
	-- Line Status Register (LSR) Next State logic and output mapping
	-------------------------------------------------------------------	
		
		-- next state logic		

		lsr_empty_tx_shiftreg  <= tx_transmitting;
		lsr_empty_tx_fifo		  <= tx_fifo_empty;		

		lsr_rx_framing_err_nxt <= '1' when rx_done_tick='1' and f_err_tick='1' 	else
										  '0' when clr_lsr_errors_i='1' 	else
										  lsr_rx_framing_err_reg;		
		
		lsr_rx_parity_err_nxt  <= '1' when rx_done_tick='1' and p_err_tick='1'	else
										  '0' when clr_lsr_errors_i='1' 	else
										  lsr_rx_parity_err_reg;
		
		lsr_rx_overrun_err_nxt <= '1' when rx_fifo_full='1' and rx_fifo_wr='1' 	else
										  '0' when clr_lsr_errors_i='1' 						else
										  lsr_rx_overrun_err_reg;
		
		lsr_rx_fifo_full <= rx_fifo_full;
		lsr_rx_data_ready <= not rx_fifo_empty;
		lsr_rx_receiving <= rx_receiving;

		-- output mapping
		-- syncronize uart_clk data with user_clock
		process(user_clk_i)
		begin
			if rising_edge(user_clk_i) then		
				lsr_o(7) <= lsr_empty_tx_shiftreg;
				lsr_o(6) <= lsr_empty_tx_fifo;
				lsr_o(5) <= lsr_rx_framing_err_reg;
				lsr_o(4) <= lsr_rx_parity_err_reg;
				lsr_o(3) <= lsr_rx_overrun_err_reg;
				lsr_o(2) <= lsr_rx_fifo_full;				
				lsr_o(0) <= lsr_rx_receiving;
			end if;
		end process;
			
		lsr_o(1) <= lsr_rx_data_ready;
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- Error counters next state logic and output mapping
	-------------------------------------------------------------------
		ERROR_CNT_GEN:
		IF C_ERROR_CNT_WIDTH>0 GENERATE
		BEGIN
		
			-- next state logic
			
			framing_err_cnt_nxt 	  <= (others=>'0')			when clr_err_cnt_i(2)='0' 			else
											  framing_err_cnt_reg+1 when lsr_rx_framing_err_nxt='1'	else
											  framing_err_cnt_reg;
			
			parity_err_cnt_nxt 	  <= (others=>'0')			when clr_err_cnt_i(1)='0' 			else 
											  parity_err_cnt_reg+1 	when lsr_rx_parity_err_nxt='1' 	else
											  parity_err_cnt_reg;
			
			overrun_err_cnt_nxt 	  <= (others=>'0') 			when clr_err_cnt_i(0)='1' 			else										  
											  overrun_err_cnt_reg+1 when lsr_rx_overrun_err_nxt='1' 	else
											  overrun_err_cnt_reg;		

			-- output mapping			
			-- syncronize uart_clk data with user_clock
			process(user_clk_i)
			begin
				if rising_edge(user_clk_i) then
					framing_err_cnt_o <= std_logic_vector(framing_err_cnt_reg);
					parity_err_cnt_o  <= std_logic_vector(parity_err_cnt_reg);
					overrun_err_cnt_o <= std_logic_vector(overrun_err_cnt_reg);
				end if;
			end process;
				
		END GENERATE;
	-------------------------------------------------------------------
	

	
end structural;

