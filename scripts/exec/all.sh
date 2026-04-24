#!/usr/bin/env bash

# Author: Dvornikov Andrey
# Year: 2026

set -e

echo "[1] Starting srsRAN..."

./run-epc.sh --rel=debug
sleep 1

./run-enb.sh --rel=debug
sleep 1

./run-ue.sh --rel=debug

echo "[2] Waiting for network..."
sleep 8

echo "[3] Starting IPERF tmux..."

gnome-terminal --title="IPERF" -- bash -c '

tmux kill-session -t iperf 2>/dev/null || true

# создаём новую сессию
tmux new-session -d -s iperf

# 🔥 создаём 6 панелей ЖЁСТКО
tmux split-window -h -t iperf:0
tmux split-window -v -t iperf:0.0
tmux split-window -v -t iperf:0.1
tmux split-window -v -t iperf:0.2
tmux split-window -v -t iperf:0.3

tmux select-layout -t iperf tiled

# === SERVERS ===
tmux send-keys -t iperf:0.0 "sudo ip netns exec ue1 iperf3 -s -p 5201" C-m
tmux send-keys -t iperf:0.2 "sudo ip netns exec ue2 iperf3 -s -p 5201" C-m
tmux send-keys -t iperf:0.4 "sudo ip netns exec ue3 iperf3 -s -p 5201" C-m

# === CLIENTS ===
tmux send-keys -t iperf:0.1 "sleep 2; iperf3 -c 172.16.0.2 -t 1000" C-m
tmux send-keys -t iperf:0.3 "sleep 2; iperf3 -c 172.16.0.3 -t 1000" C-m
tmux send-keys -t iperf:0.5 "sleep 2; iperf3 -c 172.16.0.4 -t 1000" C-m

tmux attach-session -t iperf

exec bash
'

echo "[4] Starting dashboard..."
sleep 2

gnome-terminal --title="DASHBOARD" -- bash -c '
source venv/bin/activate
streamlit run dashboard.py
exec bash
'
