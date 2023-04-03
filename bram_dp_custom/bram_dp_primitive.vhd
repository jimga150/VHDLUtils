----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:
-- Design Name: 
-- Module Name: bram_dp_primitive - Behavioral
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
use IEEE.NUMERIC_STD.ALL;




-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

use work.bram_dp_custom_pkg.all;

entity bram_dp_primitive is
    generic(
        g_init_data : t_bram_primitive := (others => (others => '0'))
    );
    PORT (
        i_clka : IN STD_LOGIC;
        i_ena : IN STD_LOGIC;
        i_wea : IN STD_LOGIC;
        i_addra : IN STD_LOGIC_VECTOR(c_primitive_addr_width-1 DOWNTO 0);
        i_dina : IN STD_LOGIC_VECTOR(c_primitive_data_width-1 DOWNTO 0);
        o_douta : OUT STD_LOGIC_VECTOR(c_primitive_data_width-1 DOWNTO 0);
        
        i_clkb : IN STD_LOGIC;
        i_enb : IN STD_LOGIC;
        i_web : IN STD_LOGIC;
        i_addrb : IN STD_LOGIC_VECTOR(c_primitive_addr_width-1 DOWNTO 0);
        i_dinb : IN STD_LOGIC_VECTOR(c_primitive_data_width-1 DOWNTO 0);
        o_doutb : OUT STD_LOGIC_VECTOR(c_primitive_data_width-1 DOWNTO 0)
      );
end bram_dp_primitive;

architecture Inferred of bram_dp_primitive is

    --you'll want to add this to your XDC (Vivado):
    --create_waiver -type METHODOLOGY -id {SYNTH-6} -user "<user>" -desc "The implied BRAM doesn't have a merged register on the output but we use one later in the output logic."
    shared variable sv_ram : t_bram_primitive := g_init_data;
    
begin

    process(i_clka)
    begin
        if rising_edge(i_clka) then
            if i_ena = '1' then
                o_douta <= sv_ram(to_integer(unsigned(i_addra)));
                if i_wea = '1' then
                    sv_ram(to_integer(unsigned(i_addra))) := i_dina;
                end if;
            end if;
        end if;
    end process;
    
    process(i_clkb)
    begin
        if rising_edge(i_clkb) then
            if i_enb = '1' then
                o_doutb <= sv_ram(to_integer(unsigned(i_addrb)));
                if i_web = '1' then
                    sv_ram(to_integer(unsigned(i_addrb))) := i_dinb;
                end if;
            end if;
        end if;
    end process;
   
end Inferred;
