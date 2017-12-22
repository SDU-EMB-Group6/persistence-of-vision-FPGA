library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity PWM_generator is
    generic( 
        CLK_FREQ      : integer := 200000000;   -- 200 MHz clock
        PWM_FREQ      : integer := 21000        -- 21 KHz pwm freq
    );
    Port( 
        clk_200mhz_in : in std_logic;
        pwm_duty_in   : std_logic_vector (7 downto 0) := x"80";
        pwm_out       : out std_logic := '0';
        stop          : in std_logic;
        start         : in std_logic
        );
end PWM_generator;

architecture Behavioral of PWM_generator is
    constant period : integer := CLK_FREQ / (PWM_FREQ*512);
    
    signal count            : integer := 0;
    signal count_direction  : std_logic := '0';
    signal scaled_CLK       : std_logic := '0';
    signal scaler_counter   : integer := 0;
    signal running          : std_logic := '0';
begin

-- Prescaler
clck_scaler: process(clk_200mhz_in)
begin
    if(rising_edge(clk_200mhz_in)) then
        scaler_counter <= scaler_counter + 1;
        if(scaler_counter = period) then
        -- reset counter and set scaler to low
            scaler_counter <= 0;
            scaled_CLK <= '0';
        elsif(scaler_counter = period/2) then
            scaled_CLK <= '1';
        end if;
    end if;
end process;

-- pwm counter process (counts up to 255 and down to 0 continuously). One step
-- is taken when the prescaled clock from above reached the selected downscaled
-- value.
counter: process(scaled_CLK)
begin
    if(rising_edge(scaled_CLK)) then
        if(count = 0) then
            count_direction <= '0';
            count <= count + 1;
        elsif(count = 255) then
            count_direction <= '1';
            count <= count - 1;
        elsif  (count_direction = '0') then
            count <= count + 1;
        elsif(count_direction = '1') then
            count <= count - 1;
        end if;
    end if;
end process;

-- duty cycle and counter compare. When the count from above reaches the
-- selected duty cycle is set the pwm signal low - otherwise it is high.
duty_compare: process(clk_200mhz_in)
begin
    if(running = '1') then
        if(count >= to_integer(unsigned(pwm_duty_in))) then
            pwm_out <= '0';
         else
            pwm_out <= '1';
         end if;
    else
        pwm_out <= '0';
    end if;
end process;

startstop: process(start,stop)
begin
    if(rising_edge(stop)) then
        running <= '0';
    end if;
    if(rising_edge(start) and stop = '0') then
        running <= '1';
    end if;
end process;
end Behavioral;

