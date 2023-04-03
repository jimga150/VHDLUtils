----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08/16/2022 10:09:37 AM
-- Design Name: 
-- Module Name: button_conditioner - Behavioral
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

entity button_conditioner is
    generic(
        g_metastability_stages : integer := 3;
        g_stable_cycles : integer := 100_000
    );
    port (
        i_clk, i_rst, i_btn : in std_logic := '0';
        o_stablized, o_debounced, o_pos_pulse, o_neg_pulse : out std_logic
    );
end button_conditioner;

architecture Behavioral of button_conditioner is
    
    attribute ASYNC_REG : boolean;
        
    signal s_meta_pline : std_logic_vector(g_metastability_stages downto 1);
    attribute ASYNC_REG of s_meta_pline : signal is TRUE;

    signal s1_btn, s2_btn : std_logic;
    signal s_stable_count : integer range 0 to g_stable_cycles := 0;
    signal s1_debounced_btn, s2_debounced_btn : std_logic := '0';
    
begin

    process(i_clk) is begin
        if rising_edge(i_clk) then
        
            s_meta_pline <= s_meta_pline(s_meta_pline'high-1 downto s_meta_pline'low) & i_btn;
            
            s1_btn <= s_meta_pline(s_meta_pline'high);
            s2_btn <= s1_btn;
            
            if (s1_btn = s2_btn) then
                if (s_stable_count /= g_stable_cycles) then
                    s_stable_count <= s_stable_count + 1;
                end if;
            else
                s_stable_count <= 0;
            end if;
            
            if (s_stable_count = g_stable_cycles) then
                s1_debounced_btn <= s2_btn;
            end if;
            
            s2_debounced_btn <= s1_debounced_btn;
            
            o_pos_pulse <= '0';
            if (s1_debounced_btn = '1' and s2_debounced_btn = '0') then
                o_pos_pulse <= '1';
            end if;
            
            o_neg_pulse <= '0';
            if (s1_debounced_btn = '0' and s2_debounced_btn = '1') then
                o_neg_pulse <= '1';
            end if;
            
            if (i_rst = '1') then
                s_meta_pline <= (others => '0');
                s1_btn <= '0';
                s2_btn <= '0';
                s_stable_count <= 0;
                s1_debounced_btn <= '0';
                s1_debounced_btn <= '0';
                o_pos_pulse <= '0';
                o_neg_pulse <= '0';
            end if;
            
        end if;
    end process;
    
    o_stablized <= s_meta_pline(s_meta_pline'high);
    o_debounced <= s1_debounced_btn;

end Behavioral;
