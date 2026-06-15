#!/usr/bin/env bash

set -euo pipefail

iperf3 -s -p 5201 &
iperf3 -s -p 5202 &
iperf3 -s -p 5203
