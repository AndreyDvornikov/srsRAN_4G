#!/bin/bash

sudo ip netns exec ue1 bash -c "echo ok >/dev/udp/172.16.0.1/9999"
sudo ip netns exec ue2 bash -c "echo ok >/dev/udp/172.16.0.1/9999"
sudo ip netns exec ue3 bash -c "echo ok >/dev/udp/172.16.0.1/9999"

sudo ip netns exec ue1 iperf3 -s -p 5201 > /tmp/iperf_ue1_server.log 2>&1 &
sudo ip netns exec ue2 iperf3 -s -p 5201 > /tmp/iperf_ue2_server.log 2>&1 &
sudo ip netns exec ue3 iperf3 -s -p 5201 > /tmp/iperf_ue3_server.log 2>&1 &

DURATION=$1
echo "$2"
BITRATE=100M

iperf3 -c 172.16.0.2 -u -b "$BITRATE" -t "$DURATION" &
iperf3 -c 172.16.0.3 -u -b "$BITRATE" -t "$DURATION" &
iperf3 -c 172.16.0.4 -u -b "$BITRATE" -t "$DURATION" &
wait
