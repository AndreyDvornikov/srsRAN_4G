#!/usr/bin/env bash

set -euo pipefail

for proc in srsue srsenb srsepc gnuradio broker; do
  pkill -f "${proc}" 2>/dev/null || true
done

sudo fuser -k 2000/tcp 2001/tcp 2100/tcp 2101/tcp 2200/tcp 2201/tcp 2300/tcp 2301/tcp 2400/tcp 2401/tcp \
  2>/dev/null || true

for ns in ue1 ue2 ue3 ue4; do
  sudo ip netns del "${ns}" 2>/dev/null || true
done

for ns in ue1 ue2 ue3 ue4; do
  sudo ip netns add "${ns}"
done

for ns in ue1 ue2 ue3; do
  sudo ip netns exec "${ns}" nc -zu 172.16.0.1 9999 || true
done
