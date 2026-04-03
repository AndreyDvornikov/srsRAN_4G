#!/usr/bin/env python3
import json
from collections import deque
import streamlit as st
from streamlit_autorefresh import st_autorefresh
import matplotlib.pyplot as plt

FILE_PATH = "/tmp/enb_report.json"
MAX_POINTS = 100

# ========= INIT STATE =========
if "history" not in st.session_state:
    st.session_state.history = {
        0: deque(maxlen=MAX_POINTS),
        1: deque(maxlen=MAX_POINTS),
        2: deque(maxlen=MAX_POINTS),
    }

if "fairness_hist" not in st.session_state:
    st.session_state.fairness_hist = deque(maxlen=MAX_POINTS)

# ========= AUTO REFRESH =========
st_autorefresh(interval=500, key="refresh")

# ========= JSON PARSER =========
def extract_json(buffer):
    objs = []
    depth = 0
    start = None

    for i, ch in enumerate(buffer):
        if ch == "{":
            if depth == 0:
                start = i
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0 and start is not None:
                objs.append(buffer[start:i+1])
                start = None
    return objs

def read_data():
    try:
        with open(FILE_PATH, "r") as f:
            data = f.read()
    except:
        return

    blocks = extract_json(data)

    for block in blocks[-5:]:
        try:
            j = json.loads(block)
        except:
            continue

        if "mac" not in j:
            continue

        ue_list = j["mac"].get("ue_list", [])

        for i, ue in enumerate(ue_list[:3]):
            ue = ue.get("mac_ue_container", {})

            prb = ue.get("dl_prb", 0)
            mcs = ue.get("dl_mcs", 0)

            # 👉 временный throughput
            thr = prb * mcs

            st.session_state.history[i].append({
                "rnti": ue.get("rnti"),
                "prb": prb,
                "mcs": mcs,
                "cqi": ue.get("dl_cqi", 0),
                "thr": thr,
                "bler": ue.get("dl_bler", 0),
                "bsr": ue.get("bsr", 0),
            })

def jain(xs):
    if not xs:
        return 0
    s = sum(xs)
    sq = sum(x*x for x in xs)
    n = len(xs)
    return (s*s)/(n*sq) if sq > 0 else 0

# ========= UI =========
st.set_page_config(layout="wide")
st.title("📡 MAC Scheduler Dashboard")

read_data()

history = st.session_state.history

# ========= FAIRNESS =========
latest_thr = []
for i in history:
    if history[i]:
        latest_thr.append(history[i][-1]["thr"])

fairness = jain(latest_thr)
st.session_state.fairness_hist.append(fairness)

st.metric("Fairness", round(fairness, 3))

# ========= MAIN PLOTS =========
fig, axs = plt.subplots(2, 2, figsize=(14, 8))

plots = [
    ("prb", "DL PRB"),
    ("mcs", "DL MCS"),
    ("cqi", "DL CQI"),
    ("thr", "DL Throughput (approx)")
]

for ax, (metric, title) in zip(axs.flatten(), plots):
    for i in history:
        data = history[i]
        if not data:
            continue

        y = [d[metric] for d in data]
        ax.plot(y, label=f"UE{i}")

    ax.set_title(title)
    ax.legend()
    ax.grid()

st.pyplot(fig)

# ========= FAIRNESS GRAPH =========
fig2, ax2 = plt.subplots(figsize=(6, 3))
ax2.plot(list(st.session_state.fairness_hist))
ax2.set_title("Fairness over time")
ax2.grid()

st.pyplot(fig2)

# ========= SIDEBAR =========
with st.sidebar:
    st.header("📊 Latest UE Metrics")

    for i in history:
        if not history[i]:
            continue

        last = history[i][-1]

        st.subheader(f"UE{i} (RNTI {last['rnti']})")
        st.json(last)
