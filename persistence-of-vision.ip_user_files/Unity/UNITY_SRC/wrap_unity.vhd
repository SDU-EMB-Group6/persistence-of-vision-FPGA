----------------------------------------------------------------------------------
-- Company: University Of Southern Denmark
-- Engineer: Anders Stengaard Sørensen [control]
--           Anders Blaabjerg Lange  [communication]
-- 
-- Create Date:    09:41:02 14/05/2012 
-- Design Name: 
-- Module Name:     
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- 0.01	14/05/2012	ANLAN		File Created
-- 0.04
--
-- Additional Comments: 
--
-- Depending on the FPGA family the CLK_MULTIPLY and CLK_DIDIVE generic
-- has the following constraints:
--
--         -----------------------------------------------
--         | generic \ fpga     | SPARTAN_6 | SPARTAN_3A |
--         -----------------------------------------------
-- 		  | Clock multiplier	  |  [1:256]  |   [1:32]   |
-- 		  | Clock divisor		  |  [2:256]  |   [1:32]   |
--         -----------------------------------------------
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_classic_interface.all;
Library UNISIM;
use UNISIM.vcomponents.all;

entity wrap_unity is
	generic (
		-- Clock Generation Configuration
		C_FPGA_FAMILY				: string	:= "ZYNQ";          -- "SPARTAN_6", "SPARTAN_3A", "ZYNQ"
		C_INPUT_CLK_PERIOD_NS 		: real		:= 5.0;				-- Period of the input clock source [ns]
		
		C_INPUT_CLK_MULTIPLY_96M	: positive	:= 12;				-- Adjust C_INPUT_CLK_MULTIPLY_96M and C_INPUT_CLK_DIVIDE_96M
		C_INPUT_CLK_DIVIDE_96M		: positive	:= 25;				-- so C_INPUT_CLK_MULTIPLY_96M/(C_INPUT_CLK_PERIOD_NS*C_INPUT_CLK_DIVIDE_96M) = 96 MHz
		
		C_INPUT_CLK_MULTIPLY_50M	: positive	:= 2;					-- Adjust C_INPUT_CLK_MULTIPLY_50M and C_INPUT_CLK_DIVIDE_50M
		C_INPUT_CLK_DIVIDE_50M		: positive	:= 8;					-- so C_INPUT_CLK_MULTIPLY_50M/(C_INPUT_CLK_PERIOD_NS*C_INPUT_CLK_DIVIDE_50M) = 50 MHz

		-- MEM configuration
		C_MEM_ADDR_WIDTH 				: integer range 0 to 32 := 6;		-- Memory depth/size (uTosNet mode: 6, TosNet node: 10)
		C_MEM_DATA_WIDTH 				: integer range 1 to 32 := 32;	-- Data bit size	(TosNet/uTosNet mode: 32)
		C_MEM_RAMSTYLE      			: string  := "AUTO"; 				-- DISTRIBUTED, BLOCK, AUTO
		C_MEM_IO_ADDR_BIT 			: integer range -2 to 31 := 2		-- default: 2 (uTosNet mode), MIXED-IO: [0:C_MEM_ADDR_WIDTH-1], MEM-INPUT-ONLY mode: -2, MEM-OUTPUT-ONLY mode: -1		
		);
	port ( 
		clk_i 	: in  std_logic;	

		rx_i 		: in  std_logic;
		tx_o 		: out std_logic;
		
		clk_user_o : out std_logic;
		
	    mem_we_i		: in std_logic;
		mem_addr_i		: in std_logic_vector(C_MEM_ADDR_WIDTH-1 downto 0);	
		mem_data_i		: in std_logic_vector(C_MEM_DATA_WIDTH-1 downto 0);
		mem_data_o		: out std_logic_vector(C_MEM_DATA_WIDTH-1 downto 0);
		mem_w_ack_o 	: out std_logic;
		mem_w_err_o 	: out std_logic
		);
end wrap_unity;



architecture structural of wrap_unity is


	--**************************************************************************
	-- DO NOT EDIT BELOW THIS LINE
	--**************************************************************************

		-- Clock signals
		signal clk_uart : std_logic;
		signal clk_user : std_logic;
		signal clk_feedback : std_logic;
		
		signal wb_o : wb_ad32sb_if;
		signal wb_i : wb_d32ae_if;


	--**************************************************************************
	-- DO NOT EDIT ABOVE THIS LINE
	--**************************************************************************
	
	-- ADD/REMOVE USER IO SIGNALS HERE -----------------------------------------
	-- The prefix RT denotes "RoboTrainer"

	
begin	

	--**************************************************************************
	-- DO NOT EDIT BELOW THIS LINE
	--**************************************************************************
	
		-------------------------------------------------------------------------
		-- Clock generation logic
		-------------------------------------------------------------------------
		SPARTAN6_GEN:
		if C_FPGA_FAMILY = "SPARTAN_6" generate
			-- UART CLOCK GENERATOR @ 96MHz
			uart_clk_dcm : entity work.clock_gen(spartan_6_clkgen)
				generic map (
					C_INPUT_CLK_PERIOD_NS 	=> C_INPUT_CLK_PERIOD_NS,
					C_CLK_MULTIPLY				=> C_INPUT_CLK_MULTIPLY_96M,
					C_CLK_DIVIDE				=> C_INPUT_CLK_DIVIDE_96M
				)
				port map ( 
					clk_i		=> clk_i,
					reset_i  => '0',
					clk_o 	=> clk_uart,
					locked_o => open
					);

			-- USER CLOCK GENERATOR @ 50MHz
			user_clk_dcm : entity work.clock_gen(spartan_6_clkgen)
				generic map (
					C_INPUT_CLK_PERIOD_NS 	=> C_INPUT_CLK_PERIOD_NS,
					C_CLK_MULTIPLY				=> C_INPUT_CLK_MULTIPLY_50M,
					C_CLK_DIVIDE				=> C_INPUT_CLK_DIVIDE_50M
				)
				port map ( 
					clk_i      => clk_i,
					reset_i    => '0',
					clk_o 	   => clk_user,
					locked_o   => open
					);
		end generate;
		
		SPARTAN3A_GEN:
		if C_FPGA_FAMILY = "SPARTAN_3A" generate
			-- UART CLOCK GENERATOR @ 96MHz
			uart_clk_dcm : entity work.clock_gen(spartan_3a_dcm)
				generic map (
					C_INPUT_CLK_PERIOD_NS 	=> C_INPUT_CLK_PERIOD_NS,
					C_CLK_MULTIPLY				=> C_INPUT_CLK_MULTIPLY_96M,
					C_CLK_DIVIDE				=> C_INPUT_CLK_DIVIDE_96M
				)
				port map ( 
					clk_i		=> clk_i,
					reset_i  => '0',
					clk_o 	=> clk_uart,
					locked_o => open
					);

			-- USER CLOCK GENERATOR @ 50MHz
			user_clk_dcm : entity work.clock_gen(spartan_3a_dcm)
				generic map (
					C_INPUT_CLK_PERIOD_NS 	=> C_INPUT_CLK_PERIOD_NS,
					C_CLK_MULTIPLY				=> C_INPUT_CLK_MULTIPLY_50M,
					C_CLK_DIVIDE				=> C_INPUT_CLK_DIVIDE_50M
				)
				port map ( 
					clk_i		=> clk_i,
					reset_i  => '0',
					clk_o 	=> clk_user,
					locked_o => open
					);
		end generate;
		
	    ZYNQ_GEN:
        if C_FPGA_FAMILY = "ZYNQ" generate
            zynq_clk_mmcm : MMCME2_BASE
            generic map (
                BANDWIDTH => "OPTIMIZED", -- Jitter programming (OPTIMIZED, HIGH, LOW)
                CLKFBOUT_MULT_F => 4.5, -- Multiply value for all CLKOUT (2.000-64.000).
                CLKFBOUT_PHASE => 0.0, -- Phase offset in degrees of CLKFB (-360.000-360.000).
                CLKIN1_PERIOD => C_INPUT_CLK_PERIOD_NS, -- Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
                -- CLKOUT0_DIVIDE - CLKOUT6_DIVIDE: Divide amount for each CLKOUT (1-128)
                CLKOUT1_DIVIDE => 18,
                CLKOUT2_DIVIDE => 1,
                CLKOUT3_DIVIDE => 1,
                CLKOUT4_DIVIDE => 1,
                CLKOUT5_DIVIDE => 1,
                CLKOUT6_DIVIDE => 1,
                CLKOUT0_DIVIDE_F => 9.375, -- Divide amount for CLKOUT0 (1.000-128.000).
                -- CLKOUT0_DUTY_CYCLE - CLKOUT6_DUTY_CYCLE: Duty cycle for each CLKOUT (0.01-0.99).
                CLKOUT0_DUTY_CYCLE => 0.5,
                CLKOUT1_DUTY_CYCLE => 0.5,
                CLKOUT2_DUTY_CYCLE => 0.5,
                CLKOUT3_DUTY_CYCLE => 0.5,
                CLKOUT4_DUTY_CYCLE => 0.5,
                CLKOUT5_DUTY_CYCLE => 0.5,
                CLKOUT6_DUTY_CYCLE => 0.5,
                -- CLKOUT0_PHASE - CLKOUT6_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
                CLKOUT0_PHASE => 0.0,
                CLKOUT1_PHASE => 0.0,
                CLKOUT2_PHASE => 0.0,
                CLKOUT3_PHASE => 0.0,
                CLKOUT4_PHASE => 0.0,
                CLKOUT5_PHASE => 0.0,
                CLKOUT6_PHASE => 0.0,
                CLKOUT4_CASCADE => FALSE, -- Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE)
                DIVCLK_DIVIDE => 1, -- Master division value (1-106)
                REF_JITTER1 => 0.010, -- Reference input jitter in UI (0.000-0.999).
                STARTUP_WAIT => FALSE -- Delays DONE until MMCM is locked (FALSE, TRUE)
            )
            port map (
                -- Clock Outputs: 1-bit (each) output: User configurable clock outputs
                ----------------------------------------------------------------------------
                CLKOUT0 => clk_uart, -- 1-bit output: CLKOUT0
                CLKOUT0B => open, -- 1-bit output: Inverted CLKOUT0
                CLKOUT1 => clk_user, -- 1-bit output: CLKOUT1
                CLKOUT1B => open, -- 1-bit output: Inverted CLKOUT1
                CLKOUT2 => open, -- 1-bit output: CLKOUT2
                CLKOUT2B => open, -- 1-bit output: Inverted CLKOUT2
                CLKOUT3 => open, -- 1-bit output: CLKOUT3
                CLKOUT3B => open, -- 1-bit output: Inverted CLKOUT3
                CLKOUT4 => open, -- 1-bit output: CLKOUT4
                CLKOUT5 => open, -- 1-bit output: CLKOUT5
                CLKOUT6 => open, -- 1-bit output: CLKOUT6
                -- Feedback Clocks: 1-bit (each) output: Clock feedback ports
                CLKFBOUT => clk_feedback, -- 1-bit output: Feedback clock
                CLKFBOUTB => open, -- 1-bit output: Inverted CLKFBOUT
                -- Status Ports: 1-bit (each) output: MMCM status ports
                LOCKED => open, -- 1-bit output: LOCK
                -- Clock Inputs: 1-bit (each) input: Clock input
                CLKIN1 => clk_i, -- 1-bit input: Clock
                -- Control Ports: 1-bit (each) input: MMCM control ports
                PWRDWN => '0', -- 1-bit input: Power-down
                RST => '0', -- 1-bit input: Reset
                -- Feedback Clocks: 1-bit (each) input: Clock feedback ports
                CLKFBIN => clk_feedback -- 1-bit input: Feedback clock
            );
        
--            -- UART CLOCK GENERATOR @ 96MHz
--            uart_clk_mmcm : entity work.clock_gen(ZYNQ_MMCM)
--                generic map (
--                    C_INPUT_CLK_PERIOD_NS     => C_INPUT_CLK_PERIOD_NS,
--                    C_CLK_MULTIPLY_MMCM       => 25.5,--C_INPUT_CLK_MULTIPLY_96M,
--                    C_CLK_DIVIDE_MMCM         => 10.625, --C_INPUT_CLK_DIVIDE_96M
--                    C_CLK_DIVIDE              => 5
--                )
--                port map ( 
--                    clk_i    => clk_i,
--                    reset_i  => '0',
--                    clk_o    => clk_uart,
--                    locked_o => open
--                    );

--            -- USER CLOCK GENERATOR @ 50MHz
--            user_clk_mmcm : entity work.clock_gen(ZYNQ_MMCM)
--                generic map (
--                    C_INPUT_CLK_PERIOD_NS     => C_INPUT_CLK_PERIOD_NS,
--                    C_CLK_MULTIPLY_MMCM       => 5.0,--C_INPUT_CLK_MULTIPLY_50M,
--                    C_CLK_DIVIDE_MMCM         => 20.0,--C_INPUT_CLK_DIVIDE_50M
--                    C_CLK_DIVIDE              => 1
--                )
--                port map ( 
--                    clk_i    => clk_i,
--                    reset_i  => '0',
--                    clk_o    => clk_user,
--                    locked_o => open
--                    );
        end generate;    		
		-------------------------------------------------------------------------

	--**************************************************************************
	-- DO NOT EDIT ABOWE THIS LINE
	--**************************************************************************

	--**************************************************************************
	-- ONLY EDIT BELOW THIS LINE TO ADJUST THE GENERIC CONFIGURATION OF THE 
	-- uart_wb_link_inst, READ THE GENERIC EDITING INFO BOX FIRST! 
	--**************************************************************************
		
		-----------------------------------------------------------------------
		-- GENERIC EDITING INFO:
		--
		-- Ensure the baud rate controlling generics is configured correct!
		--
		-- Generic that has been commented out are inactive, meaning the 
		-- qrc_uart_wb_link_inst uses its default value.
		-- Only uncomment and change these generics if you 
		-- understand what it will do! 
		-- Refer to the User Guide for detailed information.
		--		
		-----------------------------------------------------------------------

		-- C_PL_TICKS_PR_BIT=16, C_PL_BAUD_RATE_DVSR=2 : BAUD = 3000000
		-- C_PL_TICKS_PR_BIT=416, C_PL_BAUD_RATE_DVSR=2 : BAUD = 115200

		uart_wb_link_inst : entity work.uart_wb_link
			generic map (
			-- Physical Layer Configuration
			C_PL_TICKS_PR_BIT				=> 16,			-- number of (baudrate generator) ticks for each bit. MUST BE AN EVEN NUMBER. default = 16
			C_PL_BAUD_RATE_DVSR  		=> 2,				-- BAUD rate divisor: C_BAUD_RATE_DVSR = clk_frq/(C_TICKS_PR_BIT*baud_rate)
			--C_PL_STOPBITS					=> 1,			-- number of stopbits
			--C_PL_PARITY						=> 0,			-- parity mode: 0 = NONE, 1 = ODD, 2 = EVEN, 3 = MARK, 4 = SPACE		
			-- Datalink Layer Configuration
			--C_DL_FULL						=> 1,				-- 1 = Full Datalink Layer, 0 = Lite Datalink Layer (No FIFO's, Checksum or error detection)
			--C_DL_CHECKSUM					=> 2,			-- checksum mode: 0 = NONE, 1 = BYTE WISE XOR, 2 = CRC-8-CCIT		
			-- Application Layer Configuration
			--C_AL_RLC_EN						=> 1,			-- 0: Read Link Config command disabled, 1: Read Link Config command enabled
			--C_AL_RM_SIZE						=> 32,		-- 0: RM disabled, 1-255: RM enabled (up to C_RM_SIZE reads allowed in one command RM)
			--C_AL_PUB_MODE					=> 2,			-- 0: Publish mode disabled, 1: Prioritize incoming requests, 2: Prioritize Publish requests		
			--C_AL_PUBLISH_BASE_FREQ		=> 1000,		-- Publish sync strobe base frequency [Hz]			
			--C_AL_SUBMNGR_SGID_SIZE		=> 1,			-- Bitwidth of the Group ID port (controls the number of individual subscription groups)
			--C_AL_SUBGRP_RATE_BYTE_CNT 	=> 2, 		-- Number of bytes in the RATE register of each subscription group
			--C_AL_SUBGRP_ADDR_WIDTH 		=> 4,			-- Size/depth of each subscription group = (2**C_AL_SUBGRP_ADDR_WIDTH) : RANGE=[4,8,16,32]		
			-- Wishbone Interface Configuration
			C_WB_CLK_FREQ					=> 50000000,	-- Wishbone clock frequency [Hz]
			C_WB_ADDR_WIDTH				=> C_MEM_ADDR_WIDTH,				-- Wishbone bus address space/size
			C_WB_DATA_WIDTH				=> C_MEM_DATA_WIDTH				-- Wishbone bus data width: [8,16,32]
			)
			port map (		
				-- uart interface
				clk_uart_i		=> clk_uart,
				rx_uart_i		=> rx_i,
				tx_uart_o		=> tx_o,
				
				-- WB interface
				clk_i 			=> clk_user,
				rst_i 			=> '0',
				
				-- wb master interface
				wb_o 				=> wb_o,
				wb_i 				=> wb_i
			);
		
	--**************************************************************************
	-- ONLY EDIT ABOWE THIS LINE TO ADJUST THE GENERIC CONFIGURATION OF THE 
	-- uart_wb_link_inst, READ THE GENERIC EDITING INFO BOX FIRST! 
	--**************************************************************************


	--**************************************************************************
	-- ONLY EDIT BELOW THIS LINE TO ADJUST THE GENERIC CONFIGURATION OF THE 
	-- wb_mem_inst, READ THE GENERIC EDITING INFO BOX FIRST! 
	--**************************************************************************
	
		wb_mem_inst : entity work.wb_mem
			generic map(
				-- MEM configuration
				C_MEM_ADDR_WIDTH 		=> C_MEM_ADDR_WIDTH,		-- Memory depth/size (uTosNet mode: 6, TosNet node: 10)
				C_DATA_WIDTH 			=> C_MEM_DATA_WIDTH,		-- Data bit size	(TosNet/uTosNet mode: 32)
				C_RAMSTYLE				=> C_MEM_RAMSTYLE,		-- DISTRIBUTED, BLOCK, AUTO
				C_IO_ADDR_BIT 			=> C_MEM_IO_ADDR_BIT		-- default: 2 (uTosNet mode), MIXED-IO: [0:C_MEM_ADDR_WIDTH-1], INPUT-ONLY mode: -2, OUTPUT-ONLY mode: -1
			)
			port map(
					-- wb syscon interface	
					clk_i => clk_user,
					rst_i => '0',
					
					-- wb slave interface
					wb_i 	=> wb_o,
					wb_o 	=> wb_i,
					
					-- memory interface
					mem_we_i		=> mem_we_i,
					mem_addr_i	=> mem_addr_i,
					mem_data_i	=> mem_data_i,
					mem_data_o	=> mem_data_o,
					mem_w_ack_o => mem_w_ack_o,
					mem_w_err_o => mem_w_err_o
			);
			
	--**************************************************************************
	-- ONLY EDIT ABOWE THIS LINE TO ADJUST THE GENERIC CONFIGURATION OF THE 
	-- wb_mem_inst, READ THE GENERIC EDITING INFO BOX FIRST! 
	--**************************************************************************

	clk_user_o <= clk_user;

	---------------------------------------------------------------
	-- Memory interface:
	--
	--		mem_we_i		: RAM write enable input
	-- 	mem_addr_i	: RAM address input
	--		mem_data_i	: RAM data input
	-- 	mem_data_o	: RAM data output
	--		mem_w_ack_o	: combinatorial write acknowledge signal 
	--		mem_w_err_o	: combinatorial write error signal (write not allowed to the selected address)
	--    USER has RW rights to output addresses (bit 2==0) in the memory
	--    USER has R rights to all other addresses
	-- ------------------------------------------------
	-- Insert User Logic below this line
		

	-- Insert User Logic above this line
	---------------------------------------------------------------
	
end structural;

