----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:18:05 03/30/2012 
-- Design Name: 
-- Module Name:    wb_slv_mem_ctrl - Behavioral 
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

entity wb_slv_mem_ctrl is
	generic (
		C_MEM_ADDR_WIDTH 		: integer range 0 to 32 := 10;	-- Memory depth/size	
		C_DATA_WIDTH 			: integer range 1 to 32 := 32		-- Data bit size
	);
	port ( 
		-- wb syscon interface	
		clk_i : in  std_logic;
		rst_i : in  std_logic;
		
		-- wb slave interface
		wb_i 	: in  wb_ad32sb_if;
		wb_o 	: out wb_d32ae_if;
		
		-- mem interface
		mem_addr_o  : out std_logic_vector(C_MEM_ADDR_WIDTH-1 downto 0);
		mem_we_o    : out std_logic;
		mem_data_o  : out std_logic_vector(C_DATA_WIDTH-1 downto 0);
		mem_data_i	: in  std_logic_vector(C_DATA_WIDTH-1 downto 0);
		mem_w_ack_i	: in  std_logic;
		mem_w_err_i	: in  std_logic
		);
end wb_slv_mem_ctrl;

architecture Behavioral of wb_slv_mem_ctrl is

	signal ack_reg : std_logic := '0';
	signal ack_nxt : std_logic;
	signal ack_req : std_logic;
	
	signal err_reg : std_logic := '0';
	signal err_nxt : std_logic;	
	signal err_req : std_logic;

begin

	-- register process
	process(clk_i)
	begin
		if rising_edge(clk_i) then
			if rst_i='1' then
				ack_reg <= '0';
				err_reg <= '0';
			else
				ack_reg <= ack_nxt;
				err_reg <= err_nxt;
			end if;
		end if;
	end process;


	-- algorithm/logic/combinatorial process
	
	ack_nxt <= '1' when ack_req='1' and ack_reg='0' else '0';	-- ensure cycle terminating signal can only be
	err_nxt <= '1' when err_req='1' and err_reg='0' else '0';	-- asserted for one clock cycle (CLASSIC STANDARD MODE).
	
	wb_o.dat(C_DATA_WIDTH-1 downto 0) 	<= mem_data_i(C_DATA_WIDTH-1 downto 0);	-- data output (mem->wb)
	mem_data_o(C_DATA_WIDTH-1 downto 0)	<= wb_i.dat(C_DATA_WIDTH-1 downto 0);		-- data output (wb->mem)
	
	mem_addr_o(C_MEM_ADDR_WIDTH-1 downto 0) 	<= wb_i.adr(C_MEM_ADDR_WIDTH-1 downto 0);	-- "decode" addr
	
	wb_o.ack	<= ack_reg;
	wb_o.err	<= err_reg;
	
	process(wb_i, mem_w_ack_i, mem_w_err_i, ack_reg, err_reg)		
	begin
		
		-- cycle not started, 
		-- [RULE 3.30] slave MAY ONLY react to syscon signals		
		
		-- defaults
		ack_req <= '0';
		err_req <= '0';
		
		-- mem outputs
		mem_we_o	<= '0';

		if wb_i.cyc='1' then
		
			if wb_i.sgl='1' or wb_i.blk='1' then					-- cycle started in SINGLE/BLOCK mode, slave MAY be active
			
				if wb_i.blk='1' and wb_i.we='0' then				-- READ BLOCK mode cycle in progress
					-- block updates to the memory during the block read (not available for unbuffered memory)
				end if;			
			
				if wb_i.stb='1' then
					
					if wb_i.we='0' then									-- READ mode	
						ack_req <= '1'; 										-- status register/shared memory access (synchronous)
					end if;
					
					if wb_i.we='1' then									-- WRITE mode				
						-- memory access (synchronous)
						mem_we_o <= (not ack_reg) and (not err_reg);   -- ensure the write enable request is only asserted during 
																					  -- the ONE clock cycle before ack_o or err_o is asserted
						
						if mem_w_ack_i='1' then
							ack_req <= '1';
						elsif mem_w_err_i='1' then
							err_req <= '1';
						end if;
					end if;
					
				end if;		
				
			end if;
			
		end if;
		
	end process;

end Behavioral;