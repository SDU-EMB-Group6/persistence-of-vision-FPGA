----------------------------------------------------------------------------------
-- Company: University of Southern Denmark
-- Engineer: Anders Blaabjerg Lange
-- 
-- Create Date:    11:14:33 27/12/2011 
-- Design Name: 
-- Module Name:    uart_gab_link_dl_ascii_enc - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Rev:	Date:			Author:	Description:
-- 0.01	27/12/2012	ANLAN		File Created
-- 0.02	01/05/2012	ANLAN		filename changed to uart_gab_link_dl_ascii_enc
-- 0.03	
--
-- Additional Comments: 
--		
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_gab_link_dl_ascii_enc is
	port ( 
		clk_i				: in  std_logic;
		reset_i			: in  std_logic;
				
		bin_vld_i		: in  std_logic;							-- bin data valid
		bin_rd_o			: out std_logic;							-- read
		bin_cmd_i		: in  std_logic;							-- command/data
		bin_i 			: in  std_logic_vector(7 downto 0);	-- bin data
							
		ascii_vld_o		: out std_logic;							-- data valid
		ascii_o			: out std_logic_vector(7 downto 0);	-- ascii data
		ascii_rd_i		: in  std_logic							-- read data
		);
end uart_gab_link_dl_ascii_enc;

architecture behavioral of uart_gab_link_dl_ascii_enc is

   type state_type is (READ_BIN, ENC_ACSCII_HB, WR_ASCII_HB, WR_ASCII_LB, WR_CMD);
   signal state_reg	: state_type := READ_BIN;
	signal state_nxt 	: state_type; 

	signal bin_reg			: std_logic_vector(7 downto 0);
	signal bin_nxt			: std_logic_vector(7 downto 0);
	
	signal ascii_hb_reg 	: std_logic_vector(7 downto 0);
	signal ascii_hb_nxt 	: std_logic_vector(7 downto 0);
	
	signal ascii_lb_reg 	: std_logic_vector(7 downto 0);
	signal ascii_lb_nxt 	: std_logic_vector(7 downto 0);
	
	signal ascii_enc_in 	: std_logic_vector(3 downto 0);
	signal ascii_enc_out : std_logic_vector(7 downto 0);
	
begin
	
	---------------------------------------
	-- register process
	---------------------------------------
	process(clk_i)
	begin
		if rising_edge(clk_i) then
			if reset_i = '1' then
				state_reg <= READ_BIN;
			else
				state_reg 		<= state_nxt;
				bin_reg	 		<= bin_nxt;
				ascii_hb_reg	<= ascii_hb_nxt;
				ascii_lb_reg	<= ascii_lb_nxt;
			end if;
		end if;
	end process;
	---------------------------------------
	
	---------------------------------------
	-- next state logic
	---------------------------------------
	process(state_reg, bin_reg, ascii_hb_reg, ascii_lb_reg, bin_vld_i, bin_i, bin_cmd_i, ascii_enc_out, ascii_rd_i)
	begin
		-- default
		state_nxt 	<= state_reg;
		bin_nxt	 	<= bin_reg;
		ascii_hb_nxt<= ascii_hb_reg;
		ascii_lb_nxt<= ascii_lb_reg;
		
		bin_rd_o		<= '0';
		ascii_vld_o	<= '0';
		ascii_o		<= (others=>'0');
		
		ascii_enc_in <= (others=>'0');
		
		case state_reg is
			
			---------------------------------------
			-- State READ_BIN
			---------------------------------------				
				when READ_BIN =>
					if bin_vld_i='1' then					
						bin_rd_o <= '1';
						bin_nxt <= bin_i;
						if bin_cmd_i='1' then
							state_nxt <= WR_CMD;
						else
							state_nxt <= ENC_ACSCII_HB;				
						end if;
					end if;
			---------------------------------------
			
			---------------------------------------
			-- State ENC_ACSCII_HB
			---------------------------------------
				when ENC_ACSCII_HB =>
					ascii_enc_in <= bin_reg(7 downto 4);
					ascii_hb_nxt <= ascii_enc_out;
					state_nxt <= WR_ASCII_HB;
			---------------------------------------
			
			---------------------------------------
			-- State WR_ASCII_HB
			---------------------------------------
				when WR_ASCII_HB =>
					ascii_enc_in <= bin_reg(3 downto 0);
					ascii_lb_nxt <= ascii_enc_out;
				
					ascii_vld_o <= '1';
					ascii_o <= ascii_hb_reg;
						
					if ascii_rd_i='1' then
						state_nxt <= WR_ASCII_LB;
					end if;
			---------------------------------------
			
			---------------------------------------
			-- State WR_ASCII_LB
			---------------------------------------
				when WR_ASCII_LB =>
					ascii_vld_o <= '1';
					ascii_o <= ascii_lb_reg;
					
					if ascii_rd_i='1' then
						state_nxt <= READ_BIN;
					end if;
			---------------------------------------
			
			---------------------------------------
			-- State WR_CMD
			---------------------------------------
				when WR_CMD =>			
					ascii_vld_o <= '1';
					ascii_o <= bin_reg;
						
					if ascii_rd_i='1' then
						state_nxt <= READ_BIN;
					end if;
			---------------------------------------
		end case;
		
	end process;	
	---------------------------------------
	
	---------------------------------------
	-- ascii encoder
	---------------------------------------	
		with ascii_enc_in select
		ascii_enc_out <=	X"30" when "0000",	-- 0
								X"31" when "0001",	-- 1
								X"32" when "0010",	-- 2
								X"33" when "0011",	-- 3
								X"34" when "0100",	-- 4
								X"35" when "0101",	-- 5
								X"36" when "0110",	-- 6
								X"37" when "0111",	-- 7
								X"38" when "1000",	-- 8
								X"39" when "1001",	-- 9
								X"61" when "1010",	-- a
								X"62" when "1011",	-- b
								X"63" when "1100",	-- c
								X"64" when "1101",	-- d
								X"65" when "1110",	-- e
								X"66" when others;	-- f
	---------------------------------------							
	
end behavioral;

