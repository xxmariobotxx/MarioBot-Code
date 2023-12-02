#Python time window
import tkinter as tk
from datetime import datetime, timezone

def get_utc_time():
    # Get current time in UTC
    utc_now = datetime.now(timezone.utc)
    time_str = utc_now.strftime("%H:%M:%S")
    date_str = utc_now.strftime("%Y-%m-%d")
    return time_str, date_str

def update_time_label():
    # Update the label with the current UTC time and date
    time_str, date_str = get_utc_time()
    time_label.config(text=f"{time_str}\n{date_str}")
    root.after(1000, update_time_label)  # Update every 1000 milliseconds (1 second)

# Create the main window
root = tk.Tk()
root.title("UTC Time Display")

# Create a label to display the UTC time and date with white text on black background
time_label = tk.Label(root, font=("Helvetica", 16), bg="black", fg="white", anchor="center")
time_label.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)

# Run the update function initially
update_time_label()

# Start the Tkinter event loop
root.mainloop()