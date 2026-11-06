#!/system/bin/sh
DATA_DIR="/data/adb/boot_delay_manager"
LIST_FILE="$DATA_DIR/delayed_receivers.list"

# Khôi phục toàn bộ receivers về trạng thái mặc định nếu gỡ module
if [ -f "$LIST_FILE" ]; then
    while IFS= read -r rec || [ -n "$rec" ]; do
        [ -n "$rec" ] && pm default-state "$rec" >/dev/null 2>&1
    done < "$LIST_FILE"
fi

rm -rf "$DATA_DIR" 2>/dev/null
pkill -f "httpd -p 127.0.0.1:8888" >/dev/null 2>&1
