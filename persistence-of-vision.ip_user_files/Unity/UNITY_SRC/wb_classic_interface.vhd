--
--	Package File Template
--
--	Purpose: This package defines supplemental types, subtypes, 
--		 constants, and functions 
--
--   To use any of the example code shown below, uncomment the lines and modify as necessary
--

library ieee;
use ieee.std_logic_1164.all;

package wb_classic_interface is

	--------------------------------------
	-- typical usage |  core  | intercon |
	--   wb master	  | output |  input	 |
	--   wb slave 	  | input  |  output	 |
	--------------------------------------	
	type wb_ad32s_if is record
		cyc : std_logic;
		stb : std_logic;		
		adr : std_logic_vector(31 downto 0);
		dat : std_logic_vector(31 downto 0);
		we  : std_logic;
		sgl : std_logic;
	end record;

	--------------------------------------
	-- typical usage |  core  | intercon |
	--   wb master	  | output |  input	 |
	--   wb slave 	  | input  |  output	 |
	--------------------------------------	
	type wb_ad32sb_if is record
		cyc : std_logic;
		stb : std_logic;		
		adr : std_logic_vector(31 downto 0);
		dat : std_logic_vector(31 downto 0);
		we  : std_logic;
		sgl : std_logic;
		blk : std_logic;
	end record;

	--------------------------------------
	-- typical usage |  core  | intercon |
	--   wb master	  | output |  input	 |
	--   wb slave 	  | input  |  output	 |
	--------------------------------------	
	type wb_ad32sbr_if is record
		cyc : std_logic;
		stb : std_logic;		
		adr : std_logic_vector(31 downto 0);
		dat : std_logic_vector(31 downto 0);
		we  : std_logic;
		sgl : std_logic;
		blk : std_logic;
		rmw : std_logic;
	end record;
		
	--------------------------------------
	-- typical usage |  core  | intercon |
	--   wb master	  | output |  input	 |
	--   wb slave 	  | input  |  output	 |
	--------------------------------------		
	type wb_ad32q8sbr_if is record
		cyc : std_logic;
		stb : std_logic;		
		adr : std_logic_vector(31 downto 0);
		dat : std_logic_vector(31 downto 0);
		we  : std_logic;
		sel : std_logic_vector(3 downto 0);
		sgl : std_logic;
		blk : std_logic;
		rmw : std_logic;
	end record;

	
	--------------------------------------
	-- typical usage |  core  | intercon |
	--   wb master	  | input  |  output	 |
	--   wb slave 	  | output |  input	 |
	--------------------------------------
	type wb_d32a_if is record
		dat : std_logic_vector(31 downto 0);
		ack : std_logic;
	end record;	
	
	--------------------------------------
	-- typical usage |  core  | intercon |
	--   wb master	  | input  |  output	 |
	--   wb slave 	  | output |  input	 |
	--------------------------------------	
	type wb_d32ae_if is record
		dat : std_logic_vector(31 downto 0);
		ack : std_logic;
		err : std_logic;
	end record;	
	
	--------------------------------------
	-- typical usage |  core  | intercon |
	--   wb master	  | input  |  output	 |
	--   wb slave 	  | output |  input	 |
	--------------------------------------	
	type wb_d32aer_if is record
		dat : std_logic_vector(31 downto 0);
		ack : std_logic;
		err : std_logic;
		rty : std_logic;
	end record;
	

end wb_classic_interface;

package body wb_classic_interface is 
end wb_classic_interface;
