----------------------------------------------------------------------------------
-- Company: University of Southern Denmark
-- Engineer: Anders Blaabjerg Lange
-- 
-- Create Date:    09:41:01 30/12/2011 
-- Design Name: 
-- Module Name:    checksum module
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Rev:	Date:			Author:	Description:
-- 0.01	30/12/2012	ANLAN		File Created
-- 0.02
--
-- Copyright 2011
--
-- This module is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Lesser General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This module is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Lesser General Public License for more details.
--
-- You should have received a copy of the GNU Lesser General Public License
-- along with this module.  If not, see <http://www.gnu.org/licenses/>.
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity checksum is
	generic (
		C_DATA_WIDTH 		: integer := 8;
		C_CHKS_WIDTH 		: integer := 8;			
		C_CRC_POLYNOMIAL	: integer := 7	-- ex: C_CHKS_WIDTH = 8, C_CRC_POLYNOMIAL = 7 => x^8+x^2+x^1+1
	);
	port ( 
		clk_i 		: in  std_logic;
		reset_i		: in  std_logic;
		data_vld_i 	: in  std_logic;		
		data_i 		: in  std_logic_vector (C_DATA_WIDTH-1 downto 0);
		chks_o 		: out std_logic_vector (C_CHKS_WIDTH-1 downto 0);
		chks_vld_o 	: out std_logic
		);
end checksum;

----------------------------------------------------------------------------------
-- 8bit/byte wise XOR parity checksum generator
----------------------------------------------------------------------------------
architecture xor_8 of checksum is	

	signal data_reg : std_logic_vector (C_CHKS_WIDTH-1 downto 0) := (others=>'0');
	signal data_nxt : std_logic_vector (C_CHKS_WIDTH-1 downto 0);
	signal data_vld_reg : std_logic := '0';

begin
	
	ASSERT C_DATA_WIDTH<=C_CHKS_WIDTH REPORT "C_DATA_WIDTH must be less than or equal C_CHKS_WIDTH" SEVERITY failure;
	
	data_nxt(C_DATA_WIDTH-1 downto 0) <= data_reg(C_DATA_WIDTH-1 downto 0) xor data_i(C_DATA_WIDTH-1 downto 0);

	process(clk_i)
	begin
		if rising_edge(clk_i) then
			if reset_i='1' then
				data_reg <= (others=>'0');
				data_vld_reg <= '0';
			elsif data_vld_i='1' then
				data_reg <= data_nxt;
				data_vld_reg <= '1';
			end if;
		end if;
	end process;

	chks_o <= data_reg;
	chks_vld_o <= data_vld_reg;

end xor_8;
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
-- Customizable CRC checksum generator
-- ------------------------------------------------
-- CRC generator module, based on the CRC module adapted by Simon Falsig 
-- for use in the TosNet RealTime Network.
--						
--	Source originating from: "Parallel CRC Realization" 
--	By Guiseppe Campobello, Guiseppe Patanè and Marco Russo, 
--	IEEE Transactions on Computers, Vol.52, No.10, October 2003.
--
--	Adjustments have been made to the layout, the reset has been converted to a 
-- synchronous reset instead of the asynchronous reset from the original paper, 
-- and a clock enable has been added.
--
-- Revision: 
-- Revision 1.0 - 	Initial release (for TosNet by Simon Falsig)
-- Revision 1.1 - 	Module generics and constant modified to remove 
--							dependance on external package (Anders Lange 30/12/2011)
--
----------------------------------------------------------------------------------
architecture crc of checksum is
	
	constant CRCDIM		: integer := C_CHKS_WIDTH;
	constant CRC_L			: std_logic_vector(CRCDIM-1 downto 0) := std_logic_vector(TO_UNSIGNED(C_CRC_POLYNOMIAL, CRCDIM));
	constant CRC 			: std_logic_vector(CRCDIM downto 0) := ('1' & CRC_L);
	constant DATA_WIDTH	: integer range 1 to CRCDIM := C_DATA_WIDTH;
		
	type matrix is array (CRCDIM - 1 downto 0) of std_logic_vector (CRCDIM - 1 downto 0);	

	signal X		: STD_LOGIC_VECTOR(CRCDIM - 1 downto 0);
	signal X1	: STD_LOGIC_VECTOR(CRCDIM - 1 downto 0);
	signal X2	: STD_LOGIC_VECTOR(CRCDIM - 1 downto 0);
	signal Dins	: STD_LOGIC_VECTOR(CRCDIM - 1 downto 0);
	
	signal data_vld_reg : std_logic := '0';
	
begin

	ASSERT C_DATA_WIDTH<=C_CHKS_WIDTH REPORT "C_DATA_WIDTH must be less than or equal C_CHKS_WIDTH" SEVERITY failure;
	ASSERT C_CRC_POLYNOMIAL<=(2**C_CHKS_WIDTH)-1 REPORT "C_CRC_POLYNOMIAL must be less than or equal to (2^C_CHKS_WIDTH)-1" SEVERITY failure;

	process(data_i)
		variable Dinv 	: STD_LOGIC_VECTOR(CRCDIM - 1 downto 0);
	begin
		Dinv := (others => '0');
		Dinv(DATA_WIDTH - 1 downto 0) := data_i;	--LFSR:
		Dins <= Dinv;
	end process;

	X2 <= X ; 			--LFSR

	process(clk_i)
	begin
		if rising_edge(clk_i) then
			if(reset_i = '1') then
				X <= (others => '0');
				data_vld_reg <= '0';
			elsif(data_vld_i = '1') then
				X <= X1 xor Dins ;	--LFSR
				data_vld_reg <= '1';
			end if;
		end if;
	end process;

	chks_o <= X;
	chks_vld_o <= data_vld_reg;

	--This process builds matrix M=F^w
	process(X2)
		variable Xtemp	: STD_LOGIC_VECTOR(CRCDIM - 1 downto 0);	 
		variable vect	: STD_LOGIC_VECTOR(CRCDIM - 1 downto 0);	 
		variable vect2	: STD_LOGIC_VECTOR(CRCDIM - 1 downto 0);	 
		variable M		: matrix;
		variable F 		: matrix;
	begin
		--Matrix F
		F(0) := CRC(CRCDIM - 1 downto 0);
		for i in 0 to CRCDIM - 2  loop
			vect := (others => '0');
			vect(CRCDIM - i - 1) := '1';
			F(i+1) := vect;
		end loop;
		
		--Matrix M=F?w
		M(DATA_WIDTH - 1) := CRC(CRCDIM - 1 downto 0);
		for k in 2 to DATA_WIDTH loop
			vect2 := M(DATA_WIDTH - k + 1 );
			vect := (others => '0');
			for i in 0 to CRCDIM - 1 loop
				if(vect2(CRCDIM - 1 - i) = '1') then
					vect := vect xor F(i);
				end if;
			end loop;
			M(DATA_WIDTH - k) := vect;
		end loop;
		for k in DATA_WIDTH - 1 to CRCDIM - 1 loop
			M(k) := F(k - DATA_WIDTH + 1);
		end loop;

		--Combinatorial logic equations : X1 = M ( x ) X
		Xtemp := (others => '0');
		for i in 0 to CRCDIM - 1 loop
			vect := M(i);
			for j in 0 to CRCDIM - 1 loop
				if(vect(j) = '1') then
					Xtemp(j) := Xtemp(j) xor X2(CRCDIM - 1 - i);
				end if;
			end loop;
		end loop;
		X1 <= Xtemp;
	
	end process;
end crc;
----------------------------------------------------------------------------------