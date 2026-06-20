#!/usr/bin/env python3
"""Tk GUI for iperf3 with live throughput plots."""

from __future__ import annotations

import math
import os
import queue
import re
import shlex
import shutil
import subprocess
import threading
import time
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from tkinter import BOTH, END, LEFT, RIGHT, X, Y, filedialog, messagebox
import tkinter as tk
from tkinter import ttk

os.environ.setdefault("MPLCONFIGDIR", "/tmp/matplotlib")

import matplotlib

matplotlib.use("TkAgg")
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from matplotlib.figure import Figure
from matplotlib.ticker import MultipleLocator


SCRIPT_DIR = Path(__file__).resolve().parent
LOG_BASE_DIR = SCRIPT_DIR / "logs" / "iperf_gui"
IPERF_BIN = "iperf3"
MAX_POINTS = 300

CLR_BG = "#121212"
CLR_SURFACE = "#F5F5F5"
CLR_ACCENT = "#30475E"
CLR_ACCENT2 = "#F05454"
CLR_PANEL = "#171A1F"
CLR_INPUT_BG = "#20242B"
CLR_INPUT_FG = "#F5F5F5"
CLR_MUTED = "#C7CCD6"
CLR_LOG_BG = "#0F1115"
CLR_GRID = "#CAD2DC"

THROUGHPUT_RE = re.compile(
    r"^\[\s*(?P<stream>SUM|\d+)\]\s+"
    r"(?P<start>\d+(?:\.\d+)?)\s*-\s*(?P<end>\d+(?:\.\d+)?)\s+sec\s+"
    r".*?\s+(?P<rate>\d+(?:\.\d+)?)\s+(?P<unit>[KMGT]?bits/sec)\b"
)


def bits_to_mbps(value: float, unit: str) -> float:
    factors = {
        "bits/sec": 1e-6,
        "Kbits/sec": 1e-3,
        "Mbits/sec": 1.0,
        "Gbits/sec": 1e3,
        "Tbits/sec": 1e6,
    }
    return value * factors[unit]


@dataclass
class IperfConfig:
    role: str
    hosts: list[str]
    ports: list[int]
    protocol: str
    traffic: str
    duration: int
    interval: int
    parallel: int
    window: str
    rate: str
    on_time: int
    off_time: int
    cycles: int
    mss: str
    length: str
    burst: str
    reverse: bool


class IperfController:
    def __init__(self, event_callback):
        self.event_callback = event_callback
        self.stop_event = threading.Event()
        self.worker: threading.Thread | None = None
        self.processes: list[subprocess.Popen] = []
        self.lock = threading.Lock()
        self.failure_count = 0

    def running(self) -> bool:
        return self.worker is not None and self.worker.is_alive()

    def start(self, cfg: IperfConfig, log_dir: Path) -> None:
        if self.running():
            raise RuntimeError("An iperf3 job is already running")
        self.stop_event.clear()
        self.failure_count = 0
        self.worker = threading.Thread(target=self._run, args=(cfg, log_dir), daemon=True)
        self.worker.start()

    def stop(self) -> None:
        self.stop_event.set()
        with self.lock:
            for proc in list(self.processes):
                if proc.poll() is None:
                    proc.terminate()
            for proc in list(self.processes):
                try:
                    proc.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    proc.kill()
        self.event_callback(("log", "system", "Stop requested."))

    def _run(self, cfg: IperfConfig, log_dir: Path) -> None:
        try:
            log_dir.mkdir(parents=True, exist_ok=True)
            self.event_callback(("log", "system", f"Log dir: {log_dir}"))
            self.event_callback(("reset_plot",))

            if cfg.role == "server":
                self._run_server(cfg, log_dir)
            elif cfg.role == "client":
                self._run_clients(cfg, log_dir, concurrent=False)
            elif cfg.role == "users":
                self._run_clients(cfg, log_dir, concurrent=True)
            else:
                raise ValueError(f"Unsupported role: {cfg.role}")
        except Exception as exc:  # noqa: BLE001
            self.event_callback(("log", "error", f"{type(exc).__name__}: {exc}"))
        finally:
            with self.lock:
                self.processes.clear()
            self.event_callback(("job_done", self.failure_count))
            self.event_callback(("log", "system", "Job finished."))

    def _register(self, proc: subprocess.Popen) -> None:
        with self.lock:
            self.processes.append(proc)

    def _unregister(self, proc: subprocess.Popen) -> None:
        with self.lock:
            if proc in self.processes:
                self.processes.remove(proc)

    def _stream_process(
        self,
        session: str,
        graph_key: str,
        proc: subprocess.Popen,
        log_path: Path,
        expect_sum: bool,
        time_offset: float = 0.0,
    ) -> int:
        self._register(proc)
        try:
            with log_path.open("a", encoding="utf-8") as handle:
                for line in iter(proc.stdout.readline, ""):
                    if not line:
                        break
                    handle.write(line)
                    handle.flush()
                    stripped = line.rstrip()
                    self.event_callback(("log", session, stripped))
                    self._parse_throughput_line(stripped, graph_key, expect_sum, time_offset)
                    if self.stop_event.is_set():
                        proc.terminate()
                        break
                rc = proc.wait()
                handle.write(f"[exit] rc={rc}\n")
                handle.flush()
                if rc != 0 and not self.stop_event.is_set():
                    self.failure_count += 1
                    self.event_callback(("log", session, f"iperf3 exited with rc={rc}"))
                return rc
        finally:
            self._unregister(proc)

    def _parse_throughput_line(self, line: str, graph_key: str, expect_sum: bool, time_offset: float) -> None:
        if "sender" in line or "receiver" in line:
            return
        match = THROUGHPUT_RE.search(line)
        if not match:
            return
        stream = match.group("stream")
        if expect_sum and stream != "SUM":
            return
        if not expect_sum and stream == "SUM":
            return

        end_t = float(match.group("end")) + time_offset
        mbps = bits_to_mbps(float(match.group("rate")), match.group("unit"))
        self.event_callback(("sample", graph_key, end_t, mbps))

    def _spawn(
        self,
        session: str,
        cmd: list[str],
        log_dir: Path,
        graph_key: str,
        expect_sum: bool,
        time_offset: float = 0.0,
    ) -> int:
        log_path = log_dir / f"{graph_key}.log"
        self.event_callback(("log", session, " ".join(shlex.quote(part) for part in cmd)))
        try:
            proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
            )
        except OSError as exc:
            self.failure_count += 1
            self.event_callback(("log", session, f"Failed to start iperf3 process: {exc}"))
            with log_path.open("a", encoding="utf-8") as handle:
                handle.write(" ".join(shlex.quote(part) for part in cmd) + "\n")
                handle.write(f"[spawn-error] {exc}\n")
            return 1
        return self._stream_process(session, graph_key, proc, log_path, expect_sum, time_offset)

    def _run_server(self, cfg: IperfConfig, log_dir: Path) -> None:
        threads = []
        for idx, port in enumerate(cfg.ports, start=1):
            session = f"server{idx}-p{port}"
            cmd = [IPERF_BIN, "-s", "-p", str(port), "-i", str(cfg.interval), "--forceflush"]
            thread = threading.Thread(
                target=self._spawn,
                args=(session, cmd, log_dir, session, False, 0.0),
                daemon=True,
            )
            threads.append(thread)
            thread.start()

        while not self.stop_event.is_set() and any(thread.is_alive() for thread in threads):
            time.sleep(0.2)

    def _run_clients(self, cfg: IperfConfig, log_dir: Path, concurrent: bool) -> None:
        def run_one(index: int, host: str, port: int) -> None:
            graph_key = f"ue{index}"
            session = f"{graph_key}-{host}-p{port}".replace("/", "_")
            if cfg.traffic == "onoff":
                self._run_onoff(session, graph_key, cfg, host, port, log_dir)
            else:
                cmd = self._build_client_cmd(cfg, host, port, cfg.duration)
                self._spawn(session, cmd, log_dir, graph_key, cfg.parallel > 1, 0.0)

        tasks = list(enumerate(zip(cfg.hosts, cfg.ports), start=1))
        if concurrent:
            threads = []
            for index, (host, port) in tasks:
                thread = threading.Thread(target=run_one, args=(index, host, port), daemon=True)
                threads.append(thread)
                thread.start()
                time.sleep(0.05)
            while not self.stop_event.is_set() and any(thread.is_alive() for thread in threads):
                time.sleep(0.2)
            return

        index, (host, port) = tasks[0]
        run_one(index, host, port)

    def _run_onoff(self, session: str, graph_key: str, cfg: IperfConfig, host: str, port: int, log_dir: Path) -> None:
        for cycle in range(1, cfg.cycles + 1):
            if self.stop_event.is_set():
                break
            cycle_offset = (cycle - 1) * (cfg.on_time + cfg.off_time)
            self.event_callback(("log", session, f"cycle {cycle}/{cfg.cycles}: ON {cfg.on_time}s"))
            cmd = self._build_client_cmd(cfg, host, port, cfg.on_time)
            self._spawn(session, cmd, log_dir, graph_key, cfg.parallel > 1, cycle_offset)
            if cycle < cfg.cycles and not self.stop_event.is_set():
                self.event_callback(("sample", graph_key, cycle_offset + cfg.on_time, 0.0))
                self.event_callback(("sample", graph_key, cycle_offset + cfg.on_time + cfg.off_time, 0.0))
                self.event_callback(("log", session, f"cycle {cycle}/{cfg.cycles}: OFF {cfg.off_time}s"))
                slept = 0.0
                while slept < cfg.off_time and not self.stop_event.is_set():
                    time.sleep(0.2)
                    slept += 0.2

    def _build_client_cmd(self, cfg: IperfConfig, host: str, port: int, duration: int) -> list[str]:
        cmd = [IPERF_BIN, "-c", host, "-p", str(port), "-i", str(cfg.interval), "-t", str(duration), "--forceflush"]

        if cfg.protocol == "udp":
            cmd.append("-u")
        if cfg.parallel > 1:
            cmd += ["-P", str(cfg.parallel)]
        if cfg.window:
            cmd += ["-w", cfg.window]
        if cfg.length:
            cmd += ["-l", cfg.length]
        if cfg.mss:
            cmd += ["-M", cfg.mss]
        if cfg.reverse:
            cmd.append("-R")

        if cfg.traffic == "full":
            pass
        elif cfg.traffic == "cbr":
            if not cfg.rate:
                raise ValueError("Rate is required for CBR mode")
            if cfg.protocol == "udp":
                cmd += ["-b", cfg.rate]
            else:
                cmd += ["--fq-rate", cfg.rate]
        elif cfg.traffic == "onoff":
            if cfg.protocol == "udp":
                if not cfg.rate:
                    raise ValueError("Rate is required for UDP On/Off mode")
                cmd += ["-b", cfg.rate]
            elif cfg.rate:
                cmd += ["--fq-rate", cfg.rate]
        elif cfg.traffic == "burst":
            if cfg.protocol != "udp":
                raise ValueError("Burst mode requires UDP")
            if not cfg.burst:
                raise ValueError("Burst spec is required")
            cmd += ["-b", cfg.burst]
        else:
            raise ValueError(f"Unsupported traffic mode: {cfg.traffic}")

        return cmd


class App(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("ИГТ — Интерфейс Генератора Трафика | iPerf3")
        self.geometry("1440x860")
        self.configure(bg=CLR_BG)

        self.events: queue.Queue[tuple] = queue.Queue()
        self.controller = IperfController(self._enqueue_event)
        self.series_x = defaultdict(list)
        self.series_y = defaultdict(list)
        self.lines = {}
        self.plot_dirty = False
        self.placeholder_map: dict[str, str] = {}
        self.placeholder_widgets: dict[str, ttk.Entry] = {}
        self.placeholder_active: set[str] = set()
        self.current_run_failures = 0

        self._build_vars()
        self._build_ui()
        self.after(100, self._drain_events)

    def _build_vars(self) -> None:
        self.status_var = tk.StringVar(value="Готов")
        self.role_var = tk.StringVar(value="server")
        self.hosts_var = tk.StringVar(value="")
        self.ports_var = tk.StringVar(value="")
        self.protocol_var = tk.StringVar(value="tcp")
        self.traffic_var = tk.StringVar(value="full")
        self.time_var = tk.StringVar(value="")
        self.interval_var = tk.StringVar(value="")
        self.parallel_var = tk.StringVar(value="")
        self.window_var = tk.StringVar(value="")
        self.rate_var = tk.StringVar(value="")
        self.on_var = tk.StringVar(value="")
        self.off_var = tk.StringVar(value="")
        self.cycles_var = tk.StringVar(value="")
        self.mss_var = tk.StringVar(value="")
        self.len_var = tk.StringVar(value="")
        self.burst_var = tk.StringVar(value="")
        self.reverse_var = tk.BooleanVar(value=False)
        self.graph_x_step_var = tk.StringVar(value="1")
        self.graph_y_step_var = tk.StringVar(value="1")
        self.graph_x_max_var = tk.StringVar(value="")
        self.graph_y_max_var = tk.StringVar(value="")

    def _style(self) -> None:
        self.option_add("*TCombobox*Listbox.background", CLR_INPUT_BG)
        self.option_add("*TCombobox*Listbox.foreground", CLR_INPUT_FG)
        self.option_add("*TCombobox*Listbox.selectBackground", CLR_ACCENT)
        self.option_add("*TCombobox*Listbox.selectForeground", CLR_SURFACE)

        style = ttk.Style(self)
        style.theme_use("clam")
        style.configure(".", background=CLR_BG, foreground=CLR_SURFACE, fieldbackground=CLR_BG, font=("Segoe UI", 10))
        style.configure("TFrame", background=CLR_BG)
        style.configure("Panel.TFrame", background=CLR_BG)
        style.configure(
            "TLabelframe",
            background=CLR_BG,
            foreground=CLR_SURFACE,
            bordercolor=CLR_ACCENT,
            lightcolor=CLR_ACCENT,
            darkcolor=CLR_ACCENT,
            relief="solid",
        )
        style.configure("TLabelframe.Label", background=CLR_BG, foreground=CLR_SURFACE, font=("Segoe UI", 10, "bold"))
        style.configure("TLabel", background=CLR_BG, foreground=CLR_SURFACE)
        style.configure("Muted.TLabel", background=CLR_BG, foreground=CLR_MUTED)
        style.configure("Accent.TLabel", background=CLR_BG, foreground=CLR_ACCENT2, font=("Segoe UI", 11, "bold"))
        style.configure("Logo.TLabel", background=CLR_BG, foreground=CLR_ACCENT2, font=("Segoe UI", 18, "bold"))
        style.configure("Author.TLabel", background=CLR_ACCENT, foreground=CLR_SURFACE, font=("Segoe UI", 9, "bold"), padding=6)
        style.configure("TCheckbutton", background=CLR_BG, foreground=CLR_SURFACE)
        style.map("TCheckbutton", background=[("active", CLR_BG)], foreground=[("disabled", "#7F8896")])
        style.configure(
            "Input.TEntry",
            fieldbackground=CLR_INPUT_BG,
            foreground=CLR_INPUT_FG,
            insertcolor=CLR_SURFACE,
            bordercolor=CLR_ACCENT,
            lightcolor=CLR_ACCENT,
            darkcolor=CLR_ACCENT,
            padding=5,
        )
        style.configure(
            "Placeholder.TEntry",
            fieldbackground=CLR_INPUT_BG,
            foreground="#8B95A5",
            insertcolor=CLR_SURFACE,
            bordercolor=CLR_ACCENT,
            lightcolor=CLR_ACCENT,
            darkcolor=CLR_ACCENT,
            padding=5,
        )
        style.configure(
            "Input.TCombobox",
            fieldbackground=CLR_INPUT_BG,
            foreground=CLR_INPUT_FG,
            selectbackground=CLR_ACCENT,
            selectforeground=CLR_SURFACE,
            arrowcolor=CLR_SURFACE,
            bordercolor=CLR_ACCENT,
            lightcolor=CLR_ACCENT,
            darkcolor=CLR_ACCENT,
            padding=4,
        )
        style.map(
            "Input.TCombobox",
            fieldbackground=[("readonly", CLR_INPUT_BG)],
            foreground=[("readonly", CLR_INPUT_FG)],
            selectbackground=[("readonly", CLR_ACCENT)],
            selectforeground=[("readonly", CLR_SURFACE)],
        )
        style.configure("TButton", padding=6, background=CLR_ACCENT, foreground=CLR_SURFACE, bordercolor=CLR_ACCENT)
        style.map("TButton", background=[("active", "#3B5A74"), ("disabled", "#283341")], foreground=[("disabled", "#9CA7B5")])
        style.configure("Primary.TButton", padding=6, background=CLR_ACCENT2, foreground=CLR_SURFACE, bordercolor=CLR_ACCENT2)
        style.map("Primary.TButton", background=[("active", "#FF6B6B"), ("disabled", "#6F3A3A")], foreground=[("disabled", "#D5C2C2")])
        style.configure("TPanedwindow", background=CLR_BG, sashwidth=8)
        style.configure("Vertical.TScrollbar", background=CLR_ACCENT, troughcolor=CLR_PANEL, bordercolor=CLR_BG, arrowcolor=CLR_SURFACE)

    def _build_ui(self) -> None:
        self._style()

        self.columnconfigure(0, weight=1)
        self.rowconfigure(1, weight=1)

        header = ttk.LabelFrame(self, text="Параметры", padding=10)
        header.grid(row=0, column=0, sticky="ew", padx=10, pady=(10, 6))
        header.columnconfigure(5, weight=1)

        ttk.Label(header, text="⚡ ИГТ", style="Logo.TLabel").grid(row=0, column=0, sticky="w", padx=(0, 20))
        ttk.Label(header, text="Роль").grid(row=0, column=1, sticky="w")
        role_box = ttk.Combobox(header, textvariable=self.role_var, values=("server", "client", "users"), state="readonly", width=12, style="Input.TCombobox")
        role_box.grid(row=0, column=2, sticky="w", padx=(8, 14))
        ttk.Label(header, text="Протокол").grid(row=0, column=3, sticky="w")
        proto_box = ttk.Combobox(header, textvariable=self.protocol_var, values=("tcp", "udp"), state="readonly", width=10, style="Input.TCombobox")
        proto_box.grid(row=0, column=4, sticky="w", padx=(8, 14))
        ttk.Label(header, textvariable=self.status_var, style="Accent.TLabel").grid(row=0, column=5, sticky="e")

        content = ttk.Frame(self, style="Panel.TFrame", padding=(10, 0, 10, 10))
        content.grid(row=1, column=0, sticky="nsew")
        content.columnconfigure(1, weight=1)
        content.rowconfigure(0, weight=1)

        left = ttk.Frame(content, style="Panel.TFrame")
        left.grid(row=0, column=0, sticky="nsw", padx=(0, 8))
        left.rowconfigure(1, weight=1)

        form_card = ttk.LabelFrame(left, text="Настройки iperf3", padding=10)
        form_card.grid(row=0, column=0, sticky="new")

        form = ttk.Frame(form_card, style="Panel.TFrame")
        form.pack(fill=X)

        fields = [
            ("Трафик", self.traffic_var, ("full", "cbr", "onoff", "burst"), None),
            ("Hosts", self.hosts_var, None, "172.16.0.10,172.16.0.11"),
            ("Ports", self.ports_var, None, "5201 или 5201,5202"),
            ("Time", self.time_var, None, "60"),
            ("Interval", self.interval_var, None, "1"),
            ("Parallel", self.parallel_var, None, "1"),
            ("Window", self.window_var, None, "512K"),
            ("Rate", self.rate_var, None, "20M"),
            ("On", self.on_var, None, "5"),
            ("Off", self.off_var, None, "5"),
            ("Cycles", self.cycles_var, None, "12"),
            ("MSS", self.mss_var, None, "1460"),
            ("Len", self.len_var, None, "1400"),
            ("Burst", self.burst_var, None, "20M/32"),
        ]

        for idx, (label, var, values, placeholder) in enumerate(fields):
            row = idx
            ttk.Label(form, text=label).grid(row=row, column=0, sticky="w", padx=(0, 8), pady=5)
            if values:
                widget = ttk.Combobox(form, textvariable=var, values=values, state="readonly", width=18, style="Input.TCombobox")
            else:
                widget = ttk.Entry(form, textvariable=var, width=22, style="Input.TEntry")
                if placeholder:
                    self._register_placeholder(widget, var, placeholder)
            widget.grid(row=row, column=1, sticky="ew", padx=(0, 8), pady=5)

        ttk.Checkbutton(form, text="Reverse", variable=self.reverse_var).grid(row=len(fields), column=0, sticky="w", pady=(8, 4))

        form.columnconfigure(1, weight=1)

        actions = ttk.LabelFrame(left, text="Управление", padding=10)
        actions.grid(row=1, column=0, sticky="sew", pady=(8, 0))
        actions.columnconfigure(0, weight=1)
        ttk.Button(actions, text="Старт", style="Primary.TButton", command=self.start_job).grid(row=0, column=0, sticky="ew", pady=(0, 6))
        ttk.Button(actions, text="Стоп", command=self.stop_job).grid(row=1, column=0, sticky="ew", pady=6)
        ttk.Button(actions, text="Очистить лог", command=self.clear_log).grid(row=2, column=0, sticky="ew", pady=6)
        ttk.Button(actions, text="Сохранить лог", command=self.save_log).grid(row=3, column=0, sticky="ew", pady=6)
        ttk.Button(actions, text="Сохранить график", command=self.save_plot).grid(row=4, column=0, sticky="ew", pady=6)
        ttk.Label(actions, text="Логи сохраняются автоматически в scripts/logs/iperf_gui", style="Muted.TLabel", wraplength=220, justify="left").grid(row=5, column=0, sticky="w", pady=(10, 0))

        right = ttk.Frame(content, style="Panel.TFrame")
        right.grid(row=0, column=1, sticky="nsew")
        right.columnconfigure(0, weight=1)
        right.rowconfigure(0, weight=3)
        right.rowconfigure(1, weight=2)

        plot_frame = ttk.LabelFrame(right, text="График Throughput", padding=5)
        plot_frame.grid(row=0, column=0, sticky="nsew")
        plot_frame.columnconfigure(0, weight=1)
        plot_frame.rowconfigure(1, weight=1)

        plot_controls = ttk.Frame(plot_frame, style="Panel.TFrame")
        plot_controls.grid(row=0, column=0, sticky="ew", padx=8, pady=(6, 2))
        for col in (1, 3, 5, 7):
            plot_controls.columnconfigure(col, weight=1)

        ttk.Label(plot_controls, text="Шаг X (с)").grid(row=0, column=0, sticky="w", padx=(0, 6))
        x_step_entry = ttk.Entry(plot_controls, textvariable=self.graph_x_step_var, width=10, style="Input.TEntry")
        x_step_entry.grid(row=0, column=1, sticky="ew", padx=(0, 12))
        ttk.Label(plot_controls, text="Шаг Y (Мбит)").grid(row=0, column=2, sticky="w", padx=(0, 6))
        y_step_entry = ttk.Entry(plot_controls, textvariable=self.graph_y_step_var, width=10, style="Input.TEntry")
        y_step_entry.grid(row=0, column=3, sticky="ew", padx=(0, 12))
        ttk.Label(plot_controls, text="Макс X").grid(row=0, column=4, sticky="w", padx=(0, 6))
        x_max_entry = ttk.Entry(plot_controls, textvariable=self.graph_x_max_var, width=10, style="Input.TEntry")
        x_max_entry.grid(row=0, column=5, sticky="ew", padx=(0, 12))
        self._register_placeholder(x_max_entry, self.graph_x_max_var, "auto")
        ttk.Label(plot_controls, text="Макс Y").grid(row=0, column=6, sticky="w", padx=(0, 6))
        y_max_entry = ttk.Entry(plot_controls, textvariable=self.graph_y_max_var, width=10, style="Input.TEntry")
        y_max_entry.grid(row=0, column=7, sticky="ew", padx=(0, 12))
        self._register_placeholder(y_max_entry, self.graph_y_max_var, "auto")
        ttk.Button(plot_controls, text="Применить", command=self.apply_plot_settings).grid(row=0, column=8, sticky="e")

        fig = Figure(figsize=(10, 4.5), dpi=100)
        self.ax = fig.add_subplot(111)
        fig.patch.set_facecolor(CLR_SURFACE)
        self._style_axes(strict=False)
        self.canvas = FigureCanvasTkAgg(fig, master=plot_frame)
        canvas_widget = self.canvas.get_tk_widget()
        canvas_widget.configure(bg=CLR_BG, borderwidth=1, relief="solid")
        canvas_widget.grid(row=1, column=0, sticky="nsew", padx=8, pady=8)

        console_frame = ttk.LabelFrame(right, text="Логи iperf3", padding=5)
        console_frame.grid(row=1, column=0, sticky="nsew", pady=(8, 0))
        console_frame.columnconfigure(0, weight=1)
        console_frame.rowconfigure(0, weight=1)

        self.console = tk.Text(
            console_frame,
            wrap="word",
            bg=CLR_LOG_BG,
            fg=CLR_SURFACE,
            insertbackground=CLR_SURFACE,
            selectbackground=CLR_ACCENT,
            selectforeground=CLR_SURFACE,
            relief="flat",
            borderwidth=0,
            font=("Cascadia Mono", 10),
        )
        self.console.pack(side=LEFT, fill=BOTH, expand=True, padx=8, pady=8)
        scrollbar = ttk.Scrollbar(console_frame, command=self.console.yview, style="Vertical.TScrollbar")
        scrollbar.pack(side=RIGHT, fill=Y, pady=8)
        self.console.configure(yscrollcommand=scrollbar.set)

        self.role_var.trace_add("write", lambda *_: self._apply_role_defaults())
        self._apply_role_defaults()

        author_frame = ttk.Frame(self, style="Panel.TFrame")
        author_frame.grid(row=2, column=0, sticky="ew", padx=10, pady=(0, 5))
        ttk.Label(author_frame, text="© Dvornikov Andrey style adapted for iPerf3, 2026", style="Author.TLabel").pack(side=RIGHT)

    def _apply_role_defaults(self) -> None:
        role = self.role_var.get()
        placeholder = "5201,5202,5203" if role == "server" else "5201 или 5201,5202"
        key = self._var_key(self.ports_var)
        self.placeholder_map[key] = placeholder
        widget = self.placeholder_widgets.get(key)
        if widget and (key in self.placeholder_active or not self._get_raw(self.ports_var)):
            self.placeholder_active.discard(key)
            self.ports_var.set("")
            self._set_placeholder(widget, self.ports_var)

    def _register_placeholder(self, widget: ttk.Entry, var: tk.StringVar, placeholder: str) -> None:
        key = self._var_key(var)
        self.placeholder_map[key] = placeholder
        self.placeholder_widgets[key] = widget
        widget.bind("<FocusIn>", lambda _event, w=widget, v=var: self._clear_placeholder(w, v), add="+")
        widget.bind("<FocusOut>", lambda _event, w=widget, v=var: self._set_placeholder(w, v), add="+")
        self._set_placeholder(widget, var)

    def _set_placeholder(self, widget: ttk.Entry, var: tk.StringVar) -> None:
        key = self._var_key(var)
        placeholder = self.placeholder_map[key]
        if key in self.placeholder_active and self._get_raw(var) == placeholder:
            widget.configure(style="Placeholder.TEntry")
            return
        if self._get_raw(var):
            widget.configure(style="Input.TEntry")
            self.placeholder_active.discard(key)
            return
        self.placeholder_active.add(key)
        var.set(placeholder)
        widget.configure(style="Placeholder.TEntry")

    def _clear_placeholder(self, widget: ttk.Entry, var: tk.StringVar) -> None:
        key = self._var_key(var)
        if key not in self.placeholder_active:
            widget.configure(style="Input.TEntry")
            return
        self.placeholder_active.discard(key)
        var.set("")
        widget.configure(style="Input.TEntry")

    @staticmethod
    def _var_key(var: tk.StringVar) -> str:
        return str(var)

    def _get_raw(self, var: tk.StringVar) -> str:
        return var.get().strip()

    def _get_string(self, var: tk.StringVar) -> str:
        if self._var_key(var) in self.placeholder_active:
            return ""
        return self._get_raw(var)

    def _read_int(self, var: tk.StringVar, default: int, field_name: str) -> int:
        raw = self._get_string(var)
        if not raw:
            return default
        try:
            value = int(raw)
        except ValueError as exc:
            raise ValueError(f"{field_name}: ожидается целое число") from exc
        if value <= 0:
            raise ValueError(f"{field_name}: ожидается число больше 0")
        return value

    def _read_positive_float(self, var: tk.StringVar, default: float, field_name: str, strict: bool) -> float:
        raw = self._get_string(var)
        if not raw:
            return default
        try:
            value = float(raw)
        except ValueError:
            if strict:
                raise ValueError(f"{field_name}: ожидается число больше 0")
            return default
        if value <= 0:
            if strict:
                raise ValueError(f"{field_name}: ожидается число больше 0")
            return default
        return value

    def _read_optional_positive_float(self, var: tk.StringVar, field_name: str, strict: bool) -> float | None:
        raw = self._get_string(var)
        if not raw:
            return None
        try:
            value = float(raw)
        except ValueError:
            if strict:
                raise ValueError(f"{field_name}: ожидается число больше 0 или пустое поле")
            return None
        if value <= 0:
            if strict:
                raise ValueError(f"{field_name}: ожидается число больше 0 или пустое поле")
            return None
        return value

    @staticmethod
    def _round_up_to_step(value: float, step: float) -> float:
        return max(step, math.ceil(max(value, step) / step) * step)

    def _enqueue_event(self, event: tuple) -> None:
        self.events.put(event)

    def _drain_events(self) -> None:
        try:
            while True:
                event = self.events.get_nowait()
                etype = event[0]
                if etype == "log":
                    _, source, line = event
                    prefix = f"[{source}] " if source else ""
                    self.console.insert(END, prefix + line + "\n")
                    self.console.see(END)
                elif etype == "sample":
                    _, key, t_s, mbps = event
                    self._append_sample(key, float(t_s), float(mbps))
                elif etype == "reset_plot":
                    self._reset_plot()
                elif etype == "job_done":
                    _, failures = event
                    self.current_run_failures = int(failures)
        except queue.Empty:
            pass

        if self.plot_dirty:
            self._redraw_plot()
            self.plot_dirty = False

        if not self.controller.running() and self.status_var.get() not in {"Готов", "Ошибка"}:
            self.status_var.set("Ошибка" if self.current_run_failures else "Готов")

        self.after(100, self._drain_events)

    def _append_sample(self, key: str, t_s: float, mbps: float) -> None:
        xs = self.series_x[key]
        ys = self.series_y[key]
        xs.append(t_s)
        ys.append(mbps)
        if len(xs) > MAX_POINTS:
            del xs[: len(xs) - MAX_POINTS]
            del ys[: len(ys) - MAX_POINTS]
        self.plot_dirty = True

    def _reset_plot(self) -> None:
        self.series_x.clear()
        self.series_y.clear()
        self.lines.clear()
        self.ax.clear()
        self._style_axes(strict=False)
        self.plot_dirty = True

    def _redraw_plot(self) -> None:
        self.ax.clear()
        self._style_axes(strict=False)
        for key in sorted(self.series_x):
            self.ax.plot(self.series_x[key], self.series_y[key], label=key, linewidth=1.8)
        if self.series_x:
            legend = self.ax.legend(loc="upper right", frameon=True, facecolor=CLR_SURFACE, edgecolor=CLR_ACCENT)
            for text in legend.get_texts():
                text.set_color(CLR_ACCENT)
        self.canvas.draw_idle()

    def _style_axes(self, strict: bool) -> None:
        self.ax.set_title("Throughput per Session", fontsize=13, color=CLR_ACCENT)
        self.ax.set_xlabel("Time, s", color=CLR_ACCENT)
        self.ax.set_ylabel("Mbit/s", color=CLR_ACCENT)
        self.ax.tick_params(axis="both", colors=CLR_ACCENT)
        self.ax.grid(True, color=CLR_GRID, alpha=0.9, linewidth=0.8)
        self.ax.set_facecolor(CLR_SURFACE)
        for spine in self.ax.spines.values():
            spine.set_color(CLR_ACCENT)
        self._apply_plot_settings(strict=strict)

    def _apply_plot_settings(self, strict: bool) -> None:
        x_step = self._read_positive_float(self.graph_x_step_var, 1.0, "Шаг X", strict)
        y_step = self._read_positive_float(self.graph_y_step_var, 1.0, "Шаг Y", strict)
        x_max_manual = self._read_optional_positive_float(self.graph_x_max_var, "Макс X", strict)
        y_max_manual = self._read_optional_positive_float(self.graph_y_max_var, "Макс Y", strict)

        x_data_max = max((max(xs) for xs in self.series_x.values() if xs), default=x_step)
        y_data_max = max((max(ys) for ys in self.series_y.values() if ys), default=y_step)

        x_max = x_max_manual if x_max_manual is not None else self._round_up_to_step(x_data_max, x_step)
        y_max = y_max_manual if y_max_manual is not None else self._round_up_to_step(y_data_max, y_step)

        self.ax.set_xlim(0.0, x_max)
        self.ax.set_ylim(0.0, y_max)
        self.ax.xaxis.set_major_locator(MultipleLocator(x_step))
        self.ax.yaxis.set_major_locator(MultipleLocator(y_step))

    def apply_plot_settings(self) -> None:
        try:
            self._style_axes(strict=True)
            self._redraw_plot()
            self.canvas.draw_idle()
        except ValueError as exc:
            messagebox.showerror("Неверные настройки графика", str(exc))

    def _parse_hosts(self, raw: str) -> list[str]:
        return [item.strip() for item in raw.split(",") if item.strip()]

    def _parse_ports(self, raw: str, count: int, role: str) -> list[int]:
        if not raw.strip():
            raw = "5201,5202,5203" if role == "server" else "5201"
        try:
            ports = [int(item.strip()) for item in raw.split(",") if item.strip()]
        except ValueError as exc:
            raise ValueError("Ports: ожидаются целые номера портов через запятую") from exc
        if not ports:
            raise ValueError("Ports: укажи хотя бы один порт")
        if any(port <= 0 or port > 65535 for port in ports):
            raise ValueError("Ports: допустимы значения от 1 до 65535")
        if role != "server" and count > 1 and len(ports) == 1:
            ports *= count
        if role == "server":
            return ports
        if len(ports) != count:
            raise ValueError("Ports count must match hosts count, or be a single port")
        return ports

    def _build_config(self) -> IperfConfig:
        if shutil.which(IPERF_BIN) is None:
            raise ValueError("iperf3 не найден в PATH")
        role = self.role_var.get()
        hosts = self._parse_hosts(self._get_string(self.hosts_var)) if role in {"client", "users"} else []
        if role in {"client", "users"} and not hosts:
            raise ValueError("Hosts: укажи хотя бы один IP-адрес")
        if role == "client" and len(hosts) != 1:
            raise ValueError("Client mode expects exactly one host")
        ports = self._parse_ports(self._get_string(self.ports_var), max(1, len(hosts)), role)
        return IperfConfig(
            role=role,
            hosts=hosts,
            ports=ports,
            protocol=self.protocol_var.get(),
            traffic=self.traffic_var.get(),
            duration=self._read_int(self.time_var, 60, "Time"),
            interval=self._read_int(self.interval_var, 1, "Interval"),
            parallel=self._read_int(self.parallel_var, 1, "Parallel"),
            window=self._get_string(self.window_var),
            rate=self._get_string(self.rate_var),
            on_time=self._read_int(self.on_var, 5, "On"),
            off_time=self._read_int(self.off_var, 5, "Off"),
            cycles=self._read_int(self.cycles_var, 1, "Cycles"),
            mss=self._get_string(self.mss_var),
            length=self._get_string(self.len_var),
            burst=self._get_string(self.burst_var),
            reverse=self.reverse_var.get(),
        )

    def start_job(self) -> None:
        if self.controller.running():
            messagebox.showwarning("Busy", "An iperf3 job is already running.")
            return
        try:
            cfg = self._build_config()
        except Exception as exc:  # noqa: BLE001
            messagebox.showerror("Invalid config", str(exc))
            return

        timestamp = time.strftime("%Y-%m-%d_%H-%M-%S")
        log_dir = LOG_BASE_DIR / timestamp
        self.current_run_failures = 0
        self.status_var.set(f"Выполняется ({cfg.role})")
        self._enqueue_event(("log", "system", f"Starting role={cfg.role}, traffic={cfg.traffic}, protocol={cfg.protocol}"))
        self.controller.start(cfg, log_dir)

    def stop_job(self) -> None:
        self.controller.stop()
        self.status_var.set("Остановка...")

    def clear_log(self) -> None:
        self.console.delete("1.0", END)

    def save_log(self) -> None:
        path = filedialog.asksaveasfilename(
            title="Save console log",
            defaultextension=".log",
            filetypes=[("Log files", "*.log"), ("Text files", "*.txt"), ("All files", "*.*")],
        )
        if not path:
            return
        Path(path).write_text(self.console.get("1.0", END), encoding="utf-8")

    def save_plot(self) -> None:
        path = filedialog.asksaveasfilename(
            title="Сохранить график",
            defaultextension=".png",
            filetypes=[("PNG", "*.png"), ("SVG", "*.svg"), ("PDF", "*.pdf"), ("All files", "*.*")],
        )
        if not path:
            return
        try:
            figure = self.ax.figure
            figure.savefig(path, dpi=150, bbox_inches="tight", facecolor=figure.get_facecolor())
        except Exception as exc:  # noqa: BLE001
            messagebox.showerror("Ошибка сохранения графика", str(exc))


def main() -> None:
    app = App()
    app.mainloop()


if __name__ == "__main__":
    main()
