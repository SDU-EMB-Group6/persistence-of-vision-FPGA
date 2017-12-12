
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity TB_leds_controller is
end TB_leds_controller;

architecture Behavioral of TB_leds_controller is

component leds_controller is
    generic (
        FRAME_LEN   : integer := 32;
        PIXEL_LEN   : integer := 10
    );
    Port (
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
end component;
    
    signal clk      : std_logic := '0';
    signal bit_clk  : std_logic;
    signal wr       : std_logic := '1';
    signal address  : std_logic_vector(5 downto 0);
    signal data_in  : std_logic_vector(31 downto 0);
    signal frame_o  : std_logic_vector(31 downto 0); 
    signal data_out : std_logic;
    signal pix_count: std_logic_vector(7 downto 0);
    signal reg_count: std_logic_vector(7 downto 0);

    --  Clock period definitions
    constant clk_period : time := 1 us;
 
begin

mapping: leds_controller PORT MAP (
        clk_i       => clk,
        write_mem   => wr,
        Umem_addr   => address,
        data_in     => data_in,
        frame_o     => frame_o,
        data_out    => data_out,
        clk_out     => bit_clk,
        pix_count_o => pix_count,
        reg_count_o => reg_count
    );


    ----------------------------------------------------------------------------
    -- Clock process definition (clock with 50% duty cycle)
    ----------------------------------------------------------------------------
    process
    begin
        clk <= not(clk);
        wait for clk_period/2;
    end process;


    ----------------------------------------------------------------------------
    -- Address update process
    ----------------------------------------------------------------------------
    process
        variable i :integer range 0 to 63;
    begin
        wait for 20 ns;
        if (i = 63) then
            i := 0;
            address <= "000110";
        else
            i := i + 1;
            address <= "000000";
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- Pixel value process
    ----------------------------------------------------------------------------
    process
        variable i :integer range 0 to 63;
    begin
        data_in <= x"EAAAAAAA";
        wait for 20 us;
        data_in <= x"E5555555";
        wait for 20 us;
    end process;

end Behavioral;
