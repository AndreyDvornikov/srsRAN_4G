#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ИМП — Интерфейс Метрик Планировщика
Автор: Dvornikov Andrey, 2026
"""

import json
import math
import os
import shutil
import subprocess
import threading
import time
import tkinter as tk
from collections import deque
from dataclasses import dataclass
from tkinter import ttk
from typing import Optional, Dict, List

os.environ.setdefault("MPLCONFIGDIR", "/tmp/matplotlib")

import matplotlib
matplotlib.use("TkAgg")
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from matplotlib.figure import Figure

SNR_FILE = "/tmp/snr"
DEFAULT_METRICS_FILE = "/tmp/enb_report.json"
MAX_POINTS = 100
UPDATE_MS = 100
PRB_BANDWIDTH_HZ = 10 * 10**6
MOVING_AVG_WINDOW = 5
CDF_MAX_SAMPLES = 10000

CLR_BG = "#121212"
CLR_SURFACE = "#F5F5F5"
CLR_ACCENT = "#30475E"
CLR_ACCENT2 = "#F05454"

TBS_TABLE_1PRB = [
    16, 32, 56, 88, 120, 152, 176, 208, 224, 256, 288, 328, 344, 376,
    408, 440, 488, 520, 552, 584, 616, 648, 680, 712, 744, 776, 808
]


def estimate_prb_from_bitrate(bitrate_bps: float, mcs: float) -> Optional[float]:
    """Приближённо оценивает количество PRB для single-layer передачи."""
    if bitrate_bps is None or mcs is None or mcs < 0:
        return None
    mcs_idx = int(round(mcs))
    if mcs_idx < 0 or mcs_idx >= len(TBS_TABLE_1PRB):
        return None
    tbs_per_prb = TBS_TABLE_1PRB[mcs_idx]
    if tbs_per_prb == 0:
        return None
    prb = bitrate_bps / (tbs_per_prb * 1000.0)
    return max(1.0, prb)


def to_number(value):
    """Безопасно преобразует переданное значение в float."""
    if value is None:
        return None
    try:
        parsed = float(value)
    except (TypeError, ValueError):
        return None
    if not math.isfinite(parsed):
        return None
    return parsed


def is_active_ue(prb, bsr, dl_buffer, dl_throughput):
    """Проверяет, активен ли UE по ключевым метрикам."""
    return any(v is not None and v > 0 for v in (prb, bsr, dl_buffer, dl_throughput))


def jain(xs):
    """Вычисляет индекс справедливости Джайна."""
    if not xs:
        return 0.0
    active = [x for x in xs if x is not None]
    if not active:
        return 0.0
    total = sum(active)
    square_sum = sum(x * x for x in active)
    if square_sum == 0:
        return 0.0
    return (total * total) / (len(active) * square_sum)


def moving_average(data, window_size=MOVING_AVG_WINDOW):
    """Применяет простое скользящее среднее к последовательности."""
    smoothed = []
    for idx, value in enumerate(data):
        if value is None:
            smoothed.append(None)
            continue
        start = max(0, idx - window_size + 1)
        window = [v for v in list(data)[start:idx + 1] if v is not None]
        smoothed.append(sum(window) / len(window) if window else None)
    return smoothed


def extract_json_blocks(buffer: str):
    """Извлекает завершённые JSON-объекты из строкового буфера."""
    blocks = []
    depth = 0
    start = None
    in_string = False
    escape = False
    for idx, ch in enumerate(buffer):
        if in_string:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                in_string = False
            continue
        if ch == '"':
            in_string = True
        elif ch == "{":
            if depth == 0:
                start = idx
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0 and start is not None:
                blocks.append(buffer[start:idx + 1])
                start = None
    remainder = buffer[start:] if depth > 0 and start is not None else ""
    return blocks, remainder


def extract_latency_map(metrics: dict) -> dict:
    """Строит словарь {rnti: dl_latency} на основе метрик."""
    latency_map = {}
    for cell in metrics.get("cell_list", []):
        ue_list = cell.get("ue_list") or cell.get("cell_container", {}).get("ue_list", [])
        for ue_entry in ue_list:
            ue = ue_entry.get("ue_container", {})
            rnti = ue.get("ue_rnti")
            for bearer_entry in ue.get("bearer_list", []):
                bearer = bearer_entry.get("bearer_container", {})
                latency = bearer.get("dl_latency")
                if rnti is not None and latency is not None:
                    parsed = to_number(latency)
                    if parsed is not None:
                        latency_map[int(rnti)] = parsed
                    break
    return latency_map


class FileMetricsSource:
    """Читает последний полный JSON-объект из файла метрик."""

    def __init__(self, path: str):
        self.path = path
        self.offset = 0
        self.partial = ""

    def read_latest(self) -> Optional[dict]:
        try:
            stat = os.stat(self.path)
        except OSError:
            self.offset = 0
            self.partial = ""
            return None
        if stat.st_size < self.offset:
            self.offset = 0
            self.partial = ""
        try:
            with open(self.path, "r", encoding="utf-8") as handle:
                handle.seek(self.offset)
                chunk = handle.read()
                self.offset = handle.tell()
        except OSError:
            return None
        if not chunk and not self.partial:
            return None
        blocks, self.partial = extract_json_blocks(self.partial + chunk)
        latest = None
        for block in blocks:
            try:
                latest = json.loads(block)
            except json.JSONDecodeError:
                continue
        return latest


@dataclass
class AggregatedUEMetrics:
    count: int = 0
    avg_dl_throughput: Optional[float] = None
    avg_dl_bler: Optional[float] = None
    avg_dl_mcs: Optional[float] = None
    total_dl_prb: float = 0.0
    total_dl_buffer: float = 0.0
    total_dl_retx_count: int = 0
    avg_dl_aggr_level: float = 0.0
    avg_se: Optional[float] = None
    avg_dl_latency: Optional[float] = None


def compute_python_metrics(metrics: dict) -> dict:
    """Вычисляет агрегированные python-метрики для одного среза."""
    mac = metrics.get("mac", {})
    cell_list = metrics.get("cell_list", [])

    # Извлекаем данные по UE
    cell_ue_map = {}
    for cell in cell_list:
        for ue_entry in cell.get("cell_container", {}).get("ue_list", []):
            ue_c = ue_entry.get("ue_container", {})
            rnti = ue_c.get("ue_rnti")
            if rnti is not None:
                cell_ue_map[int(rnti)] = ue_c

    ue_data = []
    for entry in mac.get("ue_list", []):
        c = entry.get("mac_ue_container") or entry.get("ue_container", {})
        if not c:
            continue
        rnti = to_number(c.get("rnti"))
        if rnti is None:
            continue
        raw = {
            "dl_throughput": to_number(c.get("dl_throughput")),
            "dl_bler": to_number(c.get("dl_bler")),
            "dl_mcs": to_number(c.get("dl_mcs")),
            "dl_prb": to_number(c.get("dl_prb")),
            "dl_buffer": to_number(c.get("dl_buffer")),
        }
        cell_ue = cell_ue_map.get(int(rnti))
        if cell_ue:
            if raw["dl_throughput"] == 0:
                dl_bitrate = to_number(cell_ue.get("dl_bitrate"))
                if dl_bitrate:
                    raw["dl_throughput"] = dl_bitrate
            if raw["dl_mcs"] == 0:
                dl_mcs = to_number(cell_ue.get("dl_mcs"))
                if dl_mcs:
                    raw["dl_mcs"] = dl_mcs
            if raw["dl_bler"] == 0:
                dl_bler = to_number(cell_ue.get("dl_bler"))
                if dl_bler is not None:
                    raw["dl_bler"] = dl_bler

        if raw["dl_prb"] == 0 and raw["dl_throughput"] is not None and raw["dl_mcs"] is not None \
                and raw["dl_throughput"] > 0 and raw["dl_mcs"] >= 0:
            estimated = estimate_prb_from_bitrate(raw["dl_throughput"], raw["dl_mcs"])
            if estimated is not None:
                raw["dl_prb"] = estimated

        if any(raw[k] is None for k in ("dl_throughput", "dl_bler", "dl_mcs", "dl_prb")):
            continue
        ue_data.append(raw)

    count = len(ue_data)
    if count == 0:
        return {
            "ue_count": 0,
            "avg_dl_throughput_bps": 0,
            "avg_dl_bler_pct": 0,
            "avg_dl_mcs": 0,
            "total_dl_prb": 0,
            "total_dl_buffer": 0,
            "avg_se_bps_per_hz": 0,
            "jfi": 0
        }

    throughputs = [d["dl_throughput"] for d in ue_data]
    blers = [d["dl_bler"] for d in ue_data]
    mcses = [d["dl_mcs"] for d in ue_data]
    prbs = [d["dl_prb"] for d in ue_data]
    buffers = [d["dl_buffer"] for d in ue_data]

    avg_throughput = sum(throughputs) / count
    avg_bler = sum(blers) / count
    avg_mcs = sum(mcses) / count
    total_prb = sum(prbs)
    total_buffer = sum(b for b in buffers if b is not None)
    total_throughput = sum(throughputs)

    se = total_throughput / (PRB_BANDWIDTH_HZ)

    jfi_val = jain(throughputs)

    return {
        "ue_count": count,
        "avg_dl_throughput_bps": round(avg_throughput, 1),
        "avg_dl_bler_pct": round(avg_bler, 3),
        "avg_dl_mcs": round(avg_mcs, 1),
        "total_dl_prb": round(total_prb, 1),
        "total_dl_buffer": int(total_buffer),
        "avg_se_bps_per_hz": round(se, 3),
        "jfi": round(jfi_val, 4)
    }


class DashboardApp:
    """Главное приложение для визуализации метрик планировщика."""

    def __init__(self, root: tk.Tk, metrics_path: str):
        self.root = root
        self.source = FileMetricsSource(metrics_path)
        self._configure_styles()
        self.root.title("ИМП — Интерфейс Метрик Планировщика | Dvornikov Andrey, 2026")
        self.root.geometry("1320x900")
        self.root.configure(bg=CLR_BG)

        self.jfi_history = deque(maxlen=MAX_POINTS)
        self.se_history = deque(maxlen=MAX_POINTS)
        self.mcs_history = deque(maxlen=MAX_POINTS)
        self.total_dl_throughput_history = deque(maxlen=MAX_POINTS)
        self.se_cdf_samples: list[float] = []
        self.ue_cqi_histories: dict[int, deque] = {}

        self.aggregated_metrics = AggregatedUEMetrics()
        self.last_valid_values: dict[int, dict] = {}
        self.last_dl_prio_list = []
        self._prio_labels: list[tk.Label] = []
        self.exp_running = False
        self.exp_process = None
        self.exp_path_var = tk.StringVar(value="/home/avadik/srsRAN_Exp/PF_30sec_normal_50-0dB.json")
        self.exp_time_var = tk.StringVar(value="30")
        self.exp_progress_var = tk.DoubleVar(value=0.0)

        self._build_layout()
        self._set_initial_snr()
        self._schedule_update()

    def _configure_styles(self):
        style = ttk.Style(self.root)
        style.theme_use("clam")
        style.configure(".", background=CLR_BG, foreground=CLR_SURFACE, fieldbackground=CLR_BG, font=("Segoe UI", 10))
        style.configure("TLabel", background=CLR_BG, foreground=CLR_SURFACE)
        style.configure("TLabelframe", background=CLR_BG, foreground=CLR_SURFACE, bordercolor=CLR_ACCENT,
                        lightcolor=CLR_ACCENT, darkcolor=CLR_ACCENT, relief="solid")
        style.configure("Visible.TEntry", insertcolor=CLR_SURFACE)
        style.configure("TLabelframe.Label", background=CLR_BG, foreground=CLR_SURFACE, font=("Segoe UI", 10, "bold"))
        style.configure("TFrame", background=CLR_BG)
        style.configure("TScale", background=CLR_BG, troughcolor=CLR_ACCENT, sliderlength=20)
        style.configure("Author.TLabel", background=CLR_ACCENT, foreground=CLR_SURFACE, font=("Segoe UI", 9, "bold"), padding=6)
        style.configure("Accent.TLabel", foreground=CLR_ACCENT2, background=CLR_BG, font=("Segoe UI", 11, "bold"))
        style.configure("Logo.TLabel", background=CLR_BG, foreground=CLR_ACCENT2, font=("Segoe UI", 18, "bold"))

    def _build_layout(self):
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(1, weight=1)

        control = ttk.LabelFrame(self.root, text="Параметры", padding=10)
        control.grid(row=0, column=0, sticky="ew", padx=10, pady=(10, 6))
        control.columnconfigure(1, weight=1)

        logo_label = ttk.Label(control, text="⚡ ИМП", style="Logo.TLabel")
        logo_label.grid(row=0, column=0, sticky="w", padx=(0, 20))

        ttk.Label(control, text="SNR (dB)").grid(row=0, column=1, sticky="w")
        self.snr_var = tk.DoubleVar(value=20.0)
        self.snr_label = ttk.Label(control, text="20.0 dB", style="Accent.TLabel")
        self.snr_label.grid(row=0, column=3, sticky="e", padx=(10, 0))

        slider = ttk.Scale(control, from_=-10.0, to=50.0, variable=self.snr_var,
                           command=self._on_snr_change, orient=tk.HORIZONTAL)
        slider.grid(row=0, column=2, sticky="ew", padx=10)

        content = ttk.Frame(self.root, padding=(10, 0, 10, 10))
        content.grid(row=1, column=0, sticky="nsew")
        content.columnconfigure(1, weight=1)
        content.rowconfigure(0, weight=1)

        left_panel = ttk.Frame(content)
        left_panel.grid(row=0, column=0, sticky="nsw", padx=(0, 8))
        left_panel.rowconfigure(0, weight=1)

        nav = ttk.LabelFrame(left_panel, text="Вкладки", padding=8)
        nav.grid(row=0, column=0, sticky="ns")

        self.tab_list = tk.Listbox(nav, exportselection=False, width=24, height=5,
                                   bg=CLR_BG, fg=CLR_SURFACE,
                                   selectbackground=CLR_ACCENT, selectforeground=CLR_SURFACE,
                                   highlightthickness=0, borderwidth=1, relief="solid",
                                   font=("Segoe UI", 10))
        self.tab_list.grid(row=0, column=0, sticky="ns")
        self.tab_list.insert(tk.END, "General")
        self.tab_list.insert(tk.END, "UEs")
        self.tab_list.bind("<<ListboxSelect>>", self._on_tab_change)

        exp_frame = ttk.LabelFrame(left_panel, text="Эксперимент", padding=10)
        exp_frame.grid(row=1, column=0, sticky="ew", pady=(8, 0))
        exp_frame.columnconfigure(0, weight=1)

        ttk.Label(exp_frame, text="Файл:").grid(row=0, column=0, sticky="w")
        self.exp_file_entry = ttk.Entry(exp_frame, textvariable=self.exp_path_var, width=22, style="Visible.TEntry")
        self.exp_file_entry.grid(row=0, column=1, columnspan=2, sticky="ew", padx=5)

        ttk.Label(exp_frame, text="Длит. (с):").grid(row=1, column=0, sticky="w")
        self.exp_time_entry = ttk.Entry(exp_frame, textvariable=self.exp_time_var, width=8, style="Visible.TEntry")
        self.exp_time_entry.grid(row=1, column=1, sticky="w", padx=5)

        self.exp_start_btn = ttk.Button(exp_frame, text="Старт", command=self._start_experiment)
        self.exp_start_btn.grid(row=2, column=0, padx=5, pady=(8, 2), sticky="w")

        self.exp_cancel_btn = ttk.Button(exp_frame, text="Отмена", command=self._cancel_experiment, state=tk.DISABLED)
        self.exp_cancel_btn.grid(row=2, column=1, padx=5, pady=(8, 2), sticky="w")

        self.exp_status_var = tk.StringVar(value="Готов")
        ttk.Label(exp_frame, textvariable=self.exp_status_var).grid(row=3, column=0, columnspan=2, sticky="w", pady=(2, 0))

        self.progress = ttk.Progressbar(exp_frame, variable=self.exp_progress_var, maximum=100, mode='determinate')
        self.progress.grid(row=4, column=0, columnspan=2, sticky="ew", pady=(6, 0))

        right = ttk.Frame(content)
        right.grid(row=0, column=1, sticky="nsew")
        right.columnconfigure(0, weight=1)
        right.rowconfigure(1, weight=1)

        metrics_frame = ttk.LabelFrame(right, text="Метрики", padding=10)
        metrics_frame.grid(row=0, column=0, sticky="ew")

        self.general_panel = ttk.Frame(metrics_frame)
        self.general_panel.grid(row=0, column=0)

        self.general_values = {
            "JFI": tk.StringVar(value="0.000"),
            "Avg DL Prio": tk.StringVar(value="N/A"),
            "Max DL Prio": tk.StringVar(value="N/A"),
            "UEs": tk.StringVar(value="0"),
            "Runtime": tk.StringVar(value="0 us"),
            "PRB Util": tk.StringVar(value="N/A"),
        }
        for i, (name, var) in enumerate(self.general_values.items()):
            ttk.Label(self.general_panel, text=name).grid(row=i, column=0, sticky="w")
            ttk.Label(self.general_panel, textvariable=var).grid(row=i, column=1, sticky="w", padx=(15, 0))

        self.prio_list_title = ttk.Label(self.general_panel, text="DL Prio List:")
        self.prio_list_title.grid(row=len(self.general_values), column=0, sticky="w")
        self.prio_list_frame = ttk.Frame(self.general_panel)
        self.prio_list_frame.grid(row=len(self.general_values), column=1, sticky="w", padx=(15, 0))

        self.ue_panel = ttk.Frame(metrics_frame)
        self.ue_fields = {
            "Avg DL Throughput": tk.StringVar(),
            "Avg DL BLER": tk.StringVar(),
            "Avg DL MCS": tk.StringVar(),
            "Total DL PRB": tk.StringVar(),
            "Total DL Buffer": tk.StringVar(),
            "Total DL RETX Count": tk.StringVar(),
            "Avg DL Agg Level": tk.StringVar(),
            "Approx. Spectral Eff.": tk.StringVar(),
            "Avg DL Latency": tk.StringVar(),
        }
        for i, (name, var) in enumerate(self.ue_fields.items()):
            ttk.Label(self.ue_panel, text=name).grid(row=i, column=0, sticky="w")
            ttk.Label(self.ue_panel, textvariable=var).grid(row=i, column=1, sticky="w", padx=(15, 0))

        graph_frame = ttk.LabelFrame(right, text="История планировщика", padding=5)
        graph_frame.grid(row=1, column=0, sticky="nsew", pady=(8, 0))
        graph_frame.columnconfigure(0, weight=1)
        graph_frame.rowconfigure(0, weight=1)

        self.notebook = ttk.Notebook(graph_frame)
        self.notebook.grid(row=0, column=0, sticky="nsew")

        tab1 = ttk.Frame(self.notebook)
        self.notebook.add(tab1, text="Планировщик")
        self.figure1 = Figure(figsize=(8, 6.5), dpi=100, facecolor=CLR_SURFACE)
        self.jfi_ax = self.figure1.add_subplot(311)
        self.se_ax = self.figure1.add_subplot(312)
        self.mcs_ax = self.figure1.add_subplot(313)
        self.figure1.tight_layout(pad=2.0)
        self.canvas1 = FigureCanvasTkAgg(self.figure1, master=tab1)
        canvas1_widget = self.canvas1.get_tk_widget()
        canvas1_widget.configure(bg=CLR_BG, borderwidth=1, relief="solid")
        canvas1_widget.pack(fill=tk.BOTH, expand=True)

        tab2 = ttk.Frame(self.notebook)
        self.notebook.add(tab2, text="Общая / CQI")
        self.figure2 = Figure(figsize=(8, 6.5), dpi=100, facecolor=CLR_SURFACE)
        self.tput_ax = self.figure2.add_subplot(311)
        self.cdf_se_ax = self.figure2.add_subplot(312)
        self.cqi_ax = self.figure2.add_subplot(313)
        self.figure2.tight_layout(pad=2.0)
        self.canvas2 = FigureCanvasTkAgg(self.figure2, master=tab2)
        canvas2_widget = self.canvas2.get_tk_widget()
        canvas2_widget.configure(bg=CLR_BG, borderwidth=1, relief="solid")
        canvas2_widget.pack(fill=tk.BOTH, expand=True)

        tab3 = ttk.Frame(self.notebook)
        self.notebook.add(tab3, text="ML")
        self.ml_ranker_var = tk.StringVar(value="N/A")
        self.ml_alloc_var = tk.StringVar(value="N/A")
        self.ml_total_var = tk.StringVar(value="N/A")
        ttk.Label(tab3, text="Время работы ONNX-ранкера:", font=("Segoe UI", 10)).grid(
            row=0, column=0, sticky="w", padx=10, pady=5)
        ttk.Label(tab3, textvariable=self.ml_ranker_var, font=("Segoe UI", 10, "bold")).grid(
            row=0, column=1, sticky="w", padx=10)
        ttk.Label(tab3, text="Время аллокации ресурсов:", font=("Segoe UI", 10)).grid(
            row=1, column=0, sticky="w", padx=10, pady=5)
        ttk.Label(tab3, textvariable=self.ml_alloc_var, font=("Segoe UI", 10, "bold")).grid(
            row=1, column=1, sticky="w", padx=10)
        ttk.Label(tab3, text="Общее время планирования:", font=("Segoe UI", 10)).grid(
            row=2, column=0, sticky="w", padx=10, pady=5)
        ttk.Label(tab3, textvariable=self.ml_total_var, font=("Segoe UI", 10, "bold")).grid(
            row=2, column=1, sticky="w", padx=10)

        author_frame = ttk.Frame(self.root)
        author_frame.grid(row=2, column=0, sticky="ew", padx=10, pady=(0, 5))
        auth_label = ttk.Label(author_frame, text="© Dvornikov Andrey, 2026", style="Author.TLabel")
        auth_label.pack(side=tk.RIGHT)

        self._show_general()
        self._redraw_plots()

    def _start_experiment(self):
        if self.exp_running:
            return
        path = self.exp_path_var.get().strip()
        if not path:
            self.exp_status_var.set("Укажите путь")
            return
        try:
            duration = float(self.exp_time_var.get())
        except ValueError:
            self.exp_status_var.set("Неверная длительность")
            return
        if duration <= 0:
            self.exp_status_var.set("Длительность > 0")
            return

        try:
            with open(DEFAULT_METRICS_FILE, "w") as f:
                f.truncate(0)
        except OSError:
            pass

        self.exp_running = True
        self.exp_start_btn.config(state=tk.DISABLED)
        self.exp_cancel_btn.config(state=tk.NORMAL)
        self.exp_status_var.set("Запуск iperf...")
        self.exp_progress_var.set(0.0)

        threading.Thread(target=self._experiment_thread, args=(path, duration), daemon=True).start()

    def _cancel_experiment(self):
        if not self.exp_running:
            return
        self.exp_running = False
        self.exp_start_btn.config(state=tk.NORMAL)
        self.exp_cancel_btn.config(state=tk.DISABLED)
        if self.exp_process and self.exp_process.poll() is None:
            self.exp_process.terminate()
        self.exp_status_var.set("Отменено")
        self.exp_progress_var.set(0.0)

    def _experiment_thread(self, path, duration):
        try:
            self.exp_process = subprocess.Popen(
                ["./iperf.sh", str(int(duration))],
                cwd=os.path.dirname(__file__),
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
        except Exception:
            self.exp_process = None

        start_time = time.time()
        deadline = start_time + duration

        while time.time() < deadline and self.exp_running:
            elapsed = time.time() - start_time
            progress = min(100.0, (elapsed / duration) * 100.0)
            self.root.after(0, lambda p=progress: self._update_progress(p))
            time.sleep(0.2)

        if self.exp_running and self.exp_process and self.exp_process.poll() is None:
            self.exp_process.terminate()
            try:
                self.exp_process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.exp_process.kill()

        if self.exp_running:
            self.root.after(0, lambda: self._finalize_experiment(path, duration))
        else:
            self.root.after(0, lambda: self._update_progress(0.0))
            self.root.after(0, lambda: self.exp_status_var.set("Отменено"))
        self.exp_running = False

    def _update_progress(self, value):
        self.exp_progress_var.set(value)

    def _finalize_experiment(self, path, duration):
        try:
            with open(DEFAULT_METRICS_FILE, "r", encoding="utf-8") as src:
                raw_data = src.read()
        except Exception as e:
            self.exp_status_var.set(f"Ошибка чтения: {e}")
            self._reset_exp_ui()
            return

        blocks, _ = extract_json_blocks(raw_data)
        if not blocks:
            self.exp_status_var.set("Нет данных")
            self._reset_exp_ui()
            return

        try:
            with open(path, "w", encoding="utf-8") as out:
                for block in blocks:
                    out.write(block + "\n")
                    try:
                        metrics = json.loads(block)
                        py_metrics = compute_python_metrics(metrics)
                        out.write(json.dumps({"python_metrics": py_metrics}) + "\n")
                    except Exception:
                        out.write(json.dumps({"python_metrics": {"error": "invalid block"}}) + "\n")
        except Exception as e:
            self.exp_status_var.set(f"Ошибка записи: {e}")
            self._reset_exp_ui()
            return

        self.exp_status_var.set(f"Сохранено: {path}")
        self._reset_exp_ui()

    def _reset_exp_ui(self):
        self.exp_start_btn.config(state=tk.NORMAL)
        self.exp_cancel_btn.config(state=tk.DISABLED)
        self.exp_progress_var.set(0.0)

    def _on_tab_change(self, event=None):
        sel = self.tab_list.curselection()
        if not sel:
            return
        idx = sel[0]
        if idx == 0:
            self._show_general()
        else:
            self._show_ues()

    def _show_general(self):
        self.ue_panel.grid_forget()
        self.general_panel.grid(row=0, column=0, sticky="w")

    def _show_ues(self):
        self.general_panel.grid_forget()
        self.ue_panel.grid(row=0, column=0, sticky="w")
        self._update_ue_panel_display()

    def _update_ue_panel_display(self):
        agg = self.aggregated_metrics
        self.ue_fields["Avg DL Throughput"].set(self._format_metric(agg.avg_dl_throughput, 1))
        self.ue_fields["Avg DL BLER"].set(self._format_metric(agg.avg_dl_bler, 3))
        self.ue_fields["Avg DL MCS"].set(self._format_metric(agg.avg_dl_mcs, 1))
        self.ue_fields["Total DL PRB"].set(str(int(agg.total_dl_prb)))
        self.ue_fields["Total DL Buffer"].set(str(int(agg.total_dl_buffer)))
        self.ue_fields["Total DL RETX Count"].set(str(agg.total_dl_retx_count))
        self.ue_fields["Avg DL Agg Level"].set(f"{agg.avg_dl_aggr_level:.1f}")
        self.ue_fields["Approx. Spectral Eff."].set(self._format_metric(agg.avg_se, 3, " bps/Hz"))
        self.ue_fields["Avg DL Latency"].set(self._format_metric(agg.avg_dl_latency, 1, " ms"))

    def _poll_metrics(self):
        metrics = self.source.read_latest()
        if not metrics:
            return
        mac = metrics.get("mac")
        if not isinstance(mac, dict):
            return

        if "ranker_time_us" in mac:
            self.ml_ranker_var.set(f"{mac['ranker_time_us']:.1f} µs")
        else:
            self.ml_ranker_var.set("N/A")
        if "allocation_time_us" in mac:
            self.ml_alloc_var.set(f"{mac['allocation_time_us']:.1f} µs")
        else:
            self.ml_alloc_var.set("N/A")
        if "total_sched_time_us" in mac:
            self.ml_total_var.set(f"{mac['total_sched_time_us']:.1f} µs")
        else:
            self.ml_total_var.set("N/A")

        latency_map = extract_latency_map(metrics)
        active_throughputs, total_throughput, total_prb, avg_mcs, ue_data_list = self._update_aggregated_metrics(
            mac.get("ue_list", []), latency_map, metrics.get("cell_list", []))
        self._update_general_metrics(mac)

        prb_util_raw = to_number(mac.get("prb_util"))
        if prb_util_raw is not None:
            self.general_values["PRB Util"].set(f"{prb_util_raw * 100:.1f} %")
        else:
            nof_prb = to_number(mac.get("nof_prb"))
            if nof_prb and nof_prb > 0:
                prb_sum = sum(c.get("mac_ue_container", c.get("ue_container", {})).get("dl_prb", 0)
                              for c in mac.get("ue_list", []))
                prb_util = (prb_sum / nof_prb) * 100.0
                self.general_values["PRB Util"].set(f"{prb_util:.1f} %")
            else:
                self.general_values["PRB Util"].set("N/A")

        se_total = self._compute_se(total_throughput)
        if se_total is not None:
            self.se_history.append(se_total)

        if avg_mcs is not None:
            self.mcs_history.append(avg_mcs)

        backlogged_throughputs = [ue["dl_throughput"] for ue in ue_data_list
                                  if (ue.get("dl_buffer") is not None and ue["dl_buffer"] > 0) or
                                  (ue.get("bsr") is not None and ue["bsr"] > 0)]
        computed_jfi = jain(backlogged_throughputs)
        jfi_raw = to_number(mac.get("jfi"))
        if jfi_raw is not None:
            self.jfi_history.append(jfi_raw)
        else:
            self.jfi_history.append(computed_jfi)
            self.general_values["JFI"].set(f"{computed_jfi:.3f}")

        total_tput_bps = sum(ue["dl_throughput"] for ue in ue_data_list if ue["dl_throughput"] is not None)
        self.total_dl_throughput_history.append(total_tput_bps / 1e6)

        for ue in ue_data_list:
            if ue["se"] is not None:
                self.se_cdf_samples.append(ue["se"])
        if len(self.se_cdf_samples) > CDF_MAX_SAMPLES:
            self.se_cdf_samples = self.se_cdf_samples[-CDF_MAX_SAMPLES:]

        for ue in ue_data_list:
            rnti = ue["rnti"]
            cqi = ue.get("dl_cqi")
            if cqi is not None:
                if rnti not in self.ue_cqi_histories:
                    self.ue_cqi_histories[rnti] = deque(maxlen=MAX_POINTS)
                self.ue_cqi_histories[rnti].append(cqi)

        self._update_prio_list_display()
        self._redraw_plots()
        if self.tab_list.curselection() and self.tab_list.curselection()[0] == 1:
            self._show_ues()

    def _update_general_metrics(self, mac: dict):
        jfi = to_number(mac.get("jfi"))
        avg_dl_prio = to_number(mac.get("avg_dl_prio"))
        max_dl_prio = to_number(mac.get("max_dl_prio"))
        num_ues = self._parse_int_metric(mac.get("num_ues"), 0)
        runtime_us = self._parse_int_metric(mac.get("scheduler_runtime_us"), 0)

        self.general_values["JFI"].set(f"{jfi:.3f}" if jfi is not None else "N/A")
        self.general_values["UEs"].set(str(num_ues))
        self.general_values["Runtime"].set(f"{runtime_us} us")
        self.general_values["Avg DL Prio"].set(f"{avg_dl_prio:.3f}" if avg_dl_prio is not None else "N/A")
        self.general_values["Max DL Prio"].set(f"{max_dl_prio:.3f}" if max_dl_prio is not None else "N/A")

    def _update_aggregated_metrics(self, ue_list, latency_map, cell_list):
        active_throughputs = []
        total_throughput = 0.0
        total_prb = 0.0
        mcs_values = []
        ue_data = []

        cell_ue_map = {}
        for cell in cell_list:
            for ue_entry in cell.get("cell_container", {}).get("ue_list", []):
                ue_c = ue_entry.get("ue_container", {})
                rnti = ue_c.get("ue_rnti")
                if rnti is not None:
                    cell_ue_map[int(rnti)] = ue_c

        for entry in ue_list:
            c = entry.get("mac_ue_container") or entry.get("ue_container", {})
            if not c:
                continue
            rnti = self._parse_int_metric(c.get("rnti"), 0)
            if not rnti:
                continue
            raw = {
                "rnti": rnti,
                "dl_throughput": to_number(c.get("dl_throughput")),
                "dl_bler": to_number(c.get("dl_bler")),
                "dl_mcs": to_number(c.get("dl_mcs")),
                "dl_prb": to_number(c.get("dl_prb")),
                "dl_buffer": to_number(c.get("dl_buffer")),
                "bsr": to_number(c.get("bsr")),
                "dl_retx_count": self._parse_int_metric(c.get("dl_retx_count"), 0),
                "dl_aggr_level": self._parse_int_metric(c.get("dl_aggr_level"), 0),
                "dl_cqi": to_number(c.get("dl_cqi")),
                "dl_prio": to_number(c.get("dl_prio")),
            }

            cell_ue = cell_ue_map.get(rnti)
            if cell_ue:
                if raw["dl_throughput"] == 0:
                    dl_bitrate = to_number(cell_ue.get("dl_bitrate"))
                    if dl_bitrate:
                        raw["dl_throughput"] = dl_bitrate
                if raw["dl_mcs"] == 0:
                    dl_mcs = to_number(cell_ue.get("dl_mcs"))
                    if dl_mcs:
                        raw["dl_mcs"] = dl_mcs
                if raw["dl_bler"] == 0:
                    dl_bler = to_number(cell_ue.get("dl_bler"))
                    if dl_bler is not None:
                        raw["dl_bler"] = dl_bler
                if raw["dl_cqi"] is None:
                    raw["dl_cqi"] = to_number(cell_ue.get("dl_cqi"))

            if (
                raw["dl_prb"] == 0
                and raw["dl_throughput"] is not None
                and raw["dl_mcs"] is not None
                and raw["dl_throughput"] > 0
                and raw["dl_mcs"] >= 0
            ):
                estimated_prb = estimate_prb_from_bitrate(raw["dl_throughput"], raw["dl_mcs"])
                if estimated_prb is not None:
                    raw["dl_prb"] = estimated_prb

            required = ("dl_throughput", "dl_bler", "dl_mcs", "dl_prb")
            if any(raw[name] is None for name in required):
                continue

            active = is_active_ue(raw["dl_prb"], raw["bsr"], raw["dl_buffer"], raw["dl_throughput"])

            dl_throughput = self._metric_with_last_valid(rnti, "dl_throughput", raw["dl_throughput"], active)
            dl_bler = self._metric_with_last_valid(rnti, "dl_bler", raw["dl_bler"], active)
            dl_mcs = self._metric_with_last_valid(rnti, "dl_mcs", raw["dl_mcs"], active)
            dl_prb = self._metric_with_last_valid(rnti, "dl_prb", raw["dl_prb"], active)
            dl_buffer = self._metric_with_last_valid(rnti, "dl_buffer", raw["dl_buffer"], active)
            dl_latency = latency_map.get(rnti)

            ue_info = {
                "rnti": rnti,
                "dl_throughput": dl_throughput,
                "dl_bler": dl_bler,
                "dl_mcs": dl_mcs,
                "dl_prb": dl_prb,
                "dl_buffer": dl_buffer,
                "bsr": raw["bsr"],
                "dl_retx_count": raw["dl_retx_count"],
                "dl_aggr_level": raw["dl_aggr_level"],
                "dl_latency": dl_latency,
                "dl_cqi": raw["dl_cqi"],
                "dl_prio": raw["dl_prio"],
                "se": self._compute_se(dl_throughput),
            }
            ue_data.append(ue_info)

            if dl_prb is not None and dl_prb > 0 and dl_throughput is not None:
                total_prb += dl_prb
                total_throughput += dl_throughput

            if active and dl_throughput is not None and dl_throughput > 0:
                active_throughputs.append(dl_throughput)
                if dl_mcs is not None:
                    mcs_values.append(dl_mcs)

        count = len(ue_data)
        self.aggregated_metrics.count = count
        if count == 0:
            self.aggregated_metrics.avg_dl_throughput = None
            self.aggregated_metrics.avg_dl_bler = None
            self.aggregated_metrics.avg_dl_mcs = None
            self.aggregated_metrics.total_dl_prb = 0.0
            self.aggregated_metrics.total_dl_buffer = 0.0
            self.aggregated_metrics.total_dl_retx_count = 0
            self.aggregated_metrics.avg_dl_aggr_level = 0.0
            self.aggregated_metrics.avg_se = None
            self.aggregated_metrics.avg_dl_latency = None
        else:
            valid_throughput = [d["dl_throughput"] for d in ue_data if d["dl_throughput"] is not None]
            self.aggregated_metrics.avg_dl_throughput = (sum(valid_throughput) / len(valid_throughput)) if valid_throughput else None
            valid_bler = [d["dl_bler"] for d in ue_data if d["dl_bler"] is not None]
            self.aggregated_metrics.avg_dl_bler = (sum(valid_bler) / len(valid_bler)) if valid_bler else None
            valid_mcs = [d["dl_mcs"] for d in ue_data if d["dl_mcs"] is not None]
            self.aggregated_metrics.avg_dl_mcs = (sum(valid_mcs) / len(valid_mcs)) if valid_mcs else None
            self.aggregated_metrics.total_dl_prb = sum(d["dl_prb"] for d in ue_data if d["dl_prb"] is not None)
            self.aggregated_metrics.total_dl_buffer = sum(d["dl_buffer"] for d in ue_data if d["dl_buffer"] is not None)
            self.aggregated_metrics.total_dl_retx_count = sum(d["dl_retx_count"] for d in ue_data)
            valid_aggr = [d["dl_aggr_level"] for d in ue_data if d["dl_aggr_level"] is not None]
            self.aggregated_metrics.avg_dl_aggr_level = (sum(valid_aggr) / len(valid_aggr)) if valid_aggr else 0.0
            valid_se = [d["se"] for d in ue_data if d["se"] is not None]
            self.aggregated_metrics.avg_se = (sum(valid_se) / len(valid_se)) if valid_se else None
            valid_lat = [d["dl_latency"] for d in ue_data if d["dl_latency"] is not None]
            self.aggregated_metrics.avg_dl_latency = (sum(valid_lat) / len(valid_lat)) if valid_lat else None

        avg_mcs = sum(mcs_values) / len(mcs_values) if mcs_values else None
        self.last_dl_prio_list = [ue.get("dl_prio") for ue in ue_data if ue.get("dl_prio") is not None]
        return active_throughputs, total_throughput, total_prb, avg_mcs, ue_data

    def _metric_with_last_valid(self, rnti, metric_name, value, active):
        if value is None:
            return None
        ue_last = self.last_valid_values.setdefault(rnti, {})
        if value == 0 and active:
            return ue_last.get(metric_name)
        if value != 0:
            ue_last[metric_name] = value
        return value

    @staticmethod
    def _parse_int_metric(value, default=0):
        parsed = to_number(value)
        return default if parsed is None else int(parsed)

    @staticmethod
    def _compute_se(total_throughput, _total_prb=None):
        if total_throughput is None:
            return None
        return total_throughput / PRB_BANDWIDTH_HZ

    def _format_metric(self, value, digits=1, suffix=""):
        if value is None:
            return "N/A"
        return f"{value:.{digits}f}{suffix}"

    def _redraw_plots(self):
        self.jfi_ax.clear()
        self.se_ax.clear()
        self.mcs_ax.clear()

        jfi_values = list(self.jfi_history)
        jfi_x = [i for i, v in enumerate(jfi_values) if v is not None]
        jfi_y = [jfi_values[i] for i in jfi_x]
        if jfi_y:
            self.jfi_ax.plot(jfi_x, jfi_y, color=CLR_ACCENT2, marker="o", markersize=3, linestyle="-", linewidth=1.5)
        self.jfi_ax.set_title("JFI (индекс справедливости)", color=CLR_ACCENT)
        self.jfi_ax.set_ylim(0, 1.05)
        self.jfi_ax.grid(True, linestyle=":", alpha=0.7, color=CLR_ACCENT)
        self.jfi_ax.set_facecolor(CLR_SURFACE)

        se_values = moving_average(self.se_history, MOVING_AVG_WINDOW)
        se_x = [i for i, v in enumerate(se_values) if v is not None]
        se_y = [se_values[i] for i in se_x]
        if se_y:
            self.se_ax.plot(se_x, se_y, color=CLR_ACCENT, marker="o", markersize=3, linestyle="-", linewidth=1.5)
        self.se_ax.set_title("Спектральная эффективность (общая)", color=CLR_ACCENT)
        self.se_ax.set_ylabel("bps/Hz", color=CLR_ACCENT)
        self.se_ax.grid(True, linestyle=":", alpha=0.7, color=CLR_ACCENT)
        self.se_ax.set_facecolor(CLR_SURFACE)

        mcs_smoothed = moving_average(self.mcs_history, MOVING_AVG_WINDOW)
        mcs_x = [i for i, v in enumerate(mcs_smoothed) if v is not None]
        mcs_y = [mcs_smoothed[i] for i in mcs_x]
        if mcs_y:
            self.mcs_ax.plot(mcs_x, mcs_y, color=CLR_ACCENT2, marker="o", markersize=3, linestyle="-", linewidth=1.5)
        self.mcs_ax.set_title("Avg MCS (активные UE)", color=CLR_ACCENT)
        self.mcs_ax.set_ylabel("MCS", color=CLR_ACCENT)
        self.mcs_ax.grid(True, linestyle=":", alpha=0.7, color=CLR_ACCENT)
        self.mcs_ax.set_facecolor(CLR_SURFACE)
        self.figure1.tight_layout(pad=2.0)
        self.canvas1.draw_idle()

        self.tput_ax.clear()
        self.cdf_se_ax.clear()
        self.cqi_ax.clear()

        tput_values = moving_average(self.total_dl_throughput_history, MOVING_AVG_WINDOW)
        tput_x = [i for i, v in enumerate(tput_values) if v is not None]
        tput_y = [tput_values[i] for i in tput_x]
        if tput_y:
            self.tput_ax.plot(tput_x, tput_y, color=CLR_ACCENT, marker="o", markersize=3, linestyle="-", linewidth=1.5)
        self.tput_ax.set_title("Суммарный DL Throughput", color=CLR_ACCENT)
        self.tput_ax.set_ylabel("Мбит/с", color=CLR_ACCENT)
        self.tput_ax.grid(True, linestyle=":", alpha=0.7, color=CLR_ACCENT)
        self.tput_ax.set_facecolor(CLR_SURFACE)

        if self.se_cdf_samples:
            sorted_se = sorted(self.se_cdf_samples)
            n = len(sorted_se)
            y = [(i + 1) / n for i in range(n)]
            self.cdf_se_ax.plot(sorted_se, y, color=CLR_ACCENT2, linewidth=1.5)
        self.cdf_se_ax.set_title("CDF спектральной эффективности", color=CLR_ACCENT)
        self.cdf_se_ax.set_xlabel("bps/Hz", color=CLR_ACCENT)
        self.cdf_se_ax.set_ylabel("P(SE ≤ x)", color=CLR_ACCENT)
        self.cdf_se_ax.grid(True, linestyle=":", alpha=0.7, color=CLR_ACCENT)
        self.cdf_se_ax.set_facecolor(CLR_SURFACE)

        for rnti, hist in self.ue_cqi_histories.items():
            if hist:
                cqi_list = list(hist)
                x = [i for i in range(len(cqi_list))]
                self.cqi_ax.plot(x, cqi_list, marker="o", markersize=3, linestyle="-",
                                 linewidth=1.0, label=f"UE {rnti}")
        self.cqi_ax.set_title("Динамика DL CQI", color=CLR_ACCENT)
        self.cqi_ax.set_ylabel("CQI", color=CLR_ACCENT)
        self.cqi_ax.grid(True, linestyle=":", alpha=0.7, color=CLR_ACCENT)
        self.cqi_ax.set_facecolor(CLR_SURFACE)
        self.cqi_ax.set_ylim(0, 15.5)
        self.figure2.tight_layout(rect=[0, 0, 0.82, 1], pad=2.0)
        self.canvas2.draw_idle()

    def _schedule_update(self):
        self._poll_metrics()
        self.root.after(UPDATE_MS, self._schedule_update)

    def _set_initial_snr(self):
        try:
            with open(SNR_FILE, "r") as f:
                value = float(f.read().strip())
                self.snr_var.set(value)
                self.snr_label.config(text=f"{value:.1f} dB")
        except (FileNotFoundError, ValueError):
            self.snr_var.set(20.0)
            self.snr_label.config(text="20.0 dB")

    def _on_snr_change(self, *args):
        val = self.snr_var.get()
        self.snr_label.config(text=f"{val:.1f} dB")
        try:
            with open(SNR_FILE, "w") as f:
                f.write(f"{val:.2f}")
        except OSError:
            pass

    def _update_prio_list_display(self):
        if not self.last_dl_prio_list:
            for lbl in self._prio_labels:
                lbl.destroy()
            self._prio_labels.clear()
            if not hasattr(self, '_na_label'):
                self._na_label = ttk.Label(self.prio_list_frame, text="N/A", foreground=CLR_SURFACE)
                self._na_label.pack(side=tk.LEFT)
            else:
                self._na_label.config(text="N/A")
            return
        if hasattr(self, '_na_label'):
            self._na_label.destroy()
            del self._na_label
        min_val = min(self.last_dl_prio_list)
        max_val = max(self.last_dl_prio_list)
        if len(self._prio_labels) != len(self.last_dl_prio_list):
            for lbl in self._prio_labels:
                lbl.destroy()
            self._prio_labels.clear()
            for val in self.last_dl_prio_list:
                lbl = tk.Label(self.prio_list_frame, text=f"{val:.4f}", bg=CLR_BG, fg="#F05454",
                               font=("Segoe UI", 10, "bold"), padx=4)
                lbl.pack(side=tk.LEFT)
                self._prio_labels.append(lbl)
        for lbl, val in zip(self._prio_labels, self.last_dl_prio_list):
            if min_val == max_val:
                color = "#2ECC71"
            elif val == min_val:
                color = "#F05454"
            elif val == max_val:
                color = "#2ECC71"
            else:
                color = "#F1C40F"
            lbl.config(text=f"{val:.4f}", fg=color)


def main():
    root = tk.Tk()
    DashboardApp(root, DEFAULT_METRICS_FILE)
    root.mainloop()


if __name__ == "__main__":
    main()