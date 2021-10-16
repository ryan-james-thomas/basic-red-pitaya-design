classdef DeviceControl < handle
    properties
        jumpers
    end
    
    properties(SetAccess = immutable)
        conn
        dac
        ext_o
        adc
        ext_i
    end
    
    properties(SetAccess = protected)
        % R/W registers
        trigReg
        outputReg
        inputReg
        dacReg
        adcReg
    end
    
    properties(Constant)
        CLK = 125e6;
        HOST_ADDRESS = 'rp-f0919a.local';
        DAC_WIDTH = 14;
        ADC_WIDTH = 14;
        CONV_LV = 1.1851/2^(DeviceControl.ADC_WIDTH - 1);
        CONV_HV = 29.3570/2^(DeviceControl.ADC_WIDTH - 1);
        
    end
    
    methods
        function self = DeviceControl(varargin)
            if numel(varargin)==1
                self.conn = ConnectionClient(varargin{1});
            else
                self.conn = ConnectionClient(self.HOST_ADDRESS);
            end
            
            self.jumpers = 'lv';
            
            % R/W registers
            self.trigReg = DeviceRegister('0',self.conn);
            self.outputReg = DeviceRegister('4',self.conn);
            self.dacReg = DeviceRegister('8',self.conn);
            self.adcReg = DeviceRegister('C',self.conn);
            self.inputReg = DeviceRegister('10',self.conn);
            
            
            self.dac = DeviceParameter([0,15],self.dacReg,'int16')...
                .setLimits('lower',-1,'upper',1)...
                .setFunctions('to',@(x) x*(2^(self.DAC_WIDTH - 1) - 1),'from',@(x) x/(2^(self.DAC_WIDTH - 1) - 1));
            
            self.dac(2) = DeviceParameter([16,31],self.dacReg,'int16')...
                .setLimits('lower',-1,'upper',1)...
                .setFunctions('to',@(x) x*(2^(self.DAC_WIDTH - 1) - 1),'from',@(x) x/(2^(self.DAC_WIDTH - 1) - 1));
            
            self.ext_o = DeviceParameter([0,7],self.outputReg)...
                .setLimits('lower',0,'upper',255);
            
            self.adc = DeviceParameter([0,15],self.adcReg,'int16')...
                .setFunctions('to',@(x) self.convert2int(x),'from',@(x) self.convert2volts(x));
            
            self.adc(2) = DeviceParameter([16,31],self.adcReg,'int16')...
                .setFunctions('to',@(x) self.convert2int(x),'from',@(x) self.convert2volts(x));
            
            self.ext_i = DeviceParameter([0,7],self.inputReg);
            
        end
        
        function self = setDefaults(self,varargin)
            self.dac(1).set(0);
            self.dac(2).set(0);
            self.ext_o.set(0);
        end
        
        function self = check(self)

        end
        
        function self = upload(self)
            self.check;
            self.outputReg.write;
            self.dacReg.write;
        end
        
        function self = fetch(self)
            %Read registers
            self.outputReg.read;
            self.dacReg.read;
            self.inputReg.read;
            self.adcReg.read;
            
            self.ext_o.get;
            self.ext_i.get;
            for nn = 1:numel(self.dac)
                self.dac(nn).get;
            end
            
            for nn = 1:numel(self.adc)
                self.adc(nn).get;
            end
        end
        
        function r = convert2volts(self,x)
            if strcmpi(self.jumpers,'hv')
                c = self.CONV_HV;
            elseif strcmpi(self.jumpers,'lv')
                c = self.CONV_LV;
            end
            r = x*c;
        end
        
        function r = convert2int(self,x)
            if strcmpi(self.jumpers,'hv')
                c = self.CONV_HV;
            elseif strcmpi(self.jumpers,'lv')
                c = self.CONV_LV;
            end
            r = x/c;
        end
        
        function disp(self)
            strwidth = 20;
            fprintf(1,'DeviceControl object with properties:\n');
            fprintf(1,'\t Registers\n');
            self.outputReg.print('outputReg',strwidth);
            self.dacReg.print('dacReg',strwidth);
            self.inputReg.print('inputReg',strwidth);
            self.adcReg.print('adcReg',strwidth);
            fprintf(1,'\t ----------------------------------\n');
            fprintf(1,'\t Parameters\n');
            self.ext_o.print('External output',strwidth,'%02x');
            self.ext_i.print('External input',strwidth,'%02x');
            self.dac(1).print('DAC 1',strwidth,'%.3f');
            self.dac(2).print('DAC 2',strwidth,'%.3f');
            self.adc(1).print('ADC 1',strwidth,'%.3f');
            self.adc(2).print('ADC 2',strwidth,'%.3f');
        end
        
        
    end
    
    methods(Static)
        function d = loadData(filename,dt,c)
            if nargin == 0 || isempty(filename)
                filename = 'SavedData.bin';
            end
            
            %Load data
            fid = fopen(filename,'r');
            fseek(fid,0,'eof');
            fsize = ftell(fid);
            frewind(fid);
            x = fread(fid,fsize,'uint8');
            fclose(fid);
            
            d.v = DeviceControl.convertData(x,c);
            d.t = dt*(0:(size(d.v,1)-1));
        end
        
        function v = convertData(raw,c)
            Nraw = numel(raw);
            d = zeros(Nraw/4,2,'int16');
            
            mm = 1;
            for nn = 1:4:Nraw
                d(mm,1) = typecast(uint8(raw(nn+(0:1))),'int16');
                d(mm,2) = typecast(uint8(raw(nn+(2:3))),'int16');
                mm = mm + 1;
            end

            v = double(d)*c;
        end
    end
    
end