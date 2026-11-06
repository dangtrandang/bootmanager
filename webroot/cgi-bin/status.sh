#!/system/bin/sh
printf "Content-Type: application/json\r\n\r\n"

DATA_DIR="/data/adb/boot_delay_manager"
LOG_FILE="$DATA_DIR/boot_delay.log"
LIST_FILE="$DATA_DIR/delayed_receivers.list"

BOOT_COMPLETED=$(getprop sys.boot_completed)
UPTIME=$(uptime 2>/dev/null || echo "Unknown")

LOGS=""
if [ -f "$LOG_FILE" ]; then
    LOGS=$(tail -n 20 "$LOG_FILE" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}')
fi

HELD_RECEIVERS=0
if [ -f "$LIST_FILE" ]; then
    HELD_RECEIVERS=$(wc -l < "$LIST_FILE" 2>/dev/null || echo 0)
fi

echo "{\"boot_completed\": \"$BOOT_COMPLETED\", \"uptime\": \"$UPTIME\", \"held_receivers\": $HELD_RECEIVERS, \"logs\": \"$LOGS\"}"
