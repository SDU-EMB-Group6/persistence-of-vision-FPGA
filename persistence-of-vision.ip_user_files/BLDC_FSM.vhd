
--------------------------------------------------------------------------------
-- Create Date: 09/25/2017 03:05:24 PM
-- Design Name: BLDC Finite State Machine
-- Module Name: bldc_decoder - Behavioral
-- Target Devices: Zynqberry
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- pwm: INPUT PWM SIGNAL FOR HALF-BRIDGE DRIVING
-- inhibit_out: INHIBIT PIN of the Half bridges
-- in_halfbridge_out: INPUT PIN half bridges
-- sensors_in:  ENCODER POSITION
entity bldc_decoder is
    Port ( 
           pwm                  : in std_logic;
           inhibit_out          : out std_logic_vector (2 downto 0);
           in_halfbridge_out    : out std_logic_vector (2 downto 0);
           sensors_in           : in std_logic_vector (2 downto 0)
         );
end bldc_decoder;


architecture Behavioral of bldc_decoder is
signal inh_out      : std_logic_vector (2 downto 0);
signal inhb_out     :  std_logic_vector (2 downto 0);
signal counter_rev  : std_logic_vector (31 downto 0) := (others=>'0') ;

begin

inhibit_out <= inh_out;
in_halfbridge_out <= inhb_out;
-- Update of Finite State Machine (FSM) state transitions.
process(sensors_in, pwm)

begin
    if (sensors_in = "101") then
        -- INHIBIT HALF-BRIDGE
        inh_out <= "110"; -- HALF-BRIDGE phase C floating
        -- INPUT HALF-BRIDGE
        inhb_out(2) <= pwm;
        inhb_out(1) <= '0';
        inhb_out(0) <= '0';
        counter_rev <= std_logic_vector(unsigned(counter_rev)+1);
        
    elsif (sensors_in = "100") then
        -- INHIBIT HALF-BRIDGE
        inh_out <= "101"; -- HALF-BRIDGE phase B floating
        -- INPUT HALF-BRIDGE
        inhb_out(2) <= pwm;
        inhb_out(1) <= '0';
        inhb_out(0) <= '0';
        counter_rev <= std_logic_vector(unsigned(counter_rev)+1);

    elsif (sensors_in = "110") then
        inh_out <= "011"; -- HALF-BRIDGE phase A floating
        inhb_out(2) <= '0';
        inhb_out(1) <= pwm;
        inhb_out(0) <= '0';
        counter_rev <= std_logic_vector(unsigned(counter_rev)+1);
        
    elsif (sensors_in = "010") then
        inh_out <= "110"; -- HALF-BRIDGE phase C floating
        inhb_out(2) <= '0';
        inhb_out(1) <= pwm;
        inhb_out(0) <= '0';
        counter_rev <= std_logic_vector(unsigned(counter_rev)+1);
        
    elsif (sensors_in = "011") then
        inh_out <= "101" ;-- HALF-BRIDGE phase B floating
        inhb_out(2) <= '0';
        inhb_out(1) <= '0';
        inhb_out(0) <= pwm;
        counter_rev <= std_logic_vector(unsigned(counter_rev)+1);
        
    elsif (sensors_in = "001") then
        inh_out <= "011"; -- HALF-BRIDGE phase A floating
        inhb_out(2) <= '0';
        inhb_out(1) <= '0';
        inhb_out(0) <= pwm;
        counter_rev <= std_logic_vector(unsigned(counter_rev)+1);
        
    else
        inh_out <="000";
        inhb_out<="000";
        
    end if;
end process;

end Behavioral;
