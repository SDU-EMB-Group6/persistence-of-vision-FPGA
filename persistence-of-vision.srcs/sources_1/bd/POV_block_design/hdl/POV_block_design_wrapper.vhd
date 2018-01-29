--Copyright 1986-2017 Xilinx, Inc. All Rights Reserved.
----------------------------------------------------------------------------------
--Tool Version: Vivado v.2017.2 (lin64) Build 1909853 Thu Jun 15 18:39:10 MDT 2017
--Date        : Mon Jan 29 15:36:09 2018
--Host        : javi-SAT-L850-Ubuntu running 64-bit Ubuntu 16.04.3 LTS
--Command     : generate_target POV_block_design_wrapper.bd
--Design      : POV_block_design_wrapper
--Purpose     : IP block netlist
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity POV_block_design_wrapper is
  port (
    DDR_addr : inout STD_LOGIC_VECTOR ( 14 downto 0 );
    DDR_ba : inout STD_LOGIC_VECTOR ( 2 downto 0 );
    DDR_cas_n : inout STD_LOGIC;
    DDR_ck_n : inout STD_LOGIC;
    DDR_ck_p : inout STD_LOGIC;
    DDR_cke : inout STD_LOGIC;
    DDR_cs_n : inout STD_LOGIC;
    DDR_dm : inout STD_LOGIC_VECTOR ( 1 downto 0 );
    DDR_dq : inout STD_LOGIC_VECTOR ( 15 downto 0 );
    DDR_dqs_n : inout STD_LOGIC_VECTOR ( 1 downto 0 );
    DDR_dqs_p : inout STD_LOGIC_VECTOR ( 1 downto 0 );
    DDR_odt : inout STD_LOGIC;
    DDR_ras_n : inout STD_LOGIC;
    DDR_reset_n : inout STD_LOGIC;
    DDR_we_n : inout STD_LOGIC;
    FIXED_IO_ddr_vrn : inout STD_LOGIC;
    FIXED_IO_ddr_vrp : inout STD_LOGIC;
    FIXED_IO_mio : inout STD_LOGIC_VECTOR ( 31 downto 0 );
    FIXED_IO_ps_clk : inout STD_LOGIC;
    FIXED_IO_ps_porb : inout STD_LOGIC;
    FIXED_IO_ps_srstb : inout STD_LOGIC;
    clk_bit : out STD_LOGIC;
    data_out : out STD_LOGIC;
    in_halfbridge_out : out STD_LOGIC_VECTOR ( 2 downto 0 );
    inhibit_out : out STD_LOGIC_VECTOR ( 2 downto 0 );
    led_o : out STD_LOGIC_VECTOR ( 7 downto 0 );
    rx_i : in STD_LOGIC;
    sensors_in : in STD_LOGIC_VECTOR ( 2 downto 0 );
    start : in STD_LOGIC;
    stop : in STD_LOGIC;
    tx_o : out STD_LOGIC
  );
end POV_block_design_wrapper;

architecture STRUCTURE of POV_block_design_wrapper is
  component POV_block_design is
  port (
    DDR_cas_n : inout STD_LOGIC;
    DDR_cke : inout STD_LOGIC;
    DDR_ck_n : inout STD_LOGIC;
    DDR_ck_p : inout STD_LOGIC;
    DDR_cs_n : inout STD_LOGIC;
    DDR_reset_n : inout STD_LOGIC;
    DDR_odt : inout STD_LOGIC;
    DDR_ras_n : inout STD_LOGIC;
    DDR_we_n : inout STD_LOGIC;
    DDR_ba : inout STD_LOGIC_VECTOR ( 2 downto 0 );
    DDR_addr : inout STD_LOGIC_VECTOR ( 14 downto 0 );
    DDR_dm : inout STD_LOGIC_VECTOR ( 1 downto 0 );
    DDR_dq : inout STD_LOGIC_VECTOR ( 15 downto 0 );
    DDR_dqs_n : inout STD_LOGIC_VECTOR ( 1 downto 0 );
    DDR_dqs_p : inout STD_LOGIC_VECTOR ( 1 downto 0 );
    FIXED_IO_mio : inout STD_LOGIC_VECTOR ( 31 downto 0 );
    FIXED_IO_ddr_vrn : inout STD_LOGIC;
    FIXED_IO_ddr_vrp : inout STD_LOGIC;
    FIXED_IO_ps_srstb : inout STD_LOGIC;
    FIXED_IO_ps_clk : inout STD_LOGIC;
    FIXED_IO_ps_porb : inout STD_LOGIC;
    sensors_in : in STD_LOGIC_VECTOR ( 2 downto 0 );
    in_halfbridge_out : out STD_LOGIC_VECTOR ( 2 downto 0 );
    inhibit_out : out STD_LOGIC_VECTOR ( 2 downto 0 );
    rx_i : in STD_LOGIC;
    tx_o : out STD_LOGIC;
    data_out : out STD_LOGIC;
    clk_bit : out STD_LOGIC;
    led_o : out STD_LOGIC_VECTOR ( 7 downto 0 );
    stop : in STD_LOGIC;
    start : in STD_LOGIC
  );
  end component POV_block_design;
begin
POV_block_design_i: component POV_block_design
     port map (
      DDR_addr(14 downto 0) => DDR_addr(14 downto 0),
      DDR_ba(2 downto 0) => DDR_ba(2 downto 0),
      DDR_cas_n => DDR_cas_n,
      DDR_ck_n => DDR_ck_n,
      DDR_ck_p => DDR_ck_p,
      DDR_cke => DDR_cke,
      DDR_cs_n => DDR_cs_n,
      DDR_dm(1 downto 0) => DDR_dm(1 downto 0),
      DDR_dq(15 downto 0) => DDR_dq(15 downto 0),
      DDR_dqs_n(1 downto 0) => DDR_dqs_n(1 downto 0),
      DDR_dqs_p(1 downto 0) => DDR_dqs_p(1 downto 0),
      DDR_odt => DDR_odt,
      DDR_ras_n => DDR_ras_n,
      DDR_reset_n => DDR_reset_n,
      DDR_we_n => DDR_we_n,
      FIXED_IO_ddr_vrn => FIXED_IO_ddr_vrn,
      FIXED_IO_ddr_vrp => FIXED_IO_ddr_vrp,
      FIXED_IO_mio(31 downto 0) => FIXED_IO_mio(31 downto 0),
      FIXED_IO_ps_clk => FIXED_IO_ps_clk,
      FIXED_IO_ps_porb => FIXED_IO_ps_porb,
      FIXED_IO_ps_srstb => FIXED_IO_ps_srstb,
      clk_bit => clk_bit,
      data_out => data_out,
      in_halfbridge_out(2 downto 0) => in_halfbridge_out(2 downto 0),
      inhibit_out(2 downto 0) => inhibit_out(2 downto 0),
      led_o(7 downto 0) => led_o(7 downto 0),
      rx_i => rx_i,
      sensors_in(2 downto 0) => sensors_in(2 downto 0),
      start => start,
      stop => stop,
      tx_o => tx_o
    );
end STRUCTURE;
