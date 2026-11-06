#!/system/bin/sh
MODDIR=${0%/*}
DATA_DIR="/data/adb/boot_delay_manager"
CONFIG_FILE="$DATA_DIR/config.json"
LOG_FILE="$DATA_DIR/boot_delay.log"
LIST_FILE="$DATA_DIR/delayed_receivers.list"
PKGS_FILE="$DATA_DIR/delayed_packages.list"
WEBROOT="$MODDIR/webroot"
PORT=8888

mkdir -p "$DATA_DIR" 2>/dev/null

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

# 3. Đảm bảo danh sách receivers đầy đủ và bị khóa TRƯỚC KHI Android hoàn tất boot
REC_COUNT=0
[ -f "$LIST_FILE" ] && REC_COUNT=$(wc -l < "$LIST_FILE" 2>/dev/null || echo 0)

if [ "$REC_COUNT" -lt 10 ]; then
    log "Receiver list missing or incomplete ($REC_COUNT). Performing automatic scan from manifest..."
    pm list packages -3 2>/dev/null | sed 's/package://' | tr -d '\r ' > "$PKGS_FILE"
    dumpsys package receivers 2>/dev/null | awk '
    /android.intent.action.(LOCKED_)?BOOT_COMPLETED:/ { in_boot=1; next }
    /^[ ]*[a-zA-Z0-9._-]+:/ { if ($0 !~ /BOOT_COMPLETED/) in_boot=0 }
    in_boot && /\// {
        for (i=1; i<=NF; i++) {
            if ($i ~ /^[a-zA-Z0-9._-]+\/[a-zA-Z0-9._$-]+$/) {
                comp = $i
                split(comp, parts, "/")
                pkg = parts[1]
                cls = parts[2]
                if (substr(cls, 1, 1) == ".") {
                    cls = pkg cls
                }
                print pkg "/" cls
            }
        }
    }
    ' | sort -u > /data/local/tmp/all_boot_receivers.txt
    grep -Ff "$PKGS_FILE" /data/local/tmp/all_boot_receivers.txt 2>/dev/null | sort -u > "$LIST_FILE"
    rm -f /data/local/tmp/all_boot_receivers.txt 2>/dev/null
    REC_COUNT=$(wc -l < "$LIST_FILE" 2>/dev/null || echo 0)
    log "Scan completed. Found $REC_COUNT 3rd-party boot receivers."
fi

if [ -f "$LIST_FILE" ]; then
    while IFS= read -r rec || [ -n "$rec" ]; do
        [ -z "$rec" ] && continue
        pm disable "$rec" >/dev/null 2>&1
    done < "$LIST_FILE"
    log "Pre-boot check: All $REC_COUNT boot receivers confirmed disabled before boot completion."
fi

# 4. Chờ Android hoàn thành boot (sys.boot_completed=1)
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 1
done
log "System boot completed. Device is sitting on lockscreen."

# 5. CHỜ NGƯỜI DÙNG MỞ KHÓA MÀN HÌNH (isKeyguardShowing=false)
log "Waiting for user to unlock the lockscreen..."
while true; do
    if dumpsys window 2>/dev/null | grep -q "isKeyguardShowing=false"; then
        log "User unlocked lockscreen! Starting delay countdown..."
        break
    fi
    sleep 1
done

# 6. ĐẾM NGƯỢC THỜI GIAN VÀ HIỂN THỊ TRÊN THANH NOTIFICATION (UID 2000 shell)
rem=$DELAY
while [ $rem -gt 0 ]; do
    su 2000 -c "cmd notification post -t '⚡ Boot Delay Manager' boot_delay_timer '⏳ Đang hoãn ứng dụng bên thứ 3: còn ${rem}s...'" >/dev/null 2>&1
    sleep 1
    rem=$((rem - 1))
done

su 2000 -c "cmd notification post -t '⚡ Boot Delay Manager' boot_delay_timer '🚀 Hết thời gian hoãn! Đang kích hoạt các ứng dụng...'" >/dev/null 2>&1

# 7. ĐÁNH THỨC CÁC APP BỊ HOÃN
log "Delay finished. Awakening 3rd-party apps now..."

# BƯỚC A: Mở lại từng boot receiver và BẮN TRỰC TIẾP broadcast đích danh (-n) vào receiver đó
if [ -f "$LIST_FILE" ]; then
    COUNT=0
    while IFS= read -r rec || [ -n "$rec" ]; do
        [ -z "$rec" ] && continue
        pm enable "$rec" >/dev/null 2>&1
        am broadcast -a android.intent.action.BOOT_COMPLETED -n "$rec" >/dev/null 2>&1
        COUNT=$((COUNT + 1))
    done < "$LIST_FILE"
    log "Awakened $COUNT boot receivers directly via -n component."
fi

# BƯỚC B: Bắn bổ sung theo package (-p) để đảm bảo không sót WorkManager/JobScheduler
if [ -f "$PKGS_FILE" ]; then
    while IFS= read -r pkg || [ -n "$pkg" ]; do
        [ -z "$pkg" ] && continue
        am broadcast -a android.intent.action.BOOT_COMPLETED -p "$pkg" >/dev/null 2>&1
    done < "$PKGS_FILE"
    log "Sent package-level BOOT_COMPLETED to all packages."
fi

# Cập nhật thông báo hoàn tất trên thanh thông báo
su 2000 -c "cmd notification post -t '⚡ Boot Delay Manager' boot_delay_timer '✅ Hệ thống đã sẵn sàng! Đã kích hoạt toàn bộ app.'" >/dev/null 2>&1
log "=== All delayed apps successfully awakened and kept running! ==="

# 8. SHUTDOWN HOOK: Lắng nghe lệnh Tắt máy / Khởi động lại để tái vũ trang trước khi tắt nguồn
# (KHÔNG chạy pm disable khi máy đang dùng bình thường để tránh kill app đang chạy)
while true; do
    PWR=$(getprop sys.powerctl)
    SHUT=$(getprop sys.shutdown.requested)
    if [ -n "$PWR" ] || [ -n "$SHUT" ]; then
        log "Shutdown/reboot detected ($PWR $SHUT). Disabling boot receivers for next boot..."
        if [ -f "$LIST_FILE" ]; then
            while IFS= read -r rec || [ -n "$rec" ]; do
                [ -z "$rec" ] && continue
                pm disable "$rec" >/dev/null 2>&1
            done < "$LIST_FILE"
        fi
        log "All receivers armed for next boot."
        break
    fi
    sleep 1
done

