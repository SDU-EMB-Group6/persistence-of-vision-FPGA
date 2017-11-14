----------------------------------------------------------------------------------
-- Company: University of Southern Denmark
-- Engineer: Anders Blaabjerg Lange
-- 
-- Create Date:    09:59:03 28/12/2011 
-- Design Name: 
-- Module Name:    dual_fifo_mux - structural 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Rev:	Date:			Author:	Description:
-- 0.01	28/12/2012	ANLAN		File Created
-- 0.02
--
-- Additional Comments: 
--		
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
--use ieee.numeric_std.all;

entity dual_fifo_mux is
   generic(	
		C_ADDR_WIDTH		: positive					:= 8;	-- Reg file address width / Fifo depth
		C_DATA_WIDTH		: positive					:= 9;	-- Data width
		C_PRE_LOAD			: natural					:= 0;	-- Write<>Read Ptr offset before deasserting empty signal (read logic)
		C_EN_WRT_ACK		: natural range 0 to 1 	:= 0  -- Write acknowledge; 0 -> disabled, 1 -> enabled				
		);
	port ( 
		clk_i 				: in  std_logic;
		reset_i 				: in  std_logic;		
		sel_in_fifo_i		: in  std_logic;
		sel_out_fifo_i 	: in  std_logic;
		
		-- fifo input domain
		fifo_wr_i 			: in  std_logic;
		fifo_data_in_i		: in  std_logic_vector (C_DATA_WIDTH-1 downto 0);
		fifo_reset_i 		: in  std_logic;
		fifo_wr_ack_o 		: out std_logic;
		fifo_full_o 		: out std_logic;
		
		-- fifo output domain
		fifo_rd_i 			: in  std_logic;
		fifo_data_out_o 	: out std_logic_vector (C_DATA_WIDTH-1 downto 0);
		fifo_empty_o 		: out std_logic
		);
end dual_fifo_mux;

architecture structural of dual_fifo_mux is

	signal fifo_1_wr 			: std_logic;
	signal fifo_1_data_in 	: std_logic_vector (C_DATA_WIDTH-1 downto 0);
	signal fifo_1_reset 		: std_logic;	
	signal fifo_1_wr_ack		: std_logic;
	signal fifo_1_full		: std_logic;
	signal fifo_1_mreset		: std_logic;
	
	signal fifo_2_wr 			: std_logic;
	signal fifo_2_data_in 	: std_logic_vector (C_DATA_WIDTH-1 downto 0);
	signal fifo_2_reset 		: std_logic;	
	signal fifo_2_wr_ack		: std_logic;
	signal fifo_2_full		: std_logic;
	signal fifo_2_mreset		: std_logic;	

	signal fifo_1_rd 			: std_logic;
	signal fifo_1_data_out 	: std_logic_vector (C_DATA_WIDTH-1 downto 0);
	signal fifo_1_empty 		: std_logic;
	
	signal fifo_2_rd 			: std_logic;
	signal fifo_2_data_out 	: std_logic_vector (C_DATA_WIDTH-1 downto 0);
	signal fifo_2_empty 		: std_logic;

begin
	
	----------------------------------------------
	-- FIFO Input MUX
	----------------------------------------------
		fifo_in_mux_inst : entity work.fifo_in_mux
		generic map (	
			C_DATA_WIDTH		=> C_DATA_WIDTH
			)		
		port map (
			-- common fifo input domain signals
			fifo_sel_i 			=> sel_in_fifo_i,
			fifo_wr_i 			=> fifo_wr_i,
			fifo_data_in_i 	=> fifo_data_in_i,
			fifo_reset_i 		=> fifo_reset_i,
			fifo_wr_ack_o 		=> fifo_wr_ack_o,
			fifo_full_o 		=> fifo_full_o,
			
			-- fifo 1 input domain signals
			fifo_1_wr_o 		=> fifo_1_wr,
			fifo_1_data_in_o 	=> fifo_1_data_in,
			fifo_1_reset_o 	=> fifo_1_reset,
			fifo_1_wr_ack_i 	=> fifo_1_wr_ack,
			fifo_1_full_i 		=> fifo_1_full,
			
			-- fifo 2 input domain signals
			fifo_2_wr_o 		=> fifo_2_wr,
			fifo_2_data_in_o 	=> fifo_2_data_in,
			fifo_2_reset_o 	=> fifo_2_reset,
			fifo_2_wr_ack_i 	=> fifo_2_wr_ack,
			fifo_2_full_i 		=> fifo_2_full
		);
		
		fifo_1_mreset <= fifo_1_reset or reset_i;
		fifo_2_mreset <= fifo_2_reset or reset_i;
	----------------------------------------------
	
	----------------------------------------------
	-- FIFO 1
	----------------------------------------------
		fifo_1_inst : entity work.fifo
		generic map(	
			ADDR_WIDTH	=> C_ADDR_WIDTH,
			DATA_WIDTH	=> C_DATA_WIDTH,
			MODE_ASYNC	=> 0,
			SYNC_DEPTH	=> 2,
			PRE_LOAD		=> C_PRE_LOAD,
			EN_WRT_ACK	=> C_EN_WRT_ACK
			)
		port map(
			clk_i				=> clk_i,
			-- Input clock domain
			clkw_asynch_i	=> '0',
			wr_i				=> fifo_1_wr,
			data_in_i 		=> fifo_1_data_in,
			wr_ack_o 		=> fifo_1_wr_ack,
			full_o			=> fifo_1_full,
			-- Output clock domain
			clkr_asynch_i	=> '0',
			rd_i				=> fifo_1_rd,
			data_out_o 		=> fifo_1_data_out,
			empty_o			=> fifo_1_empty,
			-- Common inputs
			reset_i 			=> fifo_1_mreset
			);	
	----------------------------------------------

	----------------------------------------------
	-- FIFO 2
	----------------------------------------------
		fifo_2_inst : entity work.fifo
		generic map(	
			ADDR_WIDTH	=> C_ADDR_WIDTH,
			DATA_WIDTH	=> C_DATA_WIDTH,
			MODE_ASYNC	=> 0,
			SYNC_DEPTH	=> 2,
			PRE_LOAD		=> C_PRE_LOAD,
			EN_WRT_ACK	=> C_EN_WRT_ACK
			)
		port map(
			clk_i				=> clk_i,
			-- Input clock domain
			clkw_asynch_i	=> '0',
			wr_i				=> fifo_2_wr,
			data_in_i 		=> fifo_2_data_in,
			wr_ack_o 		=> fifo_2_wr_ack,
			full_o			=> fifo_2_full,
			-- Output clock domain
			clkr_asynch_i	=> '0',
			rd_i				=> fifo_2_rd,
			data_out_o 		=> fifo_2_data_out,
			empty_o			=> fifo_2_empty,
			-- Common inputs
			reset_i 			=> fifo_2_mreset
			);		
	----------------------------------------------

	----------------------------------------------
	-- FIFO Output MUX
	----------------------------------------------
		fifo_out_mux_inst : entity work.fifo_out_mux
		generic map (	
			C_DATA_WIDTH		=> C_DATA_WIDTH
			)
		port map ( 
			-- fifo 1 output domain signals
			fifo_1_rd_o 		=> fifo_1_rd,
			fifo_1_data_out_i => fifo_1_data_out,
			fifo_1_empty_i 	=> fifo_1_empty,
			
			-- fifo 2 output domain signals
			fifo_2_rd_o 		=> fifo_2_rd,
			fifo_2_data_out_i => fifo_2_data_out,
			fifo_2_empty_i 	=> fifo_2_empty,
			
			-- common fifo output domain signals
			fifo_sel_i 			=> sel_out_fifo_i,
			fifo_rd_i 			=> fifo_rd_i,
			fifo_data_out_o 	=> fifo_data_out_o,
			fifo_empty_o 		=> fifo_empty_o
			);	
	----------------------------------------------

end structural;

