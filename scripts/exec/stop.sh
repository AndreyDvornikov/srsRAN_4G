#!/usr/bin/env bash

echo "[*] Closing terminals..."

wmctrl -l | grep "ENB" | awk '{print $1}' | xargs -r wmctrl -ic
wmctrl -l | grep "UE1"  | awk '{print $1}' | xargs -r wmctrl -ic
wmctrl -l | grep "UE2"  | awk '{print $1}' | xargs -r wmctrl -ic
wmctrl -l | grep "UE3"  | awk '{print $1}' | xargs -r wmctrl -ic
wmctrl -l | grep "EPC" | awk '{print $1}' | xargs -r wmctrl -ic
wmctrl -l | grep "IPERF" | awk '{print $1}' | xargs -r wmctrl -ic
wmctrl -l | grep "DASHBOARD" | awk '{print $1}' | xargs -r wmctrl -ic

echo "[*] Done"
