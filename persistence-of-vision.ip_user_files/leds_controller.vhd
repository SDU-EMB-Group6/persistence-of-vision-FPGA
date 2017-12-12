
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity leds_controller is
    generic (
        FRAME_LEN   : integer := 32;
        PIXEL_LEN   : integer := 10
        );
    port (
        clk_i       : in std_logic;
        write_mem   : in std_logic;
        Umem_addr   : in std_logic_vector(5 downto 0);
        data_in     : in std_logic_vector(FRAME_LEN-1 downto 0);

        frame_o     : out std_logic_vector(FRAME_LEN-1 downto 0);
        led_o       : out std_logic_vector(7 downto 0);
        data_out    : out std_logic;
        clk_out     : out std_logic;

        pix_count_o : out std_logic_vector(7 downto 0);
        reg_count_o : out std_logic_vector(7 downto 0)
        );
end leds_controller;

architecture Behavioral of leds_controller is


    signal shift_counter    : unsigned(7 downto 0) := (others => '0');
    signal pixel_counter    : unsigned(7 downto 0) := (others => '0');
    signal clk_counter      : unsigned(7 downto 0) := (others => '0');
    signal bit_clk          : std_logic := '0';
    signal send_data        : std_logic_vector(FRAME_LEN-1 downto 0);
    signal pixel_data       : std_logic_vector(FRAME_LEN-1 downto 0);
    signal start_frame      : std_logic_vector(FRAME_LEN-1 downto 0) 
                                    := (others => '0');
    signal end_frame        : std_logic_vector(FRAME_LEN-1 downto 0) 
                                    := (others => '1');

begin
    clk_out <= bit_clk;
    frame_o <= send_data;
    pix_count_o <= std_logic_vector(pixel_counter);
    reg_count_o <= std_logic_vector(shift_counter);

-- 1MHz clock generation
    process (clk_i, clk_counter)
    begin
    --delay_phase_shift_out <= delay_phase_shift;
    if (rising_edge(clk_i)) then
        if (clk_counter = 24) then
            clk_counter <= (others => '0');
            bit_clk <= not(bit_clk);
        else
            clk_counter <= clk_counter + 1;
        end if;
    end if;
    end process;

----------------------------------------------------------------------
-- This process handles data from memory
----------------------------------------------------------------------
    process (clk_i, Umem_addr, write_mem)   
    begin
    --delay_phase_shift_out <= delay_phase_shift;
    if (rising_edge(clk_i)) then
    --    if(write_mem = '0') then
        if(write_mem = '1') then
            case Umem_addr is
              when "000100" => led_o <= data_in(7 downto 0);
              when "000110" => pixel_data <= data_in(FRAME_LEN-1 downto 0);
              when others =>
            end case;
        end if;
    end if;
    end process;

-- Construction of the output data.
    process(bit_clk, send_data)
    begin
    if rising_edge(bit_clk) then
        if (pixel_counter = 0) then
            send_data <= start_frame;
        elsif (pixel_counter = PIXEL_LEN+2-1) then
            send_data <= end_frame;
        else
            send_data <= pixel_data;
        end if;
    end if;
    end process;


-- Evolution of the shift register counter
    process (bit_clk, shift_counter, pixel_counter)
    begin
    if rising_edge(bit_clk) then
        if (shift_counter < FRAME_LEN-1) then
            shift_counter <= shift_counter + 1;
        else
            shift_counter <= (others => '0');
            -- Increase the pixel counter, or set it to 0 when reaches the
            -- Data frame length.
            if (pixel_counter = PIXEL_LEN+2-1) then
                pixel_counter <= (others => '0');
            else
                pixel_counter <= pixel_counter + 1;
            end if;
        end if;
    end if;
    end process;

-- Serialization of the input data.
    process (bit_clk)
    begin
    if rising_edge(bit_clk) then
        data_out <= send_data(to_integer(shift_counter));
    end if;
    end process;

end Behavioral;
