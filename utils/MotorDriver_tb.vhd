library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- entity
entity motorDriver_tb is
end entity motorDriver_tb;

architecture bhv of motorDriver_tb is
  constant sys_clk         : INTEGER := 125_000_000;
  constant pwm_freq        : INTEGER := 31_372;
  constant nMOTORS         : integer := 2;
  constant nMOTORS_bits    : integer := 1;
  constant pwm_resolution  : INTEGER := 16;
  constant pwm_resolution_bits  : INTEGER := 4;

  -- input
  signal clk   : std_logic := '0';
  signal reset : std_logic;
  signal motor_id : std_logic_vector(nMOTORS_bits-1 downto 0);
  signal motor_dir : std_logic;
  signal motor_duty_int : integer RANGE -pwm_resolution TO pwm_resolution;
  signal motor_duty_tmp : std_logic_vector(pwm_resolution_bits downto 0);
  signal motor_duty : std_logic_vector(pwm_resolution_bits downto 0);
  signal motor_set  : std_logic;

  -- output
  signal busy      : std_logic;
  signal pwm_o   : std_logic_vector(nMOTORS-1 downto 0);
  signal dir_o : std_logic_vector(nMOTORS-1 downto 0);

begin
  -- clk and reset
  clk   <= not clk  after 10 ns;  -- 25 MHz Taktfrequenz
  reset <= '0', '1' after 100 ns; -- erzeugt Resetsignal: --__

  -- stimuli   
  motor_id <=   "0",   "1" after 200000 ns,  "0" after 400000 ns,  "1" after 600000 ns;
--  motor_dir <=  '0',    '0' after 200000 ns,   '1' after 400000 ns,   '1' after 600000 ns;
  motor_duty_int <= 4,    10 after 200000 ns,  -14 after 400000 ns,   -2 after 600000 ns;
  motor_set <=  '0','1' after 200 ns, '0' after 220 ns,
                    '1' after 200000 ns, '0' after 200020 ns,
                    '1' after 400000 ns, '0' after 400020 ns,
                    '1' after 600000 ns, '0' after 600020 ns;
  
  motor_duty_tmp <= std_logic_vector(to_unsigned(motor_duty_int, pwm_resolution_bits+1));
  motor_dir <=  motor_duty_tmp(pwm_resolution_bits);
  motor_duty <= std_logic_vector(unsigned(not(motor_duty_tmp)) + 1) when (motor_dir = '1') else
                motor_duty_tmp;
  
  
  -- Module under test
  dut : entity work.motorDriver
    generic map(
      sys_clk => sys_clk,
      pwm_freq => pwm_freq,
      nMOTORS => nMOTORS,
      nMOTORS_bits => nMOTORS_bits,
      pwm_resolution => pwm_resolution,
      pwm_resolution_bits => pwm_resolution_bits
    )
    port map (
        aclk        => clk,
        aresetn     => reset,
        motor_id    => motor_id, 
        motor_dir   => motor_dir, 
        motor_duty  => motor_duty(pwm_resolution_bits-1 downto 0),
        motor_set   => motor_set,  
        busy        => busy, 
        pwm_o       => pwm_o,
        dir_o       => dir_o
      );


end architecture;