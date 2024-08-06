----------------------------------------------------------------------------------
-- Company: TU Dresden
-- Engineer: Sergio Pertuz
-- 
-- Create Date: 10.04.2024
-- Design Name: Motor Encoder Handler
-- Module Name: motorEncoder1ch - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: This Block handle the 1 channel encoder of a motor depending on a direcction pin
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
use IEEE.NUMERIC_STD.ALL;
use work.functions.all;
-- 

entity motorEncoder1ch is
GENERIC(
        nMOTORS     : integer := 2; -- number of motors
        encBit_res  : integer := 32; -- encoder bit resolution
        debounce_bit: integer := 10 -- Counter width for delay ~8us for a 125Mhz clock (n^2 * 8e-9) = 8.2 us
);
Port ( 
    -- clock and reset
    aclk    : in std_logic;
    aresetn : in std_logic;
    -- i/o
    enc_in      : in  std_logic_vector(nMOTORS - 1 downto 0);
    dir_in      : in  std_logic_vector(nMOTORS - 1 downto 0);
    count_out   : out std_logic_vector(nMOTORS*encBit_res-1 downto 0)
);
end motorEncoder1ch;

architecture Behavioral of motorEncoder1ch is

    component up_dn_counter_top
    generic (
        n : positive := encBit_res
    );
    port (  
        CLK : in  STD_LOGIC;
        updown, clr, ld, en : in STD_LOGIC;
        D : in STD_LOGIC_VECTOR(n-1 downto 0);
        Q : out  STD_LOGIC_VECTOR (n-1 downto 0);
        ovrflow : out  STD_LOGIC
    ); 
    end component;
    
    component EdgeDetector
    Port ( Clk : in STD_LOGIC;
           InputSignal : in STD_LOGIC;
           Edge : out STD_LOGIC);
    end component;

    component Debouncer
        Generic ( count_width : integer := debounce_bit);	
        Port ( clk : in  STD_LOGIC;
              button : in  STD_LOGIC;
              debounced : out  STD_LOGIC);
    end component;

    constant delay_width : integer := 10;

    -- delay signals
    signal debounced_enc_in : std_logic_vector(nMOTORS - 1 downto 0);
    
    -- Internal signals for edge detection
    signal not_debounced_enc_in : std_logic_vector(nMOTORS - 1 downto 0);
    signal rising_edge_signals : std_logic_vector(nMOTORS - 1 downto 0);
    signal falling_edge_signals : std_logic_vector(nMOTORS - 1 downto 0);
    signal edge_signals : std_logic_vector(nMOTORS - 1 downto 0);
    signal reset_p : std_logic;

begin

    reset_p <= not aresetn;
    not_debounced_enc_in <= not(debounced_enc_in);
    edge_signals <= rising_edge_signals or falling_edge_signals;

    -- Delay to simulate motor inertia
    delay_counter: for i in 0 to nMOTORS - 1 generate
        debouncer_inst : Debouncer
        generic map (
            count_width => debounce_bit
        )
        port map(
            clk         => aclk,
            button      => enc_in(i),
            debounced   => debounced_enc_in(i)
        );   
    end generate;

    -- Instantiation of EdgeDetector for each channel
    edge_detection: for i in 0 to nMOTORS - 1 generate
        rising_ed_inst: EdgeDetector
        port map (
            Clk => aclk,
            InputSignal => debounced_enc_in(i),
            Edge => rising_edge_signals(i)
        );
        falling_ed_inst: EdgeDetector
        port map (
            Clk => aclk,
            InputSignal => not_debounced_enc_in(i),
            Edge => falling_edge_signals(i)
        );
    end generate;

    -- Instantiation of up_dn_counter_top for each channel
    counter_inst: for i in 0 to nMOTORS - 1 generate
        counter: up_dn_counter_top
        generic map (
            n => encBit_res
        )
        port map (
            CLK => aclk,
            updown => dir_in(i), -- Use direction signal to determine count direction
            clr => reset_p, -- Active high reset
            ld => '0', -- Load signal, not used in this implementation
            en => edge_signals(i), -- Enable counting
            D => (others => '0'), -- Not used in this implementation
            Q => count_out(((i+1)*encBit_res)-1 downto i*encBit_res), -- Output count value
            ovrflow => open -- Overflow signal, not used in this implementation
        );
    end generate;

end Behavioral ; -- Behavioral

