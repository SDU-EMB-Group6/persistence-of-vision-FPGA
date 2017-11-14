----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    09:58:47 04/25/2012 
-- Design Name: 
-- Module Name:    wb_mem - structural 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.wb_classic_interface.all;

entity wb_mem is
	generic (
		-- MEM configuration
		C_MEM_ADDR_WIDTH 		: integer range 0 to 32 := 6;		-- Memory depth/size (uTosNet mode: 6, TosNet node: 10)
		C_DATA_WIDTH 			: integer range 1 to 32 := 32;	-- Data bit size	(TosNet/uTosNet mode: 32)
		C_RAMSTYLE      		: string  := "AUTO"; 				-- DISTRIBUTED, BLOCK, AUTO
		C_IO_ADDR_BIT 			: integer range -2 to 31 := 2		-- default: 2 (uTosNet mode), MIXED-IO: [0:C_MEM_ADDR_WIDTH-1], MEM-INPUT-ONLY mode: -2, MEM-OUTPUT-ONLY mode: -1
	);
	port (
			-- wb syscon interface	
			clk_i : in  std_logic;
			rst_i : in  std_logic;
			
			-- wb slave interface
			wb_i 			: in  wb_ad32sb_if;
			wb_o 			: out wb_d32ae_if;
			
			-- memory interface
			mem_we_i		: in  std_logic;
			mem_addr_i	: in  std_logic_vector(C_MEM_ADDR_WIDTH-1 downto 0);	
			mem_data_i	: in  std_logic_vector(C_DATA_WIDTH-1 downto 0);
			mem_data_o	: out std_logic_vector(C_DATA_WIDTH-1 downto 0);
			mem_w_ack_o : out std_logic;
			mem_w_err_o : out std_logic
	);
end wb_mem;

architecture structural of wb_mem is

	signal ctrl_we_o		: std_logic;
	signal ctrl_addr_o	: std_logic_vector(C_MEM_ADDR_WIDTH-1 downto 0);	
	signal ctrl_data_o	: std_logic_vector(C_DATA_WIDTH-1 downto 0);
	signal ctrl_data_i	: std_logic_vector(C_DATA_WIDTH-1 downto 0);
	signal ctrl_w_ack_i	: std_logic;
	signal ctrl_w_err_i	: std_logic;
	
	signal wb_mem_we_i	: std_logic;
	signal wb_mem_addr_i	: std_logic_vector(C_MEM_ADDR_WIDTH-1 downto 0);	
	signal wb_mem_data_i	: std_logic_vector(C_DATA_WIDTH-1 downto 0);
	signal wb_mem_data_o	: std_logic_vector(C_DATA_WIDTH-1 downto 0);	

	signal usr_mem_we_i		: std_logic;
	signal usr_mem_addr_i	: std_logic_vector(C_MEM_ADDR_WIDTH-1 downto 0);	
	signal usr_mem_data_i	: std_logic_vector(C_DATA_WIDTH-1 downto 0);
	signal usr_mem_data_o	: std_logic_vector(C_DATA_WIDTH-1 downto 0);		
	signal usr_mem_w_ack_o	: std_logic;
	signal usr_mem_w_err_o	: std_logic;
	
begin

	-- Wishbone Slave memory controller
	wb_slv_mem_ctrl_inst : entity work.wb_slv_mem_ctrl
		generic map(
			C_MEM_ADDR_WIDTH 		=> C_MEM_ADDR_WIDTH,
			C_DATA_WIDTH 			=> C_DATA_WIDTH
		)
		port map( 
			-- wb syscon interface	
			clk_i => clk_i,
			rst_i => rst_i,
			
			-- wb slave interface
			wb_i 	=> wb_i,
			wb_o 	=> wb_o,
			
			-- mem interface
			mem_addr_o  => ctrl_addr_o,
			mem_we_o    => ctrl_we_o,
			mem_data_o  => ctrl_data_o,
			mem_data_i	=> ctrl_data_i,
			mem_w_ack_i	=> ctrl_w_ack_i,
			mem_w_err_i	=> ctrl_w_err_i
		);

	-- write ack/err combinatorial feedback logic:
	
		-- mem-input-only mode
		IO_GEN_IN:
		if C_IO_ADDR_BIT=-2 generate
			begin
				-- in memory input mode the wb interface cannot write to any address
				ctrl_w_ack_i <= '0';
				ctrl_w_err_i <= '1' when ctrl_we_o='1' else '0';
				
				-- in memory input mode the user memory interface can write to all addresses
				usr_mem_w_ack_o <= '1' when mem_we_i='1' else '0';
				usr_mem_w_err_o <= '0';
		end generate;
		
		-- mem-output-only mode
		IO_GEN_OUT:
		if C_IO_ADDR_BIT=-1 generate
			begin
				-- in memory output mode the wb interface can write to all addresses
				ctrl_w_ack_i <= '1' when ctrl_we_o='1' else '0';
				ctrl_w_err_i <= '0';
				
				-- in memory output mode the user memory interface cannot write to any address
				usr_mem_w_ack_o <= '0';
				usr_mem_w_err_o <= '1' when mem_we_i='1' else '0';
		end generate;

		-- mixed-IO mode
		IO_GEN_MIX:
		if C_IO_ADDR_BIT>=0 generate
			begin
				-- wb interface can read+write input addresses (C_IO_ADDR_BIT=1) and read output addresses (C_IO_ADDR_BIT=0)
				ctrl_w_ack_i <= '1' when ctrl_we_o='1' and ctrl_addr_o(C_IO_ADDR_BIT)='1' else '0';
				ctrl_w_err_i <= '1' when ctrl_we_o='1' and ctrl_addr_o(C_IO_ADDR_BIT)='0' else '0';
				
				-- user memory interface can read+write output addresses (C_IO_ADDR_BIT=0) and read input addresses (C_IO_ADDR_BIT=1)
				usr_mem_w_ack_o <= '1' when mem_we_i='1' and mem_addr_i(C_IO_ADDR_BIT)='0' else '0';
				usr_mem_w_err_o <= '1' when mem_we_i='1' and mem_addr_i(C_IO_ADDR_BIT)='1' else '0'; 
		end generate;
		
		
	-- wb control <> memory signal mapping
	wb_mem_we_i 	<= ctrl_w_ack_i;
	wb_mem_addr_i 	<= ctrl_addr_o;
	wb_mem_data_i 	<= ctrl_data_o;
	ctrl_data_i 	<= wb_mem_data_o;
	
	-- user io + control <> memory signal mapping
	usr_mem_we_i 	<= usr_mem_w_ack_o;
	usr_mem_addr_i <= mem_addr_i;
	usr_mem_data_i	<= mem_data_i;
	mem_data_o		<= usr_mem_data_o;
	mem_w_ack_o 	<= usr_mem_w_ack_o;
	mem_w_err_o 	<= usr_mem_w_err_o;
	
	-- Dual ported memory
	ram_rwrw_inst : entity work.ram_rwrw
		generic map( 
			ADDR_WIDTH    => C_MEM_ADDR_WIDTH,
			DATA_WIDTH    => C_DATA_WIDTH,
			RAMSTYLE      => C_RAMSTYLE,
			PIPE_REGA_EN  => 0,
			PIPE_REGB_EN  => 0,
			INIT_DATA     => 0
			)
		port map( 
			clk_a_i    => clk_i,
			enable_a_i => '1',
			we_a_i     => wb_mem_we_i,
			addr_a_i   => wb_mem_addr_i,
			data_a_i   => wb_mem_data_i,
			data_a_o   => wb_mem_data_o,

			clk_b_i    => clk_i,
			enable_b_i => '1',
			we_b_i     => usr_mem_we_i,
			addr_b_i   => usr_mem_addr_i,
			data_b_i   => usr_mem_data_i,
			data_b_o   => usr_mem_data_o
			);

end structural;