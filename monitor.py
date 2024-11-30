import psutil
import time
import argparse
import os


def track_program_metrics(target_script, interval=1, duration=30, output_file="cpu_usage.log"):
    """
    Tracks CPU and Memory usage of all processes running the target_script.

    Args:
        target_script (str): The name of the script to monitor (e.g., 'main-non-container.py').
        interval (int, optional): Time between each measurement in seconds. Defaults to 2.
        duration (int, optional): Total duration for monitoring in seconds. Defaults to 120.
        output_file (str, optional): The log file to write the metrics. Defaults to 'cpu_usage.log'.
    """
    current_pid = os.getpid()
    start_time = time.time()

    # Open the log file for writing
    with open(output_file, mode='w') as logfile:
        # Initialize CPU percent measurement for accurate readings
        for process in psutil.process_iter(['pid', 'name', 'cmdline']):
            if process.info['cmdline'] and any(target_script == os.path.basename(arg) for arg in process.info['cmdline']):
                if process.info['pid'] == current_pid:
                    continue  # Exclude itself
                try:
                    process.cpu_percent(interval=None)
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue

        # Optional: Sleep briefly to allow CPU percent to stabilize
        time.sleep(1)

        while time.time() - start_time < duration:
            # Find all processes matching the script name
            target_processes = [
                p for p in psutil.process_iter(['pid', 'name', 'cmdline', 'memory_info'])
                if p.info['cmdline']
                and any(target_script == os.path.basename(arg) for arg in p.info['cmdline'])
                and p.info['pid'] != current_pid
            ]

            if not target_processes:
                # Optionally, log or handle the case where no processes are found
                pass
            else:
                for process in target_processes:
                    try:
                        # CPU usage since last call
                        cpu_usage = process.cpu_percent(interval=None)

                        # Memory usage in MB
                        memory_info = process.memory_info()
                        memory_usage_mb = memory_info.rss / (1024 * 1024)  # Convert bytes to MB

                        # Write the metrics to the log file with the desired format
                        process_identifier = f"PID-{process.info['pid']}-({process.info['name']})"
                        logfile.write(f"{process_identifier},{cpu_usage:.2f},{memory_usage_mb:.3f}\n")
                    except (psutil.NoSuchProcess, psutil.AccessDenied):
                        # Optionally, handle processes that have terminated or can't be accessed
                        continue

            time.sleep(interval)

    print(f"Monitoring completed. Metrics saved to {output_file}.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Monitor CPU and Memory usage of a specific script.")
    parser.add_argument("target_script", help="The name of the script to monitor (e.g., 'main-non-container.py').")
    parser.add_argument("--interval", type=int, default=1, help="Time between measurements in seconds.")
    parser.add_argument("--duration", type=int, default=30, help="Total duration for monitoring in seconds.")
    parser.add_argument("--output_file", type=str, default="cpu_usage.log", help="Log file to write the metrics.")
    args = parser.parse_args()

    track_program_metrics(
        target_script=args.target_script,
        interval=args.interval,
        duration=args.duration,
        output_file=args.output_file
    )
