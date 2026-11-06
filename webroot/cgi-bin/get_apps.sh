#!/system/bin/sh
printf "Content-Type: application/json\r\n\r\n"

MODDIR="/data/adb/modules/boot_delay_manager"
CONFIG_FILE="$MODDIR/config.json"

# Lấy danh sách app bên thứ 3
APPS=$(pm list packages -3 2>/dev/null | sed 's/package://g' | sort)
APPS_JSON=""
for p in $APPS; do
    [ -z "$p" ] && continue
    if [ -z "$APPS_JSON" ]; then
        APPS_JSON="\"$p\""
    else
        APPS_JSON="$APPS_JSON, \"$p\""
    fi
done

CURRENT_CONFIG="{}"
if [ -f "$CONFIG_FILE" ]; then
    CURRENT_CONFIG=$(cat "$CONFIG_FILE")
else
    CURRENT_CONFIG='{"enabled": true, "delay": 15, "delay_all_third_party": false, "packages": []}'
fi

echo "{\"all_apps\": [$APPS_JSON], \"config\": $CURRENT_CONFIG}"

