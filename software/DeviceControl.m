classdef DeviceControl < handle
    %DEVICECONTROL Defines a class for controlling the basic Red Pitaya
    %design.  The red-pitaya-interface folder needs to be in your path
    properties
        jumpers         % The input jumper setting, either 'lv' or 'hv'
        max_dac_voltages% Maximum DAC voltage, depends on RP version and load
    end
    
    properties(SetAccess = immutable)
        conn            % This is a ConnectionClient object that communicates with the socket server on the Red Pitaya
        dac             % 2-element DeviceParameter array that represents the fast DAC values
        ext_o           % DeviceParameter object that represents the digital outputs
        adc             % 2-element DeviceParameter array that represents the fast ADC values
        ext_i           % DeviceParameter object that represents the digital inputs
        led_o           % DeviceParameter object that represents the LED settings
        pwm             % 4-element DeviceParameter array that represents the PWM output values
        slow_adcs       % 4-element DeviceParameter array that represents the slow ADC values
    end
    
    properties(SetAccess = protected)
        trigReg         % Register handling internal trigger settings
        outputReg       % Register dealing with digital outputs
        inputReg        % Register dealing with digital inputs
        dacReg          % Register dealing with fast DAC signals
        adcReg          % Register dealing with fast ADC signals
        pwmReg          % Register dealing with PWM output signals
        slowADCRegs     % Registers (4) dealing with slow ADC signals
    end
    
    properties(Constant)
        CLK = 125e6;                                            % Clock frequency
        DAC_WIDTH = 14;                                         % Bit width of DAC signals
        ADC_WIDTH = 14;                                         % Bit width of ADC signals
        CONV_LV = 1.1851/2^(DeviceControl.ADC_WIDTH - 1);       % Conversion factor for ADC signals on jumper 'lv' setting
        CONV_HV = 29.3570/2^(DeviceControl.ADC_WIDTH - 1);      % Conversion factor for ADC signals on jumper 'hv' setting
        NUM_PWM = 4;                                            % Number of PWM outputs
        NUM_SLOW_ADC = 4;                                       % Number of "slow" ADCs
        TOP_ADDR = 0x40000000;                                  % Top level address
        XADC_ADDRESS_OFFSET = 0x00020000;                       % Address offset for accessing the XADC registers
        BLOCK_MEM_ADDRESS_OFFSET = 0x01000000;                  % Address offset for accessing block memory
        BLOCK_MEM_DEPTH = 256;                                  % Depth of block memory
    end
    
    methods
        function self = DeviceControl(host_address)
            %DEVICECONTROL Constructs a DeviceControl object
            %
            %   SELF = DEVICECONTROL(HOST_ADDRESS) Creats a DeviceControl
            %   object with a given host address
            self.conn = ConnectionClient(host_address);
            % Set the jumpers to low voltage (+/- 1 V inputs)
            self.jumpers = 'lv';
            % Set the maximum DAC voltage to 1 V.
            self.max_dac_voltages = [1,1];
            %
            % Create registers
            %
            self.trigReg = DeviceRegister('0',self.conn,self.TOP_ADDR);
            self.outputReg = DeviceRegister('4',self.conn,self.TOP_ADDR);
            self.dacReg = DeviceRegister('8',self.conn,self.TOP_ADDR);
            self.adcReg = DeviceRegister('C',self.conn,true,self.TOP_ADDR);
            self.inputReg = DeviceRegister('10',self.conn,true,self.TOP_ADDR);
            self.pwmReg = DeviceRegister('14',self.conn,self.TOP_ADDR);
            self.slowADCRegs = DeviceRegister.empty;
            for nn = 1:self.NUM_SLOW_ADC
                % The physical routing on the Red Pitaya board is a bit
                % messed up and doesn't make a lot of sense; hence, the
                % switch logic below
                switch nn
                    case 1
                        addr_offset = 0x18;
                    case 2
                        addr_offset = 0x10;
                    case 3
                        addr_offset = 0x11;
                    case 4
                        addr_offset = 0x19;
                end
                self.slowADCRegs(nn,1) = DeviceRegister(addr_offset,self.conn,true,self.TOP_ADDR + self.XADC_ADDRESS_OFFSET);
            end
            %
            % Create DeviceParameter objects
            %
            % Fast DACs
            self.dac = DeviceParameter([0,15],self.dacReg,'int16')...
                .setLimits('lower',-1,'upper',1)...
                .setFunctions('to',@(x) x/self.convert_dac_int_to_volts(1),'from',@(x) x*self.convert_dac_int_to_volts(1));
            
            self.dac(2) = DeviceParameter([16,31],self.dacReg,'int16')...
                .setLimits('lower',-1,'upper',1)...
                .setFunctions('to',@(x) x/self.convert_dac_int_to_volts(2),'from',@(x) x*self.convert_dac_int_to_volts(2));
            % Fast ADCS
            self.adc = DeviceParameter([0,15],self.adcReg,'int16')...
                .setFunctions('to',@(x) self.convert2int(x),'from',@(x) self.convert2volts(x));
            
            self.adc(2) = DeviceParameter([16,31],self.adcReg,'int16')...
                .setFunctions('to',@(x) self.convert2int(x),'from',@(x) self.convert2volts(x));
            % Digital I/O
            self.ext_i = DeviceParameter([0,7],self.inputReg);
            self.ext_o = DeviceParameter([0,7],self.outputReg)...
                .setLimits('lower',0,'upper',255);
            self.led_o = DeviceParameter([8,15],self.outputReg)...
                .setLimits('lower',0,'upper',255);
            % PWM outputs
            self.pwm = DeviceParameter.empty;
            for nn = 1:self.NUM_PWM
                self.pwm(nn) = DeviceParameter(8*(nn - 1) + [0,7],self.pwmReg)...
                    .setLimits('lower',0,'upper',1.62)...
                    .setFunctions('to',@(x) x/1.62*255,'from',@(x) x/255*1.62);
            end
            % "Slow" ADCs.  The conversion functions take into account the
            % voltage dividers on the inputs
            self.slow_adcs = DeviceParameter.empty;
            for nn = 1:self.NUM_SLOW_ADC
                self.slow_adcs(nn) = DeviceParameter([0,15],self.slowADCRegs(nn))...
                    .setFunctions('to',@(x) x*2^16*4.99/(30 + 4.99),'from',@(x) x/2^16*(30 + 4.99)/4.99);
            end
            
        end
        
        function self = setDefaults(self)
            %SETDEFAULTS Sets default values
            self.dac(1).set(0);
            self.dac(2).set(0);
            self.ext_o.set(0);
            self.led_o.set(0);
            for nn = 1:self.NUM_PWM
                self.pwm(nn).set(0);
            end
        end
        
        function self = check(self)
            %CHECK Checks settings for unwanted/dangerous combinations of
            %settings.
            %
            % Currently unused

        end
        
        function self = upload(self)
            %UPLOAD Uploads register values to the device
            %
            %   SELF = UPLOAD(SELF) uploads register values associated with
            %   object SELF
            
            %
            % Check parameters first
            %
            self.check;
            %
            % Get all write data
            %
            p = properties(self);
            d = [];
            for nn = 1:numel(p)
                if isa(self.(p{nn}),'DeviceRegister') || isa(self.(p{nn}),'DeviceSubModule')
                    d = [d;self.(p{nn}).getWriteData]; %#ok<*AGROW>
                end
            end

            d = d';
            d = d(:);
            %
            % Write every register using the same connection
            %
            self.conn.write(d,'mode','write');
            if self.conn.header.err
                error('Connection returned error: %s',self.conn.header.errMsg);
            end
        end
        
        function self = fetch(self)
            %FETCH Retrieves parameter values from the device
            %
            %   SELF = FETCH(SELF) retrieves values and stores them in
            %   object SELF
            
            %
            % Get addresses to read from for each register and get data
            % from device
            %
            p = properties(self);
            Rread = DeviceRegister.empty;
            d = [];
            for nn = 1:numel(p)
                if isa(self.(p{nn}),'DeviceRegister') || isa(self.(p{nn}),'DeviceSubModule')
                    [dtmp,Rtmp] = self.(p{nn}).getReadData;
                    d = [d;dtmp];
                    tmp = [Rread;Rtmp(:)];
                    Rread = tmp;
                end
            end
            self.conn.write(d,'mode','read','print',true);
            if self.conn.header.err
                error('Connection returned error: %s',self.conn.header.errMsg);
            end
            value = self.conn.recvMessage;
            %
            % Parse the received data in the same order as the addresses
            % were written
            %
            for nn = 1:numel(value)
                Rread(nn).value = value(nn);
            end
            %
            % Read parameters from registers
            %
            p = properties(self);
            for nn = 1:numel(p)
                if isa(self.(p{nn}),'DeviceParameter') || isa(self.(p{nn}),'DeviceSubModule')
                    self.(p{nn}).get;
                end
            end
        end
        
        function r = convert2volts(self,x)
            %CONVERT2VOLTS Converts an input ADC integer value to volts
            %
            %   R = CONVERT2VOLTS(SELF,X) Converts integer value X to
            %   volts R
            if strcmpi(self.jumpers,'hv')
                c = self.CONV_HV;
            elseif strcmpi(self.jumpers,'lv')
                c = self.CONV_LV;
            end
            r = x*c;
        end
        
        function r = convert2int(self,x)
            %CONVERT2INT Converts an ADC voltage to an integer
            %
            %   R = CONVERT2INT(SELF,X) Converts voltage X to integer value
            %   R
            if strcmpi(self.jumpers,'hv')
                c = self.CONV_HV;
            elseif strcmpi(self.jumpers,'lv')
                c = self.CONV_LV;
            end
            r = x/c;
        end

        function c = convert_dac_int_to_volts(self,idx)
            if isscalar(self.max_dac_voltages)
                v = self.max_dac_voltages;
            else
                v = self.max_dac_voltages(idx);
            end
            c = v/(2^(self.DAC_WIDTH - 1) - 1);
        end

        function data = get_xadc_status(self)
            %GET_XADC_STATUS Fetches data from the XADC corresponding to
            %monitored values
            %
            %   DATA = GET_XADC_STATUS(SELF) Returns data structure DATA
            %   with values in Celsius for the temperature and Volts for
            %   the voltages
            reg = DeviceRegister(0,self.conn,true);
            volt_conv = @(x) x/2^16*3;
            info = {'Temperature',0x00,@(x) x/2^16*503.975 - 273.15;
                    'VCCINT',0x01,volt_conv;
                    'VCCAUX',0x02,volt_conv;
                    'VSUPPLY',0x03,@(x) x/2^16*(56 + 4.99)/4.99;
                    'VCCBRAM',0x06,volt_conv;
                    'VCCPINT',0x0d,volt_conv;
                    'VCCPAUX',0x0e,volt_conv;
                    'VCCO_DDR',0x0f,volt_conv};
            data = struct;
            for nn = 1:size(info,1)
                reg.addr = double(self.XADC_ADDRESS_OFFSET) + double(info{nn,2}*4);
                reg.read;
                data.(info{nn,1}) = info{nn,3}(double(reg.value));
            end
        end

        function self = memwrite(self,data)
            %MEMWRITE Simple, but inefficient, method for testing how to
            %write to block memory
            %
            %   SELF = MEMWRITE(SELF,DATA) writes DATA to block memory.
            %   DATA should have <= 256 elements.
            reg = DeviceRegister(0,self.conn);
            if numel(data) > self.BLOCK_MEM_DEPTH
                error('Size of data exceeds block memory depth of %d',self.BLOCK_MEM_DEPTH);
            end
            d = [];
            for nn = 1:numel(data)
                reg.addr = double(self.BLOCK_MEM_ADDRESS_OFFSET) + (nn - 1)*4;
                reg.value = uint32(data(nn));
                d = [d;reg.getWriteData];
            end
            d = d';d = d(:);
            self.conn.write(d,'mode','write');
        end

        function data = memread(self,num_samples)
            %MEMREAD Simple, but inefficient, method for testing how to
            %read from block memory
            %
            %   DATA = MEMREAD(SELF,NUM_SAMPLES) Reads NUM_SAMPLES
            %   sequential addresses from memory and returns them in DATA
            reg = DeviceRegister(0,self.conn);
            if num_samples > self.BLOCK_MEM_DEPTH
                error('Size of data exceeds block memory depth of %d',self.BLOCK_MEM_DEPTH);
            end
            d = [];
            for nn = 1:num_samples
                reg.addr = double(self.BLOCK_MEM_ADDRESS_OFFSET) + (nn - 1)*4;
                d = [d;reg.getReadData];
            end
            self.conn.write(d,'mode','read');
            value = self.conn.recvMessage;
            data = zeros(numel(value),1);
            for nn = 1:numel(value)
                data(nn) = value(nn);
            end
        end
        
        function disp(self)
            %DISP Displays information about the object
            strwidth = 20;
            fprintf(1,'DeviceControl object with properties:\n');
            fprintf(1,'\t Registers\n');
            self.outputReg.print('outputReg',strwidth);
            self.dacReg.print('dacReg',strwidth);
            self.inputReg.print('inputReg',strwidth);
            self.adcReg.print('adcReg',strwidth);
            self.pwmReg.print('pwmReg',strwidth);
            for nn = 1:self.NUM_SLOW_ADC
                self.slowADCRegs(nn).print(sprintf('slowADCRegs %d',nn),strwidth);
            end
            fprintf(1,'\t ----------------------------------\n');
            fprintf(1,'\t Parameters\n');
            self.led_o.print('LEDs',strwidth,'%02x');
            self.ext_o.print('External output',strwidth,'%02x');
            self.ext_i.print('External input',strwidth,'%02x');
            self.dac(1).print('DAC 1',strwidth,'%.3f');
            self.dac(2).print('DAC 2',strwidth,'%.3f');
            self.adc(1).print('ADC 1',strwidth,'%.3f');
            self.adc(2).print('ADC 2',strwidth,'%.3f');
            for nn = 1:numel(self.pwm)
                self.pwm(nn).print(sprintf('PWM %d',nn),strwidth,'%.3f');
            end
            for nn = 1:self.NUM_SLOW_ADC
                self.slow_adcs(nn).print(sprintf('Slow ADC %d',nn),strwidth,'%.3f');
            end
        end
        
        
    end
    
end