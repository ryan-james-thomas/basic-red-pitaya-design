classdef DeviceControlSubModule < DeviceSubModule
    properties(SetAccess = protected)
        addr_offset % Address offset of this module
        reg         % Register for this module
    end

    properties(SetAccess = immutable)
        p           % Parameter for this module
    end


    methods
        function self = DeviceControlSubModule(parent, offset)
            %DeviceControlSubModule creates an instance of the class
            %
            %   DeviceControlSubModule(PARENT, OFFSET) creates instance
            %   with given parent and address offset
            self.parent = parent;
            self.addr_offset = offset;

            self.reg = DeviceRegister(0,self.parent.conn,false, self.addr_offset);
            self.p = DeviceParameter([0,31], self.reg, 'uint32');
        end

        function setDefaults(self)
            self.p.set(0);
        end

        function s = print(self, strwidth)
            s = self.p.print('Parameter',strwidth,'%08x');
            if nargout == 0
                fprintf(1,s);
            end
        end
    end
end