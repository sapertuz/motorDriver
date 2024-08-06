library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.functions.all;

entity Debouncer is
	Generic ( count_width : integer := 17);	-- Counter width for delay
	Port ( clk : in  STD_LOGIC;
          button : in  STD_LOGIC;
          debounced : out  STD_LOGIC);
end Debouncer;

architecture hierarchical of Debouncer is
    -- Component Declaration for the counter
    component up_dn_counter_top
        generic (
            n : positive := 4
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

	signal pulse : STD_LOGIC := '0';
	signal rise_edge, fall_edge : STD_LOGIC;
	signal count_enable : STD_LOGIC := '0';
	signal reset, debounce : STD_LOGIC := '0';
    signal stored_button : STD_LOGIC := '0';
    signal not_button : std_logic := '0';
begin

    delay_counter : up_dn_counter_top
        generic map (
            n => count_width -- like this we count up to 2^17 = 131071 
        )
        port map (
            CLK => clk,
            updown => '1',
            clr => '0',
            ld => '0',
            en => count_enable,
            D => (others=>'0'),
            Q => open,
            ovrflow => pulse -- we reach overflow ~1ms for a 100Mhz clock (2^n * 10e-9) = 1.3 ms
        );

	rising_edge_det : EdgeDetector
	Port map ( Clk => clk,
		   InputSignal => button,
		   Edge => rise_edge
	);

	falling_edge_det : EdgeDetector
	Port map ( Clk => clk,
		   InputSignal => not_button,
		   Edge => fall_edge
	);
	
	trigger_proc: process(clk)
		begin
		if(reset='1') then
			count_enable <= '0';
            stored_button <= button;
		elsif(rising_edge(clk)) then
			if(rise_edge='1') then
				count_enable <='1';
                stored_button <= '1';
			elsif(fall_edge='1') then
				count_enable <= '1';
                stored_button <= '0';
			end if;
		end if;
	end process;

	debounce_proc: process(clk)
		begin
		if(rising_edge(clk)) then
			if(pulse = '1') then
				debounce <= stored_button;
				reset <= '1';
			elsif(pulse='0') then
				reset <= '0';
			end if;
		end if;
	end process;
    
    not_button <= not button;
	debounced <= debounce;
	
end hierarchical;