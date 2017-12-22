library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;
use IEEE.NUMERIC_STD.ALL;
entity bldc_starter is
generic( t_sequence         : integer := 20000000 -- 100 ms (clk signal 5ns)  
     );
    Port ( 
           clk_200M_in          : in std_logic;
           push_bt1             : in std_logic;
           push_bt2             : in std_logic;
           pwm                  : in std_logic;
           flag                 : out std_logic;
           inhibit_in1          : out std_logic_vector (2 downto 0);
           in_halfbridge_in1    : out std_logic_vector (2 downto 0);
           sensors_in           : in std_logic_vector (2 downto 0)
         );
end bldc_starter;

architecture Behavioral of bldc_starter is
signal inh_out      : std_logic_vector (2 downto 0);
signal inhb_out     : std_logic_vector (2 downto 0);
signal timer_reg    : unsigned(23 downto 0) := (others => '0');
signal timer_trig   : integer := 0;
signal reset_in     : std_logic := '0';

begin
inhibit_in1 <= inh_out;
in_halfbridge_in1 <= inhb_out;
-- BLDC Motor starter. Generate pwm signal and commute slowly for the three
process(clk_200M_in,pwm)
begin
    if(reset_in = '1' or push_bt2 = '1') then 
        timer_reg <= (others => '0');
        
    elsif (rising_edge(clk_200M_in)) then
        if (push_bt1 = '1') then
            timer_reg <= timer_reg +1;  --5ns each clk
            timer_trig <= timer_trig +1;  --5ns each clk
        end if;
    
        if (timer_reg < 1000000000) then --5 s loop
            flag <= '0';
            if (timer_trig < t_sequence) then
                if (timer_trig < (t_sequence/6)) then --
                    inh_out <= "110"; -- HALF-BRIDGE phase C floating
                    -- INPUT HALF-BRIDGE
                    inhb_out(2) <= pwm;
                    inhb_out(1) <= '0';
                    inhb_out(0) <= '0';
                
                elsif (timer_trig < (t_sequence/5) and timer_trig > (t_sequence/6)) then 
                    inh_out <= "101"; -- HALF-BRIDGE phase B floating
                    -- INPUT HALF-BRIDGE
                    inhb_out(2) <= pwm;
                    inhb_out(1) <= '0';
                    inhb_out(0) <= '0';
                    
                elsif (timer_trig < (t_sequence/4) and timer_trig > (t_sequence/5) ) then 
                    inh_out <= "011"; -- HALF-BRIDGE phase A floating
                    inhb_out(2) <= '0';
                    inhb_out(1) <= pwm;
                    inhb_out(0) <= '0';
                
                elsif (timer_trig < (t_sequence/3) and timer_trig > (t_sequence/4)) then 
                    inh_out <= "110"; -- HALF-BRIDGE phase C floating
                    inhb_out(2) <= '0';
                    inhb_out(1) <= pwm;
                    inhb_out(0) <= '0';
                
                elsif (timer_trig < (t_sequence/2) and timer_trig > (t_sequence/3)) then 
                    inh_out <= "101" ;-- HALF-BRIDGE phase B floating
                    inhb_out(2) <= '0';
                    inhb_out(1) <= '0';
                    inhb_out(0) <= pwm;
                
                elsif (timer_trig < t_sequence and timer_trig > (t_sequence/2)) then 
                    inh_out <= "011"; -- HALF-BRIDGE phase A floating
                    inhb_out(2) <= '0';
                    inhb_out(1) <= '0';
                    inhb_out(0) <= pwm;
                else
                
                end if;
           else
                timer_trig <= 0;    
           end if;
        else
            flag <= '1';      
        end if;
    end if;
  

end process;
end Behavioral;