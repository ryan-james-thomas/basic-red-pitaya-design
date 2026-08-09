#!/bin/bash

VERSION=$(cat /root/.version | grep -P "2\.\d+")
if [ ${#VERSION} -gt 0 ]; then
    fpgautil -b basic.bit.bin
else
    echo "Uploading FPGA image using /dev/xdevcfg"
    cat basic.bit > /dev/xdevcfg
fi
