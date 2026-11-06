#!/system/bin/sh
printf "Content-Type: application/json\r\n\r\n"

DATA_DIR="/data/adb/boot_delay_manager"
CONFIG_FILE="$DATA_DIR/config.json"
LIST_FILE="$DATA_DIR/delayed_receivers.list"
PKGS_FILE="$DATA_DIR/delayed_packages.list"

mkdir -p "$DATA_DIR" 2>/dev/null

# Chỉ ghi đè CONFIG_FILE nếu nhận được body từ HTTP POST
if [ -n "$CONTENT_LENGTH" ] && [ "$CONTENT_LENGTH" -gt 0 ] 2>/dev/null; then
    head -c "$CONTENT_LENGTH" > "$CONFIG_FILE"
fi

# 1. Khôi phục các receiver đã disable trước đó để query đầy đủ
if [ -f "$LIST_FILE" ]; then
    while IFS= read -r rec || [ -n "$rec" ]; do
        [ -n "$rec" ] && pm enable "$rec" >/dev/null 2>&1
    done < "$LIST_FILE"
    rm -f "$LIST_FILE"
fi
rm -f "$PKGS_FILE"

# 2. Đọc cấu hình
ENABLED="true"
DELAY_ALL="false"
if [ -f "$CONFIG_FILE" ]; then
    if grep -q '"enabled": *false' "$CONFIG_FILE"; then
        ENABLED="false"
    else
        ENABLED="true"
    fi

    if grep -q '"delay_all_third_party": *true' "$CONFIG_FILE"; then
        DELAY_ALL="true"
    else
        DELAY_ALL="false"
    fi
fi

DISABLED_COUNT=0

if [ "$ENABLED" = "true" ]; then
    TARGET_PKGS=""
    if [ "$DELAY_ALL" = "true" ]; then
        TARGET_PKGS=$(pm list packages -3 2>/dev/null | sed 's/package://g' | tr -d '\r')
    else
        TARGET_PKGS=$(grep -o '"[a-zA-Z0-9._]*"' "$CONFIG_FILE" | tr -d '"\r' | grep -v 'packages' | grep -v 'delay' | grep -v 'enabled' | grep -v 'delay_all_third_party' | grep -v 'true' | grep -v 'false')
    fi

    # Lưu danh sách package
    for pkg in $TARGET_PKGS; do
        [ -n "$pkg" ] && echo "$pkg" >> "$PKGS_FILE"
    done

    # Quét tất cả boot receivers và disable
    (
        cmd package query-receivers --brief -a android.intent.action.BOOT_COMPLETED 2>/dev/null
        cmd package query-receivers --brief -a android.intent.action.LOCKED_BOOT_COMPLETED 2>/dev/null
    ) | grep / | tr -d ' \r' | while read -r rec; do
        [ -z "$rec" ] && continue
        pkg=$(echo "$rec" | cut -d/ -f1)
        if echo "$TARGET_PKGS" | grep -q "^${pkg}$"; then
            pm disable "$rec" >/dev/null 2>&1
            echo "$rec" >> "$LIST_FILE"
        fi
    done

    if [ -f "$LIST_FILE" ]; then
        sort -u -o "$LIST_FILE" "$LIST_FILE" 2>/dev/null
        DISABLED_COUNT=$(wc -l < "$LIST_FILE" 2>/dev/null || echo 0)
    fi
fi

echo "{\"status\": \"ok\", \"disabled_receivers\": $DISABLED_COUNT}"
