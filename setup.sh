#!/bin/bash

host=$1

scp fpga/basic.bit* software/programs/{*.c,Makefile} software/services/{*.service,*.sh} $host:/root/basic/