import json
import time
from collections import deque

from PyQt5 import QtWidgets, QtCore
import pyqtgraph as pg


FILE_PATH = "/tmp/enb_report.json"


# =========================
# Tail reader (как tail -f)
# =========================
class FileTail:
    def __init__(self, path):
        self.file = open(path, "r")
        self.file.seek(0, 2)  # jump to end

    def read_new(self):
        lines = []
        while True:
            line = self.file.readline()
            if not line:
                break
            lines.append(line)
        return lines


# =========================
# Stream JSON parser
# =========================
class JSONStreamParser:
    def __init__(self):
        self.buffer = ""

    def feed(self, data):
        self.buffer += data
        objects = []

        while True:
            try:
                obj, idx = json.JSONDecoder().raw_decode(self.buffer)
                objects.append(obj)
                self.buffer = self.buffer[idx:].lstrip()
            except json.JSONDecodeError:
                break

        return objects


# =========================
# Data storage
# =========================
class MetricsStore:
    def __init__(self, maxlen=200):
        self.timestamps = deque(maxlen=maxlen)
        self.cqi = deque(maxlen=maxlen)
        self.snr = deque(maxlen=maxlen)
        self.mcs = deque(maxlen=maxlen)

    def add(self, ts, cqi, snr, mcs):
        self.timestamps.append(ts)
        self.cqi.append(cqi)
        self.snr.append(snr)
        self.mcs.append(mcs)


# =========================
# UI
# =========================
class Dashboard(QtWidgets.QMainWindow):
    def __init__(self, store):
        super().__init__()
        self.store = store

        self.setWindowTitle("eNB Metrics Monitor")
        self.resize(1000, 600)

        widget = QtWidgets.QWidget()
        layout = QtWidgets.QVBoxLayout(widget)

        self.cqi_plot = pg.PlotWidget(title="DL CQI")
        self.snr_plot = pg.PlotWidget(title="UL SNR")
        self.mcs_plot = pg.PlotWidget(title="DL MCS")

        layout.addWidget(self.cqi_plot)
        layout.addWidget(self.snr_plot)
        layout.addWidget(self.mcs_plot)

        self.setCentralWidget(widget)

        self.cqi_curve = self.cqi_plot.plot(pen="y")
        self.snr_curve = self.snr_plot.plot(pen="r")
        self.mcs_curve = self.mcs_plot.plot(pen="g")

        self.timer = QtCore.QTimer()
        self.timer.timeout.connect(self.update_plots)
        self.timer.start(500)

    def update_plots(self):
        if not self.store.timestamps:
            return

        x = list(range(len(self.store.timestamps)))

        self.cqi_curve.setData(x, list(self.store.cqi))
        self.snr_curve.setData(x, list(self.store.snr))
        self.mcs_curve.setData(x, list(self.store.mcs))


# =========================
# Metrics extractor
# =========================
def extract_metrics(obj):
    if obj.get("type") != "metrics":
        return None

    ts = obj.get("timestamp")

    try:
        ue = obj["cell_list"][0]["cell_container"]["ue_list"][0]["ue_container"]

        cqi = ue.get("dl_cqi", 0)
        snr = ue.get("ul_snr", 0)
        mcs = ue.get("dl_mcs", 0)

        return ts, cqi, snr, mcs

    except (KeyError, IndexError):
        return None


# =========================
# Main loop
# =========================
def main():
    app = QtWidgets.QApplication([])

    tail = FileTail(FILE_PATH)
    parser = JSONStreamParser()
    store = MetricsStore()

    dashboard = Dashboard(store)
    dashboard.show()

    def poll_file():
        lines = tail.read_new()
        if not lines:
            return

        data = "".join(lines)
        objects = parser.feed(data)

        for obj in objects:
            result = extract_metrics(obj)
            if result:
                ts, cqi, snr, mcs = result
                store.add(ts, cqi, snr, mcs)

    timer = QtCore.QTimer()
    timer.timeout.connect(poll_file)
    timer.start(200)

    app.exec_()


if __name__ == "__main__":
    main()
