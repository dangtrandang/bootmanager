#!/system/bin/sh
SKIPUNZIP=0

ui_print "*****************************************"
ui_print "*        Boot Delay Manager v1.4        *"
ui_print "*   Tối ưu tốc độ reboot cho Android    *"
ui_print "*****************************************"

ui_print "- Đang thiết lập quyền thực thi cho module..."

DATA_DIR="/data/adb/boot_delay_manager"
mkdir -p "$DATA_DIR" 2>/dev/null

if [ ! -f "$DATA_DIR/config.json" ]; then
    cp -f "$MODPATH/config.json" "$DATA_DIR/config.json" 2>/dev/null
fi

set_perm_recursive $MODPATH 0 0 0755 0644
set_perm $MODPATH/service.sh 0 0 0755
set_perm $MODPATH/action.sh 0 0 0755
set_perm $MODPATH/uninstall.sh 0 0 0755
if [ -d "$MODPATH/webroot/cgi-bin" ]; then
    set_perm_recursive $MODPATH/webroot/cgi-bin 0 0 0755 0755
fi

ui_print "- Đang quét và kích hoạt khóa BootReceivers..."
sh "$MODPATH/webroot/cgi-bin/save_config.sh" >/dev/null 2>&1

ui_print "- Cài đặt hoàn tất!"
ui_print " "
ui_print "[!] Lưu ý:"
ui_print "    * Sau khi mở khóa màn hình, đếm ngược sẽ hiện trên thanh Notification."
ui_print "    * Hết giờ đếm ngược, toàn bộ app startup sẽ được kích hoạt tuần tự."
ui_print "*****************************************"
