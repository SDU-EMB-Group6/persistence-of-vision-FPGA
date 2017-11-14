----------------------------------------------------------------------------------
-- Company: University of Southern Denmark
-- Engineer: Anders Blaabjerg Lange
-- 
-- Create Date:    09:26:15 21/12/2011 
-- Design Name: 
-- Module Name:    uart_tx - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Rev:	Date:			Author:	Description:
-- 0.01	21/12/2012	ANLAN		File Created
-- 0.02
--
-- Additional Comments: 
--		Based on the uart_tx design from chapter 7 code-listing 3 in:
--		"FPGA Prototyping by VHDL example - Spartan 3 Edition" by: Pong P. Chu
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.log_pkg.all;

entity uart_tx is
	generic (
		C_BIT_TX_ORDER		: integer range 0 to 1 := 0;		-- databit tx order: 0 = LSB, 1 = MSB
		C_DATABITS 			: integer range 7 to 9 := 8;		-- number of databits
		C_TICKS_PR_BIT		: integer 				  := 16;		-- number of ticks for each bit
		C_STOPBITS			: integer range 1 to 2 := 1;		-- number of stopbits 
		C_PARITY				: integer range 0 to 4 := 1 		-- parity mode: 0 = NONE, 1 = ODD, 2 = EVEN, 3 = MARK, 4 = SPACE
		);
	port ( 
		clk_i 			: in  std_logic;
		reset_i 			: in  std_logic;
		tx_start_i 		: in  std_logic;
		tick_i 			: in  std_logic;
		data_i 			: in  std_logic_vector(C_DATABITS-1 downto 0);
		tx_done_tick_o : out std_logic;
		tx_o 				: out std_logic;
		transmitting_o	: out std_logic
		);
end uart_tx;

architecture behavioral of uart_tx is

	-- UART TX States
   type state_type is (IDLE, START, DATA, PARITY, STOP);
   signal state_reg	: state_type := IDLE;
	signal state_nxt 	: state_type;
	
	-- Tick Count register
   signal t_cnt_reg	: unsigned(log2c(C_TICKS_PR_BIT)-1 downto 0) := (others=>'0');
	signal t_cnt_nxt	: unsigned(log2c(C_TICKS_PR_BIT)-1 downto 0);
	
	-- Databit Count register
   signal db_cnt_reg	: unsigned(log2c(C_DATABITS)-1 downto 0) := (others=>'0');
	signal db_cnt_nxt	: unsigned(log2c(C_DATABITS)-1 downto 0);
	
	-- Data register
   signal data_reg	: std_logic_vector(C_DATABITS-1 downto 0) := (others=>'0');
	signal data_nxt	: std_logic_vector(C_DATABITS-1 downto 0);
	
	-- TX register
   signal tx_reg		: std_logic := '1'; 
	signal tx_nxt		: std_logic;

	-- Parity register
	signal parity_reg	: std_logic;
	signal parity_nxt	: std_logic;
	
begin

	------------------------------------------------
   -- FSM state & data registers
	------------------------------------------------
		process(clk_i)
		begin
			if rising_edge(clk_i) then
				if reset_i='1' then
					state_reg 	<= IDLE;
					t_cnt_reg 	<= (others=>'0');
					db_cnt_reg	<= (others=>'0');
					data_reg  	<= (others=>'0');
					tx_reg 	 	<= '1';
					
					IF C_PARITY=1 OR C_PARITY=3 THEN	-- Parity = ODD / MARK
						parity_reg <= '1';
					END IF;
					IF C_PARITY=2 OR C_PARITY=4 THEN	-- Parity = EVEN / SPACE
						parity_reg <= '0';
					END IF;
					
				else
					state_reg 	<= state_nxt;
					t_cnt_reg 	<= t_cnt_nxt;
					db_cnt_reg	<= db_cnt_nxt;
					data_reg  	<= data_nxt;
					tx_reg 	 	<= tx_nxt;
					parity_reg	<= parity_nxt;
				end if;
			end if;
		end process;
	------------------------------------------------
	
	------------------------------------------------
	-- Next State Logic
	------------------------------------------------
		process(state_reg, t_cnt_reg, db_cnt_reg, data_reg, tx_reg, parity_reg, tx_start_i, tick_i, data_i)
		begin
			-- defaults
			state_nxt 		<= state_reg;
			t_cnt_nxt 		<= t_cnt_reg;
			db_cnt_nxt 		<= db_cnt_reg;
			data_nxt 		<= data_reg;
			tx_nxt 			<= tx_reg;
			parity_nxt		<= parity_reg;
			
			tx_done_tick_o <= '0';
			transmitting_o <= '1';
						
			case state_reg is
				----------------------------------------
				-- State IDLE
				----------------------------------------
					when IDLE =>
						transmitting_o <= '0';
						-- hold TX-line idle (logic high)
						tx_nxt <= '1';
						
						if tx_start_i='1' then
							data_nxt  <= data_i;					
							
							t_cnt_nxt <= (others=>'0');	-- clear tick count
							db_cnt_nxt <= (others=>'0');	-- clear databit count

							-- init parity register
							IF C_PARITY=1 OR C_PARITY=3 THEN	-- Parity = ODD / MARK
								parity_nxt <= '1';
							END IF;
							IF C_PARITY=2 OR C_PARITY=4 THEN	-- Parity = EVEN / SPACE
								parity_nxt <= '0';
							END IF;
							
							state_nxt <= START;
						end if;
				----------------------------------------
				
				----------------------------------------
				-- State START
				----------------------------------------
				when START =>
					-- send start bit
					tx_nxt <= '0';
					
					if (tick_i = '1') then
						if t_cnt_reg=C_TICKS_PR_BIT-1 then
							t_cnt_nxt  <= (others=>'0');	-- clear tick count
							state_nxt <= DATA;
						else
							t_cnt_nxt <= t_cnt_reg + 1;
						end if;
					end if;
				----------------------------------------
				
				----------------------------------------
				-- State DATA
				----------------------------------------
					when DATA =>
						IF C_BIT_TX_ORDER=0 THEN
							-- send current LSB databit
							tx_nxt <= data_reg(0);						
						END IF;
						IF C_BIT_TX_ORDER=1 THEN
							-- send current MSB databit
							tx_nxt <= data_reg(C_DATABITS-1);						
						END IF;						
						
						if (tick_i = '1') then						
							if t_cnt_reg=C_TICKS_PR_BIT-1 then
							
								t_cnt_nxt <= (others=>'0');								-- clear tick count								
								
								IF C_BIT_TX_ORDER=0 THEN
									data_nxt <= '0' & data_reg(C_DATABITS-1 downto 1); -- shift data_reg 1 bit right
								END IF;		
								IF C_BIT_TX_ORDER=1 THEN
									data_nxt <= data_reg(C_DATABITS-2 downto 0) & '0'; -- shift data_reg 1 bit left
								END IF;	
								
								IF C_PARITY=1 OR C_PARITY=2 THEN
									parity_nxt <= parity_reg xor data_reg(0);
								END IF;								
								
								if db_cnt_reg=(C_DATABITS-1) then
									
									db_cnt_nxt <= (others=>'0');							-- clear databit count
									
									if C_PARITY>0 then
										state_nxt <= PARITY;
									else
										state_nxt <= STOP;
									end if;
								else
									db_cnt_nxt <= db_cnt_reg + 1;
								end if;
								
							else
								t_cnt_nxt <= t_cnt_reg + 1;
							end if;							
						end if;
				----------------------------------------
				
				----------------------------------------
				-- State Parity
				----------------------------------------
					when PARITY =>
						-- send parity bit
						tx_nxt <= parity_reg;
						
						if (tick_i = '1') then
							if t_cnt_reg=C_TICKS_PR_BIT-1 then
								t_cnt_nxt  <= (others=>'0');			-- clear tick count
								state_nxt <= STOP;
							else
								t_cnt_nxt <= t_cnt_reg + 1;
							end if;
						end if;
				----------------------------------------
				
				----------------------------------------
				-- State STOP
				----------------------------------------
					when STOP =>
						-- send Stopbit(s)
						tx_nxt <= '1';
						
						if (tick_i = '1') then						
							if t_cnt_reg=C_TICKS_PR_BIT-1 then
							
								t_cnt_nxt <= (others=>'0');			-- clear tick count
								
								if db_cnt_reg=(C_STOPBITS-1) then
									
									tx_done_tick_o <= '1';
									
									db_cnt_nxt <= (others=>'0');		-- clear databit (stopbit) count
									
									state_nxt <= IDLE;
								else
									db_cnt_nxt <= db_cnt_reg + 1;
								end if;
								
							else
								t_cnt_nxt <= t_cnt_reg + 1;
							end if;							
						end if;
				----------------------------------------
					
			end case;
		end process;
		
		tx_o <= tx_reg;
		
	------------------------------------------------

end behavioral;

