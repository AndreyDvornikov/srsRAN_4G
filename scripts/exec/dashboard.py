#!/usr/bin/env python3
import json
import math
from collections import deque

import matplotlib.pyplot as plt
import streamlit as st
from streamlit_autorefresh import st_autorefresh

FILE_PATH = "/tmp/enb_report.json"
MAX_POINTS = 100
MOVING_AVG_WINDOW = 5
DEBUG_INVALID_SAMPLES = True
PRB_BANDWIDTH_HZ = 180000

# ========= INIT STATE =========
if "history" not in st.session_state:
    st.session_state.history = {
        0: deque(maxlen=MAX_POINTS),
        1: deque(maxlen=MAX_POINTS),
        2: deque(maxlen=MAX_POINTS),
    }

if "fairness_hist" not in st.session_state:
    st.session_state.fairness_hist = deque(maxlen=MAX_POINTS)

if "general_history" not in st.session_state:
    st.session_state.general_history = deque(maxlen=MAX_POINTS)

if "latest_general" not in st.session_state:
    st.session_state.latest_general = {}

if "last_valid_values" not in st.session_state:
    st.session_state.last_valid_values = {0: {}, 1: {}, 2: {}}

if "invalid_samples" not in st.session_state:
    st.session_state.invalid_samples = []

if "last_metrics_timestamp" not in st.session_state:
    st.session_state.last_metrics_timestamp = None


# ========= VALIDATION UTILITIES =========
def warn_invalid(reason):
    print(f"[dashboard] skipped sample: {reason}")
    if DEBUG_INVALID_SAMPLES:
        st.session_state.invalid_samples.append(reason)


def to_number(value):
    if value is None:
        return None

    try:
        parsed = float(value)
    except (TypeError, ValueError):
        return None

    if not math.isfinite(parsed):
        return None

    return parsed


def is_active_ue(prb, bsr, dl_buffer):
    return any(value is not None and value > 0 for value in (prb, bsr, dl_buffer))


def is_valid_sample(raw_values, rnti, ue_index):
    required = ("prb", "mcs", "dl_throughput")
    for metric in required:
        if raw_values[metric] is None:
            return False, f"UE{ue_index} RNTI {rnti}: missing/invalid {metric}"

    if raw_values["prb"] == 0 and raw_values["dl_throughput"] > 0:
        return (
            False,
            f"UE{ue_index} RNTI {rnti}: PRB=0 but dl_throughput={raw_values['dl_throughput']}",
        )

    return True, None


def metric_with_last_valid(ue_index, metric_name, value, active):
    if value is None:
        return None

    last_values = st.session_state.last_valid_values[ue_index]
    if value == 0 and active and metric_name in last_values:
        fallback = last_values[metric_name]
        print(
            f"[dashboard] UE{ue_index}: reused last valid {metric_name}={fallback} "
            f"instead of active zero"
        )
        return fallback

    if value == 0 and active:
        print(
            f"[dashboard] UE{ue_index}: active zero {metric_name} has no "
            "last valid fallback"
        )
        return None

    if value != 0 or not active:
        last_values[metric_name] = value

    return value


def compute_se(dl_throughput, prb, rnti, ue_index):
    print(
        f"[dashboard] UE{ue_index} RNTI {rnti}: SE inputs "
        f"throughput={dl_throughput}, prb={prb}"
    )

    if dl_throughput is None or prb is None or prb == 0:
        return None

    se = dl_throughput / (prb * PRB_BANDWIDTH_HZ)
    print(f"[dashboard] UE{ue_index} RNTI {rnti}: computed SE={se}")
    return se


def remember_valid_values(ue_index, sample):
    for metric_name in ("mcs", "prb", "bler", "dl_buffer", "dl_throughput", "se"):
        value = sample.get(metric_name)
        if isinstance(value, (int, float)) and math.isfinite(float(value)) and value != 0:
            st.session_state.last_valid_values[ue_index][metric_name] = value


def moving_average(data, window_size=MOVING_AVG_WINDOW):
    """
    Compute moving average of data list.
    Ignores None/NaN values. Returns smoothed list.
    """
    if not data or len(data) < 1:
        return data

    smoothed = []
    for i, val in enumerate(data):
        if val is None or (isinstance(val, float) and math.isnan(val)):
            smoothed.append(None)
            continue

        # Collect valid values in window
        window_start = max(0, i - window_size + 1)
        window_vals = [
            data[j]
            for j in range(window_start, i + 1)
            if data[j] is not None
            and (not isinstance(data[j], float) or not math.isnan(data[j]))
        ]

        if window_vals:
            smoothed.append(sum(window_vals) / len(window_vals))
        else:
            smoothed.append(val)

    return smoothed


def format_number(value, digits=2):
    if value is None:
        return "n/a"

    try:
        return f"{float(value):.{digits}f}"
    except (TypeError, ValueError):
        return "n/a"


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
                objs.append(buffer[start : i + 1])
                start = None
    return objs


def extract_latency_by_rnti(j):
    latency_by_rnti = {}

    for cell_entry in j.get("cell_list", []):
        ue_entries = cell_entry.get("ue_list")
        if ue_entries is None:
            ue_entries = cell_entry.get("cell_container", {}).get("ue_list", [])

        for ue_entry in ue_entries:
            ue = ue_entry.get("ue_container", {})
            rnti = ue.get("ue_rnti")
            latency = None

            for bearer_entry in ue.get("bearer_list", []):
                bearer = bearer_entry.get("bearer_container", {})
                latency = to_number(bearer.get("dl_latency"))
                print("UE", rnti, "latency raw:", bearer.get("dl_latency"))
                if rnti is not None and latency is not None:
                    latency_by_rnti[rnti] = latency
                    print(
                        f"[dashboard] latency extracted: RNTI {rnti} dl_latency={latency}"
                    )
                    break

            if rnti is not None and rnti not in latency_by_rnti:
                print("Latency not found for UE", rnti)
                print("[dashboard] full UE JSON:", json.dumps(ue, indent=2))

    return latency_by_rnti


def parse_general_metrics(mac, timestamp):
    general = {
        "timestamp": timestamp,
        "jfi": to_number(mac.get("jfi")),
        "num_ues": to_number(mac.get("num_ues")),
        "scheduler_runtime_us": to_number(mac.get("scheduler_runtime_us")),
    }

    st.session_state.latest_general = general
    st.session_state.general_history.append(general)

    if general["jfi"] is not None:
        st.session_state.fairness_hist.append(general["jfi"])


def read_data():
    """
    Read JSON metrics from file and populate history with validated samples.
    Implements:
    - Data validation (no zero insertion for invalid samples)
    - Last-valid-value fallback
    - Inconsistency detection
    - Logging of invalid samples
    """
    try:
        with open(FILE_PATH, "r") as f:
            data = f.read()
    except:
        return

    blocks = extract_json(data)

    newest_timestamp = st.session_state.last_metrics_timestamp

    for block in blocks:
        try:
            j = json.loads(block)
        except:
            continue

        mac = j.get("mac")
        if not isinstance(mac, dict):
            continue

        timestamp = to_number(j.get("timestamp"))
        if (
            timestamp is not None
            and st.session_state.last_metrics_timestamp is not None
            and timestamp <= st.session_state.last_metrics_timestamp
        ):
            continue

        parse_general_metrics(mac, timestamp)
        latency_by_rnti = extract_latency_by_rnti(j)
        ue_list = mac.get("ue_list", [])

        for i, ue in enumerate(ue_list[:3]):
            ue = ue.get("mac_ue_container", {})

            rnti = ue.get("rnti", 0)
            raw_values = {
                "prb": to_number(ue.get("dl_prb")),
                "mcs": to_number(ue.get("dl_mcs")),
                "cqi": to_number(ue.get("dl_cqi")),
                "bler": to_number(ue.get("dl_bler")),
                "bsr": to_number(ue.get("bsr")),
                "dl_buffer": to_number(ue.get("dl_buffer")),
                "dl_throughput": to_number(ue.get("dl_throughput")),
            }
            latency = to_number(ue.get("dl_latency"))
            if latency is None:
                latency = latency_by_rnti.get(rnti)

            if latency is None:
                print("Latency not found for UE", rnti)
            else:
                print("UE", rnti, "latency raw:", latency)

            active = is_active_ue(
                raw_values["prb"], raw_values["bsr"], raw_values["dl_buffer"]
            )

            is_valid, reason = is_valid_sample(raw_values, rnti, i)

            if not is_valid:
                warn_invalid(reason)
                continue

            prb = metric_with_last_valid(i, "prb", raw_values["prb"], active)
            mcs = metric_with_last_valid(i, "mcs", raw_values["mcs"], active)
            bler = metric_with_last_valid(i, "bler", raw_values["bler"], active)
            dl_buffer = metric_with_last_valid(
                i, "dl_buffer", raw_values["dl_buffer"], active
            )
            dl_throughput = metric_with_last_valid(
                i, "dl_throughput", raw_values["dl_throughput"], active
            )
            cqi = raw_values["cqi"]
            bsr = raw_values["bsr"]
            se = compute_se(dl_throughput, raw_values["prb"], rnti, i)

            sample = {
                "rnti": rnti,
                "prb": prb,
                "mcs": mcs,
                "cqi": cqi,
                "se": se,
                "thr": dl_throughput,
                "dl_throughput": dl_throughput,
                "bler": bler,
                "bsr": bsr,
                "dl_buffer": dl_buffer,
                "active": active,
            }

            sample["latency"] = latency
            sample["dl_latency"] = latency

            remember_valid_values(i, sample)
            st.session_state.history[i].append(sample)

        if timestamp is not None:
            newest_timestamp = max(newest_timestamp or timestamp, timestamp)

    st.session_state.last_metrics_timestamp = newest_timestamp


def jain(xs):
    """
    Compute Jain Fairness Index.
    IMPROVED: Only considers active UEs (throughput > 0)
    Prevents division artifacts and zero-UE edge cases.
    """
    if not xs:
        return 0

    # Filter out inactive UEs (throughput == 0)
    active = [x for x in xs if x > 0]

    if not active:
        # All UEs inactive
        return 0

    s = sum(active)
    sq = sum(x * x for x in active)
    n = len(active)

    # Handle edge case: only one active UE -> JFI = 1.0
    if n == 1:
        return 1.0

    # Prevent division by zero
    if sq == 0:
        return 0

    return (s * s) / (n * sq)


# ========= UI =========
st.set_page_config(layout="wide")
st_autorefresh(interval=500, key="refresh")
st.title("📡 MAC Scheduler Dashboard")

read_data()

history = st.session_state.history
latest_general = st.session_state.latest_general

if latest_general.get("jfi") is None:
    latest_thr = [
        history[i][-1]["dl_throughput"]
        for i in history
        if history[i] and history[i][-1].get("dl_throughput") is not None
    ]
    latest_general["jfi"] = jain(latest_thr)

general_tab, ue_tab, debug_tab = st.tabs(["General", "UEs", "Debug"])

with general_tab:
    cols = st.columns(4)
    cols[0].metric("JFI", format_number(latest_general.get("jfi"), 3))
    cols[1].metric("UEs", format_number(latest_general.get("num_ues"), 0))
    cols[2].metric(
        "Scheduler Runtime (us)",
        format_number(latest_general.get("scheduler_runtime_us"), 0),
    )
    cols[3].metric("Timestamp", format_number(latest_general.get("timestamp"), 3))

    fig2, ax2 = plt.subplots(figsize=(8, 3))
    fairness_list = list(st.session_state.fairness_hist)
    if fairness_list:
        ax2.plot(fairness_list, marker="o", markersize=3, color="green")
        ax2.set_ylim([0, 1.05])
        ax2.axhline(
            y=1.0,
            color="r",
            linestyle="--",
            linewidth=0.5,
            alpha=0.5,
            label="Perfect fairness",
        )
        ax2.set_title("Fairness Index (Jain) over time")
        ax2.set_ylabel("JFI")
        ax2.set_xlabel("Sample #")
        ax2.legend()
        ax2.grid()
    st.pyplot(fig2)

with ue_tab:
    fig, axs = plt.subplots(2, 2, figsize=(14, 8))

    plots = [
        ("prb", "DL PRB"),
        ("mcs", "DL MCS"),
        ("cqi", "DL CQI"),
        ("se", "Spectral Efficiency (bps/Hz) - smoothed"),
    ]

    for ax, (metric, title) in zip(axs.flatten(), plots):
        for i in history:
            data = history[i]
            if not data:
                continue

            y = [d.get(metric) for d in data]

            if metric == "se":
                y = moving_average(y, MOVING_AVG_WINDOW)

            x_indices = [
                j
                for j, val in enumerate(y)
                if val is not None and math.isfinite(float(val))
            ]
            y_filtered = [y[j] for j in x_indices]

            if y_filtered:
                ax.plot(x_indices, y_filtered, label=f"UE{i}", marker="o", markersize=3)

        ax.set_title(title)
        ax.legend()
        ax.grid()

    st.pyplot(fig)

    st.subheader("Latest UE Metrics")
    for i in history:
        if not history[i]:
            continue

        last = history[i][-1]
        st.markdown(f"**UE{i} (RNTI {last['rnti']})**")

        display_dict = {
            "PRB": format_number(last.get("prb"), 0),
            "MCS": format_number(last.get("mcs"), 2),
            "CQI": format_number(last.get("cqi"), 2),
            "Spectral Efficiency (bps/Hz)": format_number(last.get("se"), 3),
            "DL Throughput (bps)": format_number(last.get("dl_throughput"), 2),
            "BLER": f"{format_number(last.get('bler'), 2)}%",
            "DL Buffer": format_number(last.get("dl_buffer"), 0),
            "BSR": format_number(last.get("bsr"), 0),
            "Latency (ms)": format_number(last.get("dl_latency"), 2),
        }

        st.json(display_dict)

with debug_tab:
    st.json(latest_general)
    if DEBUG_INVALID_SAMPLES and st.session_state.invalid_samples:
        st.text("\n".join(st.session_state.invalid_samples[-20:]))
        st.info(f"Total invalid samples: {len(st.session_state.invalid_samples)}")
    else:
        st.info("No invalid samples logged.")
