# Summary

This is a bare-bones Vivado project for the Red-Pitaya/STEMlab boards.  It is meant to be a starting point for custom designs with the Red Pitaya.  HDL code is written in VHDL, and it includes logic for reading from the ADCs, writing to the DACs, writing to the PWM outputs, reading from the "slow" ADC inputs using the programmable logic, as well as a simplified interface for reading/writing to the device via the AXI interface.

This project has been written to interface with a personal computer (PC) using either MATLAB or Python via a TCP/IP socket server running on the Red Pitaya (RP). The server code for running on the RP as well as the PC interface classes can be found in [this interface repository](https://github.com/ryan-james-thomas/red-pitaya-interface).

This project is compatible with Gen 1 STEMlab 125-14 and 125-10 boards, as well as Gen 2 boards.

# Set up

Connect the Red Pitaya (RP) to power via the USB connector labelled PWR (on the underside of the board, it's the connector closest to the edge of the board), and connect the device to the local network using an ethernet cable.  Log into the device using SSH with the user name `root` and password `root` using the hostname `rp-{MAC}.local` where `{MAC}` is the last 6 characters in the device's MAC address - this will be printed on the ethernet connector of the device.

On the RP, create directories 'server' and 'basic' in the '/root/' directory (where you land when you log in using SSH).

Clone the interface repository to your PC, and then copy over all files in that directory ending in '.py' and '.sh' using either `scp` (from a terminal on your computer) or your favourite GUI (I recommend WinSCP for Windows) to the RP and put them in the directory '/root/server/'.  You can also use the `setup.sh` script in the interface repository to transfer the relevant files. See the documentation in that repository for further details.

Next, add the interface repository on your PC to your MATLAB or Python path. 

Next, transfer this project's files to the RP. The simplest way to do that is to run the 'setup.sh' script in the top-level directory of this project:
```
./setup.sh root@rp-<MAC>.local
```
where '<MAC>' is the ethernet MAC address printed on the RP's ethernet connector. This will copy over the FPGA binaries as well as any C programs, Makefiles, service files, and shell scripts.

Finally, on the RP in the 'basic' directory, run the command './setup.sh' to:
  - Compile any binary files using the provided Makefile
  - Stop running services (if they exist), copy new service files over, and enable/start those services
  - Upload the FPGA bit file (part of starting the services)

The RP should now be set up to automatically start the socket server when it is rebooted and to automatically upload the relevant FPGA bit file. 

**If you do not want the server to boot automatically**, and/or you do not want the FPGA bit file to be uploaded automatically, you can disable those services by running:
  - `systemctl stop rp-server.service`: This stops the socket server, but if you reboot the device it will start up again.
  - `systemctl disable rp-server.service`: This disables the socket server from starting on boot.
  - `systemctl disable basic-startup.service`: This disables automatically loading of the FPGA bit file on boot.

**If you want to load the FPGA bit file manually**, you can just run `./startup.sh` which seamlessly handles loading of the FPGA binaries regardless of whether your board is Gen 1 or Gen 2 (they use different methods).

**If you want to run the socket server manually**, which is especially helpful for debugging issues or just seeing how it all works, run
```
python3 /root/server/appserver.py
```
which will automatically get your IP address and start the socket server. Run `python3 /root/server/appserver.py -h` to see the different options.

If you get complaints that the server won't start because the address is already in use, run the command
```
ps -ef | grep appserver.py
```
This will print out a list of processes that match the pattern `appserver.py`.  One of these might be the `grep` process itself -- not especially useful -- but one might be the socket server.  Here's an example output:
```
root      5768  5738  7 00:59 pts/0    00:00:00 python3 /root/server/appserver.py
root      5775  5738  0 01:00 pts/0    00:00:00 grep --color=auto appserver.py
```
The first entry is the actual socket server process and the second one is the `grep` process.  If you need to stop the server, and it is not in the jobs list because you pushed it to the background (run using `jobs`), then you can kill the process using `kill -15 5768` where `5768` is the process ID of the process (the first number in the entry above).  **Note** that if the server is running because of the 'rp-server' service, you should stop it using `systemctl stop rp-server.service`.

# Use

Once the FPGA bitstream is uploaded and the Python server is running, the suite of MATLAB or Python classes can be used to send and receive data.  

## MATLAB

Create an instance of the `DeviceControl` class using
```
dev = DeviceControl(ip_addr, max_dac_voltages);
```
where `ip_addr` is the IP address or host name of the Red Pitaya.  You can optionally specify the maximum DAC voltages as a two-element array: for Gen 1 boards the maximum DAC voltages are always 1 V, and for Gen 2 boards it is either 2 V (High-Z) or 1 V (50 Ohms). You should also set the ADC jumper values using
```
dev.jumpers = [RPJumperSetting.LV, RPJumperSetting.LV];
```
to, for example, set the jumper settings to the LV setting which reads in roughly +/-1 V (this is the default setting). You can also set it to the HV setting, which can read roughly +/-20 V. 

Default values can be set using `dev.setDefaults()`. The current configuration as represented on your PC can be uploaded using `dev.upload()`, while the configuration as stored on the FPGA can be retrieved using `dev.fetch()`. Refer to the code to see how this works.

DAC outputs can be written using `dev.dac(<index>).set(<value>).write()` where `<index>` is either 1 or 2 and `<value>` is the voltage to set. You can set both at once using `dev.dac.set(<value>).write()` where `<value>` is either a single voltage that is written to both DACs or is a two-element array of voltages for each DAC.

Fast ADC inputs can be read using `dev.adc(<index>).read()` where `<index>` is either 1 or 2 (alternatively, omit the indexing to read both at once).  The value in volts is then stored in `dev.adc(<index>).value`.  Make sure that `dev.jumpers` is set correctly.

PWM outputs can be written using `dev.pwm(<index>).set(<value>).write()` where `<index>` is an integer between 1 and 4 (indexing can also be omitted -- see comments about DAC values) and `<value>` is a value in volts between 0 and 1.62 V.  The PWM outputs are clocked at 250 MHz and the data for each output are 8 bits long leading to a PWM period of $250\,\textrm{MHz}/2^8 \approx 1\,\textrm{MHz}$.  The hardware includes single-pole low-pass filters with a corner frequency of about 100 kHz, and these show significant ripple.  Use of additional filters is necessary to get a good DC signal.   

Slow ADC inputs can be read using `dev.slow_adcs(<index>).read()` where `<index>` is an integer between 1 and 4.  The value in volts is then stored in `dev.slow_adcs(<index>).value`.  

You can query the device status as read through the XADC system, which includes temperature and supply voltages, using `dev.get_xadc_status`.

For testing purposes, a block memory element with 256 address spaces and a write/read data with of 32 has been included to show how to write to and read from a memory element.  The C program 'testMemory.c' can be used for this purpose: run it using `./testMemory 10` to write to and then read from 10 addresses in sequence.  You can replace '10' with any integer up to 255.  You can also use the methods `dev.mem_write(<data>)` and `dev.mem_read(<num_samples>)` to test it with the MATLAB interface.

## Python

Create an instance of the `DeviceControl` class using
```
import redpitaya
import devicecontrol
dev = devicecontrol.DeviceControl(ip_addr, max_dac_voltages);
```
where `ip_addr` is the IP address or host name of the Red Pitaya.  You can optionally specify the maximum DAC voltages as a two-element list: for Gen 1 boards the maximum DAC voltages are always 1 V, and for Gen 2 boards it is either 2 V (High-Z) or 1 V (50 Ohms). You should also set the ADC jumper values using
```
dev.jumpers = [redpitaya.JumperSetting.LV, redpitaya.JumperSetting.LV];
```
to, for example, set the jumper settings to the LV setting which reads in roughly +/-1 V (this is the default setting). You can also set it to the HV setting, which can read roughly +/-20 V. 

Default values can be set using `dev.set_defaults()`. The current configuration as represented on your PC can be uploaded using `dev.upload()`, while the configuration as stored on the FPGA can be retrieved using `dev.fetch()`. Refer to the code to see how this works.

DAC outputs can be written using `dev.dacs[<index>].set(<value>).write()` where `<index>` is either 1 or 2 and `<value>` is the voltage to set. You can set both at once using `dev.dacs.set(<value>).write()` where `<value>` is either a single voltage that is written to both DACs or is a two-element list of voltages for each DAC.

Fast ADC inputs can be read using `dev.adcs[<index>].read()` where `<index>` is either 1 or 2 (alternatively, omit the indexing to read both at once).  The value in volts is then stored in `dev.adcs[<index>].value`.  Make sure that `dev.jumpers` is set correctly.

PWM outputs can be written using `dev.pwms[<index>].set(<value>).write()` where `<index>` is an integer between 1 and 4 (indexing can also be omitted -- see comments about DAC values) and `<value>` is a value in volts between 0 and 1.62 V.  The PWM outputs are clocked at 250 MHz and the data for each output are 8 bits long leading to a PWM period of $250\,\textrm{MHz}/2^8 \approx 1\,\textrm{MHz}$.  The hardware includes single-pole low-pass filters with a corner frequency of about 100 kHz, and these show significant ripple.  Use of additional filters is necessary to get a good DC signal.   

Slow ADC inputs can be read using `dev.slow_adcs[<index>].read()` where `<index>` is an integer between 1 and 4.  The value in volts is then stored in `dev.slow_adcs[<index>].value`.  

You can query the device status as read through the XADC system, which includes temperature and supply voltages, using `dev.get_xadc_status()`.

The memory interface can be tested using the `mem_write(<data>)` and `mem_read(<num_samples>)` methods.

# Creating the Vivado project

To create the Vivado project, clone the repository to a directory on your computer, open Vivado, navigate to the 'fpga/' directory (use `pwd` in the TCL console to determine your current directory and `cd` to navigate, just like in Bash), and then run `source make-project.tcl` which will create the project files under the directory `basic-project`. Note that the TCL script was created using Vivado 2024.2, and it may need modification to work on later versions. While the script may work on earlier versions of Vivado, the IP blocks used in the design may not be compatible. If you want a different file name, open the `make-project.tcl` file and edit the line under the comment `# Set the project name`.  This should create the project with no errors.  It may not correctly assign the AXI addresses, so you will need to open the address editor and assign the `PS7/AXI_Parse_0/s_axi` interface the address range `0x4000_000` to `0x7fff_ffff`.

You should be able to generate the bitstream immediately after creating the project. There may be critical warnings flagged regarding the AXI clock interface settings, but you can ignore these. To create appropriate binary files, after you have generated the bitstream using Vivado run the program `./process_bitstream.sh -c` in the 'fpga' directory. This will copy the 'system_wrapper.bit' file generated by Vivado into the 'fpga' directory, rename it to 'basic.bit', and then convert it to a 'bit.bin' file needed for Gen 2 boards. For this to work, you will need to download the 'bootgen' program from [GitHub](https://github.com/Xilinx/bootgen): make sure to use the release appropriate for your version of Vivado.

