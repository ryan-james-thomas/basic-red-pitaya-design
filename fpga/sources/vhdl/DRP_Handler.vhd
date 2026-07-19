library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;


entity DRP_Handler is
    port (
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;
        
        start_i     :   in  std_logic_vector(1 downto 0);
        
        
        
        drp_den     :   out std_logic;
        drp_dwe     :   out std_logic;
        drp_drdy    :   in  std_logic;
        drp_do      :   out std_logic_vector(15 downto 0);
        drp_din     :   in  std_logic_vector(15 downto 0);
        drp_daddr   :   out std_logic_vector(6 downto 0)
    );
end DRP_Handler;

architecture Behavioral of DRP_Handler is

begin


end Behavioral;
