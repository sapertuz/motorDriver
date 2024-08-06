library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.ALL;
use work.functions.all;

entity AXI_motorDriver is
	Generic(
		-- Users to add parameters here
		sys_clk      : INTEGER := 125_000_000; -- system clock frequency in Hz
		pwm_freq     : INTEGER := 31_372;      -- PWM switching frequency in Hz
		nMOTORS      : integer := 2;           -- n motors (max 8)
		-- User parameters ends

		S_AXI_DATA_WIDTH	: integer	:= 32; -- (maintain constant) Width of S_AXI data bus
		S_AXI_ADDR_WIDTH	: integer	:= 6   -- (maintain constant) Width of S_AXI address bus
	);
    Port (
		-- Users to add ports here
        enc_in : in std_logic_vector((nMOTORS-1) downto 0);
		busy   : out  std_logic;
		pwm_o  : out std_logic_vector((nMOTORS-1) downto 0);
		dir_o  : out std_logic_vector((nMOTORS-1) downto 0);
		-- User ports ends

        -- AXI Interface
        S_AXI_ACLK                     : in  std_logic;
        S_AXI_ARESETN                  : in  std_logic;
        S_AXI_AWADDR                   : in  std_logic_vector(S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_AWVALID                  : in  std_logic;
        S_AXI_AWREADY                  : out std_logic;
        S_AXI_ARADDR                   : in  std_logic_vector(S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_ARVALID                  : in  std_logic;
        S_AXI_ARREADY                  : out std_logic;
        S_AXI_WDATA                    : in  std_logic_vector(S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_WSTRB                    : in  std_logic_vector((S_AXI_DATA_WIDTH/8)-1 downto 0);
        S_AXI_WVALID                   : in  std_logic;
        S_AXI_WREADY                   : out std_logic;
        S_AXI_RDATA                    : out std_logic_vector(S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_RRESP                    : out std_logic_vector(1 downto 0);
        S_AXI_RVALID                   : out std_logic;
        S_AXI_RREADY                   : in  std_logic;
        S_AXI_BRESP                    : out std_logic_vector(1 downto 0);
        S_AXI_BVALID                   : out std_logic;
        S_AXI_BREADY                   : in  std_logic
    );
end AXI_motorDriver;

architecture Behavioral of AXI_motorDriver is
    constant pwm_res        : INTEGER := 255 + 1; -- (maintain constant) resolution for duty cycle, the +1 is for sanity
    constant encBit_res     : INTEGER := 32;
    constant debounce_bit   : INTEGER := 10;
	constant m_id_bits : integer := log2(nMOTORS);
	constant pwm_bits : integer := log2(pwm_res);

    signal enc_count_o : std_logic_vector(nMOTORS*encBit_res-1 downto 0);

    signal busy_pwm : std_logic := '1';
    
    signal ip_motor_set     : std_logic := '0';
    signal ip_motor_duty    : std_logic_vector(pwm_bits-1 downto 0) := (others => '0');
    signal ip_motor_dir     : std_logic := '0';
    signal ip_motor_id      : std_logic_vector(m_id_bits-1 downto 0) := (others => '0');

	signal motor_dir : STD_LOGIC_VECTOR(S_AXI_DATA_WIDTH-1 downto 0);
    signal dir_o_sig : STD_LOGIC_VECTOR(nMOTORS-1 downto 0);

begin
    dir_o <= dir_o_sig;
    
    axi_interface: entity work.AXI_motorDriver_if
    Generic map(
        sys_clk => sys_clk,
        pwm_freq => pwm_freq,
        nMOTORS => nMOTORS,
        nMOTORS_bits => m_id_bits,
        pwm_resolution_bits => pwm_bits,
        encBit_res => encBit_res,
        S_AXI_DATA_WIDTH => S_AXI_DATA_WIDTH,
        S_AXI_ADDR_WIDTH => S_AXI_ADDR_WIDTH
    )
    Port map(
        busy_pwm        => busy_pwm,
        ip_motor_id     => ip_motor_id,
        ip_motor_dir    => ip_motor_dir,    
        ip_motor_duty   => ip_motor_duty,    
        ip_motor_set    => ip_motor_set,    
        enc_count_o     => enc_count_o,
        busy_logic_o    => busy,
        S_AXI_ACLK      => S_AXI_ACLK,
        S_AXI_ARESETN   => S_AXI_ARESETN,
        S_AXI_AWADDR    => S_AXI_AWADDR,    
        S_AXI_AWVALID   => S_AXI_AWVALID,    
        S_AXI_AWREADY   => S_AXI_AWREADY,    
        S_AXI_ARADDR    => S_AXI_ARADDR,    
        S_AXI_ARVALID   => S_AXI_ARVALID,    
        S_AXI_ARREADY   => S_AXI_ARREADY,    
        S_AXI_WDATA     => S_AXI_WDATA,
        S_AXI_WSTRB     => S_AXI_WSTRB,
        S_AXI_WVALID    => S_AXI_WVALID,    
        S_AXI_WREADY    => S_AXI_WREADY,    
        S_AXI_RDATA     => S_AXI_RDATA,
        S_AXI_RRESP     => S_AXI_RRESP,
        S_AXI_RVALID    => S_AXI_RVALID,    
        S_AXI_RREADY    => S_AXI_RREADY,    
        S_AXI_BRESP     => S_AXI_BRESP,
        S_AXI_BVALID    => S_AXI_BVALID,    
        S_AXI_BREADY    => S_AXI_BREADY
    );

    motor_driver: entity work.motorDriver 
    Generic map(
        sys_clk => sys_clk,
        pwm_freq    => pwm_freq,
        nMOTORS => nMOTORS,
        nMOTORS_bits => m_id_bits,
        pwm_resolution => pwm_res,
        pwm_resolution_bits => pwm_bits
    )
    Port map(
        aclk => s_axi_aclk,
        aresetn => s_axi_aresetn,
        motor_id => ip_motor_id,
        motor_dir => ip_motor_dir,
        motor_duty => ip_motor_duty,
        motor_set => ip_motor_set,
        busy => busy_pwm,
        pwm_o => pwm_o,
        dir_o => dir_o_sig
    );

    encoder : entity work.motorEncoder1ch 
    Generic map(
        nMOTORS => nMOTORS,
        encBit_res => encBit_res,
        debounce_bit => debounce_bit
    )
    Port map(
        aclk => s_axi_aclk,
        aresetn => s_axi_aresetn,
        enc_in => enc_in,
        dir_in => dir_o_sig,
        count_out => enc_count_o
    );
	-- User logic ends

end Behavioral;

