----------------------------------------------------------------------------------
-- Company: Anders Blaabjerg Lange
-- Engineer: University Of Southern Denmark
-- 
-- Create Date:    16:10:54 04/12/2012 
-- Design Name: 
-- Module Name:    rr_prio_enc - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
--	Round Robin Priority Encoder for non mutual 
-- exclusive one-hot encoded input vectors.
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
use ieee.numeric_std.all;
use work.log_pkg.all;

entity rr_prio_enc is
	generic (
		C_REQ_SIZE : positive := 4
	);
	port ( 
		req_i : in  std_logic_vector(C_REQ_SIZE-1 downto 0);
		cur_i : in  std_logic_vector (log2r(C_REQ_SIZE)-1 downto 0);
		vld_o : out std_logic;
      ptr_o : out std_logic_vector (log2r(C_REQ_SIZE)-1 downto 0)
	);
end rr_prio_enc;

architecture Behavioral of rr_prio_enc is

begin

	vld_o <= '1' when unsigned(req_i)/=0 else '0';
	
	process(cur_i, req_i)
		variable x : natural range 0 to C_REQ_SIZE-1;
	begin
		
		ptr_o <= (others=>'0');
		
		IF C_REQ_SIZE>1 THEN

			for n in 0 to C_REQ_SIZE-1 loop

				if unsigned(cur_i)=n then
									
					for i in 0 to C_REQ_SIZE-1 loop

						x := (n+i) mod (C_REQ_SIZE);
						
						if req_i(x)='1' then
							ptr_o <= std_logic_vector(to_unsigned(x,ptr_o'length));
						end if;

					end loop;
				
				end if;	

			end loop;		
			
		END IF;		
		
	end process;

end Behavioral;

--architecture manual of rr_prio_enc is
--
--begin
--	-- C_REQ_SIZE = 4
--	
--	vld_o <= '1' when unsigned(req_i)/=0 else '0';
--	
--	process(cur_i, req_i)
--	begin
--		
--		ptr_o <= (others=>'0');
--		
--		IF C_REQ_SIZE>1 THEN
--
--			if unsigned(cur_i)=0 then
--								
--				if req_i(0)='1' then
--					ptr_o <= std_logic_vector(to_unsigned(0,ptr_o'length));
--				end if;								
--								
--				if req_i(1)='1' then
--					ptr_o <= std_logic_vector(to_unsigned(1,ptr_o'length));
--				end if;					
--			
--				if req_i(2)='1' then
--					ptr_o <= std_logic_vector(to_unsigned(0,ptr_o'length));
--				end if;								
--								
--				if req_i(3)='1' then
--					ptr_o <= std_logic_vector(to_unsigned(1,ptr_o'length));
--				end if;			
--			
--			end if;
--			
--			if unsigned(cur_i)=1 then
--								
--				if req_i(1)='1' then
--					ptr_o <= std_logic_vector(to_unsigned(0,ptr_o'length));
--				end if;								
--								
--				if req_i(2)='1' then
--					ptr_o <= std_logic_vector(to_unsigned(1,ptr_o'length));
--				end if;					
--			
--				if req_i(3)='1' then
--					ptr_o <= std_logic_vector(to_unsigned(0,ptr_o'length));
--				end if;								
--								
--				if req_i(0)='1' then
--					ptr_o <= std_logic_vector(to_unsigned(1,ptr_o'length));
--				end if;			
--			
--			end if;			
--			
--			if unsigned(cur_i)=2 then
--								
--				if req_i(2)='1' then
--					ptr_o <= std_logic_vector(to_unsigned(0,ptr_o'length));
--				end if;								
--								
--				if req_i(3)='1' then
--					ptr_o <= std_logic_vector(to_unsigned(1,ptr_o'length));
--				end if;					
--			
--				if req_i(0)='1' then
--					ptr_o <= std_logic_vector(to_unsigned(0,ptr_o'length));
--				end if;								
--								
--				if req_i(1)='1' then
--					ptr_o <= std_logic_vector(to_unsigned(1,ptr_o'length));
--				end if;			
--			
--			end if;	
--
--			if unsigned(cur_i)=3 then
--								
--				if req_i(3)='1' then
--					ptr_o <= std_logic_vector(to_unsigned(0,ptr_o'length));
--				end if;								
--								
--				if req_i(0)='1' then
--					ptr_o <= std_logic_vector(to_unsigned(1,ptr_o'length));
--				end if;					
--			
--				if req_i(1)='1' then
--					ptr_o <= std_logic_vector(to_unsigned(0,ptr_o'length));
--				end if;								
--								
--				if req_i(2)='1' then
--					ptr_o <= std_logic_vector(to_unsigned(1,ptr_o'length));
--				end if;			
--			
--			end if;			
--			
--		END IF;		
--		
--	end process;
--
--end manual;