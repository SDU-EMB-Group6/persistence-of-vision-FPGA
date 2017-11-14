----------------------------------------------------------------------------------
-- Company: University of Southern Denmark
-- Engineer: Anders Blaabjerg Lange
-- 
-- Create Date:    13:31:53 6/12/2011 
-- Design Name: 
-- Module Name:    gab_link_al_fsm - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: GAB-Link Application Layer FSM
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - 19/03-2012	ANLAN First edition finished (based on uTGIP)
-- Revision 0.02 - 16/04-2012	ANLAN	sync strobe input removed (responsibility moved to subscription manager)
-- Revision 0.03 - 24/04-2012 ANLAN Validation of C_RM_SIZE during command decoding updated from: C_RM_SIZE=1 to: C_RM_SIZE>0 
-- Revision 0.04 - 30/04-2012	ANLAN	Read Link Config command added to facilitate easy (automatic) configuration of high level interface SW
-- Revision 0.05 - 01/05-2012	ANLAN	filename changed to gab_link_al_fsm
-- Revision 0.06 - 
--
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.log_pkg.all;
use work.util_pkg.all;

entity gab_link_al_fsm is
	generic (
		C_RLC_EN						: integer range 0 to 1	 := 1;				-- 0: Read Link Config command disabled, 1: Read Link Config command enabled
		C_RM_SIZE					: integer range 0 to 255 := 32;				-- 0: RM disabled, 1: RM enabled (up to C_RM_SIZE reads allowed in one command RM)
		
		C_PUB_MODE					: integer range 0 to 2 	 := 2;				-- 0: Publish mode disabled, 1: Prioritize incoming requests, 2: Prioritize Publish requests
		
		C_CLK_FREQ					: positive					 := 50000000;		-- Clock frequency [Hz]
		C_PUBLISH_SYNC_FREQ		: positive					 := 1000;			-- Publish sync strobe frequency [Hz]		
		C_SUBMNGR_SGID_SIZE		: integer range 0 to 4   := 1;				-- Bitwidth of the Group ID port (controls the number of individual subscription groups)
		C_SUBGRP_RATE_BYTE_CNT 	: integer range 1 to 4 	 := 2; 				-- Number of bytes in the RATE register of each subscription group
		C_SUBGRP_ADDR_WIDTH 		: integer range 2 to 5	 := 4;				-- Size/depth of each subscription group = (2**C_SG_ADDR_WIDTH) : RANGE=[4,8,16,32]
		
		C_BII_ADDR_WIDTH			: integer range 1 to 32  := 32;
		C_BII_DATA_WIDTH			: integer range 8 to 32  := 32
	);
	port ( 
		clk_i 				: in  std_logic;
		reset_i				: in  std_logic;
		
		-- FIFO interface
		fifo_in_empty_i 	: in  std_logic;
		fifo_in_rd_o 		: out std_logic;
		fifo_in_data_i 	: in  std_logic_vector (8 downto 0);
		fifo_out_full_i 	: in  std_logic;
		fifo_out_wr_o 		: out std_logic;
		fifo_out_data_o 	: out std_logic_vector (8 downto 0);
		
		-- BUS Independent interface (BII)		
		en_o	: out std_logic;														-- enable (keep high during a cycle/block)
		we_o	: out std_logic;														-- write enable: write=1, read=0 (must not change during a cycle/block)
		blk_o : out std_logic;														-- block mode: block=1, single=0
		nxt_o	: out std_logic;														-- has next (valid in block mode), set to 1 if current is not the last read/write in the block (update synchronous to clock when done=1)
		adr_o	: out std_logic_vector(C_BII_ADDR_WIDTH-1 downto 0);		-- address in	(clock synchronous update when done=1)
		dat_o	: out std_logic_vector(C_BII_DATA_WIDTH-1 downto 0);		-- data out (write) (update synchronous to clock when done=1)
		dat_i	: in  std_logic_vector(C_BII_DATA_WIDTH-1 downto 0);		-- data in (read)
		done_i: in  std_logic;														-- done strobe	 (Success)
		err_i : in  std_logic														-- error strobe (Failure)		
		);
end gab_link_al_fsm;

architecture Behavioral of gab_link_al_fsm is
	
	type ascii_array is array(integer range <>) of std_logic_vector(7 downto 0);	
	
	constant C_ADDR_BYTES : integer := byte_cnt(C_BII_ADDR_WIDTH);
	constant C_DATA_BYTES : integer := byte_cnt(C_BII_DATA_WIDTH);
	
	-- Datalink Layer Packet Command codes
	constant DLPC_REQ			: unsigned(7 downto 0) 				:= x"23"; -- '#'
	constant DLPC_REQ_CHK	: unsigned(7 downto 0) 				:= x"24"; -- '$'
	constant DLPC_PUB			: std_logic_vector(7 downto 0) 	:= x"25"; -- '%'
	constant DLPC_PUB_CHK	: std_logic_vector(7 downto 0) 	:= x"26"; -- '&'
	constant DLPC_COLON		: unsigned(7 downto 0) 				:= x"3A"; -- ':'
	constant DLPC_ERROR		: unsigned(7 downto 0) 				:= x"3F"; -- '?'
	constant DLPC_END			: std_logic_vector(7 downto 0) 	:= x"0A"; -- '\n'
	constant DLPC_COMMA		: std_logic_vector(7 downto 0) 	:= x"2C"; -- ','
	
	-- Application Layer Payload Command codes
	
	constant ALPC_A			: unsigned(7 downto 0)	:= x"41"; 	-- A
	constant ALPC_R			: unsigned(7 downto 0) 	:= x"52"; 	-- R
	constant ALPC_W			: unsigned(7 downto 0)	:= x"57"; 	-- W
	constant ALPC_E			: unsigned(7 downto 0)	:= x"45"; 	-- E
	constant ALPC_D			: unsigned(7 downto 0)	:= x"44"; 	-- D
	constant ALPC_M			: unsigned(7 downto 0)	:= x"4D"; 	-- M
	constant ALPC_P			: unsigned(7 downto 0)	:= x"50"; 	-- P
	constant ALPC_S			: unsigned(7 downto 0)	:= x"53"; 	-- S
	constant ALPC_C			: unsigned(7 downto 0)	:= x"43"; 	-- C
	constant ALPC_I			: unsigned(7 downto 0)	:= x"49"; 	-- I
	constant ALPC_L			: unsigned(7 downto 0)	:= x"4C"; 	-- L


	-- Application Layer Payload Success Codes
--	constant S_R	 	: std_logic_vector(7 downto 0) := x"A1";	-- Success Reading single address
--	constant S_RM	 	: std_logic_vector(7 downto 0) := x"A2";	-- Success Reading multiple addresses
--	constant S_RSI 	: std_logic_vector(7 downto 0) := x"A3";	-- Success Reading Subscription Info
--	constant S_W 		: std_logic_vector(7 downto 0) := x"B1";	-- Success Writing single address
--	constant S_WSR 	: std_logic_vector(7 downto 0) := x"B2";	-- Success Writing Subscription Rate
--	constant S_WSA 	: std_logic_vector(7 downto 0) := x"B3";	-- Success Writing Subscription Addresses
--	constant S_EPS 	: std_logic_vector(7 downto 0) := x"D1";	-- Success Enable Publish Service
--	constant S_EPC 	: std_logic_vector(7 downto 0) := x"D2";	-- Success Enable Publish Service
--	constant S_DPS 	: std_logic_vector(7 downto 0) := x"D3";	-- Success Disable Publish Service	
--	constant S_PUB 	: std_logic_vector(7 downto 0) := x"D4";	-- Publish Message Code

	constant S_R	 	: std_logic_vector(7 downto 0) := x"52";	-- Success Reading single address
	constant S_RM	 	: std_logic_vector(7 downto 0) := x"52";	-- Success Reading multiple addresses
	constant S_RSI 	: std_logic_vector(7 downto 0) := x"52";	-- Success Reading Subscription Info
	constant S_W 		: std_logic_vector(7 downto 0) := x"57";	-- Success Writing single address
	constant S_WSR 	: std_logic_vector(7 downto 0) := x"57";	-- Success Writing Subscription Rate
	constant S_WSA 	: std_logic_vector(7 downto 0) := x"57";	-- Success Writing Subscription Addresses
	constant S_EPS 	: std_logic_vector(7 downto 0) := x"45";	-- Success Enable Publish Service
	constant S_EPC 	: std_logic_vector(7 downto 0) := x"45";	-- Success Enable Publish Service
	constant S_DPS 	: std_logic_vector(7 downto 0) := x"44";	-- Success Disable Publish Service	
	constant S_PUB 	: std_logic_vector(7 downto 0) := x"50";	-- Publish Message Code
	
	-- Application Layer Configuration Message
	constant RLC_HEAD	: std_logic_vector((3*8)-1 downto 0) 	:= x"434E46";			-- Read Link Configuration Response (Header) = "CNF"
				
	constant RLC_BODY	: std_logic_vector((((byte_cnt(log2c(C_ADDR_BYTES)))*8) +	-- Read Link Configuration Response (body)
													 ((byte_cnt(log2c(C_DATA_BYTES)))*8) + 
													 ((byte_cnt(log2c(C_RM_SIZE)))*8) +
													 ((byte_cnt(log2c(C_PUB_MODE)))*8) +
													 ((byte_cnt(log2c(C_PUBLISH_SYNC_FREQ)))*8) +
													 ((byte_cnt(C_SUBMNGR_SGID_SIZE))*8) +
													 ((byte_cnt(C_SUBGRP_ADDR_WIDTH))*8) +
													 ((byte_cnt(C_SUBGRP_RATE_BYTE_CNT))*8) + (7*8) - 1) downto 0) 	:= 
			
			std_logic_vector(to_unsigned(C_ADDR_BYTES,(byte_cnt(log2c(C_ADDR_BYTES)))*8)) 					& DLPC_COMMA &	-- addr_bytes
			std_logic_vector(to_unsigned(C_DATA_BYTES,(byte_cnt(log2c(C_DATA_BYTES)))*8)) 					& DLPC_COMMA &	-- data_bytes
			std_logic_vector(to_unsigned(C_RM_SIZE,(byte_cnt(log2c(C_RM_SIZE)))*8)) 							& DLPC_COMMA &	-- rm_size
			std_logic_vector(to_unsigned(C_PUB_MODE,(byte_cnt(log2c(C_PUB_MODE)))*8)) 							& DLPC_COMMA &	-- pub_mode
			std_logic_vector(to_unsigned(C_PUBLISH_SYNC_FREQ,(byte_cnt(log2c(C_PUBLISH_SYNC_FREQ)))*8)) 	& DLPC_COMMA &	-- pub_base_freq
			std_logic_vector(to_unsigned(2**C_SUBMNGR_SGID_SIZE,(byte_cnt(C_SUBMNGR_SGID_SIZE))*8)) 		& DLPC_COMMA &	-- sg_cnt
			std_logic_vector(to_unsigned(2**C_SUBGRP_ADDR_WIDTH,(byte_cnt(C_SUBGRP_ADDR_WIDTH))*8)) 		& DLPC_COMMA &	-- sg_size
			std_logic_vector(to_unsigned(C_SUBGRP_RATE_BYTE_CNT,(byte_cnt(C_SUBGRP_RATE_BYTE_CNT))*8));					-- rate_bytes
	
	-- Application Layer Payload Error Codes
	constant E_ICC 	: std_logic_vector((5*8)-1 downto 0) := x"455F494343";	-- Error Invalid Command Code
	constant E_ISG 	: std_logic_vector((5*8)-1 downto 0) := x"455F495347";	-- Error Invalid Subscription Group-ID
	constant E_ILA 	: std_logic_vector((5*8)-1 downto 0) := x"455F494C41";	-- Error Invalid Length Argument	
	constant E_MAB		: std_logic_vector((5*8)-1 downto 0) := x"455F4D4142";	-- Error Missing Address Byte(s)
	constant E_MDB		: std_logic_vector((5*8)-1 downto 0) := x"455F4D4442";	-- Error Missing Data Byte(s)
	constant E_IBS		: std_logic_vector((5*8)-1 downto 0) := x"455F494253";	-- Error Invalid Block Size
	constant E_FBR		: std_logic_vector((5*8)-1 downto 0) := x"455F464252";	-- Error Failed Bus Read
	constant E_FBW		: std_logic_vector((5*8)-1 downto 0) := x"455F464257";	-- Error Failed Bus Write
	
	constant C_ERROR_REG_BYTES : integer := 5;
	
   type states is (WAIT_HEAD, WAIT_CMD,
						 WAIT_CMD_R, WAIT_CMD_RL, WAIT_CMD_RM, WAIT_CMD_RS, WAIT_CMD_RSI,
						 WAIT_CMD_W, WAIT_CMD_WS, WAIT_CMD_WSA, WAIT_CMD_WSR,
						 WAIT_CMD_E, WAIT_CMD_EP, 
						 WAIT_CMD_D, WAIT_CMD_DP,
						 
						 PSH_ST1, PSH_ST2, PSH_ST3, PSH_ST4, PSH_ST5, PSH_ST6, PSH_ST7, PSH_ST8,	-- Publish Service Handler (PSH) states
						 
						 R_ST1, R_ST2, R_ST3, R_ST4, R_ST5,
						 RM_ST1, RM_ST2, RM_ST3, RM_ST4, RM_ST5, RM_ST6,
						 RSI_ST1, RSI_ST2, RSI_ST3, RSI_ST4, RSI_ST5, RSI_ST6, RSI_ST7, RSI_ST8,	-- Read Subscription Info (RSI) states								 
						 
						 W_ST1, W_ST2, W_ST3, W_ST4,
						 WSR_ST1, WSR_ST2, WSR_ST3,										-- Write Subscription Rate (WSR) states
						 WSA_ST1, WSA_ST2, WSA_ST3, WSA_ST4,							-- Write Subscription Addresses (WSA) states
						 
						 EPS_ST1,																-- Enable Publish Service (EPS)
						 EPC_ST1,																-- Enable Publish service with Checksum (EPC)
						 DPS_ST1,																-- Disable Publish Service (DPS)
						 
						 RLC_ST1, RLC_ST2, RLC_ST3,										-- Read Link Configuration (RLC) states
						 
						 ERROR_ST1, ERROR_ST2,
						 WRITE_TAIL);
								
   signal next_state : states; 
	signal curr_state : states := WAIT_HEAD;
	
	signal length_nxt : unsigned(7 downto 0);
	signal length_reg : unsigned(7 downto 0) := (others=>'0');
	
	signal vaddr_nxt  : unsigned((C_ADDR_BYTES*8)-1 downto 0);
	signal vaddr_reg  : unsigned((C_ADDR_BYTES*8)-1 downto 0) := (others=>'0');
	
	signal rd_cnt_nxt : integer range 0 to ((2**5)-1);
	signal rd_cnt_reg : integer range 0 to ((2**5)-1) := 0;
	
	signal databuffer_nxt : std_logic_vector((C_DATA_BYTES*8)-1 downto 0);
	signal databuffer_reg : std_logic_vector((C_DATA_BYTES*8)-1 downto 0) := (others=>'0');
	
	signal size_nxt 	: unsigned(7 downto 0);
	signal size_reg 	: unsigned(7 downto 0) := (others=>'0');	
	
	signal wr_cnt_nxt : integer range 0 to ((2**5)-1);
	signal wr_cnt_reg : integer range 0 to ((2**5)-1) := 0;
	
	signal error_nxt	: std_logic_vector((C_ERROR_REG_BYTES*8)-1 downto 0);
	signal error_reg  : std_logic_vector((C_ERROR_REG_BYTES*8)-1 downto 0) := (others=>'0');
	
	-- Subscription Manager/Group signals
	signal sync_strobe		: std_logic;
	
	signal publish_en_reg 	: std_logic := '0';
	signal publish_en_nxt 	: std_logic;
	signal publish_chks_reg	: std_logic := '0';
	signal publish_chks_nxt	: std_logic;
	
	signal publish_srv_active_reg	: std_logic := '0';
	signal publish_srv_active_nxt	: std_logic;
	
	signal publish_srv_next_id		: std_logic;
	signal publish_group_id_vld 	: std_logic;
	signal publish_group_id_reg 	: std_logic_vector(log2r(2**C_SUBMNGR_SGID_SIZE)-1 downto 0) := (others=>'0');
	signal publish_group_id_nxt 	: std_logic_vector(log2r(2**C_SUBMNGR_SGID_SIZE)-1 downto 0);
	
	signal group_id_reg		: std_logic_vector(C_SUBMNGR_SGID_SIZE-1 downto 0) := (others=>'0');
	signal group_id_nxt		: std_logic_vector(C_SUBMNGR_SGID_SIZE-1 downto 0);
	
	signal sm_stream_en_i	: std_logic;
	signal sm_stream_nxt_i	: std_logic;
	signal sm_stream_done_o	: std_logic;
	
	signal sm_group_id_i		: std_logic_vector(C_SUBMNGR_SGID_SIZE-1 downto 0);
	
	signal sm_publish_req_o : std_logic_vector((2**C_SUBMNGR_SGID_SIZE)-1 downto 0);
	
	signal sg_publish_ack_i : std_logic;
	
	signal sg_rate_we_i 	 	: std_logic;
	signal sg_rate_data_i 	: std_logic_vector((C_SUBGRP_RATE_BYTE_CNT*8)-1 downto 0);
	signal sg_rate_data_o 	: std_logic_vector((C_SUBGRP_RATE_BYTE_CNT*8)-1 downto 0);
	
	signal sg_data_cnt_we_i : std_logic;
	signal sg_data_cnt_i 	: std_logic_vector(C_SUBGRP_ADDR_WIDTH downto 0);
	signal sg_data_cnt_o 	: std_logic_vector(C_SUBGRP_ADDR_WIDTH downto 0);
	
	signal sg_data_we_i		: std_logic;
	signal sg_addr_i			: std_logic_vector(C_SUBGRP_ADDR_WIDTH-1 downto 0);
	signal sg_data_i			: std_logic_vector(C_BII_ADDR_WIDTH-1 downto 0);		
	signal sg_data_o			: std_logic_vector(C_BII_ADDR_WIDTH-1 downto 0);
	
begin

	----------------------------------------------------
	-- Subscription Group Instance
	----------------------------------------------------
		SUB_GEN: 
		IF C_PUB_MODE > 0	GENERATE
		
			publish_req_rr_prio_enc: 
			entity work.rr_prio_enc
				generic map(
					C_REQ_SIZE => (2**C_SUBMNGR_SGID_SIZE)
				)
				port map ( 
					req_i => sm_publish_req_o,
					cur_i => publish_group_id_reg,
					vld_o => publish_group_id_vld,
					ptr_o => publish_group_id_nxt
				);
			
			publish_prc:
			process(clk_i)
			begin
				if rising_edge(clk_i) then
					if reset_i='1' then
						publish_group_id_reg <= (others=>'0');
					elsif publish_srv_next_id='1' then
						publish_group_id_reg <= publish_group_id_nxt;
					end if;
				end if;
			end process;
		
			sm_group_id_i <= publish_group_id_reg(sm_group_id_i'range) when publish_srv_active_reg='1' else group_id_reg;
			
			subscription_manager_inst : entity work.subscription_manager
				generic map(
					C_CLK_FREQ				=>	C_CLK_FREQ,						-- Clock frequency [Hz]
					C_PUBLISH_SYNC_FREQ	=>	C_PUBLISH_SYNC_FREQ,			-- Publish sync strobe frequency [Hz]
					C_SUBMNGR_SGID_SIZE	=> C_SUBMNGR_SGID_SIZE,			-- Bitwidth of the Group ID port (controls the number of individual subscription groups)
					C_SUBGRP_ADDR_WIDTH	=> C_SUBGRP_ADDR_WIDTH,			-- Address width of the data register ram in each subscription group.
					C_SUBGRP_DATA_SIZE	=> C_BII_ADDR_WIDTH,				-- Bitwidth of the data register ram in each subscription group.		
					C_SUBGRP_RATE_SIZE	=> (C_SUBGRP_RATE_BYTE_CNT*8)	-- Bitwidth of the rate register in each subscription group.		
				)
				port map( 
					clk_i 				=> clk_i,
					en_i					=> publish_en_reg,
					reset_i 				=> reset_i,
					
					stream_en_i			=> sm_stream_en_i,
					stream_nxt_i		=> sm_stream_nxt_i,
					stream_done_o 		=> sm_stream_done_o,
					
					group_id_i	 		=> sm_group_id_i,
					
					publish_req_o 		=> sm_publish_req_o,					
					
					-- Multiplexed IO
					publish_ack_i 		=> sg_publish_ack_i,
					
						-- rate io
						rate_we_i 		=> sg_rate_we_i,
						rate_data_i 	=> sg_rate_data_i,
						rate_data_o		=> sg_rate_data_o,
						
						-- data cnt io
						data_cnt_we_i	=> sg_data_cnt_we_i,
						data_cnt_i		=> sg_data_cnt_i,
						data_cnt_o 		=> sg_data_cnt_o,
						
						-- data ram io
						data_we_i 		=> sg_data_we_i,
						addr_i			=> sg_addr_i,
						data_i 			=> sg_data_i,
						data_o 			=> sg_data_o
					);	

		END GENERATE;
	----------------------------------------------------
	
	tgip_register_prc: 
	process(clk_i)
	begin
		if rising_edge(clk_i) then
			if reset_i='1' then
				curr_state 		<= WAIT_HEAD;
				length_reg 		<= (others=>'0');
				vaddr_reg		<= (others=>'0');
				rd_cnt_reg		<= 0;
				databuffer_reg <= (others=>'0');
				size_reg			<= (others=>'0');
				wr_cnt_reg		<= 0;
				error_reg		<= (others=>'0');
				publish_en_reg	<= '0';
				publish_chks_reg <= '0';
				publish_srv_active_reg <= '0';
				group_id_reg <= (others=>'0');
			else
				curr_state 		<= next_state;
				length_reg 		<= length_nxt;
				vaddr_reg		<= vaddr_nxt;
				rd_cnt_reg		<= rd_cnt_nxt;
				databuffer_reg <= databuffer_nxt;
				size_reg			<= size_nxt;
				wr_cnt_reg		<= wr_cnt_nxt;
				error_reg		<= error_nxt;
				publish_en_reg	<= publish_en_nxt;
				publish_chks_reg <= publish_chks_nxt;
				publish_srv_active_reg <= publish_srv_active_nxt;
				group_id_reg 	<= group_id_nxt;
			end if;
		end if;
	end process;
	
	
	tgip_logic_prc: 
	process(curr_state, length_reg, vaddr_reg, rd_cnt_reg, databuffer_reg, size_reg, wr_cnt_reg, error_reg,
	 		  fifo_in_empty_i, fifo_in_data_i, fifo_out_full_i, dat_i, done_i, err_i, publish_en_reg, group_id_reg, 
			  publish_chks_reg, sm_publish_req_o, sg_rate_data_o, sg_data_cnt_o, sg_data_o, sm_stream_done_o, 
			  publish_srv_active_reg, publish_group_id_vld, publish_group_id_reg)
	begin
		-- defaults
		next_state 		<= curr_state;
		length_nxt 		<= length_reg;
		vaddr_nxt		<= vaddr_reg;
		rd_cnt_nxt		<= rd_cnt_reg;
		databuffer_nxt <= databuffer_reg;
		size_nxt			<= size_reg;
		wr_cnt_nxt		<= wr_cnt_reg;
		error_nxt 		<= error_reg;
		group_id_nxt	<= group_id_reg;
		publish_srv_active_nxt <= publish_srv_active_reg;
		
		fifo_in_rd_o 		<= '0';		
		fifo_out_wr_o		<= '0';
		fifo_out_data_o	<= (others=>'0');
		
		en_o 	<= '0';
		we_o 	<= '0';
		blk_o <= '0';
		nxt_o <= '0';
		adr_o <= (others=>'0');
		dat_o <= (others=>'0');
		
		publish_srv_next_id <= '0';
		publish_en_nxt 	<= publish_en_reg;
		publish_chks_nxt	<= publish_chks_reg;
		sg_publish_ack_i	<= '0';
		sg_rate_we_i		<= '0';
		sg_rate_data_i		<= (others=>'0');
		sg_data_cnt_we_i 	<= '0';
		sg_data_cnt_i 		<= (others=>'0');
		sg_data_we_i		<= '0';
		sg_addr_i			<= (others=>'0');
		sg_data_i			<= (others=>'0');
		sm_stream_en_i 	<= '0';
		sm_stream_nxt_i 	<= '0';
		
      case (curr_state) is
         
			when WAIT_HEAD =>
				length_nxt 		<= (others=>'0');
				vaddr_nxt		<= (others=>'0');
				rd_cnt_nxt		<= 0;
				databuffer_nxt <= (others=>'0');
				size_nxt			<= (others=>'0');
				wr_cnt_nxt		<= 0;
				error_nxt		<= (others=>'0');
				publish_srv_active_nxt <= '0';

				IF C_PUB_MODE = 0	THEN
					if fifo_in_empty_i = '0' then	-- wait for data
						-- if command: # or $
						if unsigned(fifo_in_data_i) = '1' & DLPC_REQ or unsigned(fifo_in_data_i) = '1' & DLPC_REQ_CHK then
							-- verify output fifo isn't full
							if fifo_out_full_i='0' then
								-- read data from input fifo
								fifo_in_rd_o <= '1';
								-- transmit head of response
								fifo_out_wr_o 		<= '1';
								fifo_out_data_o 	<= fifo_in_data_i;						
								next_state 			<= WAIT_CMD;
							end if;						
						else
							fifo_in_rd_o <= '1';
						end if;					
					end if;
				END IF;

				IF C_PUB_MODE = 1	THEN
					if fifo_in_empty_i = '0' then	-- wait for data
						-- if command: # or $
						if unsigned(fifo_in_data_i) = '1' & DLPC_REQ or unsigned(fifo_in_data_i) = '1' & DLPC_REQ_CHK then
							-- verify output fifo isn't full
							if fifo_out_full_i='0' then
								-- read data from input fifo
								fifo_in_rd_o <= '1';
								-- transmit head of response
								fifo_out_wr_o 		<= '1';
								fifo_out_data_o 	<= fifo_in_data_i;						
								next_state 			<= WAIT_CMD;
							end if;						
						else
							fifo_in_rd_o <= '1';
						end if;
					elsif publish_en_reg='1' and unsigned(sm_publish_req_o)/=0 then -- wait for publish request
						publish_srv_active_nxt <= '1';
						next_state <= PSH_ST1;						
					end if;
				END IF;

				IF C_PUB_MODE = 2	THEN
					if publish_en_reg='1' and unsigned(sm_publish_req_o)/=0 then -- wait for publish request
						publish_srv_active_nxt <= '1';
						next_state <= PSH_ST1;
					elsif fifo_in_empty_i = '0' then	-- wait for data
						-- if command: # or $
						if unsigned(fifo_in_data_i) = '1' & DLPC_REQ or unsigned(fifo_in_data_i) = '1' & DLPC_REQ_CHK then
							-- verify output fifo isn't full
							if fifo_out_full_i='0' then
								-- read data from input fifo
								fifo_in_rd_o <= '1';
								-- transmit head of response
								fifo_out_wr_o 		<= '1';
								fifo_out_data_o 	<= fifo_in_data_i;						
								next_state 			<= WAIT_CMD;
							end if;						
						else
							fifo_in_rd_o <= '1';
						end if;
					end if;
				END IF;
         
			when WAIT_CMD =>
			
				if fifo_in_empty_i = '0' then
					fifo_in_rd_o <= '1';
					next_state <= ERROR_ST1;
					error_nxt  <= E_ICC;					
					
					if fifo_in_data_i(8)='0' then
											
						if unsigned(fifo_in_data_i(7 downto 0))=ALPC_R or
							unsigned(fifo_in_data_i(7 downto 0))=ALPC_R+x"20" then -- accept 'r' (lower case)
							next_state <= WAIT_CMD_R;
						end if;
						
						if unsigned(fifo_in_data_i(7 downto 0))=ALPC_W or
							unsigned(fifo_in_data_i(7 downto 0))=ALPC_W+x"20" then -- accept 'w' (lower case)
							next_state <= WAIT_CMD_W;
						end if;						
						
						IF C_PUB_MODE > 0 THEN
							if unsigned(fifo_in_data_i(7 downto 0))=ALPC_E or
								unsigned(fifo_in_data_i(7 downto 0))=ALPC_E+x"20" then -- accept 'e' (lower case)
								next_state <= WAIT_CMD_E;
							end if;

							if unsigned(fifo_in_data_i(7 downto 0))=ALPC_D or
								unsigned(fifo_in_data_i(7 downto 0))=ALPC_D+x"20" then -- accept 'd' (lower case)
								next_state <= WAIT_CMD_D;
							end if;
						END IF;
						
					end if;					
				end if;

			when WAIT_CMD_R =>
			
				if fifo_in_empty_i = '0' then
					fifo_in_rd_o <= '1';
					next_state <= ERROR_ST1;
					error_nxt <= E_ICC;
					
					if fifo_in_data_i(8)='0' then -- AL data/cmd
						
						IF C_RM_SIZE > 0 THEN
							if unsigned(fifo_in_data_i(7 downto 0))=ALPC_M or
								unsigned(fifo_in_data_i(7 downto 0))=ALPC_M+x"20" then -- accept 'm' (lower case)
								next_state <= WAIT_CMD_RM;
							end if;
						END IF;
						
						IF C_PUB_MODE > 0 THEN
							if unsigned(fifo_in_data_i(7 downto 0))=ALPC_S or
								unsigned(fifo_in_data_i(7 downto 0))=ALPC_S+x"20" then -- accept 's' (lower case)
								next_state <= WAIT_CMD_RS;
							end if;																	
						END IF;		
					
						IF C_RLC_EN > 0 THEN
							if unsigned(fifo_in_data_i(7 downto 0))=ALPC_L or
								unsigned(fifo_in_data_i(7 downto 0))=ALPC_L+x"20" then -- accept 'l' (lower case)
								next_state <= WAIT_CMD_RL;
							end if;																	
						END IF;					
					
					else -- DL command
					
						if unsigned(fifo_in_data_i(7 downto 0))=DLPC_COLON then
							next_state <= R_ST1;
						end if;			

					end if;					
				end if;				
			
			when WAIT_CMD_RM =>
				if fifo_in_empty_i = '0' then
					fifo_in_rd_o <= '1';
					next_state <= ERROR_ST1;
					error_nxt <= E_ICC;
					
					if fifo_in_data_i(8)='1' then  -- DL command
						
						IF C_RM_SIZE > 0 THEN
							if unsigned(fifo_in_data_i(7 downto 0))=DLPC_COLON then
								next_state <= RM_ST1;
							end if;
						END IF;

					end if;					
				end if;						
			
			when WAIT_CMD_RS =>
				if fifo_in_empty_i = '0' then
					fifo_in_rd_o <= '1';
					next_state <= ERROR_ST1;
					error_nxt <= E_ICC;
					
					if fifo_in_data_i(8)='0' then -- AL data/cmd
						
						IF C_PUB_MODE > 0 THEN
							if unsigned(fifo_in_data_i(7 downto 0))=ALPC_I or
								unsigned(fifo_in_data_i(7 downto 0))=ALPC_I+x"20" then -- accept 'i' (lower case)
								next_state <= WAIT_CMD_RSI;
							end if;																	
						END IF;

					end if;					
				end if;
			
			when WAIT_CMD_RSI =>
				if fifo_in_empty_i = '0' then
					fifo_in_rd_o <= '1';
					next_state <= ERROR_ST1;
					error_nxt <= E_ICC;
					
					if fifo_in_data_i(8)='1' then  -- DL command
						
						IF C_PUB_MODE > 0 THEN
							if unsigned(fifo_in_data_i(7 downto 0))=DLPC_COLON then
								next_state <= RSI_ST1;
							end if;
						END IF;

					end if;					
				end if;
			
			when WAIT_CMD_RL =>
			
				if fifo_in_empty_i = '0' then
					fifo_in_rd_o <= '1';
					next_state <= ERROR_ST1;
					error_nxt <= E_ICC;
					
					if fifo_in_data_i(8)='0' then -- AL data/cmd
						
						IF C_RLC_EN > 0 THEN
							if unsigned(fifo_in_data_i(7 downto 0))=ALPC_C or
								unsigned(fifo_in_data_i(7 downto 0))=ALPC_C+x"20" then -- accept 'c' (lower case)
								next_state <= RLC_ST1;
							end if;
						END IF;

					end if;					
				end if;
				
			when WAIT_CMD_W =>
			
				if fifo_in_empty_i = '0' then
					fifo_in_rd_o <= '1';
					next_state <= ERROR_ST1;
					error_nxt <= E_ICC;
					
					if fifo_in_data_i(8)='0' then -- AL data/cmd
						
						IF C_PUB_MODE > 0 THEN
							if unsigned(fifo_in_data_i(7 downto 0))=ALPC_S or
								unsigned(fifo_in_data_i(7 downto 0))=ALPC_S+x"20" then -- accept 's' (lower case)
								next_state <= WAIT_CMD_WS;
							end if;
						END IF;		
					
					else -- DL command
					
						if unsigned(fifo_in_data_i(7 downto 0))=DLPC_COLON then
							next_state <= W_ST1;
						end if;			

					end if;					
				end if;			
					
			when WAIT_CMD_WS =>
				if fifo_in_empty_i = '0' then
					fifo_in_rd_o <= '1';
					next_state <= ERROR_ST1;
					error_nxt <= E_ICC;
					
					if fifo_in_data_i(8)='0' then -- AL data/cmd
						
						IF C_PUB_MODE > 0 THEN
							if unsigned(fifo_in_data_i(7 downto 0))=ALPC_A or
								unsigned(fifo_in_data_i(7 downto 0))=ALPC_A+x"20" then -- accept 'a' (lower case)
								next_state <= WAIT_CMD_WSA;
							end if;																	
							
							if unsigned(fifo_in_data_i(7 downto 0))=ALPC_R or
								unsigned(fifo_in_data_i(7 downto 0))=ALPC_R+x"20" then -- accept 'r' (lower case)
								next_state <= WAIT_CMD_WSR;
							end if;															
						END IF;

					end if;					
				end if;
				
			when WAIT_CMD_WSA =>
				if fifo_in_empty_i = '0' then
					fifo_in_rd_o <= '1';
					next_state <= ERROR_ST1;
					error_nxt <= E_ICC;
					
					if fifo_in_data_i(8)='1' then  -- DL command
						
						IF C_PUB_MODE > 0 THEN
							if unsigned(fifo_in_data_i(7 downto 0))=DLPC_COLON then
								next_state <= WSA_ST1;
							end if;
						END IF;

					end if;
				end if;
			
			when WAIT_CMD_WSR =>
				if fifo_in_empty_i = '0' then
					fifo_in_rd_o <= '1';
					next_state <= ERROR_ST1;
					error_nxt <= E_ICC;
					
					if fifo_in_data_i(8)='1' then  -- DL command
						
						IF C_PUB_MODE > 0 THEN
							if unsigned(fifo_in_data_i(7 downto 0))=DLPC_COLON then
								next_state <= WSR_ST1;
							end if;
						END IF;

					end if;
				end if;
			
			when WAIT_CMD_E =>
				if fifo_in_empty_i = '0' then
					fifo_in_rd_o <= '1';
					next_state <= ERROR_ST1;
					error_nxt <= E_ICC;
					
					if fifo_in_data_i(8)='0' then -- AL data/cmd
											
						IF C_PUB_MODE > 0 THEN
							if unsigned(fifo_in_data_i(7 downto 0))=ALPC_P or
								unsigned(fifo_in_data_i(7 downto 0))=ALPC_P+x"20" then -- accept 'p' (lower case)
								next_state <= WAIT_CMD_EP;
							end if;
						END IF;		

					end if;					
				end if;			
			
			when WAIT_CMD_EP =>
				if fifo_in_empty_i = '0' then
					fifo_in_rd_o <= '1';
					next_state <= ERROR_ST1;
					error_nxt <= E_ICC;
					
					if fifo_in_data_i(8)='0' then -- AL data/cmd
											
						IF C_PUB_MODE > 0 THEN
							if unsigned(fifo_in_data_i(7 downto 0))=ALPC_S or
								unsigned(fifo_in_data_i(7 downto 0))=ALPC_S+x"20" then -- accept 's' (lower case)
								next_state <= EPS_ST1;
							end if;
							
							if unsigned(fifo_in_data_i(7 downto 0))=ALPC_C or
								unsigned(fifo_in_data_i(7 downto 0))=ALPC_C+x"20" then -- accept 'c' (lower case)
								next_state <= EPC_ST1;
							end if;							
						END IF;

					end if;					
				end if;
				
			when WAIT_CMD_D =>
				if fifo_in_empty_i = '0' then
					fifo_in_rd_o <= '1';
					next_state <= ERROR_ST1;
					error_nxt <= E_ICC;
					
					if fifo_in_data_i(8)='0' then -- AL data/cmd
											
						IF C_PUB_MODE > 0 THEN
							if unsigned(fifo_in_data_i(7 downto 0))=ALPC_P or
								unsigned(fifo_in_data_i(7 downto 0))=ALPC_P+x"20" then -- accept 'p' (lower case)
								next_state <= WAIT_CMD_DP;
							end if;
						END IF;		

					end if;					
				end if;	
			
			when WAIT_CMD_DP =>
				if fifo_in_empty_i = '0' then
					fifo_in_rd_o <= '1';
					next_state <= ERROR_ST1;
					error_nxt <= E_ICC;
					
					if fifo_in_data_i(8)='0' then -- AL data/cmd
											
						IF C_PUB_MODE > 0 THEN
							if unsigned(fifo_in_data_i(7 downto 0))=ALPC_S or
								unsigned(fifo_in_data_i(7 downto 0))=ALPC_S+x"20" then -- accept 's' (lower case)
								next_state <= DPS_ST1;
							end if;
						END IF;		

					end if;					
				end if;


			--------------------------------------------------------
			-- Read Single				
				when R_ST1 =>			
					-- wait for and retrieve address bytes
					if fifo_in_empty_i = '0' then
						
						if fifo_in_data_i(8)='0' then
							-- read address
							fifo_in_rd_o 	<= '1';

							vaddr_nxt(((C_ADDR_BYTES-rd_cnt_reg)*8)-1 downto ((C_ADDR_BYTES-rd_cnt_reg-1)*8))	<= unsigned(fifo_in_data_i(7 downto 0));
							
							-- increment read count
							rd_cnt_nxt <= rd_cnt_reg+1;

							if(rd_cnt_reg=(C_ADDR_BYTES-1)) then
								next_state <= R_ST2;
							end if;
							
						else
							-- error
							next_state <= ERROR_ST1;
							error_nxt <= E_MAB;
						end if;						
					end if;				
				
				
				when R_ST2 =>
					-- Read data
					en_o <= '1';
					adr_o <= std_logic_vector(vaddr_reg(adr_o'range));
					
					if done_i='1' then					
						databuffer_nxt <= dat_i;
						next_state <= R_ST3;
					elsif err_i='1' then
						-- error
						next_state <= ERROR_ST1;
						error_nxt <= E_FBR;						
					end if;					
					
				when R_ST3 =>
					-- verify output fifo isn't full
					if fifo_out_full_i='0' then
						-- transmit response code
						fifo_out_wr_o 		<= '1';
						fifo_out_data_o 	<= '0' & S_R;
						
						next_state 			<= R_ST4;
					end if;
					
				when R_ST4 =>
					-- verify output fifo isn't full
					if fifo_out_full_i='0' then
						-- transmit ':'
						fifo_out_wr_o 		<= '1';
						fifo_out_data_o 	<= '1' & std_logic_vector(DLPC_COLON);
						
						next_state 			<= R_ST5;
					end if;					
				
				when R_ST5 =>
					-- Return data
					
					-- verify fifo isn't full
					if fifo_out_full_i='0' then
						-- write selected shared memory data
						fifo_out_wr_o <= '1';
						
						fifo_out_data_o <= '0' & databuffer_reg(((C_DATA_BYTES-wr_cnt_reg)*8)-1 downto ((C_DATA_BYTES-wr_cnt_reg-1)*8));
						
						-- increment write count
						wr_cnt_nxt <= wr_cnt_reg+1;
						
						if wr_cnt_reg=C_DATA_BYTES-1 then
							next_state <= WRITE_TAIL;
						end if;
					end if;
					
			--------------------------------------------------------
			-- Read Block (SLOW: NOT PIPELINED!)
				when RM_ST1 =>
					-- wait for, retrieve and evaluate block size
					if fifo_in_empty_i = '0' then
						
						if (fifo_in_data_i(8)='0' and (unsigned(fifo_in_data_i(7 downto 0)) > 0) and (unsigned(fifo_in_data_i(7 downto 0)) < C_RM_SIZE)) then
							-- read block size
							fifo_in_rd_o 	<= '1';
							size_nxt			<= unsigned(fifo_in_data_i(7 downto 0));
							next_state 		<= RM_ST2;
							
						else
							-- error
							next_state <= ERROR_ST1;
							error_nxt <= E_IBS;
						end if;						
					end if;						
					
				when RM_ST2 =>
					-- verify output fifo isn't full
					if fifo_out_full_i='0' then
						-- transmit response code
						fifo_out_wr_o 		<= '1';
						fifo_out_data_o 	<= '0' & S_RM;
						
						next_state 			<= RM_ST3;
					end if;
					
				when RM_ST3 =>
					-- verify output fifo isn't full
					if fifo_out_full_i='0' then
						-- transmit ':'
						fifo_out_wr_o 		<= '1';
						fifo_out_data_o 	<= '1' & std_logic_vector(DLPC_COLON);
						
						next_state 			<= RM_ST4;
					end if;						
					
				
				when RM_ST4 =>
					-- wait for and retrieve address bytes
					blk_o <= '1';
					if fifo_in_empty_i = '0' then
						
						if fifo_in_data_i(8)='0' then
							-- read address
							fifo_in_rd_o 	<= '1';

							vaddr_nxt(((C_ADDR_BYTES-rd_cnt_reg)*8)-1 downto ((C_ADDR_BYTES-rd_cnt_reg-1)*8))	<= unsigned(fifo_in_data_i(7 downto 0));
							
							-- increment read count
							rd_cnt_nxt <= rd_cnt_reg+1;

							if(rd_cnt_reg=(C_ADDR_BYTES-1)) then								
								next_state <= RM_ST5;
							end if;
							
						else
							-- error
							next_state <= ERROR_ST1;
							error_nxt <= E_MAB;
						end if;						
					end if;						
					
				when RM_ST5 =>
					-- Read data
					en_o <= '1';
					blk_o <= '1';
					adr_o <= std_logic_vector(vaddr_reg(adr_o'range));					
					
					if done_i='1' then	
						if size_reg > 1 then
							nxt_o <= '1';
						end if;						
						databuffer_nxt <= dat_i;
						next_state <= RM_ST6;
					elsif err_i='1' then
						-- error
						next_state <= ERROR_ST1;
						error_nxt <= E_FBR;						
					end if;	
									
				when RM_ST6 =>
					-- return data
					blk_o <= '1';
					
					-- verify fifo isn't full
					if fifo_out_full_i='0' then
						-- write selected shared memory data
						fifo_out_wr_o <= '1';
						
						fifo_out_data_o <= '0' & databuffer_reg(((C_DATA_BYTES-wr_cnt_reg)*8)-1 downto ((C_DATA_BYTES-wr_cnt_reg-1)*8));
						
						-- increment write count
						wr_cnt_nxt <= wr_cnt_reg+1;
						
						if size_reg > 1 and wr_cnt_reg=C_DATA_BYTES-1 then
							size_nxt <= size_reg-1;
							wr_cnt_nxt <= 0;
							rd_cnt_nxt <= 0;
							next_state <= RM_ST4;
						elsif wr_cnt_reg=C_DATA_BYTES-1 then
							next_state <= WRITE_TAIL;
						end if;
					end if;					

			--------------------------------------------------------
			-- Write Single		
				when W_ST1 =>					
					-- wait for and retrieve address bytes
					if fifo_in_empty_i = '0' then
						
						if fifo_in_data_i(8)='0' then
							-- read address
							fifo_in_rd_o 	<= '1';

							vaddr_nxt(((C_ADDR_BYTES-rd_cnt_reg)*8)-1 downto ((C_ADDR_BYTES-rd_cnt_reg-1)*8))	<= unsigned(fifo_in_data_i(7 downto 0));
							
							-- increment read count
							rd_cnt_nxt <= rd_cnt_reg+1;

							if(rd_cnt_reg=(C_ADDR_BYTES-1)) then
								rd_cnt_nxt <= 0;
								next_state <= W_ST2;
							end if;
							
						else
							-- error
							next_state <= ERROR_ST1;
							error_nxt  <= E_MAB;
						end if;
					end if;
					
				when W_ST2 =>
					-- wait for and retrieve data bytes				
					if fifo_in_empty_i = '0' then
						
						if fifo_in_data_i(8)='0' then
							-- read address
							fifo_in_rd_o 	<= '1';

							databuffer_nxt(((C_DATA_BYTES-rd_cnt_reg)*8)-1 downto ((C_DATA_BYTES-rd_cnt_reg-1)*8))	<= fifo_in_data_i(7 downto 0);
							
							-- increment read count
							rd_cnt_nxt <= rd_cnt_reg+1;

							if(rd_cnt_reg=(C_DATA_BYTES-1)) then
								next_state <= W_ST3;
							end if;
							
						else
							-- error
							next_state <= ERROR_ST1;
							error_nxt  <= E_MDB;								
						end if;
					end if;
				
				when W_ST3 =>
					-- write data					
					en_o <= '1';
					we_o <= '1';
					adr_o <= std_logic_vector(vaddr_reg(adr_o'range));
					dat_o <= databuffer_reg;
					
					if done_i='1' then
						next_state <= W_ST4;
					elsif err_i='1' then
						-- error
						next_state <= ERROR_ST1;
						error_nxt  <= E_FBW;
					end if;
				
				when W_ST4 =>
					-- verify output fifo isn't full
					if fifo_out_full_i='0' then
						-- transmit response code
						fifo_out_wr_o 		<= '1';
						fifo_out_data_o 	<= '0' & S_W;
						
						next_state 			<= WRITE_TAIL;
					end if;			

			--------------------------------------------------------
			-- Publish Service Handler (PSH)
				when PSH_ST1 =>					
					-- verify output fifo isn't full
					if fifo_out_full_i='0' then

						-- if valid publish requests exist 
						if publish_group_id_vld='1' then
																
							-- retrieve subscription group id
							publish_srv_next_id <= '1';						
							
							-- transmit head (%/&) code
							fifo_out_wr_o 		<= '1';
							
							if publish_chks_reg='1' then
								fifo_out_data_o 	<= '1' & DLPC_PUB_CHK;
							else
								fifo_out_data_o 	<= '1' & DLPC_PUB;
							end if;
							
							next_state	<= PSH_ST2;							
							
						else
							-- error
							next_state <= ERROR_ST1;
							--error_nxt  <= ;
						end if;

					end if;						
				
				when PSH_ST2 =>
					-- verify output fifo isn't full
					if fifo_out_full_i='0' then

						-- acknowledge publish request from the selected subscription group
						sg_publish_ack_i <= '1';
						
						-- transmit publish command code
						fifo_out_wr_o 		<= '1';
						fifo_out_data_o 	<= '0' & S_PUB;
						
						next_state	<= PSH_ST3;
					end if;						
				
				when PSH_ST3 =>
					-- verify output fifo isn't full
					if fifo_out_full_i='0' then
						-- transmit ':'
						fifo_out_wr_o 		<= '1';
						fifo_out_data_o 	<= '1' & std_logic_vector(DLPC_COLON);
						
						next_state 			<= PSH_ST4;
					end if;
				
				when PSH_ST4 =>
					-- verify output fifo isn't full
					if fifo_out_full_i='0' then

						-- transmit group-id
						fifo_out_wr_o 		<= '1';
						fifo_out_data_o	<= (others=>'0');
						fifo_out_data_o(publish_group_id_reg'range) 	<= publish_group_id_reg;
						
						next_state	<= PSH_ST5;
					end if;
					
				when PSH_ST5 =>					
					-- verify output fifo isn't full
					if fifo_out_full_i='0' then

						-- transmit size
						fifo_out_wr_o 		<= '1';
						fifo_out_data_o	<= (others=>'0');
						fifo_out_data_o(sg_data_cnt_o'range) <= sg_data_cnt_o;
						
						next_state	<= PSH_ST6;
					end if;
				
				when PSH_ST6 =>
					blk_o <= '1';				-- set wishbone master in block mode
					sm_stream_en_i <= '1';	-- initiate stream read of address data from subscription group
					
					next_state	<= PSH_ST7;
					
				when PSH_ST7 =>
					blk_o <= '1';				-- set wishbone master in block mode
					sm_stream_en_i <= '1';	-- keep address data valid while reading data					
					
					-- Read data addressed by subscription group
					en_o <= '1';
					adr_o <= std_logic_vector(sg_data_o);
					
					if done_i='1' then					
						databuffer_nxt <= dat_i;
						sm_stream_nxt_i <= '1'; -- retrieve next data piece from subscription manager
						next_state <= PSH_ST8;
					elsif err_i='1' then
						-- error
						next_state <= ERROR_ST1;
						error_nxt <= E_FBR;
					end if;
				
				when PSH_ST8 =>									
					blk_o <= '1';				-- set wishbone master in block mode
					sm_stream_en_i <= '1';	-- keep subscription manager in stream mode
					
					-- return data
					-- verify fifo isn't full
					if fifo_out_full_i='0' then
						-- write selected shared memory data
						fifo_out_wr_o <= '1';
						
						fifo_out_data_o <= '0' & databuffer_reg(((C_DATA_BYTES-wr_cnt_reg)*8)-1 downto ((C_DATA_BYTES-wr_cnt_reg-1)*8));
						
						-- increment write count
						wr_cnt_nxt <= wr_cnt_reg+1;
						
						if sm_stream_done_o='1' and wr_cnt_reg=C_DATA_BYTES-1 then
							next_state <= WRITE_TAIL;
						elsif wr_cnt_reg=C_DATA_BYTES-1 then
							wr_cnt_nxt <= 0;							
							next_state <= PSH_ST7;							
						end if;
					end if;
			--------------------------------------------------------

			--------------------------------------------------------
			-- Read Subscription Info (RSI)
				when RSI_ST1 =>
					-- wait for and read group id
					if fifo_in_empty_i = '0' then	
						if fifo_in_data_i(8)='0' then
							
							fifo_in_rd_o 	<= '1';
							if unsigned(fifo_in_data_i(7 downto 0))<(2**C_SUBMNGR_SGID_SIZE) then
								
								-- save group-id
								group_id_nxt <= fifo_in_data_i(group_id_nxt'range);
								
								next_state <= RSI_ST2;
							else
								-- error (invalid subscription group-id)
								next_state <= ERROR_ST1;
								error_nxt <= E_ISG;
							end if;								
							
						else
							-- error
							next_state <= ERROR_ST1;
							error_nxt  <= E_MDB;								
						end if;
					end if;
					
				when RSI_ST2 =>							
					-- verify output fifo isn't full
					if fifo_out_full_i='0' then

						-- transmit response code
						fifo_out_wr_o 		<= '1';
						fifo_out_data_o 	<= '0' & S_RSI;	
						
						next_state <= RSI_ST3;
					end if;				
				
				when RSI_ST3 =>
					-- verify output fifo isn't full
					if fifo_out_full_i='0' then
						-- transmit ':'
						fifo_out_wr_o 		<= '1';
						fifo_out_data_o 	<= '1' & std_logic_vector(DLPC_COLON);
						
						next_state 			<= RSI_ST4;
					end if;				
				
				when RSI_ST4 =>							
					-- verify output fifo isn't full
					if fifo_out_full_i='0' then
						-- write rate bytes
						fifo_out_wr_o <= '1';
						
						fifo_out_data_o 	<= '0' & sg_rate_data_o((8*(C_SUBGRP_RATE_BYTE_CNT-wr_cnt_reg))-1 downto (8*((C_SUBGRP_RATE_BYTE_CNT-1)-wr_cnt_reg)));			
						
						-- increment write count
						wr_cnt_nxt <= wr_cnt_reg+1;
						
						if wr_cnt_reg=(C_SUBGRP_RATE_BYTE_CNT-1) then
							wr_cnt_nxt <= 0;
							next_state <= RSI_ST5;
						end if;
					end if;
				
				when RSI_ST5 =>										
					-- verify output fifo isn't full
					if fifo_out_full_i='0' then
						-- write data cnt
						fifo_out_wr_o <= '1';
						
						fifo_out_data_o(8 downto C_SUBGRP_ADDR_WIDTH+1) <= (others=>'0');
						fifo_out_data_o(C_SUBGRP_ADDR_WIDTH downto 0) <= sg_data_cnt_o;
						
						if unsigned(sg_data_cnt_o)=0 then
							next_state <= WRITE_TAIL;
						else
							next_state <= RSI_ST6;
						end if;
					end if;					
				
				when RSI_ST6 =>
					-- initiate read of address data from subscription group					
					sg_addr_i <= std_logic_vector(TO_UNSIGNED(rd_cnt_reg, sg_addr_i'length));
					next_state <= RSI_ST7;
				
				when RSI_ST7 =>	
					-- keep data valid until it has been registered
					sg_addr_i <= std_logic_vector(TO_UNSIGNED(rd_cnt_reg, sg_addr_i'length));	

					vaddr_nxt <= (others=>'0');
					vaddr_nxt(sg_data_o'range) <= unsigned(sg_data_o);
					
					next_state <= RSI_ST8;
				
				when RSI_ST8 =>								
					
					-- verify output fifo isn't full
					if fifo_out_full_i='0' then
						-- write address data
						fifo_out_wr_o <= '1';
											
						fifo_out_data_o <= '0' & std_logic_vector(vaddr_reg(((C_ADDR_BYTES-wr_cnt_reg)*8)-1 downto ((C_ADDR_BYTES-wr_cnt_reg-1)*8)));
						
						-- increment write count
						wr_cnt_nxt <= wr_cnt_reg+1;
						
						if wr_cnt_reg=(C_ADDR_BYTES-1) then
							wr_cnt_nxt <= 0;
							
							if rd_cnt_reg=unsigned(sg_data_cnt_o)-1 then
								next_state <= WRITE_TAIL;
							else
								rd_cnt_nxt <= rd_cnt_reg+1;
								next_state <= RSI_ST6;
							end if;
							
						end if;						
					end if;			
			--------------------------------------------------------	

			------------------------------------------------------	
			-- Write Subscription Rate (WSR)			
				when WSR_ST1 =>
					-- wait for and read group id
					if fifo_in_empty_i = '0' then	
						if fifo_in_data_i(8)='0' then
							
							fifo_in_rd_o 	<= '1';
							if unsigned(fifo_in_data_i(7 downto 0))<(2**C_SUBMNGR_SGID_SIZE) then
								
								-- save group-id
								group_id_nxt <= fifo_in_data_i(group_id_nxt'range);
								
								next_state <= WSR_ST2;
							else
								-- error (invalid subscription group-id)
								next_state <= ERROR_ST1;
								error_nxt <= E_ISG;
							end if;
							
						else
							-- error
							next_state <= ERROR_ST1;
							error_nxt  <= E_MDB;								
						end if;
					end if;				
				
				when WSR_ST2 => 						
					-- wait for and read rate bytes
					if fifo_in_empty_i = '0' then	
						if fifo_in_data_i(8)='0' then
							
							fifo_in_rd_o 	<= '1';										

							case rd_cnt_reg is
								when 0 => databuffer_nxt(31 downto 24)	<= fifo_in_data_i(7 downto 0);			-- Rate data...
								when 1 => databuffer_nxt(23 downto 16)	<= fifo_in_data_i(7 downto 0);
								when 2 => databuffer_nxt(15 downto 8)	<= fifo_in_data_i(7 downto 0);
								when 3 => databuffer_nxt(7 downto 0)	<= fifo_in_data_i(7 downto 0);
								when others => null;
							end case;
							
							-- increment read count
							rd_cnt_nxt <= rd_cnt_reg+1;

							if(rd_cnt_reg=(C_SUBGRP_RATE_BYTE_CNT-1)) then
								next_state <= WSR_ST3;
							end if;							
							
						else
							-- error
							next_state <= ERROR_ST1;
							error_nxt  <= E_MDB;								
						end if;
					end if;				
				
				when WSR_ST3 =>				
					-- verify output fifo isn't full
					if fifo_out_full_i='0' then
						-- write rate bytes					
						sg_rate_we_i		<= '1';
						sg_rate_data_i		<= databuffer_reg(31 downto 8*(4-C_SUBGRP_RATE_BYTE_CNT));
					
						-- transmit response code
						fifo_out_wr_o 		<= '1';
						fifo_out_data_o 	<= '0' & S_WSR;
						
						next_state 			<= WRITE_TAIL;
					end if;				
			--------------------------------------------------------
			
			--------------------------------------------------------
			-- Write Subscription Addresses (WSA)		
				when WSA_ST1 =>
					-- wait for and read group id
					if fifo_in_empty_i = '0' then	
						if fifo_in_data_i(8)='0' then
							
							fifo_in_rd_o 	<= '1';
							if unsigned(fifo_in_data_i(7 downto 0))<(2**C_SUBMNGR_SGID_SIZE) then
								
								-- save group-id
								group_id_nxt <= fifo_in_data_i(group_id_nxt'range);
								
								next_state <= WSA_ST2;
							else
								-- error (invalid subscription group-id)
								next_state <= ERROR_ST1;
								error_nxt <= E_ISG;
							end if;								
							
						else
							-- error
							next_state <= ERROR_ST1;
							error_nxt  <= E_MDB;								
						end if;
					end if;
				
				when WSA_ST2 =>
					-- read & write length

					-- wait for data
					if fifo_in_empty_i = '0' then	
						if fifo_in_data_i(8)='0' then

							fifo_in_rd_o 	<= '1';		
							if unsigned(fifo_in_data_i(7 downto 0))>0 and unsigned(fifo_in_data_i(7 downto 0))<=(2**C_SUBGRP_ADDR_WIDTH) then
								
								-- write length/data_cnt data
								sg_data_cnt_we_i <= '1';
								sg_data_cnt_i	<= fifo_in_data_i(sg_data_cnt_i'range);
								
								-- calc message length-1
								length_nxt <= unsigned(fifo_in_data_i(7 downto 0))-1;
								
								next_state <= WSA_ST3;
							else
								-- error (invalid lenght argument)
								next_state <= ERROR_ST1;
								error_nxt <= E_ILA;
							end if;								
							
						else
							-- error
							next_state <= ERROR_ST1;
							error_nxt  <= E_MDB;								
						end if;
					end if;
					
				when WSA_ST3 =>
					-- wait for and retrieve address bytes
					if fifo_in_empty_i = '0' then
						
						if fifo_in_data_i(8)='0' then
							-- read address
							fifo_in_rd_o 	<= '1';

							vaddr_nxt(((C_ADDR_BYTES-rd_cnt_reg)*8)-1 downto ((C_ADDR_BYTES-rd_cnt_reg-1)*8))	<= unsigned(fifo_in_data_i(7 downto 0));
							
							-- increment read count
							rd_cnt_nxt <= rd_cnt_reg+1;

							if(rd_cnt_reg=(C_ADDR_BYTES-1)) then
								rd_cnt_nxt <= 0;
								next_state <= WSA_ST4;
							end if;
							
						else
							-- error
							next_state <= ERROR_ST1;
							error_nxt  <= E_MAB;
						end if;
					end if;									
					
				when WSA_ST4 =>
					-- write address
					
					sg_data_we_i <= '1';
					sg_addr_i	 <= std_logic_vector(TO_UNSIGNED(wr_cnt_reg, sg_addr_i'length));
					sg_data_i	 <= std_logic_vector(vaddr_reg(sg_data_i'range));
					
					-- increment write count
					wr_cnt_nxt <= wr_cnt_reg+1;

					if wr_cnt_reg = length_reg then

						-- verify fifo isn't full
						if fifo_out_full_i='0' then				
							-- transmit response code
							fifo_out_wr_o 		<= '1';
							fifo_out_data_o 	<= '0' & S_WSA;
							
							next_state 			<= WRITE_TAIL;
						end if;				
					else		
						rd_cnt_nxt <= 0;
						next_state <= WSA_ST3;				
					end if;
			--------------------------------------------------------

			--------------------------------------------------------
			-- Enable Publish Service (EPS)
				when EPS_ST1 =>
					publish_en_nxt 	<= '1';
					publish_chks_nxt 	<= '0';					
						
					-- verify output fifo isn't full
					if fifo_out_full_i='0' then								
						-- transmit response code
						fifo_out_wr_o 		<= '1';
						fifo_out_data_o 	<= '0' & S_EPS;
						next_state 			<= WRITE_TAIL;
					end if;
			--------------------------------------------------------
			
			--------------------------------------------------------
			-- Enable Publish service with Checksum (EPC)
				when EPC_ST1 =>
					publish_en_nxt 	<= '1';
					publish_chks_nxt 	<= '1';					
						
					-- verify output fifo isn't full
					if fifo_out_full_i='0' then								
						-- transmit response code
						fifo_out_wr_o 		<= '1';
						fifo_out_data_o 	<= '0' & S_EPC;
						next_state 			<= WRITE_TAIL;
					end if;
			--------------------------------------------------------			
			
			--------------------------------------------------------
			-- Disable Publish Service (DPS)
				when DPS_ST1 =>
					publish_en_nxt 	<= '0';
		
					-- verify output fifo isn't full
					if fifo_out_full_i='0' then
						-- transmit response code
						fifo_out_wr_o 		<= '1';
						fifo_out_data_o 	<= '0' & S_DPS;
						
						next_state 			<= WRITE_TAIL;
					end if;
			--------------------------------------------------------
			
			--------------------------------------------------------
			-- Read Link Configuration (RLC)			
				when RLC_ST1 =>
					-- verify output fifo isn't full
					if fifo_out_full_i='0' then
						-- write configuration data head
						fifo_out_wr_o <= '1';
											
						fifo_out_data_o <= '0' & RLC_HEAD((((RLC_HEAD'length/8)-wr_cnt_reg)*8)-1 downto (((RLC_HEAD'length/8)-wr_cnt_reg-1)*8));
						
						-- increment write count
						wr_cnt_nxt <= wr_cnt_reg+1;
						
						if wr_cnt_reg=((RLC_HEAD'length/8)-1) then
							wr_cnt_nxt <= 0;
							next_state <= RLC_ST2;
						end if;
					end if;

				when RLC_ST2 =>
					-- verify output fifo isn't full
					if fifo_out_full_i='0' then
						-- transmit ':'
						fifo_out_wr_o 		<= '1';
						fifo_out_data_o 	<= '1' & std_logic_vector(DLPC_COLON);
						
						next_state 			<= RLC_ST3;						
					end if;	

				when RLC_ST3 =>
					-- verify output fifo isn't full
					if fifo_out_full_i='0' then
						-- write configuration data body
						fifo_out_wr_o <= '1';
						
						if RLC_BODY((((RLC_BODY'length/8)-wr_cnt_reg)*8)-1 downto (((RLC_BODY'length/8)-wr_cnt_reg-1)*8)) = DLPC_COMMA then						
							fifo_out_data_o <= '1' & RLC_BODY((((RLC_BODY'length/8)-wr_cnt_reg)*8)-1 downto (((RLC_BODY'length/8)-wr_cnt_reg-1)*8));
						else
							fifo_out_data_o <= '0' & RLC_BODY((((RLC_BODY'length/8)-wr_cnt_reg)*8)-1 downto (((RLC_BODY'length/8)-wr_cnt_reg-1)*8));
						end if;
						
						-- increment write count
						wr_cnt_nxt <= wr_cnt_reg+1;
						
						if wr_cnt_reg=((RLC_BODY'length/8)-1) then
							wr_cnt_nxt <= 0;
							next_state <= WRITE_TAIL;
						end if;						
					end if;						
			--------------------------------------------------------
			
			when ERROR_ST1 =>
				-- verify output fifo isn't full
				if fifo_out_full_i='0' then
					-- write error header '?'
					fifo_out_wr_o <= '1';
					fifo_out_data_o <= '1' & std_logic_vector(DLPC_ERROR);
					
					wr_cnt_nxt <= 0;
					next_state <= ERROR_ST2;
				end if;		
				
			when ERROR_ST2 =>							
				-- verify output fifo isn't full
				if fifo_out_full_i='0' then
					-- write error code
					fifo_out_wr_o <= '1';
										
					fifo_out_data_o <= '0' & error_reg(((C_ERROR_REG_BYTES-wr_cnt_reg)*8)-1 downto ((C_ERROR_REG_BYTES-wr_cnt_reg-1)*8));
					
					-- increment write count
					wr_cnt_nxt <= wr_cnt_reg+1;
					
					if wr_cnt_reg=(C_ERROR_REG_BYTES-1) then
						wr_cnt_nxt <= 0;
						next_state <= WRITE_TAIL;						
					end if;						
				end if;					
			
			when WRITE_TAIL =>
				if fifo_out_full_i='0' then
					fifo_out_wr_o <= '1';
					fifo_out_data_o <= '1' & DLPC_END;
					next_state <= WAIT_HEAD;
				end if;
				
			when others =>
				null;				
				
      end case;		
	
	end process;

end Behavioral;

