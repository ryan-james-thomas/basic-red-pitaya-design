library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity topmod_tb is
--  Port ( );
end topmod_tb;

architecture Behavioral of topmod_tb is

component topmod is
    port (
        --
        -- Clocks and reset
        --
        sysClk          :   in  std_logic;
        adcClk          :   in  std_logic;
        aresetn         :   in  std_logic;
        --
        -- AXI-super-lite signals
        --      
        addr_i          :   in  unsigned(AXI_ADDR_WIDTH-1 downto 0);            --Address out
        writeData_i     :   in  std_logic_vector(AXI_DATA_WIDTH-1 downto 0);    --Data to write
        dataValid_i     :   in  std_logic_vector(1 downto 0);                   --Data valid out signal
        readData_o      :   out std_logic_vector(AXI_DATA_WIDTH-1 downto 0);    --Data to read
        resp_o          :   out std_logic_vector(1 downto 0);                   --Response in
        --
        -- External I/O
        --
        ext_i           :   in  std_logic_vector(7 downto 0);
        ext_o           :   out std_logic_vector(7 downto 0);
        --
        -- ADC data
        --
        adcData_i       :   in  std_logic_vector(31 downto 0);
        --
        -- DAC data
        --
        m_axis_tdata    :   out std_logic_vector(31 downto 0);
        m_axis_tvalid   :   out std_logic
    );
end component;

component AXI_Tester is
    port (
        --
        -- Clocking and reset
        --
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;
        --
        -- Main AXI data to transfer
        --
        axi_addresses   :   in  t_axi_addr_array;
        axi_data        :   in  t_axi_data_array;
        start_i         :   in  std_logic;
        --
        -- Single data to transfer
        --
        axi_addr_single :   in  t_axi_addr;
        axi_data_single :   in  t_axi_data;
        start_single_i  :   in  std_logic_vector(1 downto 0);
        --
        -- Signals
        --
        bus_m           :   out t_axi_bus_master;
        bus_s           :   in  t_axi_bus_slave
    );
end component;

--
-- Clocks and reset
--
signal clk_period   :   time    :=  10 ns;
signal sysClk,adcClk:   std_logic;
signal aresetn      :   std_logic;
--
-- ADC and DAC data
--
signal adcData_i    :   std_logic_vector(31 downto 0);
signal m_axis_tdata :   std_logic_vector(31 downto 0);
signal m_axis_tvalid:   std_logic;
--
-- External inputs and outputs
--
signal ext_i,ext_o  :   std_logic_vector(7 downto 0);
--
-- AXI signals
--
signal addr_i                   :   unsigned(AXI_ADDR_WIDTH-1 downto 0);
signal writeData_i, readData_o  :   std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
signal dataValid_i, resp_o      :   std_logic_vector(1 downto 0);
signal bus_m                    :   t_axi_bus_master;
signal bus_s                    :   t_axi_bus_slave;

--
-- AXI data
--

constant axi_addresses   :   t_axi_addr_array(3 downto 0)  :=   (0  =>  X"00000000",
                                                                 1  =>  X"00000004",
                                                                 2  =>  X"00000014",
                                                                 3  =>  X"00000018");

signal axi_data :   t_axi_data_array(axi_addresses'length - 1 downto 0);          

signal triggers, outputReg          :   t_param_reg;
signal dds_phase_inc_reg            :   t_param_reg;
signal dds_phase_off_reg            :   t_param_reg;

--
-- AXI control signals
--
signal startAXI     :   std_logic;
signal axi_addr_single  :   t_axi_addr;
signal axi_data_single  :   t_axi_data;
signal start_single_i   :   std_logic_vector(1 downto 0);

begin

clk_proc: process is
begin
    sysClk <= '0';
    adcClk <= '0';
    wait for clk_period/2;
    sysClk <= '1';
    adcClk <= '1';
    wait for clk_period/2;
end process;

uut: topmod
port map(
    sysclk          =>  sysclk,
    adcclk          =>  adcclk,
    aresetn         =>  aresetn,
    addr_i          =>  addr_i,
    writeData_i     =>  writeData_i,
    dataValid_i     =>  dataValid_i,
    readData_o      =>  readData_o,
    resp_o          =>  resp_o,
    ext_i           =>  ext_i,
    ext_o           =>  ext_o,
    m_axis_tdata    =>  m_axis_tdata,
    m_axis_tvalid   =>  m_axis_tvalid,
    adcData_i       =>  adcData_i
);

AXI: AXI_Tester
port map(
    clk             =>  sysClk,
    aresetn         =>  aresetn,
    axi_addresses   =>  axi_addresses,
    axi_data        =>  axi_data,
    start_i         =>  startAXI,
    axi_addr_single =>  axi_addr_single,
    axi_data_single =>  axi_data_single,
    start_single_i  =>  start_single_i,
    bus_m           =>  bus_m,
    bus_s           =>  bus_s
);
addr_i <= bus_m.addr;
writeData_i <= bus_m.data;
dataValid_i <= bus_m.valid;
bus_s.data <= readData_o;
bus_s.resp <= resp_o;

--
-- Assign AXI registers
--
axi_data <= (0  =>  triggers,
             1  =>  outputReg,
             2  =>  dds_phase_inc_reg,
             3  =>  dds_phase_off_reg
             );

adcData_i <= m_axis_tdata;

main_proc: process is
begin
    --
    -- Initialize the registers and reset
    --
    aresetn <= '0';
    wait for 50 ns;
    startAXI <= '0';
    ext_i <= (others => '0');
    triggers <= (others => '0');
    outputReg <= (others => '0');
    dds_phase_inc_reg <= std_logic_vector(to_unsigned(34359738,32));
    dds_phase_off_reg <= (others => '0');
    
    axi_addr_single <= (others => '0');
    axi_data_single <= (others => '0');
    start_single_i <= "00";
    wait for 200 ns;
    aresetn <= '1';
    wait for 100 ns;
    --
    -- Start AXI transfer
    --
    wait until rising_edge(sysclk);
    startAXI <= '1';
    wait until rising_edge(sysclk);
    startAXI <= '0';
    wait for 10 us;
    --
    -- Change DDS frequency
    --
    wait until rising_edge(sysclk);
    axi_addr_single <= X"0000_0014";
    axi_data_single <= std_logic_vector(to_unsigned(343597380,32));
    start_single_i <= "01";
    wait until bus_s.resp(0) = '1';
    start_single_i <= "00";
    wait for 500 ns;

    wait;
end process; 


end Behavioral;
