----------------------------------------------------------------------------------
-- Company: TU Dresden
-- Engineer: Sergio Pertuz
-- 
-- Create Date: 10.04.2024
-- Design Name: Motor Driver
-- Module Name: motorDriver - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: This blocks receives a value between `-pwm_resolution` and `pwm_resolution` to control the `nMOTORS` motor pwm and direction
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

-- Entity declaration using the calculated pwm_resolution_bits from the package
entity motorDriver is
GENERIC(
    sys_clk         : INTEGER := 125_000_000;   -- system clock frequency in Hz
    pwm_freq        : INTEGER := 31_372;        -- PWM switching frequency in Hz
    nMOTORS         : integer := 2;             -- number of motors 
    nMOTORS_bits    : integer := 1;             -- should be log2(nMOTORS)
    pwm_resolution  : INTEGER := 255;            -- resolution setting for the duty cycle
    pwm_resolution_bits  : INTEGER := 8         -- should be log2(pwm_resolution) 
);
Port ( 
    -- clock and reset
    aclk    : in std_logic;
    aresetn : in std_logic;
    -- i/o
    motor_id : in std_logic_vector(nMOTORS_bits-1 downto 0);
    motor_dir : in std_logic;
    motor_duty : in std_logic_vector(pwm_resolution_bits-1 downto 0);
    motor_set  : in std_logic;
    busy      : out std_logic;
    pwm_o   : out std_logic_vector(nMOTORS-1 downto 0);
    dir_o : out std_logic_vector(nMOTORS-1 downto 0)
);
end motorDriver;

architecture Behavioral of motorDriver is

    constant bits_resolution : natural := pwm_resolution_bits;
    constant zero : std_logic_vector (bits_resolution-1 DOWNTO 0) := (OTHERS => '0');
    constant ones : std_logic_vector (bits_resolution-1 DOWNTO 0) := (OTHERS => '1');

    component pwm is
    GENERIC(
        sys_clk         : INTEGER := sys_clk;         --system clock frequency in Hz
        pwm_freq        : INTEGER := pwm_freq;        --PWM switching frequency in Hz
        pwm_resolution_bits  : INTEGER := pwm_resolution_bits; --bits of resolution setting the duty cycle
        phases          : INTEGER := nMOTORS          --number of output pwms and phases
    );
	Port (    
        clk       : IN  STD_LOGIC;                                    --system clock
        reset_n   : IN  STD_LOGIC;                                    --asynchronous reset
        ena       : IN  STD_LOGIC;                                    --latches in new duty cycle
        duty      : IN  STD_LOGIC_VECTOR(pwm_resolution_bits-1 DOWNTO 0); --duty cycle
        phase     : IN  integer range 0 to phases-1;                  --pwm phases
        pwm_out   : OUT STD_LOGIC_VECTOR(phases-1 DOWNTO 0);          --pwm outputs
        pwm_n_out : OUT STD_LOGIC_VECTOR(phases-1 DOWNTO 0)            --pwm inverse outputs
    );         
    end component;

    signal myMotorADDR : integer range 0 to nMotors-1 := 0;
    signal tmp_myMotorADDR : std_logic_vector(3 downto 0) := (others=>'0') ;
    signal width1 : STD_LOGIC_VECTOR(bits_resolution-1 DOWNTO 0) := (OTHERS => '0');
    signal ena1 : STD_LOGIC := '0';
    signal signalIn : STD_LOGIC_VECTOR(bits_resolution-1 DOWNTO 0) := (OTHERS => '0');
    signal sgn : STD_LOGIC := '0';

    signal pwm_clk : STD_LOGIC := '0';

    signal pwmCH1 : STD_LOGIC_VECTOR(nMotors-1 DOWNTO 0) := (OTHERS => '0');
    signal dirCH2 : STD_LOGIC_VECTOR(nMotors-1 DOWNTO 0) := (OTHERS => '0');

    type t_state is (IDLE, work, pass);
    signal state: t_state := IDLE;

begin
    pwm_o   <= pwmCH1;
    dir_o   <= dirCH2;
    
    -- PWM instance
    pwm1: pwm
    generic map(
        sys_clk =>      sys_clk,
        pwm_freq =>     pwm_freq,
        pwm_resolution_bits => pwm_resolution_bits,
        phases =>       nMotors 
    )
    port map(     
        clk =>          aclk,
        reset_n =>      aresetn,
        ena =>          ena1,
        duty =>         width1,
        phase =>        myMotorADDR,
        pwm_out =>      pwmCH1,
        pwm_n_out =>    open
    );

    --control outputs for each motor                            
    process(aclk)
    begin
        if rising_edge(aclk) then
        if aresetn = '0' then 
            ena1 <= '0';
            width1 <= zero;-- ones;
            state <= IDLE;
            dirCH2 <= (others => '0');
        else
            case state is
                when IDLE =>
                    ena1 <= '0';
                    if (motor_set='1') then  
                        state <= work;
                        myMotorADDR <= TO_INTEGER(unsigned(motor_id)); 
                        sgn         <= motor_dir;
                        signalIn    <= motor_duty;
                        busy <= '1';
                    else
                        busy <= '0';    
                    end if;
                    
                when work =>
                    if myMotorADDR < nMOTORS then
                        if signalIn = zero then
                        width1 <= (OTHERS => '1');
                        else
                            width1 <= signalIn;
                        end if;
                        dirCH2(myMotorADDR) <= sgn;
                            
                        state <= pass;
                    else
                        state <= IDLE;
                    end if;
                
                when pass =>
                    ena1 <= '1';
                    busy <= '0';
                    state <= IDLE;
                
                when others => state <= IDLE;
            end case;
            
            end if;
        end if;
    end process;

end Behavioral;
