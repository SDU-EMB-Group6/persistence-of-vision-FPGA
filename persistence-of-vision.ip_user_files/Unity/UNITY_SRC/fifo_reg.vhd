----------------------------------------------------------------------------------
-- Company: University of Southern Denmark
-- Engineer: Anders Blaabjerg Lange
-- 
-- Create Date:    12:15:19 23/01/2012 
-- Design Name: 
-- Module Name:    fifo_reg - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 	 Data register emulating a synchronous FIFO interface
--
-- Dependencies: 
--
-- Rev:	Date:			Author:	Description:
-- 0.01	23/01/2012	ANLAN		File Created
-- 0.02	
--
-- Additional Comments: 
--		
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity fifo_reg is
	generic (
		C_DATA_WIDTH	: positive := 8
	);
	port ( 
		clk_i		: in  std_logic;
		reset_i	: in  std_logic;
		wr_i 		: in  std_logic;
		data_i 	: in  std_logic_vector (C_DATA_WIDTH-1 downto 0);
		full_o 	: out std_logic;
		rd_i 		: in  std_logic;
		data_o 	: out std_logic_vector (C_DATA_WIDTH-1 downto 0);
		empty_o 	: out std_logic
		);
end fifo_reg;

architecture Behavioral of fifo_reg is

	signal data_reg : std_logic_vector(C_DATA_WIDTH-1 downto 0) := (others=>'0');	
	signal data_vld_reg : std_logic := '0';

	signal wr_en : std_logic;
	signal rd_en : std_logic;
	

begin

	wr_en <= '1' when data_vld_reg='0' and wr_i='1' else '0';
	rd_en <= '1' when data_vld_reg='1' and rd_i='1' else '0';
					
	process(clk_i)
	begin
		if rising_edge(clk_i) then
		
			if reset_i='1' then
				data_reg <= (others=>'0');
				data_vld_reg <= '0';
			else
				
				if wr_en = '1' then
					data_reg <= data_i;
					data_vld_reg <= '1';
				elsif rd_en = '1' then
					data_vld_reg <= '0';
				end if;				
				
			end if;
			
		end if;
	end process;
	
	full_o <= data_vld_reg;	
	data_o <= data_reg;
	empty_o <= not data_vld_reg;	

end Behavioral;

