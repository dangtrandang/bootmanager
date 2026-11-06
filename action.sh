#!/system/bin/sh
MODDIR=${0%/*}
PORT=8888
WEBROOT="$MODDIR/webroot"

# 1. Đảm bảo server WebUI đang chạy (nếu bị tắt thì khởi động lại)
if ! pgrep -f "httpd -p 127.0.0.1:$PORT" >/dev/null 2>&1; then
    BB=""
    if [ -f "/data/adb/magisk/busybox" ]; then
        BB="/data/adb/magisk/busybox"
    elif [ -f "/data/adb/ksu/bin/busybox" ]; then
        BB="/data/adb/ksu/bin/busybox"
    elif [ -f "/data/adb/ap/bin/busybox" ]; then
        BB="/data/adb/ap/bin/busybox"
    elif command -v busybox >/dev/null 2>&1; then
        BB="busybox"
    fi

    if [ -n "$BB" ] && [ -d "$WEBROOT" ]; then
        chmod +x "$WEBROOT/cgi-bin/"*.sh 2>/dev/null
        $BB httpd -p 127.0.0.1:$PORT -h "$WEBROOT" 2>/dev/null
    fi
fi

# 2. Bắn Intent mở ngay trình duyệt mặc định trên máy vào localhost:8888
am start -a android.intent.action.VIEW -d "http://localhost:$PORT" >/dev/null 2>&1

