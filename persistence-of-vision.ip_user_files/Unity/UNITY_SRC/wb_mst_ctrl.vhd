----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    12:42:04 04/03/2012 
-- Design Name: 
-- Module Name:    wb_mst_ctrl - Behavioral 
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

entity wb_mst_ctrl is
	generic (
		C_ADDR_WIDTH 		: integer range 0 to 32 := 6;		-- Adressable memory depth/size
		C_DATA_WIDTH 		: integer range 1 to 32 := 32 	-- Data bit size
	);
	port ( 
		-- wb syscon interface	
		clk_i : in  std_logic;
		rst_i : in  std_logic;
		
		-- wb master interface
		wb_o 	: out wb_ad32sb_if;
		wb_i 	: in  wb_d32ae_if;
		
		-- user logic interface
		en_i	: in  std_logic;												-- enable (keep high during a cycle/block)
		we_i	: in  std_logic;												-- write enable: write=1, read=0 (must not change during a cycle/block)
		blk_i : in  std_logic;												-- block mode: block=1, single=0
		nxt_i	: in  std_logic;												-- has next (valid in block mode), set to 1 if current is not the last read/write in the block (update synchronous to clock when done=1)
		adr_i	: in  std_logic_vector(C_ADDR_WIDTH-1 downto 0);	-- address in	(clock synchronous update when done=1)
		dat_i	: in  std_logic_vector(C_DATA_WIDTH-1 downto 0);	-- data in (write) (update synchronous to clock when done=1)
		dat_o	: out std_logic_vector(C_DATA_WIDTH-1 downto 0);	-- data out (read) (update synchronous to clock when done=1)
		done_o: out std_logic;												-- done strobe	 (Success)
		err_o : out std_logic												-- error strobe (Failure)
	);
end wb_mst_ctrl;

architecture Behavioral of wb_mst_ctrl is

   type states is (IDLE, SGL, BLK1, BLK2, ERR); 
   signal state_reg : states := IDLE; 	
	signal state_nxt : states;
	
	signal we_i_reg : std_logic := '0';
	signal we_i_nxt : std_logic;

begin

	process(clk_i)
	begin
		if rising_edge(clk_i) then
			if rst_i='1' then
				state_reg <= IDLE;
				we_i_reg  <= '0';
			else
				state_reg <= state_nxt;
				we_i_reg  <= we_i_nxt;
			end if;
		end if;
	end process;
	
	process(state_reg, wb_i, en_i, blk_i, we_i, we_i_reg, adr_i, dat_i, nxt_i)
	begin
		
		state_nxt <= state_reg;
		we_i_nxt  <= we_i_reg;
		
		dat_o  <= (others=>'0');
		done_o <= '0';
		err_o  <= '0';
		
		wb_o.cyc <= '0';
		wb_o.stb <= '0';
		wb_o.adr <= (others=>'0');
		wb_o.dat <= (others=>'0');
		wb_o.we  <= '0';
		wb_o.sgl <= '0';
		wb_o.blk <= '0';
		
		case(state_reg) is
		
			when IDLE =>
				
				if en_i='1' then
					we_i_nxt <= we_i;
					if blk_i='1' then
						state_nxt <= BLK1;
					else
						state_nxt <= SGL;
					end if;				
				end if;
			
			when SGL =>
				wb_o.cyc <= '1';
				wb_o.stb <= '1';
				wb_o.adr(adr_i'range) <= adr_i;
				wb_o.dat(dat_i'range) <= dat_i;
				wb_o.we  <= we_i_reg;
				wb_o.sgl <= '1';			
				
				if wb_i.ack='1' then
					if we_i='0' then
						dat_o <= wb_i.dat(dat_o'range);
					end if;
					done_o <= '1';
					state_nxt <= IDLE;
				elsif wb_i.err='1' then
					err_o<='1';
					state_nxt <= ERR;
				end if;
				
			
			when BLK1 =>
				wb_o.cyc <= '1';
				wb_o.stb <= '1';
				wb_o.adr(adr_i'range) <= adr_i;
				wb_o.dat(dat_i'range) <= dat_i;
				wb_o.we  <= we_i_reg;
				wb_o.blk <= '1';
				
				if wb_i.ack='1' then
					if we_i_reg='0' then
						dat_o <= wb_i.dat(dat_o'range);
					end if;
					done_o <= '1';
					if nxt_i='1' then
						state_nxt <= BLK2;
					else
						state_nxt <= IDLE;
					end if;
				elsif wb_i.err='1' then
					err_o<='1';
					state_nxt <= ERR;
				end if;			
			
			when BLK2 =>
				wb_o.cyc <= '1';
				wb_o.we  <= we_i_reg;
				wb_o.blk <= '1';
				
				if en_i='1' and blk_i='1' then
					state_nxt <= BLK1;
				elsif en_i='0' and blk_i='0' then
					state_nxt <= IDLE;
				end if;
			
			when ERR =>
				err_o<='1';
				
				if en_i='0' and blk_i='0' and we_i='0' and nxt_i='0' then
					err_o<='0';
					state_nxt <= IDLE;
				end if;
			
		end case;
		
	end process;

end Behavioral;

