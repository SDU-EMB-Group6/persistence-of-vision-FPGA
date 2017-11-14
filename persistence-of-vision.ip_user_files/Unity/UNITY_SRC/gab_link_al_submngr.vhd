----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    08:53:24 12/20/2011 
-- Design Name: 
-- Module Name:    subscription_manager - Structural 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - 12/20-2011	ANLAN	First edition finished.
-- Revision 0.02 - 04/12-2011	ANLAN	....
--
--
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity subscription_manager is
	generic (
		C_CLK_FREQ				: positive					:= 50000000;	-- Clock frequency [Hz]
		C_PUBLISH_SYNC_FREQ	: positive					:= 1000;			-- Publish sync strobe frequency [Hz]
		C_SUBMNGR_SGID_SIZE	: integer range 0 to 4  := 1;				-- Bitwidth of the Group ID port (controls the number of individual subscription groups)
		C_SUBGRP_ADDR_WIDTH	: integer range 2 to 5  := 4;  			-- Address width of the data register ram in each subscription group.
		C_SUBGRP_DATA_SIZE	: integer range 1 to 32 := 10;			-- Bitwidth of the data register ram in each subscription group.		
		C_SUBGRP_RATE_SIZE	: integer range 1 to 32 := 16 			-- Bitwidth of the sync rate divider register in each subscription group.		
	);
	port ( 
		clk_i 				: in  std_logic;
		en_i					: in  std_logic;
		reset_i 				: in  std_logic;
		
		stream_en_i			: in  std_logic;  -- Hold high to enable the subscription manager to stream out the data stored in the selected subscription group
		stream_nxt_i		: in  std_logic;  -- Strobe (one clock period wide) to make the subscription manager output the next data piece
		stream_done_o 		: out std_logic; 	-- stream done output (is asserted when all data in the selected subscription group has been streamed out)
		
		group_id_i	 		: in  std_logic_vector (C_SUBMNGR_SGID_SIZE-1 downto 0);	-- Used to select the subscription group to access
		
		publish_req_o 		: out std_logic_vector ((2**C_SUBMNGR_SGID_SIZE)-1 downto 0); -- Publish request output for each subscription group, (one-hot) encoded
		
		-- Multiplexed IO
		publish_ack_i 		: in  std_logic;	-- Used to acknowledge a publish request (after the subscription groups data has been read/streamed out)
		
			-- rate io
			rate_we_i 			: in  std_logic;	-- Rate_data write enable input
			rate_data_i 		: in  std_logic_vector (C_SUBGRP_RATE_SIZE-1 downto 0); -- Rate_data input (number of sync_strobes between each publish request)
			rate_data_o 		: out std_logic_vector (C_SUBGRP_RATE_SIZE-1 downto 0); 	-- Rate output (number of sync_strobes between each publish request)			
		
			-- data cnt io
			data_cnt_we_i 		: in  std_logic;	-- Data_cnt write enable input
			data_cnt_i 			: in  std_logic_vector (C_SUBGRP_ADDR_WIDTH downto 0);	-- Data_cnt input (number of stored data variables)
			data_cnt_o 			: out std_logic_vector (C_SUBGRP_ADDR_WIDTH downto 0); 	-- Data_cnt output	
		
			-- data ram io
			data_we_i 			: in  std_logic;	-- Data write enable input to the selected subscription group		
			addr_i 				: in  std_logic_vector (C_SUBGRP_ADDR_WIDTH-1 downto 0);	-- Address input
			data_i 				: in  std_logic_vector (C_SUBGRP_DATA_SIZE-1 downto 0); 	-- Data input
			data_o 				: out std_logic_vector (C_SUBGRP_DATA_SIZE-1 downto 0) 	-- Data output
		);
end subscription_manager;

architecture Structural of subscription_manager is

	constant C_SYNC_PULSE_PERIOD : integer := C_CLK_FREQ/C_PUBLISH_SYNC_FREQ;

	component subscription_group is
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
	end component;
	
	signal sync_strobe : std_logic;	-- Sync_strobe must be exactly one clk_i period wide. Used to indicate the shortest update period
	
	signal publish_ack : std_logic_vector ((2**C_SUBMNGR_SGID_SIZE)-1 downto 0);
	signal rate_we 	 : std_logic_vector ((2**C_SUBMNGR_SGID_SIZE)-1 downto 0);
	signal data_cnt_we : std_logic_vector ((2**C_SUBMNGR_SGID_SIZE)-1 downto 0);
	signal data_we 	 : std_logic_vector ((2**C_SUBMNGR_SGID_SIZE)-1 downto 0);

	signal addr			 : std_logic_vector (C_SUBGRP_ADDR_WIDTH-1 downto 0);
	signal addr_reg	 : unsigned (C_SUBGRP_ADDR_WIDTH-1 downto 0) := (others=>'0');

	type data_out_type is array((2**C_SUBMNGR_SGID_SIZE)-1 downto 0) of std_logic_vector(C_SUBGRP_DATA_SIZE-1 downto 0);
	type rate_out_type is array((2**C_SUBMNGR_SGID_SIZE)-1 downto 0) of std_logic_vector(C_SUBGRP_RATE_SIZE-1 downto 0);
	type data_cnt_out_type is array((2**C_SUBMNGR_SGID_SIZE)-1 downto 0) of std_logic_vector(C_SUBGRP_ADDR_WIDTH downto 0);
	
	signal data_out 	  : data_out_type;
	signal rate_out 	  : rate_out_type;
	signal data_cnt_out : data_cnt_out_type;
	
	signal data_cnt_output : std_logic_vector(C_SUBGRP_ADDR_WIDTH downto 0);
	
	signal stream_done_reg : std_logic := '0';
	
begin
	
	------------------------------------------------	
	-- Sync strobe generator
	------------------------------------------------		
		synct_strobe_gen_inst : entity work.pulse_gen
			generic map(
				C_PULSE_WIDTH 	=> 1,
				C_PULSE_PERIOD => C_SYNC_PULSE_PERIOD
			)
			port map( 
				clk_i 	=> clk_i,
				en_i 		=> en_i,
				strb_o 	=> sync_strobe
			);
	------------------------------------------------
	
	------------------------------------------------	
	-- Input MUX logic
	------------------------------------------------
		input_mux_prc:
		process(group_id_i, publish_ack_i, rate_we_i, data_cnt_we_i, data_we_i)
			variable group_id : integer range 0 to (2**C_SUBMNGR_SGID_SIZE)-1;
		begin
			group_id := to_integer(unsigned(group_id_i));
			
			publish_ack <= (others=>'0');
			rate_we		<= (others=>'0');
			data_cnt_we <= (others=>'0');
			data_we		<= (others=>'0');
			
			publish_ack(group_id) <= publish_ack_i;
			rate_we(group_id) 	 <= rate_we_i;
			data_cnt_we(group_id) <= data_cnt_we_i;
			data_we(group_id)		 <= data_we_i;
			
		end process;
	------------------------------------------------
	
	------------------------------------------------
	-- Address Generator
	------------------------------------------------	
		process(clk_i)
		begin
			if rising_edge(clk_i) then			
				
				if stream_en_i='1' then
					if stream_done_reg='0' and stream_nxt_i='1' then
						if addr_reg+1=unsigned(data_cnt_output) then
							stream_done_reg <= '1';
						else
							addr_reg	<= addr_reg+1;
						end if;
					end if;
				else
					addr_reg <= (others=>'0');
					stream_done_reg <= '0';
				end if;
			end if;
		end process;	
		
		stream_done_o <= stream_done_reg;
		
		addr <= std_logic_vector(addr_reg) when stream_en_i='1' else addr_i;
	------------------------------------------------
	
	------------------------------------------------
	-- Subscription Group Instance(s)
	------------------------------------------------
		SG_GEN:
		for i in 0 to (2**C_SUBMNGR_SGID_SIZE)-1 generate
		begin
			sg : subscription_group
				generic map (
					C_SG_ADDR_WIDTH	=> C_SUBGRP_ADDR_WIDTH,
					C_SG_DATA_SIZE		=> C_SUBGRP_DATA_SIZE,
					C_SG_RATE_SIZE		=> C_SUBGRP_RATE_SIZE
				)
				port map ( 
					clk_i 			=> clk_i,
					reset_i 			=> reset_i,
					sync_strobe_i 	=> sync_strobe,
					
					publish_ack_i 	=> publish_ack(i),
					publish_req_o 	=> publish_req_o(i),
					
					-- rate io
					rate_we_i 		=> rate_we(i),
					rate_data_i 	=> rate_data_i,
					rate_data_o		=> rate_out(i),
					
					-- data cnt io
					data_cnt_we_i	=> data_cnt_we(i),
					data_cnt_i		=> data_cnt_i,
					data_cnt_o 		=> data_cnt_out(i),
					
					-- data ram io
					data_we_i 		=> data_we(i),
					addr_i			=> addr,
					data_i 			=> data_i,
					data_o 			=> data_out(i)
				);
		end generate;			
	------------------------------------------------
	
	------------------------------------------------
	-- Output MUX
	------------------------------------------------
		output_mux_prc:
		process(group_id_i, rate_out, data_cnt_out, data_out)
			variable group_id : integer range 0 to (2**C_SUBMNGR_SGID_SIZE)-1;
		begin
			group_id := to_integer(unsigned(group_id_i));
			
			rate_data_o			<= rate_out(group_id);
			data_cnt_output 	<= data_cnt_out(group_id);
			data_o				<= data_out(group_id);
			
		end process;	
		
		data_cnt_o <= data_cnt_output;
	------------------------------------------------
	
end Structural;

