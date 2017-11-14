----------------------------------------------------------------------------------
-- Company: University of Southern Denmark
-- Engineer: Anders Blaabjerg Lange
-- 
-- Create Date:    13:50:13 19/12/2011 
-- Design Name: 
-- Module Name:    subscription_group - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - 19/12-2011	ANLAN	First edition finished.
-- Revision 0.02 - 16/01/2012 ANLAN Sync cnt next state logic updated to prevent
--                                  glitch when updating rate_reg to a smaller value.
-- Revision 0.03
--
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity subscription_group is
	generic (
		C_SG_ADDR_WIDTH: integer range 2 to 5 := 4; 		-- Address width of the data register ram.
		C_SG_DATA_SIZE	: integer range 1 to 32 := 10;	-- Bitwidth of the data register.		
		C_SG_RATE_SIZE	: integer range 1 to 32 := 16 	-- Bitwidth of the rate register.				
	);
	port ( 
		clk_i 			: in  std_logic;
		reset_i 			: in  std_logic;
		sync_strobe_i 	: in  std_logic;
		
		publish_ack_i 	: in  std_logic;
		publish_req_o 	: out std_logic;
		
		-- rate io
		rate_we_i 		: in  std_logic;
		rate_data_i 	: in  std_logic_vector (C_SG_RATE_SIZE-1 downto 0);
		rate_data_o		: out std_logic_vector (C_SG_RATE_SIZE-1 downto 0);
		
		-- data cnt io
		data_cnt_we_i	: in  std_logic;
		data_cnt_i		: in  std_logic_vector (C_SG_ADDR_WIDTH downto 0);
		data_cnt_o 		: out std_logic_vector (C_SG_ADDR_WIDTH downto 0);
		
		-- data ram io
		data_we_i 		: in  std_logic;
		addr_i			: in  std_logic_vector (C_SG_ADDR_WIDTH-1 downto 0);
		data_i 			: in  std_logic_vector (C_SG_DATA_SIZE-1 downto 0);		
		data_o 			: out std_logic_vector (C_SG_DATA_SIZE-1 downto 0)
		);
end subscription_group;

architecture Behavioral of subscription_group is

   type data_ram is array ((2**C_SG_ADDR_WIDTH)-1 downto 0) of std_logic_vector (C_SG_DATA_SIZE-1 downto 0);
   signal ram : data_ram := (others=>(others=>'0'));
	 
	signal addr	: integer range 0 to (2**C_SG_ADDR_WIDTH)-1;
	
	signal data_cnt_reg : unsigned (C_SG_ADDR_WIDTH downto 0) := (others=>'0');
	signal data_cnt_nxt : unsigned (C_SG_ADDR_WIDTH downto 0);
	
	signal rate_reg : unsigned (C_SG_RATE_SIZE-1 downto 0) := (others=>'0');
	signal rate_nxt : unsigned (C_SG_RATE_SIZE-1 downto 0);	

	signal sync_strobe_reg : std_logic_vector(1 downto 0) := "11";

	signal sync_cnt_reg : unsigned (C_SG_RATE_SIZE-1 downto 0) := (others=>'0');
	signal sync_cnt_nxt : unsigned (C_SG_RATE_SIZE-1 downto 0);	
	
	signal publish_req_reg : std_logic := '0';
	signal publish_req_nxt : std_logic;
	
begin
	
	--------------------------------------------------
	-- data RAM logic
	--------------------------------------------------
		ram_prc :
		process(clk_i)
		begin
			if rising_edge(clk_i) then
				if data_we_i = '1' then
					ram(TO_INTEGER(unsigned(addr_i))) <= data_i;
				end if;
				
				data_o <= ram(TO_INTEGER(unsigned(addr_i)));
			end if;
		end process;
	--------------------------------------------------
	
	--------------------------------------------------
	-- Data cnt logic
	--------------------------------------------------
		data_cnt_nxt <= unsigned(data_cnt_i);
		
		data_cnt_prc :
		process(clk_i)
		begin
			if rising_edge(clk_i) then
				if reset_i='1' then
					data_cnt_reg <= (others=>'0');
				elsif data_cnt_we_i = '1' then
					data_cnt_reg <= data_cnt_nxt;
				end if;
			end if;
		end process;
		
		data_cnt_o <= std_logic_vector(data_cnt_reg);	
	--------------------------------------------------
	
	--------------------------------------------------
	-- Rate logic
	--------------------------------------------------
		rate_nxt <= unsigned(rate_data_i);
		
		rate_prc :
		process(clk_i)
		begin
			if rising_edge(clk_i) then
				if reset_i='1' then
					rate_reg <= (others=>'0');
				elsif rate_we_i = '1' then
					rate_reg <= rate_nxt;
				end if;			
			end if;
		end process;	
		
		rate_data_o <= std_logic_vector(rate_reg);
	--------------------------------------------------	

	--------------------------------------------------
	-- Sync strobe cnt & publish req/ack logic
	--------------------------------------------------
		publish_req_nxt <= '1' when rate_reg>0 and sync_cnt_reg=rate_reg else
								 '0' when publish_ack_i='1' else
								 publish_req_reg;

		sync_cnt_nxt <= (others=>'0')  when sync_cnt_reg>=rate_reg else
							 sync_cnt_reg+1 when rate_reg>0 and sync_strobe_reg="01" else
							 sync_cnt_reg;
		
		sync_strobe_prc :
		process(clk_i)
		begin
			if rising_edge(clk_i) then
				if reset_i='1' then
					sync_strobe_reg <= "11";
					sync_cnt_reg <= (others=>'0');					
					publish_req_reg <= '0';
				else
					sync_strobe_reg <= sync_strobe_reg(0) & sync_strobe_i;
					sync_cnt_reg <= sync_cnt_nxt;
					publish_req_reg <= publish_req_nxt;
				end if;			
			end if;
		end process;
	
		publish_req_o <= publish_req_reg;
	--------------------------------------------------
	
end Behavioral;

