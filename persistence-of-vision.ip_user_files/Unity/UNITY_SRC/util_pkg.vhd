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

package util_pkg is
	function byte_cnt(n: integer) return integer;
	function max(a: integer; b: integer) return integer;
	function min(a: integer; b: integer) return integer;
end util_pkg;

package body util_pkg is

	function byte_cnt(n: integer) return integer is
		variable b, v: integer := 0;
	begin
		b := 1;
		v := 8;
		while v < n loop
			b := b + 1;
			v := 8 * b;
		end loop;
		return b;
	end byte_cnt;
	
	function max(a: integer; b: integer) return integer is
 		variable c : integer := 0;
	begin
		if a>=b then
			c := a;
		else
			c := b;
		end if;
		return c;
	end max;
	
	function min(a: integer; b: integer) return integer is
 		variable c : integer := 0;
	begin
		if a<=b then
			c := a;
		else
			c := b;
		end if;
		return c;
	end min;	
	
end util_pkg;
