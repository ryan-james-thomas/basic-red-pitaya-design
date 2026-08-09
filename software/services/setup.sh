#!/bin/bash

echo "Compiling binaries"
make

echo "Stopping running services"
systemctl stop basic-startup.service
systemctl stop rp-server.service

echo "Copying services to systemd directory and enabling"
cp *.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable basic-startup.service
systemctl enable rp-server.service

echo "Starting server and uploading FPGA image"
systemctl start basic-startup.service
systemctl start rp-server.service