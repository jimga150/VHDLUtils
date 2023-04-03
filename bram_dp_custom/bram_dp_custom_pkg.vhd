----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/02/2023 10:30:11 PM
-- Design Name: 
-- Module Name: bram_dp_custom_pkg
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

package bram_dp_custom_pkg is

    constant c_primitive_data_width : integer := 36;
    constant c_primitive_addr_width : integer := 10;
    constant c_primitive_word_depth : integer := 2**c_primitive_addr_width;
    constant c_primitive_delay : integer := 1;
    
    type t_bram_primitive is array(c_primitive_word_depth-1 downto 0) of std_logic_vector(c_primitive_data_width-1 downto 0);
    type t_prim_init_2d_arr is array(natural range<>, natural range<>) of t_bram_primitive;
    
    --use this to initialize bram_dp_custom - row, then col (y, then x)
    type t_custom_ram is array(natural range<>) of std_logic_vector;

end bram_dp_custom_pkg;

package body bram_dp_custom_pkg is

end bram_dp_custom_pkg;
