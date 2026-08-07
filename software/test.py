from devicecontrol import *

d = DeviceControl(('rp-f0f025.local',6666))
d._conn.timeout = 5
d._conn._args = {"print": True}
d.max_dac_voltages = [2,2]
d.set_defaults()
d.led_o.set(0x55)
d.dacs[0].set(0.5)
d.sub_module_a.p.set(0x12345678)
d.sub_module_b.p.set(0x55aa55aa)
d.upload()
d.fetch()
# d._dac_reg.read()
# print(d.get_xadc_status())
print(d)

# data_i = [x - 5 for x in range(10)]
# d.mem_write(data_i)

# data_o = d.mem_read(10)
# print(data_o)