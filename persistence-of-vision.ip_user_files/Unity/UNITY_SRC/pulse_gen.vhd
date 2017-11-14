----------------------------------------------------------------------------------
-- Company: University Of Southern Denmark
-- Engineer: Anders Blaabjerg Lange
-- 
-- Create Date:    09:25:43 04/17/2012 
-- Design Name: 
-- Module Name:    pulse_gen - Behavioral 
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

entity pulse_gen is
	generic(
		C_PULSE_WIDTH : integer := 1;
		C_PULSE_PERIOD : integer := 10
	);
   port( 
		clk_i 	: in std_logic;
      en_i 		: in std_logic;
      strb_o 	: out std_logic
	);
end pulse_gen;

architecture Behavioral of pulse_gen is

	signal counter : integer range 0 to C_PULSE_PERIOD := 0;

begin

	ASSERT (C_PULSE_WIDTH>0) REPORT "Value of C_PULSE_WIDTH must be greater than 0!" SEVERITY failure;
	ASSERT (C_PULSE_PERIOD>0) REPORT "Value of C_PULSE_PERIOD must be greater than 0!" SEVERITY failure;
	ASSERT (C_PULSE_PERIOD>C_PULSE_WIDTH) REPORT "Value of C_PULSE_PERIOD must be greater than the value of C_PULSE_WIDTH!" SEVERITY failure;

	process(clk_i)
	begin
		if rising_edge(clk_i) then
			if en_i='1' then
				if counter < C_PULSE_PERIOD-1 then
					counter <= counter+1;
				else
					counter <= 0;
				end if;

				if counter < C_PULSE_WIDTH then
					strb_o <= '1';
				else
					strb_o <= '0';
				end if;
			else
				counter <= 0;
			end if;
		end if;
	end process;

end Behavioral;