#!/bin/sh

if [ "$1" != "run_now_no_reset" ]; then
    sleep 180
fi

# Number of containers to run
AMOUNT_OF_CONTAINERS=5
SCRIPT_DIR="/LOCATION_OF_THIS_FILE"  # Directory where the script is located
EXPERIMENT_COUNTER_FILE="$SCRIPT_DIR/experiment_counter.txt"

# Retrieve and increment the experiment number
if [ ! -f "$EXPERIMENT_COUNTER_FILE" ]; then
    echo 1 > "$EXPERIMENT_COUNTER_FILE"  # Initialize the counter file if it doesn't exist
fi
EXPERIMENT_NUMBER=$(cat "$EXPERIMENT_COUNTER_FILE")
NEXT_EXPERIMENT_NUMBER=$((EXPERIMENT_NUMBER + 1))
echo "$NEXT_EXPERIMENT_NUMBER" > "$EXPERIMENT_COUNTER_FILE"

# Experiment directory
EXPERIMENT_DIR="$SCRIPT_DIR/data/experiment$EXPERIMENT_NUMBER"
mkdir -p "$EXPERIMENT_DIR"

# Build the Docker image
docker build -t docker-performance-computing .

# Start the containers and store their names
CONTAINERS=""
i=1
while [ "$i" -le "$AMOUNT_OF_CONTAINERS" ]; do
    CONTAINER_NAME="docker-performance-computing_$i"
    docker run --rm -d \
        --name "$CONTAINER_NAME" \
        --mount type=bind,source="$SCRIPT_DIR/data",target=/data \
        docker-performance-computing
    CONTAINERS="$CONTAINERS $CONTAINER_NAME"
    i=$((i + 1))
done

echo "$AMOUNT_OF_CONTAINERS containers started, saving data to $SCRIPT_DIR/data."

# Function to monitor CPU usage in real-time
monitor_cpu_usage() {
    MONITOR_FILE="$EXPERIMENT_DIR/cpu_usage.log"
    echo "Monitoring CPU usage for containers: $CONTAINERS"

    # Start docker stats in streaming mode
    docker stats --format "table {{.Container}}\t{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" $CONTAINERS | {
        # Compute the number of samples to skip
        skip=$((2 * AMOUNT_OF_CONTAINERS))
        while read -r line; do
            if echo "$line" | grep -q "MEM USAGE"; then
                continue  # Skip the header line
            fi

            # Skip the first 'skip' iterations
            if [ $skip -gt 0 ]; then
                skip=$((skip - 1))
                continue
            fi

            # Extract metrics
            container=$(echo "$line" | awk '{print $1}')
            cpu=$(echo "$line" | awk '{print $3}' | sed 's/%//')
            mem_usage=$(echo "$line" | awk '{print $4}' | cut -d'/' -f1)

            # Normalize memory units
            if echo "$mem_usage" | grep -q "GiB"; then
                mem_usage=$(echo "$mem_usage" | sed 's/GiB//' | awk '{print $1 * 1024}')
            elif echo "$mem_usage" | grep -q "KiB"; then
                mem_usage=$(echo "$mem_usage" | sed 's/KiB//' | awk '{print $1 / 1024}')
            else
                mem_usage=$(echo "$mem_usage" | sed 's/MiB//')
            fi

            # Append the processed metrics to the monitor file
            echo "$container,$cpu,$mem_usage" >> "$MONITOR_FILE"
        done
    } &

    MONITOR_PID=$!
}

# Track the current state of the data directory
PREVIOUS_DATA_CONTENT=$(ls "$SCRIPT_DIR/data")

# Start monitoring CPU usage
monitor_cpu_usage

# Wait for all containers to finish
for CONTAINER in $CONTAINERS; do
    docker wait "$CONTAINER" >/dev/null 2>&1
done

# Stop CPU usage monitoring
if [ -n "$MONITOR_PID" ]; then
    echo "Stopping CPU usage monitoring."
    kill "$MONITOR_PID" 2>/dev/null
fi

echo "All containers have stopped. Monitoring is complete."

# Move generated files to the experiment directory
echo "Organizing experiment data..."
for FILE in "$SCRIPT_DIR/data"/*; do
    BASENAME=$(basename "$FILE")
    if ! echo "$PREVIOUS_DATA_CONTENT" | grep -q "$BASENAME"; then
        mv "$FILE" "$EXPERIMENT_DIR/"
    fi
done

echo "Experiment completed. Data saved in $EXPERIMENT_DIR."

if [ "$1" != "run_now_no_reset" ]; then
    echo "Rebooting system..."
    sudo reboot
fi
