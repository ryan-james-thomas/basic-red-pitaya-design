"""Defines classes for control of the basic Red Pitaya design

Classes
JumperType(Enum) -- Enumerated type for different input jumper settings
DeviceControlSubModule(redpitaya.DeviceSubModule) -- Represents the submodules in the basic design
DeviceControl -- Represents the main design
"""
import libserver
import redpitaya
from enum import Enum

class JumperType(Enum):
    """Represents the LV or HV ADC input jumper settings"""
    LV = 0
    HV = 1

class DeviceControlSubModule(redpitaya.DeviceSubModule):
    def __init__(self, parent, offset: int):
        """Creates an instance of the sub modules
        
        Arguments
        parent -- The parent device
        offset -- The top-level address offset of this module
        """
        self._parent = parent
        self._offset = offset

        self._reg = redpitaya.DeviceRegister(0, self._parent._conn, offset=self._offset)
        self.p = redpitaya.DeviceParameter([0, 31], self._reg)

    def set_defaults(self):
        """Sets the default values"""
        self.p.set(0)

    def print(self, width: int=20):
        """Prints a summary of the module's parameters
        
        Arguments
        width: int -- Width of the parameter name field
        """
        s = self.p.print("Parameter", width, "#010x")
        return s


class DeviceControl:

    CLK = 125e6
    DAC_WIDTH = 14
    ADC_WIDTH = 14
    MAX_ADC_LV = 1.1851
    MAX_ADC_HV = 29.3570

    NUM_PWM = 4
    MAX_PWM = 1.62
    PWM_WIDTH = 8
    
    NUM_SLOW_ADC = 4
    MAX_SLOW_ADC = (30 + 4.99)/4.99
    SLOW_ADC_WIDTH = 16

    TOP_ADDR = 0x40000000
    XADC_ADDR_OFFSET = 0x00020000
    BLOCK_MEM_ADDRESS_OFFSET = 0x00010000
    BLOCK_MEM_DEPTH = 256

    def __init__(self, server_target):
        """Creates an instance of the class
        
        Arguments
        server_target -- A string indicating the server host, or a tuple of
            (server host name, port)
        """
        # Create client connection object
        self._conn = libserver.ClientConnection(server_target)
        # Create extra parameters
        self.jumpers = [JumperType.LV] * 2
        self.max_dac_voltages = [1,1]
        #
        # Create registers
        #
        self._trig_reg = redpitaya.DeviceRegister(0x0, self._conn, offset=self.TOP_ADDR)
        self._output_reg = redpitaya.DeviceRegister(0x4, self._conn, offset=self.TOP_ADDR)
        self._dac_reg = redpitaya.DeviceRegister(0x8, self._conn, offset=self.TOP_ADDR)
        self._adc_reg = redpitaya.DeviceRegister(0xC, self._conn, read_only=True, offset=self.TOP_ADDR)
        self._input_reg = redpitaya.DeviceRegister(0x10, self._conn, read_only=True, offset=self.TOP_ADDR)
        self._pwm_reg = redpitaya.DeviceRegister(0x14, self._conn, offset=self.TOP_ADDR)
        self._slow_adc_regs = redpitaya.DeviceRegisterList()
        for i in range(self.NUM_SLOW_ADC):
            match i:
                case 0:
                    addr = 0x18
                case 1:
                    addr = 0x10
                case 2:
                    addr = 0x11
                case 3:
                    addr = 0x19
            self._slow_adc_regs.append(
                redpitaya.DeviceRegister(addr, self._conn, read_only=True, offset=self.TOP_ADDR + self.XADC_ADDR_OFFSET)
            )
        #
        # Create parameters
        #
        self.dacs = redpitaya.DeviceParameterList()
        for nn in range(2):
            self.dacs.append(
                redpitaya.DeviceParameter(
                    [16*nn, 16*(nn + 1) - 1], self._dac_reg, redpitaya.ParamType.INT16,
                    to_int=lambda x, idx=nn: self.convert_dac_volts_to_int(x, idx),
                    from_int=lambda x, idx=nn: self.convert_dac_int_to_volts(x, idx),
                    lower_limit=-self.max_dac_voltages[nn],
                    upper_limit=self.max_dac_voltages[nn],
                    units="V")
        )

        self.adcs = redpitaya.DeviceParameterList()
        for nn in range(2):
            self.adcs.append(
                redpitaya.DeviceParameter(
                    [16*nn, 16*(nn + 1) - 1], self._adc_reg, redpitaya.ParamType.INT16,
                    to_int=lambda x, idx=nn: self.convert_adc_volts_to_int(x, idx),
                    from_int=lambda x, idx=nn: self.convert_adc_int_to_volts(x, idx),
                    units="V")
        )

        self.ext_i = redpitaya.DeviceParameter([0, 7], self._input_reg)
        self.ext_o = redpitaya.DeviceParameter([0, 7], self._output_reg, lower_limit=0, upper_limit=255)
        self.led_o = redpitaya.DeviceParameter([8, 15], self._output_reg, lower_limit=0, upper_limit=255)

        self.pwms = redpitaya.DeviceParameterList()
        for nn in range(self.NUM_PWM):
            self.pwms.append(
                redpitaya.DeviceParameter(
                    [8*nn, 8*(nn + 1) - 1], self._pwm_reg,
                    to_int=lambda x: x/self.MAX_PWM*(2**self.PWM_WIDTH - 1),
                    from_int=lambda x: x*self.MAX_PWM/(2**self.PWM_WIDTH - 1),
                    lower_limit=0, upper_limit=self.MAX_PWM,
                    units="V")
                )

        self.slow_adcs = redpitaya.DeviceParameterList()
        for nn in range(self.NUM_SLOW_ADC):
            self.slow_adcs.append(
                redpitaya.DeviceParameter(
                    [8*nn, 8*(nn + 1) - 1], self._slow_adc_regs[nn],
                    to_int=lambda x: x*2**(self.SLOW_ADC_WIDTH)/self.MAX_SLOW_ADC,
                    from_int=lambda x: x/2**(self.SLOW_ADC_WIDTH)*self.MAX_SLOW_ADC,
                    units="V")
                )
        #
        # Create sub modules
        #
        self.sub_module_a = DeviceControlSubModule(self, self.TOP_ADDR + 0x03000000)
        self.sub_module_b = DeviceControlSubModule(self, self.TOP_ADDR + 0x04000000)


    def set_defaults(self):
        """Set default values"""
        self.dacs.set(0)
        self.ext_o.set(0)
        self.led_o.set(0)
        self.pwms.set(0)
        self.sub_module_a.set_defaults()
        self.sub_module_b.set_defaults()

    def upload(self):
        """Upload configuration to FPGA"""
        d = []
        for p in self.__dict__.values():
            if hasattr(p, "get_write_data"):
                d.extend(p.get_write_data())

        self._conn.write(d, mode="write")

    def fetch(self):
        """Retrieve configuration from FPGA"""
        d = []
        R = []
        for p in self.__dict__.values():
            if hasattr(p, "get_read_data"):
                tmp = p.get_read_data()
                d.extend(tmp[0])
                R.extend(tmp[1])

        self._conn.write(d, mode="read")
        for key, value in enumerate(self._conn.recv_data):
            R[key].value = value

        for p in self.__dict__.values():
            if isinstance(p,(redpitaya.DeviceParameter, redpitaya.DeviceParameterList, redpitaya.DeviceSubModule)):
                p.get()


    def convert_dac_int_to_volts(self, x: int , idx: int) -> float:
        """Convert DAC values from integer to volts
        
        Arguments
        x: int -- Integer value to convert
        idx: int -- DAC to convert from, since max DAC voltages can be DAC-dependent
        """
        return x/(2**(self.DAC_WIDTH - 1) - 1)*self.max_dac_voltages[idx]

    def convert_dac_volts_to_int(self, x: float, idx: int) -> int:
        """Convert DAC values from volts to an integer
        
        Arguments
        x: float -- Physical value to convert
        idx: int -- DAC to convert from, since max DAC voltages can be DAC-dependent
        """
        return int(x/self.max_dac_voltages[idx]*(2**(self.DAC_WIDTH - 1) - 1))

    def convert_adc_int_to_volts(self, x, idx) -> float:
        """Convert ADC values from integer to volts
        
        Arguments
        x: int -- Integer value to convert
        idx: int -- ADC to convert from, since ADC jumper settings can be different
        """
        match self.jumpers[idx]:
            case JumperType.LV:
                max_adc_voltage = self.MAX_ADC_LV
            case JumperType.HV:
                max_adc_voltage = self.MAX_ADC_HV
            case _:
                raise ValueError("Jumper values must be of type 'JumperType'")

        return x/(2**(self.ADC_WIDTH - 1) - 1)*max_adc_voltage

    def convert_adc_volts_to_int(self, x, idx) -> int:
        """Convert ADC values from volts to an integer
        
        Arguments
        x: float -- Physical value to convert
        idx: int -- ADC to convert from, since ADC jumper settings can be different
        """
        match self.jumpers[idx]:
            case JumperType.LV:
                max_adc_voltage = self.MAX_ADC_LV
            case JumperType.HV:
                max_adc_voltage = self.MAX_ADC_HV
            case _:
                raise ValueError("Jumper values must be of type 'JumperType'")

        return int(x/max_adc_voltage*(2**(self.ADC_WIDTH - 1) - 1))

    def get_xadc_status(self) -> dict:
        """Retrieves the FPGA status via the XADC interface
        
        Returns a dict with available properties"""
        reg = redpitaya.DeviceRegister(0, self._conn, read_only=True, offset=self.TOP_ADDR + self.XADC_ADDR_OFFSET)
        volt_conv = lambda x: 3*x/2**16
        info = {
            "Temperature": [0x00, lambda x: x/2**16*503.975 - 273.15],
            "VCCINT": [0x01, volt_conv],
            "VCCAUX": [0x02, volt_conv],
            "VCCSUPPLY": [0x03, lambda x: x/2**16*(56 + 4.99)/4.99],
            "VCCBRAM": [0x06, volt_conv],
            "VCCPINT": [0x0d, volt_conv],
            "VCCPAUX": [0x0e, volt_conv],
            "VCCO_DDR": [0x0f, volt_conv],
        }
        data = info.copy()
        for key, value in info.items():
            reg.set_addr(value[0]*4)
            reg.read()
            data[key] = value[1](reg.value)

        return data

    def mem_write(self, data: list):
        """Simple test of writing data to the block memory
        
        Arguments:
        data: list -- integer data to write
        """
        reg = redpitaya.DeviceRegister(0, self._conn, offset=self.TOP_ADDR + self.BLOCK_MEM_ADDRESS_OFFSET)
        if len(data) > self.BLOCK_MEM_DEPTH:
            raise ValueError("Size of data exceeds block memory depth of {:d}".format(self.BLOCK_MEM_DEPTH))
        d = []
        for nn in range(len(data)):
            reg.set_addr(nn*4)
            reg.value = data[nn] & 0xFFFFFFFF
            d.extend(reg.get_write_data())
        self._conn.write(d, mode="write")

    def mem_read(self, num_samples: int=BLOCK_MEM_DEPTH) -> list[int]:
        """Simple test of reading data from the block memory
        
        Arguments:
        num_samples: int -- Number of samples to read

        Returns a list containing the data read from the block memory
        """
        reg = redpitaya.DeviceRegister(0, self._conn, offset=self.TOP_ADDR + self.BLOCK_MEM_ADDRESS_OFFSET)
        if num_samples > self.BLOCK_MEM_DEPTH:
            raise ValueError("Number of samples exceeds block memory depth of {:d}".format(self.BLOCK_MEM_DEPTH))
        d = []
        for nn in range(num_samples):
            reg.set_addr(nn*4)
            d.extend(reg.get_read_data()[0])
        self._conn.write(d, mode="read")
        value = self._conn.recv_data
        data = []
        for nn in range(len(value)):
            data.append(redpitaya.typecast(value[nn],redpitaya.ParamType.INT32))
        return data

    def __str__(self):
        width = 20
        s = (
            "DeviceControl object with properties:\n" \
            "\t Registers:\n"
            )
        for key, item in self.__dict__.items():
            if isinstance(item,redpitaya.DeviceRegister) or isinstance(item,redpitaya.DeviceRegisterList):
                s += item.print(key, width)

        s += (
            "\t ----------------------------------\n" \
            "\t Parameters\n"
            )
        s += self.led_o.print("LEDs", width, "#04x")
        s += self.ext_o.print("External output", width, "#04x")
        s += self.ext_i.print("External input", width, "#04x")
        s += self.dacs[0].print("DAC 0", width, " .3f")
        s += self.dacs[1].print("DAC 1", width, " .3f")
        s += self.adcs[0].print("ADC 0", width, " .3f")
        s += self.adcs[1].print("ADC 1", width, " .3f")
        s += self.pwms.print("PWM", width, " .3f")
        s += self.slow_adcs.print("Slow ADC", width, " .3f")
        s += (
            "\t ----------------------------------\n" \
            "\t Sub Module A\n"
            )
        s += self.sub_module_a.print(width)
        s += (
            "\t ----------------------------------\n" \
            "\t Sub Module B\n"
            )
        s += self.sub_module_b.print(width)

        return s


