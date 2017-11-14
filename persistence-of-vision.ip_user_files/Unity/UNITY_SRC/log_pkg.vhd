library ieee;
use ieee.std_logic_1164.all;

package log_pkg is
	function log2c (n: integer) return integer;
	function log2r (n: integer) return integer;
end log_pkg;

package body log_pkg is
   
	
	function log2c(n: integer) return integer is
		variable m, p: integer := 0;
	begin
		m := 0;
		p := 1;
		while p < n loop
			m := m + 1;
			p := p * 2;
		end loop;
		return m;
	end log2c;
	
	
	function log2r(n: integer) return integer is
      variable m, p: integer := 0;
	begin
		m := 0;
		p := 1;
		while p < n loop
			m := m + 1;
			p := p * 2;
		end loop;
		if m = 0 then
			return 1;
		else
			return m;
		end if;
	end log2r;
	
end log_pkg;