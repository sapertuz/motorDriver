library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.ALL;
use work.functions.all;

entity AXI_motorDriver_if is
	Generic(
		-- Users to add parameters here
		sys_clk             : INTEGER := 125_000_000; -- system clock frequency in Hz
		pwm_freq            : INTEGER := 31_372;      -- PWM switching frequency in Hz
		nMOTORS             : integer := 2;           -- n motors (max 8)
        nMOTORS_bits        : integer := 1;
        pwm_resolution_bits : integer := 8;
        encBit_res          : integer := 32;
		-- User parameters ends

		S_AXI_DATA_WIDTH	: integer	:= 32; -- (maintain constant) Width of S_AXI data bus
		S_AXI_ADDR_WIDTH	: integer	:= 6 -- (maintain constant) Width of S_AXI address bus
	);
    Port (
		-- Users to add ports here
        busy_pwm        : in  std_logic;
        ip_motor_id     : out std_logic_vector(nMOTORS_bits-1 downto 0);
        ip_motor_dir    : out std_logic;
        ip_motor_duty   : out std_logic_vector(pwm_resolution_bits-1 downto 0);
        ip_motor_set    : out std_logic;
        
        enc_count_o     : in  std_logic_vector(nMOTORS*encBit_res-1 downto 0);

        busy_logic_o     : out std_logic;
        -- User ports ends

        -- AXI Interface
        S_AXI_ACLK      : in  std_logic;
        S_AXI_ARESETN   : in  std_logic;
        S_AXI_AWADDR    : in  std_logic_vector(S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_AWVALID   : in  std_logic;
        S_AXI_AWREADY   : out std_logic;
        S_AXI_ARADDR    : in  std_logic_vector(S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_ARVALID   : in  std_logic;
        S_AXI_ARREADY   : out std_logic;
        S_AXI_WDATA     : in  std_logic_vector(S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_WSTRB     : in  std_logic_vector((S_AXI_DATA_WIDTH/8)-1 downto 0);
        S_AXI_WVALID    : in  std_logic;
        S_AXI_WREADY    : out std_logic;
        S_AXI_RDATA     : out std_logic_vector(S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_RRESP     : out std_logic_vector(1 downto 0);
        S_AXI_RVALID    : out std_logic;
        S_AXI_RREADY    : in  std_logic;
        S_AXI_BRESP     : out std_logic_vector(1 downto 0);
        S_AXI_BVALID    : out std_logic;
        S_AXI_BREADY    : in  std_logic
    );
end AXI_motorDriver_if;

architecture Behavioral of AXI_motorDriver_if is
    constant pwm_res        : INTEGER := 255 + 1; -- (maintain constant) resolution for duty cycle, the +1 is for sanity
    constant debounce_bit   : INTEGER := 10;
	constant m_id_bits : integer := log2(nMOTORS);
	constant pwm_bits : integer := log2(pwm_res);

	constant control_reg_offset : natural := 1;
	constant status_reg_offset : natural := 2;
	constant pwm_reg_offset_a : natural := 3;
	constant pwm_reg_offset_b : natural := 4;
	constant dir_reg_offset : natural := 5;
	constant enc_offset_offset : natural := 8;

    -- AXI4LITE signals
	signal axi_awaddr	: std_logic_vector(S_AXI_ADDR_WIDTH-1 downto 0);
	signal axi_awready	: std_logic;
	signal axi_wready	: std_logic;
	signal axi_bresp	: std_logic_vector(1 downto 0);
	signal axi_bvalid	: std_logic;
	signal axi_araddr	: std_logic_vector(S_AXI_ADDR_WIDTH-1 downto 0);
	signal axi_arready	: std_logic;
	signal axi_rdata	: std_logic_vector(S_AXI_DATA_WIDTH-1 downto 0);
	signal axi_rresp	: std_logic_vector(1 downto 0);
	signal axi_rvalid	: std_logic;

	-- Example-specific design signals
	-- local parameter for addressing 32 bit / 64 bit S_AXI_DATA_WIDTH
	-- ADDR_LSB is used for addressing 32/64 bit registers/memories
	-- ADDR_LSB = 2 for 32 bits (n downto 2)
	-- ADDR_LSB = 3 for 64 bits (n downto 3)
	constant ADDR_LSB  : integer := (S_AXI_DATA_WIDTH/32)+ 1;
	constant OPT_MEM_ADDR_BITS : integer := 3;
	------------------------------------------------
	---- Signals for user logic register space example
	--------------------------------------------------
	---- Number of Slave Registers 16
	signal slv_reg0	:std_logic_vector(S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg1	:std_logic_vector(S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg2	:std_logic_vector(S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg3	:std_logic_vector(S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg4	:std_logic_vector(S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg5	:std_logic_vector(S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg6	:std_logic_vector(S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg7	:std_logic_vector(S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg8 :std_logic_vector(S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg9	:std_logic_vector(S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg10	:std_logic_vector(S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg11	:std_logic_vector(S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg12	:std_logic_vector(S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg13	:std_logic_vector(S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg14	:std_logic_vector(S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg15	:std_logic_vector(S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg_rden	: std_logic;
	signal slv_reg_wren	: std_logic;
	signal reg_data_out	:std_logic_vector(S_AXI_DATA_WIDTH-1 downto 0);
	signal byte_index	: integer;
	signal aw_en	: std_logic;

    type reg_array is array (0 to 15) of STD_LOGIC_VECTOR(S_AXI_DATA_WIDTH-1 downto 0); -- 16 registers of 32 bits each
    signal regs : reg_array := (others => (others => '0')); -- Initialize all registers with zeros
    
    type enc_array is array (0 to 8) of STD_LOGIC_VECTOR(encBit_res-1 downto 0);
    signal encs_o : enc_array := (others => (others => '0')); 

    signal status_reg : STD_LOGIC_VECTOR(S_AXI_DATA_WIDTH-1 downto 0);
    signal control_reg : STD_LOGIC_VECTOR(S_AXI_DATA_WIDTH-1 downto 0);
	signal reset_reg : std_logic := '0';
    signal commit : std_logic := '0';
    signal busy_logic : std_logic := '1';

	type motor_pwm_array is array (0 to nMOTORS) of std_logic_vector(pwm_bits-1 downto 0);
	signal motor_pwm : motor_pwm_array := (others => (others => '0'));
    signal motor_dir : STD_LOGIC_VECTOR(S_AXI_DATA_WIDTH-1 downto 0);
    signal dir_o_sig : STD_LOGIC_VECTOR(nMOTORS-1 downto 0);

    type t_state is (IDLE, commit_log, wait_busy, working, releasing);
    signal state: t_state := IDLE;

begin
    busy_logic_o <= busy_logic;

	-- I/O Connections assignments
	S_AXI_AWREADY	<= axi_awready;
	S_AXI_WREADY	<= axi_wready;
	S_AXI_BRESP	<= axi_bresp;
	S_AXI_BVALID	<= axi_bvalid;
	S_AXI_ARREADY	<= axi_arready;
	S_AXI_RDATA	<= axi_rdata;
	S_AXI_RRESP	<= axi_rresp;
	S_AXI_RVALID	<= axi_rvalid;
	-- Implement axi_awready generation
	-- axi_awready is asserted for one S_AXI_ACLK clock cycle when both
	-- S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
	-- de-asserted when reset is low.

	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
	      axi_awready <= '0';
	      aw_en <= '1';
	    else
	      if (axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' and aw_en = '1') then
	        -- slave is ready to accept write address when
	        -- there is a valid write address and write data
	        -- on the write address and data bus. This design 
	        -- expects no outstanding transactions. 
	           axi_awready <= '1';
	           aw_en <= '0';
	        elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then
	           aw_en <= '1';
	           axi_awready <= '0';
	      else
	        axi_awready <= '0';
	      end if;
	    end if;
	  end if;
	end process;

	-- Implement axi_awaddr latching
	-- This process is used to latch the address when both 
	-- S_AXI_AWVALID and S_AXI_WVALID are valid. 

	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
	      axi_awaddr <= (others => '0');
	    else
	      if (axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' and aw_en = '1') then
	        -- Write Address latching
	        axi_awaddr <= S_AXI_AWADDR;
	      end if;
	    end if;
	  end if;                   
	end process; 

	-- Implement axi_wready generation
	-- axi_wready is asserted for one S_AXI_ACLK clock cycle when both
	-- S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
	-- de-asserted when reset is low. 

	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
	      axi_wready <= '0';
	    else
	      if (axi_wready = '0' and S_AXI_WVALID = '1' and S_AXI_AWVALID = '1' and aw_en = '1') then
	          -- slave is ready to accept write data when 
	          -- there is a valid write address and write data
	          -- on the write address and data bus. This design 
	          -- expects no outstanding transactions.           
	          axi_wready <= '1';
	      else
	        axi_wready <= '0';
	      end if;
	    end if;
	  end if;
	end process; 

	-- Implement memory mapped register select and write logic generation
	-- The write data is accepted and written to memory mapped registers when
	-- axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
	-- select byte enables of slave registers while writing.
	-- These registers are cleared when reset (active low) is applied.
	-- Slave register write enable is asserted when valid address and data are available
	-- and the slave is ready to accept the write address and write data.
	slv_reg_wren <= axi_wready and S_AXI_WVALID and axi_awready and S_AXI_AWVALID ;

	process (S_AXI_ACLK)
	variable loc_addr :std_logic_vector(OPT_MEM_ADDR_BITS downto 0); 
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
	      slv_reg0 <= (others => '0');
	      slv_reg1 <= (others => '0');
	      slv_reg3 <= (others => '0');
	      slv_reg4 <= (others => '0');
	      slv_reg5 <= (others => '0');
	      slv_reg6 <= (others => '0');
	      slv_reg7 <= (others => '0');
	    else
	      loc_addr := axi_awaddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
	      if (slv_reg_wren = '1') then
	        case loc_addr is
	          when b"0000" =>
	            for byte_index in 0 to (S_AXI_DATA_WIDTH/8-1) loop
	              if ( S_AXI_WSTRB(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 0
	                slv_reg0(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"0001" =>
	            for byte_index in 0 to (S_AXI_DATA_WIDTH/8-1) loop
	              if ( S_AXI_WSTRB(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 1
	                slv_reg1(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"0011" =>
	            for byte_index in 0 to (S_AXI_DATA_WIDTH/8-1) loop
	              if ( S_AXI_WSTRB(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 3
	                slv_reg3(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"0100" =>
	            for byte_index in 0 to (S_AXI_DATA_WIDTH/8-1) loop
	              if ( S_AXI_WSTRB(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 4
	                slv_reg4(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"0101" =>
	            for byte_index in 0 to (S_AXI_DATA_WIDTH/8-1) loop
	              if ( S_AXI_WSTRB(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 5
	                slv_reg5(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"0110" =>
	            for byte_index in 0 to (S_AXI_DATA_WIDTH/8-1) loop
	              if ( S_AXI_WSTRB(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 6
	                slv_reg6(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"0111" =>
	            for byte_index in 0 to (S_AXI_DATA_WIDTH/8-1) loop
	              if ( S_AXI_WSTRB(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 7
	                slv_reg7(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when others =>
	            slv_reg0 <= slv_reg0;
	            slv_reg1 <= slv_reg1;
	            slv_reg3 <= slv_reg3;
	            slv_reg4 <= slv_reg4;
	            slv_reg5 <= slv_reg5;
	            slv_reg6 <= slv_reg6;
	            slv_reg7 <= slv_reg7;
	        end case;
	      end if;
	    end if;
	  end if;                   
	end process; 

	-- Implement write response logic generation
	-- The write response and response valid signals are asserted by the slave 
	-- when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
	-- This marks the acceptance of address and indicates the status of 
	-- write transaction.

	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
	      axi_bvalid  <= '0';
	      axi_bresp   <= "00"; --need to work more on the responses
	    else
	      if (axi_awready = '1' and S_AXI_AWVALID = '1' and axi_wready = '1' and S_AXI_WVALID = '1' and axi_bvalid = '0'  ) then
	        axi_bvalid <= '1';
	        axi_bresp  <= "00"; 
	      elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then   --check if bready is asserted while bvalid is high)
	        axi_bvalid <= '0';                                 -- (there is a possibility that bready is always asserted high)
	      end if;
	    end if;
	  end if;                   
	end process; 

	-- Implement axi_arready generation
	-- axi_arready is asserted for one S_AXI_ACLK clock cycle when
	-- S_AXI_ARVALID is asserted. axi_awready is 
	-- de-asserted when reset (active low) is asserted. 
	-- The read address is also latched when S_AXI_ARVALID is 
	-- asserted. axi_araddr is reset to zero on reset assertion.

	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
	      axi_arready <= '0';
	      axi_araddr  <= (others => '1');
	    else
	      if (axi_arready = '0' and S_AXI_ARVALID = '1') then
	        -- indicates that the slave has acceped the valid read address
	        axi_arready <= '1';
	        -- Read Address latching 
	        axi_araddr  <= S_AXI_ARADDR;           
	      else
	        axi_arready <= '0';
	      end if;
	    end if;
	  end if;                   
	end process; 

	-- Implement axi_arvalid generation
	-- axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
	-- S_AXI_ARVALID and axi_arready are asserted. The slave registers 
	-- data are available on the axi_rdata bus at this instance. The 
	-- assertion of axi_rvalid marks the validity of read data on the 
	-- bus and axi_rresp indicates the status of read transaction.axi_rvalid 
	-- is deasserted on reset (active low). axi_rresp and axi_rdata are 
	-- cleared to zero on reset (active low).  
	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then
	    if S_AXI_ARESETN = '0' then
	      axi_rvalid <= '0';
	      axi_rresp  <= "00";
	    else
	      if (axi_arready = '1' and S_AXI_ARVALID = '1' and axi_rvalid = '0') then
	        -- Valid read data is available at the read data bus
	        axi_rvalid <= '1';
	        axi_rresp  <= "00"; -- 'OKAY' response
	      elsif (axi_rvalid = '1' and S_AXI_RREADY = '1') then
	        -- Read data is accepted by the master
	        axi_rvalid <= '0';
	      end if;            
	    end if;
	  end if;
	end process;

	-- Implement memory mapped register select and read logic generation
	-- Slave register read enable is asserted when valid address is available
	-- and the slave is ready to accept the read address.
	slv_reg_rden <= axi_arready and S_AXI_ARVALID and (not axi_rvalid) ;

	process (slv_reg0, slv_reg2, slv_reg3, slv_reg4, slv_reg5, slv_reg6, slv_reg7, slv_reg8, slv_reg9, slv_reg10, slv_reg11, slv_reg12, slv_reg13, slv_reg14, slv_reg15, axi_araddr, S_AXI_ARESETN, slv_reg_rden)
	variable loc_addr :std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
	begin
	    -- Address decoding for reading registers
	    loc_addr := axi_araddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
	    case loc_addr is
	      when b"0000" =>
	        reg_data_out <= slv_reg0;
	      when b"0010" =>
	        reg_data_out <= slv_reg2;
	      when b"0011" =>
	        reg_data_out <= slv_reg3;
	      when b"0100" =>
	        reg_data_out <= slv_reg4;
	      when b"0101" =>
	        reg_data_out <= slv_reg5;
	      when b"0110" =>
	        reg_data_out <= slv_reg6;
	      when b"0111" =>
	        reg_data_out <= slv_reg7;
	      when b"1000" =>
	        reg_data_out <= slv_reg8;
	      when b"1001" =>
	        reg_data_out <= slv_reg9;
	      when b"1010" =>
	        reg_data_out <= slv_reg10;
	      when b"1011" =>
	        reg_data_out <= slv_reg11;
	      when b"1100" =>
	        reg_data_out <= slv_reg12;
	      when b"1101" =>
	        reg_data_out <= slv_reg13;
	      when b"1110" =>
	        reg_data_out <= slv_reg14;
	      when b"1111" =>
	        reg_data_out <= slv_reg15;
	      when others =>
	        reg_data_out  <= (others => '0');
	    end case;
	end process; 

	-- Output register or memory read data
	process( S_AXI_ACLK ) is
	begin
	  if (rising_edge (S_AXI_ACLK)) then
	    if ( S_AXI_ARESETN = '0' ) then
	      axi_rdata  <= (others => '0');
	    else
	      if (slv_reg_rden = '1') then
	        -- When there is a valid read address (S_AXI_ARVALID) with 
	        -- acceptance of read address by the slave (axi_arready), 
	        -- output the read dada 
	        -- Read address mux
	          axi_rdata <= reg_data_out;     -- register read data
	      end if;   
	    end if;
	  end if;
	end process;
    
    -- Axi Registers
    process (s_axi_aclk, s_axi_aresetn)
    begin
        if s_axi_aresetn = '0' then
            regs <= (others => (others => '0')); -- Reset all registers to zero when reset is active
        elsif rising_edge(s_axi_aclk) then
            -- These come from outside
            regs(control_reg_offset)  <= slv_reg1;
            regs(pwm_reg_offset_a)  <= slv_reg3;
            regs(pwm_reg_offset_b)  <= slv_reg4;
            regs(dir_reg_offset)  <= slv_reg5;
            
            -- these come from inside
            slv_reg2 <= status_reg; -- status_reg_offset
            enc_reg_loop: for i in 0 to nMOTORS-1 loop
                regs(i+enc_offset_offset) <= encs_o(i);
            end loop;
            slv_reg8    <= regs(enc_offset_offset);
            slv_reg9    <= regs(enc_offset_offset+1);
            slv_reg10   <= regs(enc_offset_offset+2);
            slv_reg11   <= regs(enc_offset_offset+3);
            slv_reg12   <= regs(enc_offset_offset+4);
            slv_reg13   <= regs(enc_offset_offset+5);
            slv_reg14   <= regs(enc_offset_offset+6);
            slv_reg15   <= regs(enc_offset_offset+7);                
        end if;
    end process;

    -- Register and Split Control and Status Reg
    motor_dir <= regs(dir_reg_offset);
    process(s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if reset_reg = '1' then
                control_reg <= (others => '0');
            else
                control_reg <= regs(control_reg_offset);
            end if;
        end if;
    end process;

    motor_pwm_a_gen: if (nMOTORS <= 4) generate
        process(regs(pwm_reg_offset_a))
        begin
            for i in 0 to nMOTORS-1 loop
                motor_pwm(i) <= regs(pwm_reg_offset_a)(pwm_bits*(i+1)-1 downto pwm_bits*i);
            end loop;
        end process;
    end generate ;

	motor_pwm_b_gen : if (nMOTORS > 4 and nMOTORS <= 8) generate
	    process(regs(pwm_reg_offset_b))
        begin
            for i in 0 to (nMOTORS-4)-1 loop
                motor_pwm(i+4) <= regs(pwm_reg_offset_b)(pwm_bits*(i+1)-1 downto pwm_bits*i);
            end loop;
        end process;
    end generate ;
    
	register_proc: process(s_axi_aclk, s_axi_aresetn) is
    begin
        if s_axi_aresetn = '0' then
            commit <= '0';
            status_reg <= (others => '0');
        else   
            if rising_edge(s_axi_aclk) then
                commit <= control_reg(0);
                status_reg(1) <= busy_pwm;
                status_reg(0) <= busy_logic;
            end if;
        end if;
    end process;

    -- Registers for Encoder Counter
    enc_proc : for i in 0 to nMOTORS-1 generate
        encs_o(i) <= enc_count_o(((i+1)*encBit_res)-1 downto i*encBit_res);
    end generate ;
    
    -- Motor Driver Control FSM
    fsm_pwm: process(s_axi_aclk, s_axi_aresetn)
        variable ii : integer := 0;
    begin
        if s_axi_aresetn = '0' then
            ii := 0;
            busy_logic 		<= busy_pwm;
            ip_motor_set 	<= '0';
            ip_motor_duty  	<= (others => '0');
            ip_motor_dir  	<= '0';
            ip_motor_id  	<= (others => '0');
			reset_reg 		<= '0'; 
        elsif rising_edge(s_axi_aclk) then
            case state is
                when IDLE =>
                    ii := 0;
                    ip_motor_set <= '0';
					reset_reg <= '0'; 
                    if commit = '1' then
                        state <= commit_log;
                        busy_logic <= '1'; 
                    else
                        busy_logic <= '0';
                    end if;
                
                when commit_log =>
                    if (ii < nMOTORS) then
                        ip_motor_duty <= motor_pwm(ii);
                        ip_motor_dir <= motor_dir(ii);
                        ip_motor_id <= std_logic_vector(to_unsigned(ii, ip_motor_id'length));
                        ip_motor_set <= '1';
                        state <= wait_busy;
                    else
                        ip_motor_set <= '0';
                        state <= releasing;
                    end if;
                    
                when wait_busy =>
                    busy_logic <= '1';
                    ip_motor_set <= '0';
                    state <= working;

                when working =>
                    busy_logic <= '1';
                    ip_motor_set <= '0';
                    if (busy_pwm = '0') then
                        state <= commit_log;
						ii := ii + 1;
                    else
						state <= working;
                    end if;

                when releasing =>
                    busy_logic <= '0';
                    ip_motor_set <= '0';
                    reset_reg <= '1';
                    ii := 0;
                    state <= IDLE;

                when others =>
                    ii := 0;
                    reset_reg <= '0';
                    busy_logic <= '0';
                    ip_motor_set <= '0';
            
            end case;
        end if;
    end process;
    
	-- User logic ends --

end Behavioral;

