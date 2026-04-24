#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ИМП — Интерфейс Метрик Планировщика
Автор: Dvornikov Andrey, 2026
"""

import json
import math
import os
import tkinter as tk
from collections import deque
from dataclasses import dataclass
from tkinter import ttk
from typing import Optional

os.environ.setdefault("MPLCONFIGDIR", "/tmp/matplotlib")

import matplotlib

matplotlib.use("TkAgg")
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from matplotlib.figure import Figure

# ----------------------------------------------------------------------
# Конфигурация
# ----------------------------------------------------------------------
SNR_FILE = "/tmp/snr"
DEFAULT_METRICS_FILE = "/tmp/enb_report.json"
MAX_POINTS = 100
UPDATE_MS = 100
PRB_BANDWIDTH_HZ = 180000.0
MOVING_AVG_WINDOW = 5

# Цветовая палитра (из задания)
CLR_BG = "#121212"  # основной фон
CLR_SURFACE = "#F5F5F5"  # светлый (текст, графики)
CLR_ACCENT = "#30475E"  # тёмно-синий акцент
CLR_ACCENT2 = "#F05454"  # красный акцент


# ----------------------------------------------------------------------
# Валидация
# ----------------------------------------------------------------------
def to_number(value):
    """Безопасное приведение к float, None при ошибке."""
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
    """UE считается активным, если хоть один ключевой параметр >0."""
    return any(v is not None and v > 0 for v in (prb, bsr, dl_buffer, dl_throughput))


def jain(xs):
    """Индекс справедливости Джайна."""
    active = [x for x in xs if x is not None and x > 0]
    if not active:
        return 0.0
    total = sum(active)
    square_sum = sum(x * x for x in active)
    if square_sum == 0:
        return 0.0
    return (total * total) / (len(active) * square_sum)


def moving_average(data, window_size=MOVING_AVG_WINDOW):
    """Скользящее среднее по последовательности."""
    smoothed = []
    for idx, value in enumerate(data):
        if value is None:
            smoothed.append(None)
            continue
        start = max(0, idx - window_size + 1)
        window = [v for v in list(data)[start : idx + 1] if v is not None]
        smoothed.append(sum(window) / len(window) if window else None)
    return smoothed


# ----------------------------------------------------------------------
# Работа с JSON
# ----------------------------------------------------------------------
def extract_json_blocks(buffer: str):
    """Выделение завершённых JSON-объектов из потока."""
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
                blocks.append(buffer[start : idx + 1])
                start = None

    remainder = buffer[start:] if depth > 0 and start is not None else ""
    return blocks, remainder


def extract_latency_map(metrics: dict) -> dict:
    """Возвращает {rnti: dl_latency} из метрик."""
    latency_map = {}
    for cell in metrics.get("cell_list", []):
        ue_list = cell.get("ue_list") or cell.get("cell_container", {}).get(
            "ue_list", []
        )
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


# ----------------------------------------------------------------------
# Источник данных
# ----------------------------------------------------------------------
class FileMetricsSource:
    def __init__(self, path: str):
        self.path = path
        self.offset = 0
        self.partial = ""

    def read_latest(self) -> Optional[dict]:
        """Читает последний JSON-объект из файла."""
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


# ----------------------------------------------------------------------
# Агрегированные метрики по всем UE
# ----------------------------------------------------------------------
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


# ================= Главное приложение =================
class DashboardApp:
    def __init__(self, root: tk.Tk, metrics_path: str):
        self.root = root
        self.source = FileMetricsSource(metrics_path)

        self._configure_styles()

        self.root.title("ИМП — Интерфейс Метрик Планировщика | Dvornikov Andrey, 2026")
        self.root.geometry("1320x900")  # чуть выше для третьего графика
        self.root.configure(bg=CLR_BG)

        # Истории для графиков
        self.jfi_history = deque(maxlen=MAX_POINTS)
        self.se_history = deque(maxlen=MAX_POINTS)  # общая SE
        self.mcs_history = deque(maxlen=MAX_POINTS)  # средний MCS активных UE

        self.aggregated_metrics = AggregatedUEMetrics()
        self.last_valid_values: dict[int, dict] = {}

        self._build_layout()
        self._set_initial_snr()
        self._schedule_update()

    # ------------------------------------------------------------------
    # Стили ttk
    # ------------------------------------------------------------------
    def _configure_styles(self):
        style = ttk.Style(self.root)
        style.theme_use("clam")

        style.configure(
            ".",
            background=CLR_BG,
            foreground=CLR_SURFACE,
            fieldbackground=CLR_BG,
            font=("Segoe UI", 10),
        )
        style.configure("TLabel", background=CLR_BG, foreground=CLR_SURFACE)
        style.configure(
            "TLabelframe",
            background=CLR_BG,
            foreground=CLR_SURFACE,
            bordercolor=CLR_ACCENT,
            lightcolor=CLR_ACCENT,
            darkcolor=CLR_ACCENT,
            relief="solid",
        )
        style.configure(
            "TLabelframe.Label",
            background=CLR_BG,
            foreground=CLR_SURFACE,
            font=("Segoe UI", 10, "bold"),
        )
        style.configure("TFrame", background=CLR_BG)
        style.configure(
            "TScale", background=CLR_BG, troughcolor=CLR_ACCENT, sliderlength=20
        )

        style.configure(
            "Author.TLabel",
            background=CLR_ACCENT,
            foreground=CLR_SURFACE,
            font=("Segoe UI", 9, "bold"),
            padding=6,
        )
        style.configure(
            "Accent.TLabel",
            foreground=CLR_ACCENT2,
            background=CLR_BG,
            font=("Segoe UI", 11, "bold"),
        )
        style.configure(
            "Logo.TLabel",
            background=CLR_BG,
            foreground=CLR_ACCENT2,
            font=("Segoe UI", 18, "bold"),
        )

    # ------------------------------------------------------------------
    # Построение интерфейса
    # ------------------------------------------------------------------
    def _build_layout(self):
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(1, weight=1)

        # Панель управления (SNR + логотип)
        control = ttk.LabelFrame(self.root, text="Параметры", padding=10)
        control.grid(row=0, column=0, sticky="ew", padx=10, pady=(10, 6))
        control.columnconfigure(1, weight=1)

        logo_label = ttk.Label(control, text="⚡ ИМП", style="Logo.TLabel")
        logo_label.grid(row=0, column=0, sticky="w", padx=(0, 20))

        ttk.Label(control, text="SNR (dB)").grid(row=0, column=1, sticky="w")
        self.snr_var = tk.DoubleVar(value=20.0)
        self.snr_label = ttk.Label(control, text="20.0 dB", style="Accent.TLabel")
        self.snr_label.grid(row=0, column=3, sticky="e", padx=(10, 0))

        slider = ttk.Scale(
            control,
            from_=-10.0,
            to=50.0,
            variable=self.snr_var,
            command=self._on_snr_change,
            orient=tk.HORIZONTAL,
        )
        slider.grid(row=0, column=2, sticky="ew", padx=10)

        # Основная область
        content = ttk.Frame(self.root, padding=(10, 0, 10, 10))
        content.grid(row=1, column=0, sticky="nsew")
        content.columnconfigure(1, weight=1)
        content.rowconfigure(0, weight=1)

        # Левая панель с вкладками
        nav = ttk.LabelFrame(content, text="Вкладки", padding=8)
        nav.grid(row=0, column=0, sticky="nsw", padx=(0, 8))

        self.tab_list = tk.Listbox(
            nav,
            exportselection=False,
            width=24,
            height=5,
            bg=CLR_BG,
            fg=CLR_SURFACE,
            selectbackground=CLR_ACCENT,
            selectforeground=CLR_SURFACE,
            highlightthickness=0,
            borderwidth=1,
            relief="solid",
            font=("Segoe UI", 10),
        )
        self.tab_list.grid(row=0, column=0, sticky="ns")
        self.tab_list.insert(tk.END, "General")
        self.tab_list.insert(tk.END, "UEs")
        self.tab_list.bind("<<ListboxSelect>>", self._on_tab_change)

        # Правая часть (метрики + графики)
        right = ttk.Frame(content)
        right.grid(row=0, column=1, sticky="nsew")
        right.columnconfigure(0, weight=1)
        right.rowconfigure(1, weight=1)

        # Метрики
        metrics_frame = ttk.LabelFrame(right, text="Метрики", padding=10)
        metrics_frame.grid(row=0, column=0, sticky="ew")

        self.general_panel = ttk.Frame(metrics_frame)
        self.general_panel.grid(row=0, column=0)

        self.general_values = {
            "JFI": tk.StringVar(value="0.000"),
            "UEs": tk.StringVar(value="0"),
            "Runtime": tk.StringVar(value="0 us"),
        }
        for i, (name, var) in enumerate(self.general_values.items()):
            ttk.Label(self.general_panel, text=name).grid(row=i, column=0, sticky="w")
            ttk.Label(self.general_panel, textvariable=var).grid(
                row=i, column=1, sticky="w", padx=(15, 0)
            )

        self.ue_panel = ttk.Frame(metrics_frame)

        self.ue_fields = {
            "Avg DL Throughput": tk.StringVar(),
            "Avg DL BLER": tk.StringVar(),
            "Avg DL MCS": tk.StringVar(),
            "Total DL PRB": tk.StringVar(),
            "Total DL Buffer": tk.StringVar(),
            "Total DL RETX Count": tk.StringVar(),
            "Avg DL Agg Level": tk.StringVar(),
            "Avg Spectral Eff.": tk.StringVar(),
            "Avg DL Latency": tk.StringVar(),
        }
        for i, (name, var) in enumerate(self.ue_fields.items()):
            ttk.Label(self.ue_panel, text=name).grid(row=i, column=0, sticky="w")
            ttk.Label(self.ue_panel, textvariable=var).grid(
                row=i, column=1, sticky="w", padx=(15, 0)
            )

        # Графики (теперь 3 subplot)
        graph_frame = ttk.LabelFrame(right, text="История планировщика", padding=5)
        graph_frame.grid(row=1, column=0, sticky="nsew", pady=(8, 0))
        graph_frame.columnconfigure(0, weight=1)
        graph_frame.rowconfigure(0, weight=1)

        self.figure = Figure(figsize=(8, 6.5), dpi=100, facecolor=CLR_SURFACE)
        self.jfi_ax = self.figure.add_subplot(311)
        self.se_ax = self.figure.add_subplot(312)
        self.mcs_ax = self.figure.add_subplot(313)
        self.figure.tight_layout(pad=2.0)
        self.canvas = FigureCanvasTkAgg(self.figure, master=graph_frame)
        canvas_widget = self.canvas.get_tk_widget()
        canvas_widget.configure(bg=CLR_BG, borderwidth=1, relief="solid")
        canvas_widget.grid(row=0, column=0, sticky="nsew")

        # Авторская подпись
        author_frame = ttk.Frame(self.root)
        author_frame.grid(row=2, column=0, sticky="ew", padx=10, pady=(0, 5))
        auth_label = ttk.Label(
            author_frame, text="© Dvornikov Andrey, 2026", style="Author.TLabel"
        )
        auth_label.pack(side=tk.RIGHT)

        self._show_general()
        self._redraw_plots()

    # ------------------------------------------------------------------
    # Вкладки
    # ------------------------------------------------------------------
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
        self.ue_fields["Avg DL Throughput"].set(
            self._format_metric(agg.avg_dl_throughput, 1)
        )
        self.ue_fields["Avg DL BLER"].set(self._format_metric(agg.avg_dl_bler, 3))
        self.ue_fields["Avg DL MCS"].set(self._format_metric(agg.avg_dl_mcs, 1))
        self.ue_fields["Total DL PRB"].set(str(int(agg.total_dl_prb)))
        self.ue_fields["Total DL Buffer"].set(str(int(agg.total_dl_buffer)))
        self.ue_fields["Total DL RETX Count"].set(str(agg.total_dl_retx_count))
        self.ue_fields["Avg DL Agg Level"].set(f"{agg.avg_dl_aggr_level:.1f}")
        self.ue_fields["Avg Spectral Eff."].set(
            self._format_metric(agg.avg_se, 3, " bps/Hz")
        )
        self.ue_fields["Avg DL Latency"].set(
            self._format_metric(agg.avg_dl_latency, 1, " ms")
        )

    # ------------------------------------------------------------------
    # Сбор метрик
    # ------------------------------------------------------------------
    def _poll_metrics(self):
        metrics = self.source.read_latest()
        if not metrics:
            return

        mac = metrics.get("mac")
        if not isinstance(mac, dict):
            return

        latency_map = extract_latency_map(metrics)

        active_throughputs, total_throughput, total_prb, avg_mcs = (
            self._update_aggregated_metrics(mac.get("ue_list", []), latency_map)
        )
        self._update_general_metrics(mac)

        # Общая спектральная эффективность
        se_total = self._compute_se(total_throughput, total_prb)
        if se_total is not None:
            self.se_history.append(se_total)

        # Средний MCS (если есть)
        if avg_mcs is not None:
            self.mcs_history.append(avg_mcs)

        # JFI
        jfi_raw = to_number(mac.get("jfi"))
        if jfi_raw is not None:
            self.jfi_history.append(jfi_raw)
        else:
            computed_jfi = jain(active_throughputs)
            self.jfi_history.append(computed_jfi)
            self.general_values["JFI"].set(f"{computed_jfi:.3f}")

        self._redraw_plots()
        if self.tab_list.curselection() and self.tab_list.curselection()[0] == 1:
            self._show_ues()

    def _update_general_metrics(self, mac: dict):
        jfi = to_number(mac.get("jfi"))
        if jfi is not None:
            self.jfi_history.append(jfi)

        num_ues = self._parse_int_metric(mac.get("num_ues"), 0)
        runtime_us = self._parse_int_metric(mac.get("scheduler_runtime_us"), 0)

        self.general_values["JFI"].set(f"{jfi:.3f}" if jfi is not None else "N/A")
        self.general_values["UEs"].set(str(num_ues))
        self.general_values["Runtime"].set(f"{runtime_us} us")

    def _update_aggregated_metrics(self, ue_list, latency_map):
        active_throughputs = []
        total_throughput = 0.0
        total_prb = 0.0
        mcs_values = []  # собираем MCS только активных UE

        ue_data = []
        for entry in ue_list:
            c = entry.get("mac_ue_container")
            if c is None:
                c = entry.get("ue_container", {})
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
            }

            required = ("dl_throughput", "dl_bler", "dl_mcs", "dl_prb")
            if any(raw[name] is None for name in required):
                print(
                    f"[snr] skipping UE {rnti}: missing fields {[n for n in required if raw[n] is None]}, raw={raw}"
                )
                continue

            if raw["dl_prb"] == 0 and raw["dl_throughput"] > 0:
                print(
                    f"[snr] skipping UE {rnti}: PRB=0 but throughput={raw['dl_throughput']}"
                )
                continue

            active = is_active_ue(
                raw["dl_prb"], raw["bsr"], raw["dl_buffer"], raw["dl_throughput"]
            )

            dl_throughput = self._metric_with_last_valid(
                rnti, "dl_throughput", raw["dl_throughput"], active
            )
            dl_bler = self._metric_with_last_valid(
                rnti, "dl_bler", raw["dl_bler"], active
            )
            dl_mcs = self._metric_with_last_valid(rnti, "dl_mcs", raw["dl_mcs"], active)
            dl_prb = self._metric_with_last_valid(rnti, "dl_prb", raw["dl_prb"], active)
            dl_buffer = self._metric_with_last_valid(
                rnti, "dl_buffer", raw["dl_buffer"], active
            )
            dl_latency = latency_map.get(rnti)

            ue_data.append(
                {
                    "rnti": rnti,
                    "dl_throughput": dl_throughput,
                    "dl_bler": dl_bler,
                    "dl_mcs": dl_mcs,
                    "dl_prb": dl_prb,
                    "dl_buffer": dl_buffer,
                    "dl_retx_count": raw["dl_retx_count"],
                    "dl_aggr_level": raw["dl_aggr_level"],
                    "dl_latency": dl_latency,
                    "se": self._compute_se(dl_throughput, dl_prb),
                }
            )

            if dl_prb is not None and dl_prb > 0 and dl_throughput is not None:
                total_prb += dl_prb
                total_throughput += dl_throughput

            if active and dl_throughput is not None and dl_throughput > 0:
                active_throughputs.append(dl_throughput)
                if dl_mcs is not None:
                    mcs_values.append(dl_mcs)

        # Агрегация (как раньше)
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
            valid_throughput = [
                d["dl_throughput"] for d in ue_data if d["dl_throughput"] is not None
            ]
            self.aggregated_metrics.avg_dl_throughput = (
                sum(valid_throughput) / len(valid_throughput)
                if valid_throughput
                else None
            )

            valid_bler = [d["dl_bler"] for d in ue_data if d["dl_bler"] is not None]
            self.aggregated_metrics.avg_dl_bler = (
                sum(valid_bler) / len(valid_bler) if valid_bler else None
            )

            valid_mcs = [d["dl_mcs"] for d in ue_data if d["dl_mcs"] is not None]
            self.aggregated_metrics.avg_dl_mcs = (
                sum(valid_mcs) / len(valid_mcs) if valid_mcs else None
            )

            self.aggregated_metrics.total_dl_prb = sum(
                d["dl_prb"] for d in ue_data if d["dl_prb"] is not None
            )
            self.aggregated_metrics.total_dl_buffer = sum(
                d["dl_buffer"] for d in ue_data if d["dl_buffer"] is not None
            )
            self.aggregated_metrics.total_dl_retx_count = sum(
                d["dl_retx_count"] for d in ue_data
            )

            valid_aggr = [
                d["dl_aggr_level"] for d in ue_data if d["dl_aggr_level"] is not None
            ]
            self.aggregated_metrics.avg_dl_aggr_level = (
                sum(valid_aggr) / len(valid_aggr) if valid_aggr else 0.0
            )

            valid_se = [d["se"] for d in ue_data if d["se"] is not None]
            self.aggregated_metrics.avg_se = (
                sum(valid_se) / len(valid_se) if valid_se else None
            )

            valid_lat = [
                d["dl_latency"] for d in ue_data if d["dl_latency"] is not None
            ]
            self.aggregated_metrics.avg_dl_latency = (
                sum(valid_lat) / len(valid_lat) if valid_lat else None
            )

        # Возвращаем средний MCS активных UE для графика
        avg_mcs = sum(mcs_values) / len(mcs_values) if mcs_values else None
        return active_throughputs, total_throughput, total_prb, avg_mcs

    # ------------------------------------------------------------------
    # Вспомогательные функции
    # ------------------------------------------------------------------
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
    def _compute_se(total_throughput, total_prb):
        if total_prb is None or total_prb <= 0:
            return None
        if total_throughput is None:
            return None
        return total_throughput / (total_prb * PRB_BANDWIDTH_HZ)

    def _format_metric(self, value, digits=1, suffix=""):
        if value is None:
            return "N/A"
        return f"{value:.{digits}f}{suffix}"

    # ------------------------------------------------------------------
    # Графики (теперь три)
    # ------------------------------------------------------------------
    def _redraw_plots(self):
        self.jfi_ax.clear()
        self.se_ax.clear()
        self.mcs_ax.clear()

        # JFI
        jfi_values = list(self.jfi_history)
        jfi_x = [i for i, v in enumerate(jfi_values) if v is not None]
        jfi_y = [jfi_values[i] for i in jfi_x]
        if jfi_y:
            self.jfi_ax.plot(
                jfi_x,
                jfi_y,
                color=CLR_ACCENT2,
                marker="o",
                markersize=3,
                linestyle="-",
                linewidth=1.5,
            )
        self.jfi_ax.set_title("JFI (индекс справедливости)", color=CLR_ACCENT)
        self.jfi_ax.set_ylim(0, 1.05)
        self.jfi_ax.grid(True, linestyle=":", alpha=0.7, color=CLR_ACCENT)
        self.jfi_ax.set_facecolor(CLR_SURFACE)

        # Общая SE (сглаженная)
        se_values = moving_average(self.se_history, MOVING_AVG_WINDOW)
        se_x = [i for i, v in enumerate(se_values) if v is not None]
        se_y = [se_values[i] for i in se_x]
        if se_y:
            self.se_ax.plot(
                se_x,
                se_y,
                color=CLR_ACCENT,
                marker="o",
                markersize=3,
                linestyle="-",
                linewidth=1.5,
            )
        self.se_ax.set_title("Спектральная эффективность (общая)", color=CLR_ACCENT)
        self.se_ax.set_ylabel("bps/Hz", color=CLR_ACCENT)
        self.se_ax.grid(True, linestyle=":", alpha=0.7, color=CLR_ACCENT)
        self.se_ax.set_facecolor(CLR_SURFACE)

        # Средний MCS активных UE (сглаженный)
        mcs_smoothed = moving_average(self.mcs_history, MOVING_AVG_WINDOW)
        mcs_x = [i for i, v in enumerate(mcs_smoothed) if v is not None]
        mcs_y = [mcs_smoothed[i] for i in mcs_x]
        if mcs_y:
            self.mcs_ax.plot(
                mcs_x,
                mcs_y,
                color=CLR_ACCENT2,
                marker="o",
                markersize=3,
                linestyle="-",
                linewidth=1.5,
            )
        self.mcs_ax.set_title("Avg MCS (активные UE)", color=CLR_ACCENT)
        self.mcs_ax.set_ylabel("MCS", color=CLR_ACCENT)
        self.mcs_ax.grid(True, linestyle=":", alpha=0.7, color=CLR_ACCENT)
        self.mcs_ax.set_facecolor(CLR_SURFACE)

        self.figure.tight_layout(pad=2.0)
        self.canvas.draw_idle()

    # ------------------------------------------------------------------
    # Цикл обновления
    # ------------------------------------------------------------------
    def _schedule_update(self):
        self._poll_metrics()
        self.root.after(UPDATE_MS, self._schedule_update)

    # ------------------------------------------------------------------
    # Управление SNR
    # ------------------------------------------------------------------
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


# ================= Точка входа =================
def main():
    root = tk.Tk()
    DashboardApp(root, DEFAULT_METRICS_FILE)
    root.mainloop()


if __name__ == "__main__":
    main()
