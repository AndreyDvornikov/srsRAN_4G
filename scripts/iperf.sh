#!/usr/bin/env bash

set -euo pipefail

DURATION="${1:-}"
BITRATE="${2:-100M}"

if [[ -z "${DURATION}" ]]; then
  echo "Usage: $0 <duration-seconds> [bitrate]" >&2
  exit 1
fi

for ns in ue1 ue2 ue3; do
  sudo ip netns exec "${ns}" bash -c "echo ok >/dev/udp/172.16.0.1/9999"
done

for idx in 1 2 3; do
  sudo ip netns exec "ue${idx}" iperf3 -s -p 5201 >"/tmp/iperf_ue${idx}_server.log" 2>&1 &
done

trap 'pkill -f "iperf3 -s -p 5201" 2>/dev/null || true' EXIT

iperf3 -c 172.16.0.2 -u -b "${BITRATE}" -t "${DURATION}" &
iperf3 -c 172.16.0.3 -u -b "${BITRATE}" -t "${DURATION}" &
iperf3 -c 172.16.0.4 -u -b "${BITRATE}" -t "${DURATION}" &
wait
