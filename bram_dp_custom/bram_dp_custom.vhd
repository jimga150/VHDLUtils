----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08/23/2022 02:48:45 PM
-- Design Name: 
-- Module Name: bram_dp_custom - Structural
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
use IEEE.MATH_REAL.ALL;

use work.bram_dp_custom_pkg.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity bram_dp_custom is
    generic(
        g_read_delay : integer := 6+3;
        g_data_width : integer := 8;
        g_word_depth : integer := 35*1024; --32k
        g_init_vals : t_custom_ram(g_word_depth-1 downto 0)(g_data_width-1 downto 0) := (others => (others => '0'));
        --------------------------------------------------------------------
        --DO NOT OVERRIDE ANYTHING BELOW THIS LINE IN INSTANTIATION
        --------------------------------------------------------------------
        g_addr_width : integer := integer(ceil(log2(real(g_word_depth))))
    );
    PORT (
        i_clka : in std_logic;
        i_ena : in std_logic;
        i_wea : in std_logic;
        i_addra : in std_logic_vector(g_addr_width-1 downto 0);
        i_dina : in std_logic_vector(g_data_width-1 downto 0);
        o_douta : out std_logic_vector(g_data_width-1 downto 0);
        
        i_clkb : in std_logic;
        i_enb : in std_logic;
        i_web : in std_logic;
        i_addrb : in std_logic_vector(g_addr_width-1 downto 0);
        i_dinb : in std_logic_vector(g_data_width-1 downto 0);
        o_doutb : out std_logic_vector(g_data_width-1 downto 0)
      );
end bram_dp_custom;

architecture Structural of bram_dp_custom is
    
    --how many rows of primitives to instantiate
    --where each row is one major address
    constant c_num_prims_deep : integer := integer(ceil(real(g_word_depth)/real(c_primitive_word_depth)));
    
    --how many primitives to instantiate per row
    --one row of primitives handles one address, and together the primitives handle one data word
    --data words wider than the primitive data word will need to be shared across multiple primitives
    constant c_num_prims_wide : integer := integer(ceil(real(g_data_width)/real(c_primitive_data_width)));

    pure function f_init_prims(i_init_vals : in t_custom_ram) return t_prim_init_2d_arr is
    
        variable v_ans : t_prim_init_2d_arr(c_num_prims_deep-1 downto 0, c_num_prims_wide-1 downto 0) 
            := (others => (others => (others => (others => 'X'))));
            
        variable v_prim_row_major, v_prim_row_minor, v_prim_col_major, v_prim_col_minor : integer;
        
    begin
    
        for lv_row in i_init_vals'range loop
        
            v_prim_row_major := lv_row / c_primitive_word_depth;
            report "v_prim_row_major := " & integer'image(v_prim_row_major);
            v_prim_row_minor := lv_row mod c_primitive_word_depth;
            report "v_prim_row_minor := " & integer'image(v_prim_row_minor);
        
            for lv_col in i_init_vals(i_init_vals'low)'range loop
                
                v_prim_col_major := lv_col / c_primitive_data_width;
                report "v_prim_col_major := " & integer'image(v_prim_col_major);
                v_prim_col_minor := lv_col mod c_primitive_data_width;
                report "v_prim_col_minor := " & integer'image(v_prim_col_minor);
                
                v_ans(v_prim_row_major, v_prim_col_major)(v_prim_row_minor)(v_prim_col_minor) := i_init_vals(lv_row)(lv_col);
                
            end loop;
            
        end loop;
        
        return v_ans;
        
    end function;

    constant c_ram_init : t_prim_init_2d_arr(c_num_prims_deep-1 downto 0, c_num_prims_wide-1 downto 0) 
        := f_init_prims(g_init_vals);
    
    --the cycles of delay between data in and the BRAM primitives
    constant c_input_delay : integer := 2;
    
    --delay between input and primitive output
    constant c_primitive_dout_stage_idx : integer := c_input_delay + c_primitive_delay;
    
    --the number of registered stages to make the pipelined multiplexers for the data outputs.
    constant c_mux_stages : integer := g_read_delay - c_primitive_dout_stage_idx; --subtract 1 for the primitive read delay
    
    --the number of inputs every individual mux will have
    --on Vivado 2022.1, this line wont elaborate without this patch:
    --https://support.xilinx.com/s/article/2022-1-Vivado-Synthesis-Change-in-Parser-Behavior?language=en_US
    --also, calling ceil() on results of floating point math that aould otherwise evaluate to an exact integer
    --sometimes results in evaluating to the next integer up, not the integer you want.
    --subtract a tiny amount to adjust for this
    constant c_mux_depth : integer := integer(ceil( c_num_prims_deep**(1.0/real(c_mux_stages)) - 0.0001 ));
    
    --round c_num_prims_deep up to the nearest multiple of c_mux_depth to ensure the signals exist for the first stage of mux inputs
    constant c_num_stage0_mux_ins : integer := integer(ceil(real(c_num_prims_deep)/real(c_mux_depth)))*c_mux_depth;
    
    --for a given stage index, returns the number of muxes that stage should have
    --0 = first stage of muxes, prims/mux depth
    pure function getNumMuxesForStage(i_stage_idx : in integer) return integer is
        variable v_ans : integer;
    begin
        v_ans := integer(ceil( real(c_num_prims_deep)/real(c_mux_depth**(i_stage_idx+1)) - 0.0001 ));
        return v_ans;
    end function;
    
    --round the stage 0 mux count up to the nearest multiple of c_mux_depth to ensure the signals exist for the second stage of mux inputs
    constant c_num_stage1_mux_ins : integer := integer(ceil(real(getNumMuxesForStage(0))/real(c_mux_depth)))*c_mux_depth;
    
    --write enable pipelines
    signal s_wea_pline, s_web_pline : std_logic_vector(c_input_delay downto 1);
    
    --data 1D and 2D array types
    type t_data_arr is array(natural range<>) of std_logic_vector(g_data_width-1 downto 0);
    type t_data_2d_arr is array(natural range<>, natural range<>) of std_logic_vector(g_data_width-1 downto 0);
    
    --data in pipelines
    signal s_dina_pline, s_dinb_pline : t_data_arr(c_input_delay downto 1);
    
    --major address pipelines
    signal s_major_addra_pline, s_major_addrb_pline : integer_vector(g_read_delay downto 2);
    
    --major address: address to select between primitives
    signal s1_major_addra, s1_major_addrb : integer;
    
    --minor address: address to feed primitives to select for word within
    signal s1_minor_addra, s1_minor_addrb : integer;
    
    signal s1_ena, s1_enb : std_logic;
    
    
    signal s2_minor_addra, s2_minor_addrb : std_logic_vector(c_primitive_addr_width-1 downto 0);
    
    --data outputs right from primitives
    signal s3_doutas, s3_doutbs : t_data_arr(c_num_stage0_mux_ins-1 downto 0);
    
    
    --the outputs of all muxes in all stages
    signal s_mux_outs_a, s_mux_outs_b : t_data_2d_arr(c_mux_stages-1 downto 0, c_num_stage1_mux_ins-1 downto 0);
        
begin
    
    assert g_read_delay > c_primitive_dout_stage_idx report "Read delay must be greater than " & integer'image(c_primitive_dout_stage_idx) severity failure;
    
    assert 2**c_mux_stages <= c_num_prims_deep 
        report "Output multiplexer has more pipeline stages than it can use to interleave logic. The maximum number of stages it can use is " 
        & integer'image(integer(ceil( log2(real(c_num_prims_deep)) + 0.0001 )))
        & " (read delay of " & integer'image(c_primitive_dout_stage_idx + integer(ceil( log2(real(c_num_prims_deep)) + 0.0001 ))) & ")"
        severity warning;
        
    assert g_data_width >= c_primitive_data_width
        report "The requested data width is smaller than the data width of the primitives generated in this component. " & 
        "You might save area by implying a RAM module and letting the synthesizer come up with a configuration. " & 
        "This component does not support configuring primitives to be a different data width and depth." 
        severity warning;

    gen_dout_mux_stages: for gv_stage_idx in s_mux_outs_a'range(1) generate
        --gv_stage_idx is the stage index, where 0 is the first stage of muxes 
        --and the last one is the final mux that drives the data output.
        
        --number of muxes this stage wil have
        constant c_num_muxes : integer := getNumMuxesForStage(gv_stage_idx);
        
        --delay index within pipeline--the stage of delay this mux stage will be taking input from.
        --this stage will output to delay stage c_pline_idx+1.
        constant c_pline_idx : integer := gv_stage_idx + c_primitive_dout_stage_idx;
        
        --the amount to divide down the primitive address to isolate 
        --the part of the address pertaining to this stage of muxes
        constant c_mux_mag : integer := c_mux_depth**gv_stage_idx;
        
        --select input to all muxes for this stage
        signal s_sela, s_selb : integer range 0 to c_mux_depth-1;
            
    begin
    
        process(i_clka) is begin
            if rising_edge(i_clka) then
                s_sela <= (s_major_addra_pline(c_pline_idx-1)/c_mux_mag) mod c_mux_depth;
            end if;
        end process;
        
        process(i_clkb) is begin
            if rising_edge(i_clkb) then
                s_selb <= (s_major_addrb_pline(c_pline_idx-1)/c_mux_mag) mod c_mux_depth;
            end if;
        end process;
            
        gen_dout_muxes: for gv_mux_idx in 0 to c_num_muxes-1 generate
            --gv_mux_idx is this multiplexer's index within the stage. 
            --it selects between c_mux_depth data values from the last stage.
        
            --array to multiplex between on this mux
            signal s_mux_inputs_a, s_mux_inputs_b : t_data_arr(c_mux_depth-1 downto 0);
        
        begin
            
            process(i_clka) is begin
                if rising_edge(i_clka) then
                    s_mux_outs_a(gv_stage_idx, gv_mux_idx) <= s_mux_inputs_a(s_sela);
                end if;
            end process;
            
            process(i_clkb) is begin
                if rising_edge(i_clkb) then
                    s_mux_outs_b(gv_stage_idx, gv_mux_idx) <= s_mux_inputs_b(s_selb);
                end if;
            end process;
            
            gen_mux_inputs: if (gv_stage_idx = 0) generate
                s_mux_inputs_a <= s3_doutas(c_mux_depth*(gv_mux_idx+1) - 1 downto c_mux_depth*gv_mux_idx);
                s_mux_inputs_b <= s3_doutbs(c_mux_depth*(gv_mux_idx+1) - 1 downto c_mux_depth*gv_mux_idx);
            else generate
                gen_nth_stage_inputs: for gv_mux_in_idx in 0 to c_mux_depth - 1 generate
                    --assign mux inputs with a for generate since slices arent supported in 2D arrays in Vivado's VHDL 2008.
                    --gv_mux_in_idx is the index of the multiplexer's input, representing one data bus.
                    s_mux_inputs_a(gv_mux_in_idx) <= s_mux_outs_a(gv_stage_idx-1, gv_mux_in_idx + c_mux_depth*gv_mux_idx);
                    s_mux_inputs_b(gv_mux_in_idx) <= s_mux_outs_b(gv_stage_idx-1, gv_mux_in_idx + c_mux_depth*gv_mux_idx);
                end generate;
            end generate;
            
        end generate;
        
        gen_dout_mux_0s: for gv_mux_idx in c_num_muxes to s_mux_outs_a'high(2) generate
            s_mux_outs_a(gv_stage_idx, gv_mux_idx) <= (others => '0');
            s_mux_outs_b(gv_stage_idx, gv_mux_idx) <= (others => '0');
        end generate;
        
    end generate;
    
    o_douta <= s_mux_outs_a(c_mux_stages-1, 0);
    o_doutb <= s_mux_outs_b(c_mux_stages-1, 0);

    process(i_clka) is begin
        if rising_edge(i_clka) then
            
            s_wea_pline <= s_wea_pline(s_wea_pline'high-1 downto s_wea_pline'low) & i_wea;
            s_dina_pline <= s_dina_pline(s_dina_pline'high-1 downto s_dina_pline'low) & i_dina;
            s_major_addra_pline <= s_major_addra_pline(s_major_addra_pline'high-1 downto s_major_addra_pline'low) & s1_major_addra;
            
            s1_major_addra <= to_integer(unsigned(i_addra(i_addra'high downto c_primitive_addr_width)));
            s1_minor_addra <= to_integer(unsigned(i_addra(c_primitive_addr_width-1 downto 0)));
            s1_ena <= i_ena;
            
            s2_minor_addra <= std_logic_vector(to_unsigned(s1_minor_addra, s2_minor_addra'length));

        end if;
    end process;
    
    process(i_clkb) is begin
        if rising_edge(i_clkb) then
        
            s_web_pline <= s_web_pline(s_web_pline'high-1 downto s_web_pline'low) & i_web;
            s_dinb_pline <= s_dinb_pline(s_dinb_pline'high-1 downto s_dinb_pline'low) & i_dinb;
            s_major_addrb_pline <= s_major_addrb_pline(s_major_addrb_pline'high-1 downto s_major_addrb_pline'low) & s1_major_addrb;
            
            s1_major_addrb <= to_integer(unsigned(i_addrb(i_addrb'high downto c_primitive_addr_width)));
            s1_minor_addrb <= to_integer(unsigned(i_addrb(c_primitive_addr_width-1 downto 0)));
            s1_enb <= i_enb;
            
            s2_minor_addrb <= std_logic_vector(to_unsigned(s1_minor_addrb, s2_minor_addrb'length));
            
        end if;
    end process;

    gen_prims: for gv_prim_row_idx in 0 to c_num_prims_deep-1 generate
        
        signal s2_ena, s2_enb : std_logic;
        
    begin
    
        process(i_clka) is begin
            if rising_edge(i_clka) then
                
                s2_ena <= '0';
                if (s1_major_addra = gv_prim_row_idx) then
                    s2_ena <= s1_ena;
                end if;
                
            end if;
        end process;
        
        process(i_clkb) is begin
            if rising_edge(i_clkb) then
                
                s2_enb <= '0';
                if (s1_major_addrb = gv_prim_row_idx) then
                    s2_enb <= s1_enb;
                end if;
                
            end if;
        end process;
    
        gen_prim_row: for gv_prim_col_idx in 0 to c_num_prims_wide-1 generate
        
            constant c_data_low_idx : integer := gv_prim_col_idx*c_primitive_data_width;
            constant c_data_high_idx : integer := minimum((gv_prim_col_idx+1)*c_primitive_data_width - 1, g_data_width-1);
            constant c_data_used : integer := c_data_high_idx - c_data_low_idx + 1;
            
            --stage 3
            signal s_dina, s_dinb, s_douta, s_doutb : std_logic_vector(c_primitive_data_width-1 downto 0);
            
        begin
        
            s_dina(c_data_used-1 downto 0) <= s_dina_pline(2)(c_data_high_idx downto c_data_low_idx);
            s_dina(s_dina'high downto c_data_used) <= (others => '0');
            s_dinb(c_data_used-1 downto 0) <= s_dinb_pline(2)(c_data_high_idx downto c_data_low_idx);
            s_dinb(s_dinb'high downto c_data_used) <= (others => '0');
            
            s3_doutas(gv_prim_row_idx)(c_data_high_idx downto c_data_low_idx) <= s_douta(c_data_used-1 downto 0);
            s3_doutbs(gv_prim_row_idx)(c_data_high_idx downto c_data_low_idx) <= s_doutb(c_data_used-1 downto 0);
            
            bram_prim_inst: entity work.bram_dp_primitive
            generic map(
                g_init_data => c_ram_init(gv_prim_row_idx, gv_prim_col_idx)
            )
            port map(
                i_clka => i_clka,
                i_ena => s2_ena,
                i_wea => s_wea_pline(2),
                i_addra => s2_minor_addra,
                i_dina => s_dina,
                o_douta => s_douta,
                i_clkb => i_clkb,
                i_enb => s2_enb,
                i_web => s_web_pline(2),
                i_addrb => s2_minor_addrb,
                i_dinb => s_dinb,
                o_doutb => s_doutb
            );
            
        end generate;
        
    end generate;
    
    s3_doutas(s3_doutas'high downto c_num_prims_deep) <= (others => (others => '0'));
    s3_doutbs(s3_doutas'high downto c_num_prims_deep) <= (others => (others => '0'));

end Structural;
