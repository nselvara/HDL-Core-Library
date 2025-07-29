--! 
--! @author:    N. Selvarajah
--! @brief:     Memories Package
--! @details:   This package contains all the constants used in the NiPU project.
--! 
--! @license    This project is released under the terms of the MIT License. See LICENSE for more details.
--! 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package memories_pkg is
    type rom_t is array (natural range <>) of std_ulogic_vector;
end package;

package body memories_pkg is

end package body;
