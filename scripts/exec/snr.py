# snr_slider_gui.py
import tkinter as tk

SNR_FILE = "/tmp/snr"

def set_snr(val):
    with open(SNR_FILE, "w") as f:
        f.write(f"{float(val):.2f}\n")

root = tk.Tk()
root.title("SNR Control")

label = tk.Label(root, text="SNR (dB)", font=("Arial", 14))
label.pack(pady=10)

slider = tk.Scale(
    root,
    from_=-10,
    to=50,
    resolution=0.5,
    orient=tk.HORIZONTAL,
    length=400,
    command=set_snr
)
slider.set(20)
slider.pack(pady=20)

root.mainloop()
