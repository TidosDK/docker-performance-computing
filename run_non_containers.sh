#!/bin/sh

# Exit immediately if a command exits with a non-zero status
set -e

# Handle arguments
if [ "$1" != "run_now_no_reset" ]; then
    sleep 180
fi

AMOUNT_OF_SCRIPTS=5
SCRIPT_DIR="/LOCATION_OF_THIS_FILE"  # Directory where the scripts are located
EXPERIMENT_COUNTER_FILE="$SCRIPT_DIR/experiment-counter-non-container.txt"
SCRIPT="main-non-container.py"
MONITOR_SCRIPT="monitor.py"

# Initialize the experiment counter if it doesn't exist
if [ ! -f "$EXPERIMENT_COUNTER_FILE" ]; then
    echo 1 > "$EXPERIMENT_COUNTER_FILE"  # Initialize the counter file
fi

EXPERIMENT_NUMBER=$(cat "$EXPERIMENT_COUNTER_FILE")
NEXT_EXPERIMENT_NUMBER=$((EXPERIMENT_NUMBER + 1))
echo "$NEXT_EXPERIMENT_NUMBER" > "$EXPERIMENT_COUNTER_FILE"

# Experiment directory
EXPERIMENT_DIR="$SCRIPT_DIR/data-non-container/experiment$EXPERIMENT_NUMBER"
mkdir -p "$EXPERIMENT_DIR"

# Start the instances and capture their PIDs
PIDS=""
for i in $(seq 1 $AMOUNT_OF_SCRIPTS); do
    echo "Starting instance $i..."
    python3 "$SCRIPT_DIR/$SCRIPT" 2>&1 &
    PIDS="$PIDS $!"
done
echo "All $AMOUNT_OF_SCRIPTS instances of $SCRIPT started in the background."
echo "Output logs will be stored in $EXPERIMENT_DIR"

# Run the monitoring script and write its output to a log file
if [ -f "$SCRIPT_DIR/$MONITOR_SCRIPT" ]; then
    echo "Starting CPU and Memory monitoring for the instances..."
    python3 "$SCRIPT_DIR/$MONITOR_SCRIPT" "$SCRIPT" --interval 1 --duration 30 --output_file "$EXPERIMENT_DIR/cpu_usage.log" &
    MONITOR_PID=$!
else
    echo "Monitoring script ($MONITOR_SCRIPT) not found. Skipping monitoring."
fi

# Wait for all instances to finish
echo "\nExperiment running. Waiting for all instances to complete..."
for PID in $PIDS; do
    wait "$PID"
    echo "Instance with PID $PID has completed."
done

sleep 2
echo "All instances of $SCRIPT have completed. Monitoring is complete."

# Move generated files to the experiment directory
echo "Organizing experiment data..."
for FILE in "$SCRIPT_DIR/data-non-container"/*; do
    # Check if the entry exists (handles cases where the directory might be empty)
    if [ -e "$FILE" ]; then
        # Check if it's a regular file
        if [ -f "$FILE" ]; then
            mv "$FILE" "$EXPERIMENT_DIR/"
        fi
    fi
done
echo "\nExperiment completed. Data saved in $EXPERIMENT_DIR"

# Reboot the system if required
if [ "$1" != "run_now_no_reset" ]; then
    echo "Rebooting system..."
    sudo reboot
fi
