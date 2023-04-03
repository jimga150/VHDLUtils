--------------------------------------------------------------------------------
--
--   FileName:         vga_controller.vhd
--   Dependencies:     none
--   Design Software:  Quartus II 64-bit Version 12.1 Build 177 SJ Full Version
--
--   HDL CODE IS PROVIDED "AS IS."  DIGI-KEY EXPRESSLY DISCLAIMS ANY
--   WARRANTY OF ANY KIND, WHETHER EXPRESS OR IMPLIED, INCLUDING BUT NOT
--   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
--   PARTICULAR PURPOSE, OR NON-INFRINGEMENT. IN NO EVENT SHALL DIGI-KEY
--   BE LIABLE FOR ANY INCIDENTAL, SPECIAL, INDIRECT OR CONSEQUENTIAL
--   DAMAGES, LOST PROFITS OR LOST DATA, HARM TO YOUR EQUIPMENT, COST OF
--   PROCUREMENT OF SUBSTITUTE GOODS, TECHNOLOGY OR SERVICES, ANY CLAIMS
--   BY THIRD PARTIES (INCLUDING BUT NOT LIMITED TO ANY DEFENSE THEREOF),
--   ANY CLAIMS FOR INDEMNITY OR CONTRIBUTION, OR OTHER SIMILAR COSTS.
--
--   Version History
--   Version 1.0 05/10/2013 Scott Larson
--     Initial Public Release
--   Version 1.1 03/07/2018 Scott Larson
--     Corrected two minor "off-by-one" errors
--    
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity vga_controller is
    generic(
        g_h_pixels  :   integer := 1680;    --horizontal display width in pixels
        g_h_fp      :   integer := 104;     --horizontal front porch width in pixels
        g_h_pulse   :   integer := 184;     --horizontal sync pulse width in pixels
        g_h_bp      :   integer := 288;     --horizontal back porch width in pixels
        g_h_pol     :   std_logic := '0';   --horizontal sync pulse polarity (1 = positive, 0 = negative)
        g_v_pixels  :   integer := 1050;    --vertical display width in rows
        g_v_fp      :   integer := 1;       --vertical front porch width in rows
        g_v_pulse   :   integer := 3;       --vertical sync pulse width in rows
        g_v_bp      :   integer := 33;      --vertical back porch width in rows
        g_v_pol     :   std_logic := '1'    --vertical sync pulse polarity (1 = positive, 0 = negative)
    );	
    port(
        i_clk       :   in  std_logic;  --pixel clock at frequency of VGA mode being used
        i_rst_n     :   in  std_logic;  --active low synchronous reset
        o_h_sync    :   out std_logic;  --horizontal sync pulse
        o_v_sync    :   out std_logic;  --vertical sync pulse
        o_disp_ena  :   out std_logic;  --display enable ('1' = display time, '0' = blanking time)
        o_column    :   out integer range 0 to g_h_pixels - 1;  --horizontal pixel coordinate
        o_row       :   out integer range 0 to g_v_pixels - 1   --vertical pixel coordinate
    ); 
end vga_controller;

architecture behavior of vga_controller is

    constant c_h_period	: integer := g_h_pulse + g_h_bp + g_h_pixels + g_h_fp;  --total number of pixel clocks in a row
    constant c_v_period	: integer := g_v_pulse + g_v_bp + g_v_pixels + g_v_fp;  --total number of rows in column
    
    signal s_h_count : integer range 0 to c_h_period - 1 := 0;  --horizontal counter (counts the columns)
    signal s_v_count : integer range 0 to c_v_period - 1 := 0;  --vertical counter (counts the rows)
    
    --high on the cycle where s_h_count = c_h_period - 1
    signal s_h_count_is_max : std_logic := '0';
    signal s_v_count_is_max : std_logic := '0';
    
    signal s_h_sync : std_logic := '0';
    signal s_v_sync : std_logic := '0';
    
    signal s_h_active : std_logic := '0';
    signal s_v_active : std_logic := '0';
    
    signal s1_h_sync : std_logic := '0';
    signal s1_v_sync : std_logic := '0';
    
    signal s1_col : integer range 0 to g_h_pixels - 1 := 0;
    signal s1_row : integer range 0 to g_v_pixels - 1 := 0;
    
    signal s1_disp_en : std_logic := '0';
    
begin

    o_h_sync <= s1_h_sync;
    o_v_sync <= s1_v_sync;
    
    o_disp_ena <= s1_disp_en;
    
    o_column <= s1_col;
    o_row <= s1_row;
    
    process(i_clk) is begin
        if (rising_edge(i_clk)) then
            
            s_h_count <= s_h_count + 1;
            
            s_h_count_is_max <= '0';
            if (s_h_count = c_h_period - 2) then
                s_h_count_is_max <= '1';
            end if;
            
            if (s_h_count_is_max = '1') then
            
                s_h_count <= 0;
                
                s_v_count <= s_v_count + 1;
                
                s_v_count_is_max <= '0';
                if (s_v_count = c_v_period - 2) then
                    s_v_count_is_max <= '1';
                end if;
                
                if (s_v_count_is_max = '1') then
                    s_v_count <= 0;
                end if;
            end if;
                   
            
            if (s_h_count = g_h_pixels - 1) then
                s_h_active <= '0';
            end if;
            
            if (s_h_count = g_h_pixels + g_h_fp - 1) then
                s_h_sync <= g_h_pol;
            end if;
            
            if (s_h_count = g_h_pixels + g_h_fp + g_h_pulse - 1) then
                s_h_sync <= not g_h_pol;
            end if;
            
            if (s_h_count_is_max = '1') then
            
                s_h_active <= '1';
                
                if (s_v_count = g_v_pixels - 1) then
                    s_v_active <= '0';
                end if;
                
                if (s_v_count = g_v_pixels + g_v_fp - 1) then
                    s_v_sync <= g_v_pol;
                end if;
                
                if (s_v_count = g_v_pixels + g_v_fp + g_v_pulse - 1) then
                    s_v_sync <= not g_v_pol;
                end if;
                
                if (s_v_count_is_max = '1') then
                    s_v_active <= '1';
                end if;
                
            end if;
            
            
            s1_h_sync <= s_h_sync;
            s1_v_sync <= s_v_sync;
            
            if (s_h_active = '1') then
                s1_col <= s_h_count;
            end if;
            
            if (s_v_active = '1') then
                s1_row <= s_v_count;
            end if;
            
            s1_disp_en <= s_v_active and s_h_active;
            
            
            if(i_rst_n = '0') then
            
                s_h_count <= 0;
                s_v_count <= 0;
                
                s_h_count_is_max <= '0';
                s_v_count_is_max <= '0';
                
                s_h_sync <= not g_h_pol;
                s_v_sync <= not g_v_pol;
                s_h_active <= '0';
                s_v_active <= '0';
                
                s1_h_sync <= not g_h_pol;
                s1_v_sync <= not g_v_pol;
                s1_col <= 0;
                s1_row <= 0;
                s1_disp_en <= '0';
                
            end if;
            
        end if;
    end process;
    
end behavior;
