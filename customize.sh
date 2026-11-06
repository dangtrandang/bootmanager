#!/system/bin/sh
SKIPUNZIP=0

ui_print "*****************************************"
ui_print "*        Boot Delay Manager v1.0        *"
ui_print "*   Tối ưu tốc độ reboot cho Android    *"
ui_print "*****************************************"

ui_print "- Đang thiết lập quyền thực thi cho module..."

set_perm_recursive $MODPATH 0 0 0755 0644
set_perm $MODPATH/service.sh 0 0 0755
set_perm $MODPATH/action.sh 0 0 0755
set_perm $MODPATH/uninstall.sh 0 0 0755
if [ -d "$MODPATH/webroot/cgi-bin" ]; then
    set_perm_recursive $MODPATH/webroot/cgi-bin 0 0 0755 0755
fi

ui_print "- Cài đặt hoàn tất!"
ui_print " "
ui_print "[!] Mở WebUI nhanh bằng cách:"
ui_print "    * Bấm nút [Action] trực tiếp trên thẻ module trong Magisk / KernelSU"
ui_print "    * Hoặc truy cập: http://localhost:8888"
ui_print "*****************************************"
