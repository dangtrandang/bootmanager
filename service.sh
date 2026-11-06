#!/system/bin/sh
MODDIR=${0%/*}
CONFIG_FILE="$MODDIR/config.json"
LOG_FILE="$MODDIR/boot_delay.log"
LIST_FILE="$MODDIR/delayed_receivers.list"
PKGS_FILE="$MODDIR/delayed_packages.list"
WEBROOT="$MODDIR/webroot"
PORT=8888

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "=== Boot Delay Manager Service Started ==="

# 1. Khởi động Web Server
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
    pkill -f "httpd -p 127.0.0.1:$PORT" 2>/dev/null
    $BB httpd -p 127.0.0.1:$PORT -h "$WEBROOT" 2>/dev/null
    log "WebUI started at http://127.0.0.1:$PORT"
fi

# 2. Đọc cấu hình
ENABLED="true"
DELAY=15
if [ -f "$CONFIG_FILE" ]; then
    if grep -q '"enabled": *false' "$CONFIG_FILE"; then
        ENABLED="false"
    else
        ENABLED="true"
    fi

    PARSED_DELAY=$(grep -E -o '"delay": *[0-9]+' "$CONFIG_FILE" | grep -E -o '[0-9]+')
    [ -n "$PARSED_DELAY" ] && DELAY="$PARSED_DELAY"
fi

if [ "$ENABLED" != "true" ]; then
    log "Boot Delay is disabled in config. Service standby."
    exit 0
fi

# 3. Chờ Android hoàn thành boot (sys.boot_completed=1)
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 1
done
log "System boot completed. Device is sitting on lockscreen."

# 4. CHỜ NGƯỜI DÙNG MỞ KHÓA MÀN HÌNH (isKeyguardShowing=false)
log "Waiting for user to unlock the lockscreen..."
while true; do
    if dumpsys window 2>/dev/null | grep -q "isKeyguardShowing=false"; then
        log "User unlocked lockscreen! Starting delay countdown..."
        break
    fi
    sleep 1
done

# 5. ĐẾM NGƯỢC THỜI GIAN VÀ HIỂN THỊ TRÊN THANH NOTIFICATION (chạy dưới UID 2000 shell)
rem=$DELAY
while [ $rem -gt 0 ]; do
    su 2000 -c "cmd notification post -t '⚡ Boot Delay Manager' boot_delay_timer '⏳ Đang hoãn ứng dụng bên thứ 3: còn ${rem}s...'" >/dev/null 2>&1
    sleep 1
    rem=$((rem - 1))
done

su 2000 -c "cmd notification post -t '⚡ Boot Delay Manager' boot_delay_timer '🚀 Hết thời gian hoãn! Đang kích hoạt các ứng dụng...'" >/dev/null 2>&1

# 6. ĐÁNH THỨC CÁC APP BỊ HOÃN
log "Delay finished. Awakening 3rd-party apps now..."

# Kích hoạt lại toàn bộ receivers
if [ -f "$LIST_FILE" ]; then
    COUNT=0
    while IFS= read -r rec || [ -n "$rec" ]; do
        [ -z "$rec" ] && continue
        pm enable "$rec" >/dev/null 2>&1
        COUNT=$((COUNT + 1))
    done < "$LIST_FILE"
    log "Re-enabled $COUNT boot receivers."
fi

# Phát broadcast khởi động toàn diện cho tất cả app
am broadcast -a android.intent.action.BOOT_COMPLETED >/dev/null 2>&1
log "Broadcasted BOOT_COMPLETED to all apps."

# Cập nhật thông báo hoàn tất trên thanh thông báo
su 2000 -c "cmd notification post -t '⚡ Boot Delay Manager' boot_delay_timer '✅ Hệ thống đã sẵn sàng! Đã kích hoạt toàn bộ app.'" >/dev/null 2>&1

# Tái vũ trang (Re-disable) các receivers để sẵn sàng cho lần reboot tiếp theo
if [ -f "$LIST_FILE" ]; then
    while IFS= read -r rec || [ -n "$rec" ]; do
        [ -z "$rec" ] && continue
        pm disable "$rec" >/dev/null 2>&1
    done < "$LIST_FILE"
    log "Re-armed all receivers for next reboot."
fi

log "=== All delayed apps successfully awakened. Ready! ==="
