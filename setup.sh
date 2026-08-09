#!/bin/bash

host=$1

scp fpga/basic.bit* software/programs/{*.c,*.h,Makefile,*.sh} software/servers/{*.service,*.sh} $host:/root/basic/