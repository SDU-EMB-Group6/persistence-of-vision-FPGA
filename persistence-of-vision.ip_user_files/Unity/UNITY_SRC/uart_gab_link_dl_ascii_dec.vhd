----------------------------------------------------------------------------------
-- Company: University of Southern Denmark
-- Engineer: Anders Blaabjerg Lange
-- 
-- Create Date:    15:28:00 16/03/2012 
-- Design Name: 	 UART GAB-Link Datalink Layer ASCII Decoder
-- Module Name:    uart_gab_link_dl_ascii_dec - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Rev:	Date:			Author:	Description:
-- 0.01	16/03/2012	ANLAN		File Created
-- 0.02	01/05/2012	ANLAN		filename changed to uart_gab_link_dl_ascii_dec
-- 0.03 
--
-- Additional Comments: 
--		
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_gab_link_dl_ascii_dec is
	port ( 
		clk_i				: in  std_logic;
		reset_i			: in  std_logic;

		ascii_vld_i		: in  std_logic;							-- ascii data valid
		ascii_rd_o		: out std_logic;							-- read
		ascii_i			: in  std_logic_vector(7 downto 0);	-- ascii data
				
		bin_vld_o		: out std_logic;							-- data valid
		bin_pc_o			: out std_logic;							-- packet command
		bin_ac_o			: out std_logic;							-- application command
		bin_ad_o			: out std_logic;							-- application data
		bin_o 			: out std_logic_vector(7 downto 0);	-- bin data
		bin_rd_i			: in  std_logic;							-- read data
		st_rd_ac_i		: in  std_logic;							-- rxFSM state reading application command
		st_rd_ad_i		: in  std_logic;							-- rxFSM state reading application data
		clr_err_i		: in  std_logic;							-- Clear errors (necesarry for receiving additional data)
		err_invd_o		: out std_logic;							-- Error: invalid data
		err_mdb_o		: out std_logic							-- Error: missing data byte (ascii) / nibble (bin)
		);
end uart_gab_link_dl_ascii_dec;

architecture behavioral of uart_gab_link_dl_ascii_dec is

   type state_type is (READ_ASCII_B1, DEC_ASCII_B1, READ_ASCII_B2, DEC_ASCII_B2, WR_PCMD, WR_ACMD, WR_DATA, ERROR);
   signal state_reg			: state_type := READ_ASCII_B1;
	signal state_nxt 			: state_type; 
	
	signal ascii_reg 			: std_logic_vector(7 downto 0);
	signal ascii_nxt 			: std_logic_vector(7 downto 0);

	signal bin_reg				: std_logic_vector(7 downto 0);
	signal bin_nxt				: std_logic_vector(7 downto 0);	
	
	signal ascii_dec_in 		: std_logic_vector(7 downto 0);
	signal ascii_dec_out 	: std_logic_vector(3 downto 0);
	
	signal ascii_dec_vld 	: std_logic;
	signal ascii_dec_pc 		: std_logic;
	signal ascii_dec_ac 		: std_logic;
	signal ascii_dec_ad 		: std_logic;
	signal ascii_dec_data 	: std_logic_vector(7 downto 0);	

	signal err_invd_reg		: std_logic := '0';
	signal err_invd_nxt		: std_logic;
	
	signal err_mdb_reg 		: std_logic := '0';
	signal err_mdb_nxt 		: std_logic;
	
begin
	
	---------------------------------------
	-- register process
	---------------------------------------
		process(clk_i)
		begin
			if rising_edge(clk_i) then
				if reset_i = '1' then
					state_reg <= READ_ASCII_B1;
					err_invd_reg <= '0';
					err_mdb_reg <= '0';					
				else
					state_reg 	<= state_nxt;
					bin_reg	 	<= bin_nxt;
					ascii_reg	<= ascii_nxt;
					err_invd_reg <= err_invd_nxt;
					err_mdb_reg <= err_mdb_nxt;
				end if;
			end if;
		end process;
	---------------------------------------
	
	---------------------------------------
	-- next state logic
	---------------------------------------
		process(state_reg, bin_reg, ascii_reg, err_invd_reg, err_mdb_reg, ascii_dec_out, ascii_dec_vld, ascii_vld_i, ascii_i, bin_rd_i, clr_err_i, ascii_dec_pc, ascii_dec_ac, ascii_dec_ad, st_rd_ac_i, st_rd_ad_i)
		begin
			-- default
			state_nxt 	<= state_reg;
			bin_nxt	 	<= bin_reg;
			ascii_nxt	<= ascii_reg;
			err_invd_nxt <= err_invd_reg;
			err_mdb_nxt <= err_mdb_reg;
			
			ascii_rd_o	<= '0';
			bin_vld_o 	<= '0';
			bin_pc_o		<= '0';
			bin_ac_o		<= '0';
			bin_ad_o		<= '0';
			bin_o			<= (others=>'0');
			
			err_mdb_o 	<= '0';
			err_invd_o 	<= '0';

			ascii_dec_in <= (others=>'0');
			
			case state_reg is
			
				---------------------------------------
				-- State READ_ASCII_B1
				---------------------------------------
					when READ_ASCII_B1 =>
						if ascii_vld_i='1' then
							ascii_rd_o	<= '1';
							ascii_nxt 	<= ascii_i;
							state_nxt 	<= DEC_ASCII_B1;
						end if;
				---------------------------------------
		
				---------------------------------------
				-- State DEC_ASCII_B1
				-- -----------------------
				--  allows command codes
				---------------------------------------
					when DEC_ASCII_B1 =>
						ascii_dec_in <= ascii_reg;
						
						if ascii_dec_vld='1' and ascii_dec_pc='1' then								-- if valid data AND valid PC
							state_nxt <= WR_PCMD;
						elsif ascii_dec_vld='1' and ascii_dec_ac='1' and st_rd_ac_i='1' then	-- if valid data AND valid AC AND RxFSM is reading AC
							state_nxt <= WR_ACMD;
						elsif ascii_dec_vld='1' and ascii_dec_ad='1' and st_rd_ad_i='1' then	-- if valid data AND valid AD AND RxFSM is reading AD
							bin_nxt(7 downto 4) <= ascii_dec_out;
							state_nxt <= READ_ASCII_B2;
						elsif ascii_dec_vld='1' and ascii_dec_ad='0' and ascii_dec_ac='0' then
							state_nxt <= READ_ASCII_B1; -- Valid Data seperator (ignore data)
						else
							err_invd_nxt <= '1';																-- Error Invalid Data 
							state_nxt <= ERROR;
						end if;
				---------------------------------------
				
				---------------------------------------
				-- State READ_ASCII_B2
				---------------------------------------
					when READ_ASCII_B2 =>
						if ascii_vld_i='1' then
							ascii_rd_o	<= '1';
							ascii_nxt 	<= ascii_i;
							state_nxt 	<= DEC_ASCII_B2;
						end if;
				---------------------------------------
				
				---------------------------------------
				-- State DEC_ASCII_B2
				---------------------------------------
					when DEC_ASCII_B2 =>
						ascii_dec_in <= ascii_reg;
						
						if ascii_dec_vld='1' and ascii_dec_ad='1' and st_rd_ad_I='1' then	-- if valid data AND valid AD AND RxFSM is reading AD
							bin_nxt(3 downto 0) <= ascii_dec_out;
							state_nxt <= WR_DATA;				
						else
							if ascii_dec_vld='1' and ascii_dec_pc='1' then						-- if valid data AND valid PC
								err_mdb_nxt <= '1';														-- 	Error Missing Data Byte
							else
								err_invd_nxt <= '1';														-- 	Error Invalid Data  							
							end if;								
							state_nxt <= ERROR;
						end if;								
				---------------------------------------
				
				---------------------------------------
				-- State WR_PCMD
				---------------------------------------
					when WR_PCMD =>			
						bin_vld_o <= '1';
						bin_pc_o  <= '1';
						bin_o <= ascii_reg;
						
						if bin_rd_i='1' then
							state_nxt <= READ_ASCII_B1;
						end if;
				---------------------------------------
				
				---------------------------------------
				-- State WR_ACMD
				---------------------------------------
					when WR_ACMD =>			
						bin_vld_o <= '1';
						bin_ac_o  <= '1';
						bin_o <= ascii_reg;
						
						if bin_rd_i='1' then
							state_nxt <= READ_ASCII_B1;
						end if;
				---------------------------------------				
				
				---------------------------------------
				-- State WR_DATA
				---------------------------------------
					when WR_DATA =>
						bin_vld_o <= '1';
						bin_ad_o  <= '1';
						bin_o <= bin_reg;				

						if bin_rd_i='1' then
							state_nxt <= READ_ASCII_B1;
						end if;
				---------------------------------------

				---------------------------------------
				-- State ERROR
				---------------------------------------
					when ERROR =>
						err_mdb_o <= err_mdb_reg;
						err_invd_o <= err_invd_reg;

						if clr_err_i='1' then
							err_invd_nxt <= '0';
							err_mdb_nxt <= '0';							
							state_nxt <= READ_ASCII_B1;
						end if;
				---------------------------------------
				
			end case;
			
		end process;	
	---------------------------------------
	
	---------------------------------------
	-- ascii decoder
	---------------------------------------
		with ascii_dec_in select
		ascii_dec_data <=	"1001"&"0000" when X"30",	-- 0		Application Data
								"1001"&"0001" when X"31",	-- 1		Application Data
								"1001"&"0010" when X"32",	-- 2		Application Data
								"1001"&"0011" when X"33",	-- 3		Application Data
								"1001"&"0100" when X"34",	-- 4		Application Data
								"1001"&"0101" when X"35",	-- 5		Application Data
								"1001"&"0110" when X"36",	-- 6		Application Data
								"1001"&"0111" when X"37",	-- 7		Application Data
								"1001"&"1000" when X"38",	-- 8		Application Data
								"1001"&"1001" when X"39",	-- 9		Application Data
								"1011"&"1010" when X"61",	-- a		Application Data+Command
								"1011"&"1011" when X"62",	-- b		Application Data+Command
								"1011"&"1100" when X"63",	-- c		Application Data+Command
								"1011"&"1101" when X"64",	-- d		Application Data+Command
								"1011"&"1110" when X"65",	-- e		Application Data+Command
								"1011"&"1111" when X"66",  -- f		Application Data+Command
								
								"1010"&"----" when X"67",	-- g		Application Command
								"1010"&"----" when X"68",	-- h		Application Command
								"1010"&"----" when X"69",	-- i		Application Command
								"1010"&"----" when X"6A",	-- j		Application Command
								"1010"&"----" when X"6B",	-- k		Application Command
								"1010"&"----" when X"6C",  -- l		Application Command
								"1010"&"----" when X"6D",	-- m		Application Command
								"1010"&"----" when X"6E",	-- n		Application Command
								"1010"&"----" when X"6F",	-- o		Application Command
								"1010"&"----" when X"70",	-- p		Application Command
								"1010"&"----" when X"71",	-- q		Application Command
								"1010"&"----" when X"72",  -- r		Application Command									
								"1010"&"----" when X"73",	-- s		Application Command
								"1010"&"----" when X"74",	-- t		Application Command
								"1010"&"----" when X"75",	-- u		Application Command
								"1010"&"----" when X"76",	-- p		Application Command
								"1010"&"----" when X"77",	-- w		Application Command
								"1010"&"----" when X"78",  -- x		Application Command	
								"1010"&"----" when X"79",	-- y		Application Command
								"1010"&"----" when X"7A",  -- z		Application Command
								
								"1011"&"1010" when X"41",	-- A		Application Data+Command
								"1011"&"1011" when X"42",	-- B		Application Data+Command
								"1011"&"1100" when X"43",	-- C		Application Data+Command
								"1011"&"1101" when X"44",	-- D		Application Data+Command
								"1011"&"1110" when X"45",	-- E		Application Data+Command
								"1011"&"1111" when X"46",  -- F		Application Data+Command

								"1010"&"----" when X"47",	-- G		Application Command
								"1010"&"----" when X"48",	-- H		Application Command
								"1010"&"----" when X"49",	-- I		Application Command
								"1010"&"----" when X"4A",	-- J		Application Command
								"1010"&"----" when X"4B",	-- K		Application Command
								"1010"&"----" when X"4C",  -- L		Application Command
								"1010"&"----" when X"4D",	-- M		Application Command
								"1010"&"----" when X"4E",	-- N		Application Command
								"1010"&"----" when X"4F",	-- O		Application Command
								"1010"&"----" when X"50",	-- P		Application Command
								"1010"&"----" when X"51",	-- Q		Application Command
								"1010"&"----" when X"52",  -- R		Application Command									
								"1010"&"----" when X"53",	-- S		Application Command
								"1010"&"----" when X"54",	-- T		Application Command
								"1010"&"----" when X"55",	-- U		Application Command
								"1010"&"----" when X"56",	-- V		Application Command
								"1010"&"----" when X"57",	-- W		Application Command
								"1010"&"----" when X"58",  -- X		Application Command	
								"1010"&"----" when X"59",	-- Y		Application Command
								"1010"&"----" when X"5A",  -- Z		Application Command

								"1100"&"----" when X"23",	-- #		Packet Command
								"1100"&"----" when X"24",	-- $		Packet Command
								"1100"&"----" when X"25",	-- %		Packet Command
								"1100"&"----" when X"26",	-- $		Packet Command
								"1100"&"----" when X"3A",	-- :		Packet Command
								"1100"&"----" when X"2A",	-- *		Packet Command
								"1100"&"----" when X"0A",	-- '\n'	Packet Command (Newline/Line Feed)
								"1100"&"----" when X"0D",	-- 'CR'	Packet Command (Carriage Return)
								
								"1000"&"----" when X"09",	-- 'TAB'	Allowed data separator (TAB)
								"1000"&"----" when X"20",	-- ' '	Allowed data separator (whitespace)
								"1000"&"----" when X"2C",	-- ','	Allowed data separator (comma)
								"1000"&"----" when X"2E",	-- '.'	Allowed data separator (period)								
								
								"0000"&"----" when others;	--			Invalid Data

		ascii_dec_vld <= ascii_dec_data(7);
		ascii_dec_pc  <= ascii_dec_data(6);
		ascii_dec_ac  <= ascii_dec_data(5);
		ascii_dec_ad  <= ascii_dec_data(4);
		ascii_dec_out <= ascii_dec_data(3 downto 0);
	---------------------------------------
	
end behavioral;

