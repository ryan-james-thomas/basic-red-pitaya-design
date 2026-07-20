#!/bin/bash
#
# This script converts .bit files into .bit.bin files for the newer RP OS
#

function usage() {
  echo "usage: $0 [-c]"
  echo "Converts the file basic.bit to basic.bit.bin using bootgen"
  echo "  -c    Copy system_wrapper.bit from runs directory and convert"
}

FILE_PREFIX="basic"
OPTSTRING="ch"

while getopts $OPTSTRING opt; do
    case $opt in
        c)
            # Copy bitstream from implementation folder
            SW_BIT_FILE=$(find ./ -type f -regex ".*system_wrapper.bit")
            cp $SW_BIT_FILE ./$FILE_PREFIX.bit
            ;;
        h)
            usage
            exit 1
            ;;
        ?)
            echo "Invalid option: -${OPTARG}"
            exit 1
            ;;
    esac
done

# This just copies the quoted string to the .bif file
echo -n "all:{ $FILE_PREFIX.bit }" > $FILE_PREFIX.bif
# This generates a boot image
bootgen -image $FILE_PREFIX.bif -arch zynq -process_bitstream bin -o $FILE_PREFIX.bit.bin -w
