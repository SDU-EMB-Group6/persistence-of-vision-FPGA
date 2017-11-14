----------------------------------------------------------------------------------
-- Company: University of Southern Denmark
-- Engineer: Anders Blaabjerg Lange
-- 
-- Create Date:    11:53:42 12/28/2011 
-- Design Name: 
-- Module Name:    uart_gab_link_dl_tx_fsm - behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Rev:	Date:			Author:	Description:
-- 0.01	02/01/2012	ANLAN		File Created
-- 0.02	04/04/2012	ANLAN		Updated for the new message format: [#],([cmd]]]{:([d1],[d2])))}),[\n] OR [$],([cmd]]]{:([d1],[d2])))}),[*],([chk1],[chk2]),[\n]
-- 0.03  04/10/2012	ANLAN		Updated to frame error messages with ? instead of #
-- 0.04  04/17/2012	ANLAN		Updated to disable ASCII encoding on data bytes after a ? (error command byte)
-- 0.05 	30/04/2012	ANLAN		Updated to support TAB, WHITESPACE, COMMA and PERIOD characters in a message from the application layer
-- 0.06	01/05/2012	ANLAN		filename changed to uart_gab_link_dl_tx_fsm
-- 0.07
--
-- Additional Comments: 
--		
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_gab_link_dl_tx_fsm is
	generic (
		C_CHECKSUM				: integer range 0 to 2  := 2		-- checksum mode: 0 = NONE, 1 = BYTE WISE XOR, 2 = CRC-8-CCIT
	);
	port ( 
		clk_i 					: in  std_logic;
		reset_i 					: in  std_logic;
		
		-- TxFIFO A interface
		txfifo_a_rd_o 			: out std_logic;
		txfifo_a_data_out_i 	: in  std_logic_vector (8 downto 0);
		txfifo_a_empty_i 		: in  std_logic;
		
		-- TxFIFO B interface
		txfifo_b_rd_o 			: out std_logic;
		txfifo_b_data_out_i 	: in  std_logic_vector (7 downto 0);
		txfifo_b_empty_i 		: in  std_logic;
		
		-- ASCII encoder interface
		bin_vld_o 				: out std_logic;
		bin_rd_i 				: in  std_logic;
		bin_cmd_o 				: out std_logic;
		bin_data_o 				: out std_logic_vector (7 downto 0)
		);
end uart_gab_link_dl_tx_fsm;

architecture behavioral of uart_gab_link_dl_tx_fsm is

	-- Datalink Layer Packet Command codes
	constant PCMD_ANSW		: unsigned(7 downto 0) := x"23";	-- '#'
	constant PCMD_ANSW_CHK	: unsigned(7 downto 0) := x"24"; -- '$'
	constant PCMD_PUB			: unsigned(7 downto 0) := x"25"; -- '%'
	constant PCMD_PUB_CHK	: unsigned(7 downto 0) := x"26"; -- '&'
	constant PCMD_COLON		: unsigned(7 downto 0) := x"3A"; -- ':'
	constant PCMD_ERROR		: unsigned(7 downto 0) := x"3F";	-- '?'
	constant PCMD_STR			: unsigned(7 downto 0) := x"2A"; -- '*'
	constant PCMD_END			: unsigned(7 downto 0) := x"0A"; -- '\n'

	constant PCMD_TAB			: unsigned(7 downto 0) := x"09"; -- 'TAB'
	constant PCMD_WHTSP		: unsigned(7 downto 0) := x"20"; -- ' '
	constant PCMD_COMMA		: unsigned(7 downto 0) := x"2C"; -- ','
	constant PCMD_PERIOD		: unsigned(7 downto 0) := x"2E"; -- '.'

	-- TxFSM States
	type txfsm_states is (WAIT_DATA, WRITE_DLE_HEAD, READ_WRITE_DLE_BODY, WRITE_DLE_TAIL,
								 READ_WRITE_AL_HEAD, READ_WRITE_AL_BODY, WRITE_AL_STAR, WRITE_AL_CHKS, WRITE_AL_TAIL);

	signal state_reg : txfsm_states := WAIT_DATA;
	signal state_nxt : txfsm_states;
	
	signal head_reg	: std_logic_vector(7 downto 0);
	signal head_nxt	: std_logic_vector(7 downto 0);	
	
	signal st_rd_cnd_reg		: std_logic := '0';		-- state reading command not data: '0' = data, '1' = command
	signal st_rd_cnd_nxt		: std_logic;	

	-- checksum module signals
	signal chks_reset 		: std_logic;
	signal chks_data_vld		: std_logic;
	signal chks_data			: std_logic_vector (7 downto 0);
	signal chks_chks			: std_logic_vector (7 downto 0);
	signal chks_vld			: std_logic;
	
begin


	CHECKSUM_XOR_GEN:
   if C_CHECKSUM=1 generate
      begin
		-- checksum XOR instance
		checksum_xor8 : entity work.checksum(xor_8)
			generic map(
				C_DATA_WIDTH 		=> 8,
				C_CHKS_WIDTH 		=> 8
				)
			port map( 
				clk_i 		=> clk_i,
				reset_i		=> chks_reset, 
				data_vld_i 	=> chks_data_vld,
				data_i 		=> chks_data,
				chks_o 		=> chks_chks,
				chks_vld_o 	=> chks_vld
				);		         
   end generate;
	
	CHECKSUM_CRC_GEN:
   if C_CHECKSUM=2 generate
      begin
		-- checksum CRC instance
		checksum_crc8 : entity work.checksum(crc)
			generic map(
				C_DATA_WIDTH 		=> 8,
				C_CHKS_WIDTH 		=> 8,			
				C_CRC_POLYNOMIAL	=> 7	-- C_CHKS_WIDTH = 8, C_CRC_POLYNOMIAL = 7 => x^8+x^2+x^1+1 (CRC-8-CCIT)
				)
			port map( 
				clk_i 		=> clk_i,
				reset_i		=> chks_reset, 
				data_vld_i 	=> chks_data_vld,
				data_i 		=> chks_data,
				chks_o 		=> chks_chks,
				chks_vld_o 	=> chks_vld
				);	         
   end generate;	
	

	-- register process
	process (clk_i)
	begin
		if rising_edge(clk_i) then
			if reset_i='1' then
				state_reg <= WAIT_DATA;			
			else
				state_reg <= state_nxt;				
				head_reg 		<= head_nxt;
				st_rd_cnd_reg  <= st_rd_cnd_nxt;
			end if;
		end if;
	end process;


	-- next state logic
	process(state_reg, head_reg, txfifo_a_empty_i, txfifo_a_data_out_i, txfifo_b_empty_i, txfifo_b_data_out_i, bin_rd_i, chks_chks, chks_vld, st_rd_cnd_reg)
	begin
		-- default
		state_nxt 		<= state_reg;
		head_nxt	 		<= head_reg;
		st_rd_cnd_nxt  <= st_rd_cnd_reg;
		
		chks_reset		<= '0';
		chks_data_vld 	<= '0';
		chks_data 		<= (others=>'0');	
		
		bin_vld_o 		<= '0';
		bin_cmd_o 		<= '0';
		bin_data_o 		<= (others=>'0');
		
		txfifo_a_rd_o	<= '0';
		txfifo_b_rd_o	<= '0';
		
		case state_reg is
			
			-------------------------------------
			-- State WAIT_DATA
			-------------------------------------
				when WAIT_DATA =>					
					if txfifo_a_empty_i='0' then
						chks_reset	<= '1';
						st_rd_cnd_nxt <= '1';
						state_nxt 	<= READ_WRITE_AL_HEAD;
					elsif txfifo_b_empty_i='0' then
						state_nxt 	<= WRITE_DLE_HEAD;
					end if;
			-------------------------------------

			-------------------------------------
			-- State Write Datalink Layer Error HEAD
			-------------------------------------			
				when WRITE_DLE_HEAD =>					
					bin_vld_o 	<= '1';
					bin_cmd_o 	<= '1';
					bin_data_o 	<= std_logic_vector(PCMD_ERROR);
					
					if bin_rd_i='1' then
						state_nxt 	<= READ_WRITE_DLE_BODY;
					end if;
			-------------------------------------

			-------------------------------------
			-- State Read+Write Datalink Layer Error BODY
			-------------------------------------
				when READ_WRITE_DLE_BODY =>
					if txfifo_b_empty_i='0' then

						bin_vld_o 	<= '1';
						bin_data_o 	<= txfifo_b_data_out_i;
						
						if bin_rd_i='1' then
							txfifo_b_rd_o 	<= '1';
							state_nxt 		<= WRITE_DLE_TAIL;
						end if;
					else
						state_nxt 	<= WRITE_DLE_TAIL;
					end if;
			-------------------------------------

			-------------------------------------
			-- State Write Datalink Layer Error TAIL
			-------------------------------------
				when WRITE_DLE_TAIL =>
					bin_vld_o 	<= '1';
					bin_cmd_o 	<= '1';
					bin_data_o 	<= std_logic_vector(PCMD_END);
					
					if bin_rd_i='1' then
						state_nxt 	<= WAIT_DATA;
					end if;						
			-------------------------------------

			-------------------------------------
			-- State Read+Write Application Layer HEAD
			-------------------------------------
				when READ_WRITE_AL_HEAD =>
					if txfifo_a_empty_i='0' and txfifo_a_data_out_i(8)='1' and
						(unsigned(txfifo_a_data_out_i(7 downto 0))=PCMD_ANSW or unsigned(txfifo_a_data_out_i(7 downto 0))=PCMD_ANSW_CHK or
						 unsigned(txfifo_a_data_out_i(7 downto 0))=PCMD_PUB  or unsigned(txfifo_a_data_out_i(7 downto 0))=PCMD_PUB_CHK) then	-- if valid command
						
						bin_vld_o 	<= '1';
						bin_cmd_o 	<= '1';
						bin_data_o 	<= txfifo_a_data_out_i(7 downto 0);
						head_nxt		<= txfifo_a_data_out_i(7 downto 0);
						
						if bin_rd_i='1' then
							txfifo_a_rd_o 	<= '1';
							state_nxt 		<= READ_WRITE_AL_BODY;
						end if;
					else
						txfifo_a_rd_o 	<= '1';
						state_nxt 	<= WAIT_DATA;
					end if;
			-------------------------------------

			-------------------------------------
			-- State Read+Write Application Layer BODY
			-------------------------------------
				when READ_WRITE_AL_BODY =>
					if txfifo_a_empty_i='0' then																					-- if data/command available
					
						if txfifo_a_data_out_i(8)='1' then 																		-- if DL Layer packet command code (byte)
						
							if unsigned(txfifo_a_data_out_i(7 downto 0))=PCMD_COLON then								-- 	if valid (':') command														
								
								bin_vld_o 		<= '1';																				--			write (':') 
								bin_cmd_o 		<= '1';																				--			disable ASCII encoding for command codes
								bin_data_o 		<= std_logic_vector(PCMD_COLON);												--			present data....
								
								if bin_rd_i='1' then																					-- 		if encoder ready to read data							
									txfifo_a_rd_o 	<= '1';																			--				read/remove (':') from TxFIFO_A
									st_rd_cnd_nxt  <= '0';																			--				clear st_rd_cnd_reg to ensure payload data bytes are encoded to ASCII
								end if;							
							
							elsif unsigned(txfifo_a_data_out_i(7 downto 0))=PCMD_END then								-- 	if valid ('\n') command
								
								txfifo_a_rd_o 	<= '1';																				-- 		read/remove '\n' character from TxFIFO_A
								
								if unsigned(head_reg)=PCMD_ANSW_CHK or unsigned(head_reg)=PCMD_PUB_CHK then		-- 		if head is checksum type								
									chks_data 		<= "00000000";																	-- 			calc checksum (insert intended chk result)
									chks_data_vld 	<= '1';																			--				......
									state_nxt 		<= WRITE_AL_STAR;																-- 			insert checksum
								else																										--			else
									state_nxt 	<= WRITE_AL_TAIL;																	--				write tail
								end if;				
							
							elsif unsigned(txfifo_a_data_out_i(7 downto 0))=PCMD_ERROR then							-- 	if valid ('?') command
							
								bin_vld_o 		<= '1';																				--			write ('?') 
								bin_cmd_o 		<= '1';																				--			disable ASCII encoding for command codes
								bin_data_o 		<= std_logic_vector(PCMD_ERROR);												--			present data....
								head_nxt			<= (others=>'0');																	--			clear head_reg to ensure no CRC data is transmitted
								
								if bin_rd_i='1' then																					--	 		if encoder ready to read data							
									txfifo_a_rd_o 	<= '1';																			--				read/remove (':') from TxFIFO_A
									st_rd_cnd_nxt  <= '1';																			--				set st_rd_cnd_reg to disable ASCII encoding for error data
								end if;						
							elsif unsigned(txfifo_a_data_out_i(7 downto 0))=PCMD_TAB or									-- 	if valid ('TAB') command
									unsigned(txfifo_a_data_out_i(7 downto 0))=PCMD_WHTSP or								-- 	if valid (' ') command
									unsigned(txfifo_a_data_out_i(7 downto 0))=PCMD_COMMA or								-- 	if valid (',') command
									unsigned(txfifo_a_data_out_i(7 downto 0))=PCMD_PERIOD then							-- 	if valid ('.') command
							
								bin_vld_o 		<= '1';																				--			write data... 
								bin_cmd_o 		<= '1';																				--			disable ASCII encoding for command codes
								bin_data_o 		<= txfifo_a_data_out_i(7 downto 0);											--			present data....
								
								if bin_rd_i='1' then																					--	 		if encoder ready to read data							
									txfifo_a_rd_o 	<= '1';																			--				read/remove data from TxFIFO_A
								end if;						
							end if;
							
						elsif txfifo_a_data_out_i(8)='0' then																	-- if payload byte (cmd/data)
							
							bin_vld_o 	<= '1';																						--		present data to encoder
							bin_cmd_o 	<= st_rd_cnd_reg;																			--		disable ASCII encoding for payload cmd bytes
							bin_data_o 	<= txfifo_a_data_out_i(7 downto 0);													--		......							
							
							if bin_rd_i='1' then																						-- 	if encoder ready to read data
								if unsigned(head_reg)=PCMD_ANSW_CHK or unsigned(head_reg)=PCMD_PUB_CHK then		-- 		if head is checksum type													
									chks_data 		<= txfifo_a_data_out_i(7 downto 0);										-- 			calc checksum
									chks_data_vld 	<= '1';
								end if;							
								txfifo_a_rd_o 	<= '1';																				--			read/remove data from TxFIFO_A
							end if;							
						end if;

					end if;					
			-------------------------------------

			-------------------------------------
			-- State Write Application Layer STAR
			-------------------------------------
				when WRITE_AL_STAR =>
					bin_vld_o 	<= '1';
					bin_cmd_o 	<= '1';
					bin_data_o 	<= std_logic_vector(PCMD_STR);
					
					if bin_rd_i='1' then
						state_nxt	<= WRITE_AL_CHKS;
					end if;						
			-------------------------------------

			-------------------------------------
			-- State Write Application Layer Checksum
			-------------------------------------
				when WRITE_AL_CHKS =>
					if chks_vld='1' then
						bin_vld_o 	<= '1';
						bin_data_o 	<= chks_chks;
						
						if bin_rd_i='1' then
							state_nxt	<= WRITE_AL_TAIL;
						end if;
					end if;
			-------------------------------------

			-------------------------------------
			-- State Write Application Layer TAIL
			-------------------------------------
				when WRITE_AL_TAIL =>
					bin_vld_o 	<= '1';
					bin_cmd_o 	<= '1';
					bin_data_o 	<= std_logic_vector(PCMD_END);
					
					if bin_rd_i='1' then
						state_nxt	<= WAIT_DATA;
					end if;		
			-------------------------------------
			
		end case;
		
	end process;
	
end behavioral;

	