LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;
use work.functions.all;

ENTITY pwm IS
  GENERIC(
      sys_clk         : INTEGER := 100_000_000; -- system clock frequency in Hz
      pwm_freq        : INTEGER := 5_000;    		-- PWM switching frequency in Hz
      pwm_resolution_bits 	: INTEGER := 4;         -- bit width of resolution setting the duty cycle
      phases          : INTEGER := 7         		-- number of output pwms and phases
      );
  PORT(
      clk       : IN  STD_LOGIC;                                    --system clock
      reset_n   : IN  STD_LOGIC;                                    --asynchronous reset
      ena       : IN  STD_LOGIC;                                    --latches in new duty cycle
      duty      : IN  STD_LOGIC_VECTOR(pwm_resolution_bits-1 DOWNTO 0); --duty cycle
      phase     : IN  integer range 0 to phases-1;                  --pwm outputs
      pwm_out   : OUT STD_LOGIC_VECTOR(phases-1 DOWNTO 0);          --pwm outputs
      pwm_n_out : OUT STD_LOGIC_VECTOR(phases-1 DOWNTO 0));         --pwm inverse outputs
END pwm;

ARCHITECTURE logic OF pwm IS
  CONSTANT 	bits_resolution : natural := pwm_resolution_bits;
  CONSTANT  pwm_period      :  INTEGER := sys_clk/(pwm_freq*(2**bits_resolution));		--number of clocks in one pwm period
  CONSTANT  pwm_half_period :  INTEGER := sys_clk/(2*pwm_freq*(2**bits_resolution));	--number of clocks in one pwm period
  CONSTANT  period          :  INTEGER := 2**bits_resolution;													--number of clocks in one pwm period
  CONSTANT  half_period     :  INTEGER := 2**bits_resolution/2;												--number of clocks in one pwm period
  CONSTANT  max_half_period :  INTEGER := period/2;																		--max half period

	TYPE      half_duties IS ARRAY (0 TO phases-1) OF INTEGER RANGE 0 TO period/2; 			--data type for array of half duty values

	SIGNAL    pwm_count      :  integer range 0 to sys_clk/pwm_freq - 1;
  SIGNAL    count          :  integer range 0 to period-1;
  signal    half_duty_new  :  half_duties := (others => 0);		--number of clocks in 1/2 duty cycle
  SIGNAL    half_duty      :  half_duties := (OTHERS => 0);		--array of half duty values (for each phase)
  
  SIGNAL    pwm_clk  :  std_logic:='0' ;                     	--array of half duty values (for each phase)
  SIGNAL    flag_end_of_period  :  std_logic:='0' ;						--array of half duty values (for each phase)
  
  type t_state is (IDLE, work, pass);
  signal state: t_state := IDLE;
  
BEGIN

		gen_cnt: PROCESS(clk, reset_n)
    BEGIN
        IF(reset_n = '0') then              -- asynchronous reset
            half_duty_new <= (others => 0); -- (others => max_half_period-1);
            pwm_count <= 0;
            pwm_clk <= '0';

        ELSIF rising_edge(clk) THEN 				--rising system clock edge
          
            if (ena = '1') then
                half_duty_new(phase) <= conv_integer(duty(bits_resolution-1 DOWNTO 1));   -- 1/2 duty cycle
            END IF;
          
            IF (pwm_count = pwm_period - 1) then		--end of period reached
                pwm_clk <= '1';
                pwm_count <= 0;											--reset counter
            else    
                pwm_clk <= '0';
                pwm_count <= pwm_count + 1;					--increment counter
            END IF;

        END IF;
    END PROCESS ;

		gen_duty : process( clk, reset_n )
		begin
			if reset_n = '0' then

				half_duty <= (others => 0); 		-- (others => max_half_period-1);
			
			elsif rising_edge(clk) then
			
				if (flag_end_of_period = '1' and ena = '0') then
					for ii in 0 to phases-1 loop
							half_duty(ii) <= half_duty_new(ii);
					end loop;
				end if;				
			
			end if ;
		end process ; -- gen_duty

		gen_pwm : process( clk, reset_n )
		begin
			if reset_n = '0' then
			
				count <= 0; -- period - 1;
				flag_end_of_period <= '1';
				pwm_out <= (others => '1');
				pwm_n_out <= (others => '0');
          
			elsif rising_edge(clk) then
				if (pwm_clk = '1') then
            
					IF(count = period - 1) then					--end of period reached
							count <= 0;                     --reset counter
							flag_end_of_period <= '1';
					else 
							flag_end_of_period <= '0';
							count <= count + 1;							--increment counter
					END IF;
					
					FOR i IN 0 to phases-1 LOOP													--control outputs for each phase
									IF(count = half_duty(i)) THEN								--phase's falling edge reached
											pwm_out(i) <= '0';											--deassert the pwm output
											pwm_n_out(i) <= '1';										--assert the pwm inverse output
									ELSIF(count = period - half_duty(i)) THEN   --phase's rising edge reached
											pwm_out(i) <= '1';											--assert the pwm output
											pwm_n_out(i) <= '0';										--deassert the pwm inverse output
									END IF;
					END LOOP;
				
				end if;
			end if ;
		end process ; -- gen_duty

END logic;

