
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity leds_controller is
    generic (
        frame_len   : integer := 32
        );
    port (
        clk_i       : in std_logic;
        bit_clk     : in std_logic;
        write_mem   : in std_logic;
        Umem_addr   : in std_logic_vector(5 downto 0);
        data_in : in std_logic_vector(frame_len-1 downto 0);

        data_out    : out std_logic;
        clk_out     : out std_logic
           );
end leds_controller;

architecture Behavioral of leds_controller is


    signal shift_counter    : integer := 0;
    signal pixel_data       : std_logic_vector(frame_len-1 downto 0);
    clk_out <= (others => '1');
----------------------------------------------------------------------
-- This process handles data from memory
----------------------------------------------------------------------
    process (clk_i, Umem_addr, write_mem)   
    begin
    --delay_phase_shift_out <= delay_phase_shift;
    if(rising_edge(clk_i)) then
    --    if(write_mem = '0') then
        if(write_mem = '1') then
            case Umem_addr is
              when "000110" => pixel_data <= data_in(frame_len-1 downto 0);
              when others =>
            end case;
        end if;
    end if;
    end process;

-- Evolution of the shift register counter
    process (bit_clk)
    if (rising_edge(clk_i)) then
        if (shift_counter >= frame_len-1) then
            shift_counter := shift_counter + 1;
        else
            shift_counter := 0;
        end if;
    end if;
    end process;

-- Serialization of the input data.
    process (bit_clk)
    if (rising_edge(bit_clk)) then
        data_out <= data_in(shift_counter);
    end if;
    end process;

end Behavioral;
