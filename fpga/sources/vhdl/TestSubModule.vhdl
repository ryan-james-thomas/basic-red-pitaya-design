library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity TestSubModule is
    generic(
        TOP_ADDR:   t_axi_top_addr
    );
    port (
        clk     :   in  std_logic;
        aresetn :   in  std_logic;

        bus_m   :   in  t_axi_bus_master;
        bus_s   :   out t_axi_bus_slave

    );
end TestSubModule;

architecture rtl of TestSubModule is

signal test_register    :   t_param_reg;
signal com_state        :   t_status;

begin

Parse: process(clk,aresetn) is
begin
    if aresetn = '0' then
        test_register <= (others => '0');
        com_state <= idle;
        bus_s <= INIT_AXI_BUS_SLAVE;
    elsif rising_edge(clk) then
        FSM: case(com_state) is
            when idle => 
                bus_s.resp <= "00";
                if bus_m.valid(0) = '1' and compare_top_axi_addr(bus_m,TOP_ADDR) then
                    com_state <= processing;
                end if;

            when processing =>
                AddrCase: case(bus_m.addr(7 downto 0)) is
                    when X"00" => rw(bus_m,bus_s,com_state,test_register);
                    when others =>
                        com_state <= finishing;
                        bus_s.resp <= "11";
                end case;

            when finishing =>
                com_state <= idle;

            when others => com_state <= idle;
            
        end case;
    end if;
end process;


end architecture rtl;