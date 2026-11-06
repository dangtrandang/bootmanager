#!/system/bin/sh
MODDIR=${0%/*}
LIST_FILE="$MODDIR/delayed_receivers.list"

# Khôi phục toàn bộ receivers về trạng thái mặc định nếu gỡ module
if [ -f "$LIST_FILE" ]; then
    while IFS= read -r rec || [ -n "$rec" ]; do
        [ -n "$rec" ] && pm default-state "$rec" >/dev/null 2>&1
    done < "$LIST_FILE"
    rm -f "$LIST_FILE"
fi

# Tắt tiến trình httpd của module
pkill -f "httpd -p 127.0.0.1:8888" >/dev/null 2>&1
