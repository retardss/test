#!/system/bin/sh

# @HemanthJabalpuri XDA

# Replace KingRoot or Kingo ROOT possibly others with SuperSU
# Idea to remove root from terminal with shell script is by Mr.Wolf and edited his script
# +for compatible of newer versions of KingRoot
# Newer versions of KingRoot are capable of recreating deleted files immediately
# For this you need to completely uninstall KingRoot app
# +or delete files of KingRoot in /data will solve this
# My script will do the same thing by deleting all dirs and files of KingRoot
# +and capable of flashing SuperSU directly in booted android without need of custom recovery

##########################################################################################
# Helper Functions
##########################################################################################
delete() {
  [ -z "$1" ] && return
  if [ -f $1 -o -L $1 ]; then
    echo "removing file--$1" >&2
  elif [ -d $1 ]; then
    echo "removing dir--$1" >&2
  fi
  chattr -ia $1 2>/dev/null
  shred -fzu $1 2>/dev/null
  rm -rf $1
}

move() {
  chattr -ia $1
  if [ -f $2 ]; then
    chattr -ia $2
  fi
  mv -f $1 $2
}

set_perm() {
  chown $1 "$4"; chgrp $2 "$4"
  chmod $3 "$4"
  if [ -z "$5" ] ; then
    chcon u:object_r:system_file:s0 "$4"
  else
    chcon u:object_r:$5:s0 "$4"
  fi
}

get_context() {
  CON=$(ls -Z "$1" 2>/dev/null | grep "u:object_r" | cut -d: -f3)
  if [ -z "$CON" ] ; then
    CON=$(LD_LIBRARY_PATH=/system/lib:/vendor/lib /system/bin/toolbox ls -Z "$1" 2>/dev/null | grep "u:object_r" | cut -d: -f3)
  fi
  if [ -z "$CON" ] ; then
    CON=$(LD_LIBRARY_PATH=/system/lib:/vendor/lib /system/bin/toybox ls -Z "$1" 2>/dev/null | grep "u:object_r" | cut -d: -f3)
  fi
  if [ -z "$CON" ] ; then
    CON=system_file
  fi
  echo "$CON"
}

find_delete() {
  if [ "$find_delete_app" -eq "3" ]; then
    return
  fi
  greppkg="$(pm list packages -f 2>/dev/null | grep -i "$1" | head -n1 | cut -d= -f2)"

  if [ -z "$greppkg" ]; then
    return
  else
    find_delete_app=$((find_delete_app+1))
  fi
  rootapk="$(dumpsys package $greppkg | grep -i "codepath" | head -n1 | cut -d= -f2 | cut -d' ' -f1)"
  rootlib="$(dumpsys package $greppkg | grep -i "nativelibrarypath" | head -n1 | cut -d= -f2 | cut -d' ' -f1)"
  rootdata="$(dumpsys package $greppkg | grep -i "datadir" | head -n1 | cut -d= -f2 | cut -d' ' -f1)"
  rootver="$(dumpsys package $greppkg | grep -i "versionname" | head -n1 | cut -d= -f2 | cut -d' ' -f1)"
  rootverc="$(dumpsys package $greppkg | grep -i "versioncode" | head -n1 | cut -d= -f2 | cut -d' ' -f1)"
  echo "$rootapk--$rootver--$rootverc--$rootdata--$rootlib" >&2

  sys=0
  if [ "$(dumpsys package $greppkg | grep -ci "codepath")" -eq 2 ]; then
    rootsysapk="$(dumpsys package $greppkg | grep -i "codepath" | tail -n1 | cut -d= -f2 | cut -d' ' -f1)"
    rootsysver="$(dumpsys package $greppkg | grep -i "versionname" | tail -n1 | cut -d= -f2 | cut -d' ' -f1)"
    rootsysverc="$(dumpsys package $greppkg | grep -i "versioncode" | tail -n1 | cut -d= -f2 | cut -d' ' -f1)"
    echo "$rootsysapk--$rootsysver--$rootsysverc" >&2
    sys=1
  fi

  LD_LIBRARY_PATH=/system/lib:/vendor/lib am force-stop $greppkg >/dev/null 2>&1
  LD_LIBRARY_PATH=/system/lib:/vendor/lib am kill $greppkg >/dev/null 2>&1
  for i in disable block clear uninstall; do
    LD_LIBRARY_PATH=/system/lib:/vendor/lib pm $i $greppkg >/dev/null 2>&1
  done
  delete "$rootapk"
  delete "$rootdata"
  delete "$rootlib"
  find /data/dalvik-cache -iname *${greppkg}* -delete

  if [ "$sys" -eq "1" ]; then
    delete "$rootsysapk"
    find /data/dalvik-cache -iname *$(basename $rootsysapk)* -delete
  fi
}

sha1_check() {
  [ $2 = "$(sha1sum "$1" | cut -d' ' -f1)" ] && return 0
  return 1
}

getdir() {
  case "$1" in
    */*) dir=${1%/*}; [ -z $dir ] && echo "/" || echo $dir ;;
    *) echo "." ;;
  esac
}

is_substring() {
  case "$2" in
    *$1*) return 0;;
    *) return 1;;
  esac;
}

abort() {
  echo
  for i in "$@"; do
    echo -e $R"  ${i}\n"$N
  done
  rm "$cdir/busybox-arm" "$cdir/busybox-mips" "$cdir/busybox-x86" \
     "$cdir/KingRoot_4.5.0.apk" "$cdir/SuperSU-v2.82-SR5-20171001.zip" "$cdir/update-binary" 2>/dev/null
  exit 1
}

common_files() {
  commfiles="
    /system/bin/su
    /system/xbin/su
    /system/xbin/supolicy
  "
  for i in $commfiles; do delete $i; done
}

extract_file() {
  bbarmb=1308724;   bbarm=$((bbarmb/1024));     bbarme=$((bbarmb%1024));     bbarms=$((bbarmb-bbarme));       bbarmz=$((1024-bbarme))
  bbmipsb=2598944;  bbmips=$((bbmipsb/1024));   bbmipse=$((bbmipsb%1024));   bbmipss=$((bbmipsb-bbmipse));    bbmipsz=$((1024-bbmipse))
  bbx86b=1103396;   bbx86=$((bbx86b/1024));     bbx86e=$((bbx86b%1024));     bbx86s=$((bbx86b-bbx86e));       bbx86z=$((1024-bbx86e))
  kingrb=2979596;   kingr=$((kingrb/1024));     kingre=$((kingrb%1024));     kingrs=$((kingrb-kingre));       kingrz=$((1024-kingre))
  readmeb=3354;     readme=$((readmeb/1024));   readmee=$((readmeb%1024));   readmes=$((readmeb-readmee));    readmez=$((1024-readmee))
  supersub=6882992; supersu=$((supersub/1024)); supersue=$((supersub%1024)); supersus=$((supersub-supersue)); supersuz=$((1024-supersue))
  updatebb=15946;   updateb=$((updatebb/1024)); updatebe=$((updatebb%1024)); updatebs=$((updatebb-updatebe)); updatebz=$((1024-updatebe))

  script=23
  scriptb=23552

  skip=$script
  skip1=$((scriptb+bbarms))
  if [ "$1" = "busybox-arm" ] || [ "$1" = "all" ]; then
    dd if="$0" of="$cdir/busybox-arm" bs=1024 skip=$skip count=$bbarm
    dd if="$0" of="$cdir/busybox-arm1" bs=1 skip=$skip1 count=$bbarme
    cat "$cdir/busybox-arm1" >> "$cdir/busybox-arm"
    rm "$cdir/busybox-arm1"
    if ! [ -f "$cdir/busybox-arm" ] || ! sha1_check "$cdir/busybox-arm" "1232d6d9ee6507c2904c9fbeecf9e36af3b6035d"; then
      abort "Unable to extract busybox-arm"
    fi
  fi

  skip=$((skip+bbarm+1))
  skip1=$((skip1+bbarme+bbarmz+bbmipss))
  if [ "$1" = "busybox-mips" ] || [ "$1" = "all" ]; then
    dd if="$0" of="$cdir/busybox-mips" bs=1024 skip=$skip count=$bbmips
    dd if="$0" of="$cdir/busybox-mips1" bs=1 skip=$skip1 count=$bbmipse
    cat "$cdir/busybox-mips1" >> "$cdir/busybox-mips"
    rm "$cdir/busybox-mips1"
    if ! [ -f "$cdir/busybox-mips" ] || ! sha1_check "$cdir/busybox-mips" "3df1a0803395aab2ec66160482fd571096b3911d"; then
      abort "Unable to extract busybox-mips"
    fi
  fi

  skip=$((skip+bbmips+1))
  skip1=$((skip1+bbmipse+bbmipsz+bbx86s))
  if [ "$1" = "busybox-x86" ] || [ "$1" = "all" ]; then
    dd if="$0" of="$cdir/busybox-x86" bs=1024 skip=$skip count=$bbx86
    dd if="$0" of="$cdir/busybox-x861" bs=1 skip=$skip1 count=$bbx86e
    cat "$cdir/busybox-x861" >> "$cdir/busybox-x86"
    rm "$cdir/busybox-x861"
    if ! [ -f "$cdir/busybox-x86" ] || ! sha1_check "$cdir/busybox-x86" "d9e8528908dcf87a34df110f05d03695ed291760"; then
      abort "Unable to extract busybox-x86"
    fi
  fi

  skip=$((skip+bbx86+1))
  skip1=$((skip1+bbx86e+bbx86z+kingrs))
  if [ "$1" = "KingRoot_4.5.0.apk" ] || [ "$1" = "all" ]; then
    dd if="$0" of="$cdir/KingRoot_4.5.0.apk" bs=1024 skip=$skip count=$kingr
    dd if="$0" of="$cdir/KingRoot_4.5.0.apk1" bs=1 skip=$skip1 count=$kingre
    cat "$cdir/KingRoot_4.5.0.apk1" >> "$cdir/KingRoot_4.5.0.apk"
    rm "$cdir/KingRoot_4.5.0.apk1"
    if ! [ -f "$cdir/KingRoot_4.5.0.apk" ] || ! sha1_check "$cdir/KingRoot_4.5.0.apk" "df48a7852a458da71f44bb3c95ef9b9588938e82"; then
      abort "Unable to extract KingRoot_4.5.0.apk"
    fi
  fi

  skip=$((skip+kingr+1))
  skip1=$((skip1+kingre+kingrz+readmes))
  if [ "$1" = "README.html" ] || [ "$1" = "all" ]; then
    dd if="$0" of="$cdir/README.html" bs=1024 skip=$skip count=$readme
    dd if="$0" of="$cdir/README.html1" bs=1 skip=$skip1 count=$readmee
    cat "$cdir/README.html1" >> "$cdir/README.html"
    rm "$cdir/README.html1"
    if ! [ -f "$cdir/README.html" ] || ! sha1_check "$cdir/README.html" "c8fcdf115eea49963f7de872bb90a2b57cf36f56"; then
      abort "Unable to extract README.html"
    fi
  fi

  skip=$((skip+readme+1))
  skip1=$((skip1+readmee+readmez+supersus))
  if [ "$1" = "SuperSU-v2.82-SR5-20171001.zip" ] || [ "$1" = "all" ]; then
    dd if="$0" of="$cdir/SuperSU-v2.82-SR5-20171001.zip" bs=1024 skip=$skip count=$supersu
    dd if="$0" of="$cdir/SuperSU-v2.82-SR5-20171001.zip1" bs=1 skip=$skip1 count=$supersue
    cat "$cdir/SuperSU-v2.82-SR5-20171001.zip1" >> "$cdir/SuperSU-v2.82-SR5-20171001.zip"
    rm "$cdir/SuperSU-v2.82-SR5-20171001.zip1"
    if ! [ -f "$cdir/SuperSU-v2.82-SR5-20171001.zip" ] || ! sha1_check "$cdir/SuperSU-v2.82-SR5-20171001.zip" "263e0d8ebecfa1cb5a6a3a7fcdd9ad1ecd7710b7"; then
      abort "Unable to extract SuperSU-v2.82-SR5-20171001.zip"
    fi
  fi

  skip=$((skip+supersu+1))
  skip1=$((skip1+supersue+supersuz+updatebs))
  if [ "$1" = "update-binary" ] || [ "$1" = "all" ]; then
    dd if="$0" of="$cdir/update-binary" bs=1024 skip=$skip count=$updateb
    dd if="$0" of="$cdir/update-binary1" bs=1 skip=$skip1 count=$updatebe
    cat "$cdir/update-binary1" >> "$cdir/update-binary"
    rm "$cdir/update-binary1"
    if ! [ -f "$cdir/update-binary" ] || ! sha1_check "$cdir/update-binary" "a87d406e927898be30f3932dd741df821123ffb9"; then
      abort "Unable to extract update-binary"
    fi
  fi
}

##########################################################################################
# KingRoot
##########################################################################################
kingroot_data() {
  delete /data/app/*kingroot*
  delete /data/data/com.kingroot.kinguser
  delete /data/data/*kingroot*
  delete /data/dalvik-cache/*kingroot*
  delete /data/dalvik-cache/*/*kingroot*
  delete /data/dalvik-cache/*tpsdaemon*
  delete /data/dalvik-cache/*/*tpsdaemon*
  delete /data/dalvik-cache/daemon
  delete /data/app-lib/*kingroot*
  delete /data/app-lib/*uranus*
  delete /data/data-lib
  delete /data/local/tmp/*uranus*
  delete /data/system/*uranus*
  delete /data/system/tmp_init.rc
  delete /data/media/obb/*kingroot*
  LD_LIBRARY_PATH=/system/lib:/vendor/lib pm uninstall com.kingroot.kinguser >/dev/null 2>&1
}

kingroot_storage() {
  delete /storage/emulated/obb/*kinguser*
  delete /storage/emulated/*/Android/*/*kinguser*
  delete /storage/*/Android/*/*kinguser*
  delete /storage/emulated/*/*kinguser*
  delete /storage/*/*kinguser*
  delete /storage/emulated/*/*Kingroot*
  delete /storage/*/*Kingroot*
  delete /storage/emulated/*/tencent
  delete /storage/*/tencent
  delete /storage/emulated/*/toprange
  delete /storage/*/toprange
  delete /storage/emulated/*/*-stock-conf
  delete /storage/*/*-stock-conf
}

kingroot_dev() {
  for i in user root; do
    if [ -d /dev/king$i.req.cache ]; then
      if [ ! -z "$(ls /dev/king$i.req.cache)" ]; then
        for j in /dev/king$i.req.cache/*; do
          delete $j
        done
      fi
      delete /dev/king$i.req.cache
    fi
  done
  delete /dev/ktools
  delete /dev/kufblck
  delete /dev/kulck
  delete /dev/rt.sh
}

kingroot_system() {
  kingfiles="
    /system/app/Kinguser.apk
    /system/app/Kinguser/*
    /system/app/Kinguser
    /system/bin/.usr/.ku
    /system/bin/.usr
    /system/bin/rt.sh
    /system/usr/iku/isu
    /system/usr/iku
    /system/xbin/ku.sud
    /system/xbin/ku.sud.tmp
  "
  for file in $kingfiles; do
    if [ -d $file ]; then
      rmdir $file
    else
      delete $file
    fi
  done
  if [ -f /system/bin/debuggerd64 ]; then
    strings /system/bin/debuggerd64 | grep -q ku.sud
    if [ $? -eq 0 ]; then
      delete /system/bin/debuggerd64
    fi
  fi
}

##########################################################################################
# Kingoroot
##########################################################################################
kingoroot_data() {
  delete /data/app/*kingo*
  delete /data/data/*kingo*
  delete /data/dalvik-cache/*kingo*
  delete /data/dalvik-cache/*Kingo*
  delete /data/dalvik-cache/*/*kingo*
  delete /data/dalvik-cache/*/*Kingo*
  delete /data/app-lib/*kingo*
  delete /data/media/obb/*kingo*
}

kingoroot_storage() {
  delete /storage/*/Android/*/*kingo*
  delete /storage/emulated/obb/*kingo*
  delete /storage/emulated/*/*kingoroot*
  delete /storage/*/*kingoroot*
}

kingoroot_system() {
  kingofiles="
    /system/app/KingoUser.apk
    /system/app/KingoUser/*
    /system/app/KingoUser
    /system/bin/.ext/.su
    /system/bin/.ext
    /system/etc/init.d/99SuperSUDaemon
    /system/etc/.has_su_daemon
    /system/lib/libsupol.so
    /system/lib64/libsupol.so
    /system/sbin/su
    /system/sbin
    /system/xbin/daemonsu
  "
  for file in $kingofiles; do
    if [ -d $file ]; then
      rmdir $file
    else
      delete $file
    fi
  done
}

##########################################################################################
# Special files
##########################################################################################
remove_install_recovery() {
  if [ -f /system/etc/install-recovery.sh-ku.bak ]; then
    move /system/etc/install-recovery.sh-ku.bak /system/etc/install-recovery.sh
    IRCON=$(get_context /system/etc/install-recovery.sh-ku.bak)
    set_perm 0 0 755 /system/etc/install-recovery.sh $IRCON
    #restorecon /system/etc/install-recovery.sh
  elif [ -f /system/etc/install-recovery.sh ] && grep -q xbin /system/etc/install-recovery.sh; then
    delete /system/etc/install-recovery.sh
    delete /system/bin/install-recovery.sh
  fi
  if [ -f /system/bin/install-recovery.sh-ku.bak ] && ! [ -L /system/bin/install-recovery.sh ]; then
    move /system/bin/install-recovery.sh-ku.bak /system/bin/install-recovery.sh
    IRCON=$(get_context /system/bin/install-recovery.sh-ku.bak)
    set_perm 0 0 755 /system/bin/install-recovery.sh $IRCON
    #restorecon /system/bin/install-recovery.sh
  fi
}

remove_ddexe() {
  if [ -f /system/bin/ddexe_real ]; then
    DDEXECON=$(get_context /system/bin/ddexe_real)
    move /system/bin/ddexe_real /system/bin/ddexe
    if [ -f /system/bin/ddexe-ku.bak ]; then
      move /system/bin/ddexe-ku.bak /system/bin/ddexe
    fi
    set_perm 0 0 755 /system/bin/ddexe $DDEXECON
    #restorecon /system/bin/ddexe
    delete /system/bin/ddexe_real
    delete /system/bin/ddexe-ku.bak
  fi
}

remove_debuggerd() {
  if [ -f /system/bin/debuggerd_real ]; then
    DEBUGGERDCON=$(get_context /system/bin/debuggerd_real)
    move /system/bin/debuggerd_real /system/bin/debuggerd
    if [ -f /system/bin/debuggerd-ku.bak ]; then
      move /system/bin/debuggerd-ku.bak /system/bin/debuggerd
    fi
    set_perm 0 0 755 /system/bin/debuggerd $DEBUGGERDCON
    #restorecon /system/bin/debuggerd
    delete /system/bin/debuggerd_real
    delete /system/bin/debuggerd-ku.bak
  fi
}

supersu_code() {
  if [ -f "/system/etc/install-recovery_original.sh" ]; then
    rm -f /system/etc/install-recovery.sh
    mv /system/etc/install-recovery_original.sh /system/etc/install-recovery.sh
  fi
  if [ -f "/system/bin/install-recovery_original.sh" ]; then
    rm -f /system/bin/install-recovery.sh
    mv /system/bin/install-recovery_original.sh /system/bin/install-recovery.sh
  fi
  if [ -f "/system/bin/app_process64_original" ]; then
    rm -f /system/bin/app_process64
    if [ -f "/system/bin/app_process64_xposed" ]; then
      ln -s /system/bin/app_process64_xposed /system/bin/app_process64
    else
      mv /system/bin/app_process64_original /system/bin/app_process64
    fi
  fi
  if [ -f "/system/bin/app_process32_original" ]; then
    rm -f /system/bin/app_process32
    if [ -f "/system/bin/app_process32_xposed" ]; then
      ln -s /system/bin/app_process32_xposed /system/bin/app_process32
    else
      mv /system/bin/app_process32_original /system/bin/app_process32
    fi
  fi
  if [ -f "/system/bin/app_process64" ]; then
    rm /system/bin/app_process
    ln -s /system/bin/app_process64 /system/bin/app_process
  elif [ -f "/system/bin/app_process32" ]; then
    rm /system/bin/app_process
    ln -s /system/bin/app_process32 /system/bin/app_process
  fi
  rm -f /system/bin/app_process_init
}

##########################################################################################
# Remove Root
##########################################################################################
remove_king() {
  common_files

  # KingRoot
  kingroot_data
  kingroot_storage
  kingroot_dev
  kingroot_system

  # KingoRoot
  kingoroot_data
  kingoroot_storage
  kingoroot_system

  # Special files
  remove_install_recovery
  supersu_code
}

root() {
  if ! [ -f /data/replaceroot ]; then
    echo 1 > /data/replaceroot
  elif [ "$(cat /data/replaceroot)" -eq 5 ]; then
    rm -f /data/replaceroot
    abort " Unable to remove Kingroot" " Try other methods by reading $cdir/README.html"
  else
    echo $((`cat /data/replaceroot`+1)) > /data/replaceroot
  fi

  delete /data/app/*kingroot*
  find /system/app -iname *kinguser* -delete
  extract_file "KingRoot_4.5.0.apk"
  LD_LIBRARY_PATH=/system/lib:/vendor/lib pm install -r $cdir/KingRoot_4.5.0.apk >/dev/null 2>&1
  rm "$cdir/KingRoot_4.5.0.apk"

  find_delete kingroot
  find_delete com.toprange.locker
  find_delete com.kingx.cloudsdk
  find_delete kingo
  find_delete kingo
  find_delete mgyun.shua.su
  find_delete geohot.towelroot
  find_delete shuame.rootgenius
  find_delete z4mod.z4root
  find_delete dianxinos.superuser
  find_delete baidu.easyroot
  find_delete baiyi_mobile.easyroot
  find_delete zhiqupk.root.global
  find_delete qihoo.permmgr
  find_delete corner23.android.universalandroot
  find_delete m0narx.su
  find_delete genymotion.superuser

  echo;  echo -e $B"Cleaning ..."$N
  remove_king
  # Second time cleaning to destroy all
  echo;  echo -e $B"Cleaning ..."$N
  remove_king
  sleep 1
  echo; echo -e $G"Finished Cleaning King(o)Root"$N
  echo; echo -e $G"Execute root.sh again to install root"$N
  echo
  exit
}

postuninstall() {
  echo; echo -e $C"Cleaning..."$N
  kingroot_data
  kingroot_dev
  kingroot_storage
  kingoroot_data
  kingoroot_storage
  remove_ddexe
  remove_debuggerd
  postfiles="
    /system/app/Kinguser.apk
    /system/app/Kinguser/*
    /system/app/Kinguser
    /system/bin/.usr/.ku
    /system/bin/.usr
    /system/bin/rt.sh
    /system/bin/su
    /system/usr/iku/isu
    /system/usr/iku
    /system/xbin/ku.sud
    /system/xbin/ku.sud.tmp
    /system/app/KingoUser.apk
    /system/app/KingoUser/*
    /system/app/KingoUser
    /system/sbin/su
    /system/sbin
  "
  for file in $postfiles; do
    if [ -d $file ]; then
      rmdir $file
    else
      delete $file
    fi
  done
  echo; echo -e $G"Finished Cleaning..."$N
  echo
  exit
}

##########################################################################################
# Pre-Checks
##########################################################################################
cdir="$(cd "$0"/../; pwd)"
if ! [ -f "$cdir/root.sh" ]; then
  abort "Unable to get path of script"
fi

LOG="$cdir/root.log"
exec 2>>"$LOG"

if [ "$1" = "-x" ] && ! [ -z "$2" ]; then
  extract_file "$2" 2>/dev/null
  exit
else
  extract_file "README.html" 2>/dev/null
fi

BL='\e[01;90m' >/dev/null 2>&1; # Black
R='\e[01;91m' >/dev/null 2>&1; # Red
G='\e[01;92m' >/dev/null 2>&1; # Green
Y='\e[01;93m' >/dev/null 2>&1; # Yellow
B='\e[01;94m' >/dev/null 2>&1; # Blue
P='\e[01;95m' >/dev/null 2>&1; # Purple
C='\e[01;96m' >/dev/null 2>&1; # Cyan
W='\e[01;97m' >/dev/null 2>&1; # White
N='\e[0m' >/dev/null 2>&1; # Null

id="$(id)"; id="${id#*=}"; id="${id%%\(*}"; id="${id%% *}"
if [ "$id" != "0" ] && [ "$id" != "root" ]; then
  abort "Type su and then execute"
fi

mount -o remount,rw /
mount -o remount,rw /system

mount | while read line; do
  case "$line" in
    *" /system "*)
      is_substring "rw," "$line" || abort "Unable to mount /system"
      break
    ;;
  esac
done

if [ -z "$(command -v getprop)" ] || [ -z "$(command -v dd)" ]; then
  abort "getprop/dd command not found."
fi

ARCH="$(getprop ro.product.cpu.abi)"
case "$ARCH" in
  *arm*) ARCH=arm;;
  *86*) ARCH=x86;;
  *mips*) ARCH=mips;;
  *) abort " Unsupported ARCH:- $ARCH"
  ;;
esac

bb="/system/xbin/busybox"
[ -e "$bb" ] && rm $bb
if ! [ -d /system/xbin ]; then
  mkdir /system/xbin && chmod 755 /system/xbin
fi
extract_file "busybox-$ARCH" 2>/dev/null
cat ${cdir}/busybox-$ARCH > $bb
rm "$cdir/busybox-$ARCH"
chmod 555 $bb
if ! [ -x "$bb" ]; then
  abort "Busybox setup failed"
fi
cd /system/xbin
for link in $($bb ls); do
  if [ -L $link ]; then
    case $($bb readlink $link) in
      *busybox) $bb rm -f $link;;
    esac
  fi
done
$bb --install -s /system/xbin

export PATH=/system/xbin:/system/bin
set_perm 0 0 0755 $bb
cd /

for i in basename cat chattr chcon chgrp chmod chown cut dd dirname echo find grep head ln mkdir mv readlink reboot rm rmdir sh sha1sum shred sleep strings tail unzip; do
  if [ -z "$(command -v $i)" ]; then
    abort "Busybox setup failed .. aborting"
  fi
done

##########################################################################################
# Logging
##########################################################################################
ARCH="$(grep -Eo "ro.product.cpu.abi(2)?=.+" /system/build.prop 2>/dev/null | grep -Eo "[^=]*$" | head -n1)"
for field in ro.product.device ro.build.product ro.product.name; do
  device_name="$(getprop "$field")"
  if [ "${#device_name}" -ge "2" ]; then
    break
  fi
  device_name="Bad ROM"
done
if [ -z "$(cat $LOG)" ]; then
  {
  echo "### Replace KingRoot with SuperSU ###"
  echo "Version:- 4"
  echo "   "
  echo ">> Device: $(getprop ro.product.brand) $(getprop ro.product.model)"
  echo ">> Device Name: $device_name"
  echo ">> Device Model: $(getprop ro.product.model)"
  echo ">> Architecture: $ARCH"
  echo ">> ROM version: $(getprop ro.build.display.id)"
  echo ">> Android version: $(getprop ro.build.version.release)"
  echo ">> SDK: $(getprop ro.build.version.sdk)"
  echo ">> SElinux state: $(getenforce)"
  } >>$LOG
fi

##########################################################################################
# Main
##########################################################################################
echo -e $C"---------------------------------------"$N
echo -e $C"---------- ${G}Made By : Mr.W0lf${C} ----------"$N
echo -e $C"---- ${G}Thanks @Chainfire for SuperSU${C} ----"$N
echo -e $C"---------------------------------------"$N

[ -e /system/bin/su ] && root
[ -e /system/xbin/ku.sud ] && root
[ -L /system/bin/su ] && root
[ -L /system/xbin/su ] && root
[ -L /system/xbin/supolicy ] && root
[ -e /system/xbin/ku.sud ] && exit
[ -L /system/bin/su ] && exit
[ -e /system/bin/su ] && exit
[ -L /system/xbin/su ] && exit

if [ -f /system/xbin/su ]; then
  su -v | grep -qi SUPERSU && postuninstall || root
elif [ -d /data/adb/magisk ]; then
  root
fi

echo; echo -e $G" Installing Root"$N; echo

[ -f /data/replaceroot ] && rm /data/replaceroot
# SuperSU installation
extract_file "SuperSU-v2.82-SR5-20171001.zip"
extract_file "update-binary"

mkdir /dev/tmp || abort "Unable to create /dev/tmp, aborting"
echo "###BEGIN SUPERSU LOG###" >&2
sh "$cdir/update-binary" "dummy" "1" "$cdir/SuperSU-v2.82-SR5-20171001.zip"
echo "###END SUPERSU LOG###" >&2

rm "$cdir/SuperSU-v2.82-SR5-20171001.zip"
rm "$cdir/update-binary"

if [ -f /system/xbin/su ] && su -v | grep -qi SUPERSU
then
  echo; echo -e $G"* ${C}the device will reboot after a few seconds${G} *"$N
  echo; echo -e $G"**********************************************"$N
  (
  setprop sys.powerctl reboot
  sleep 3
  /system/bin/reboot
  )&
fi
echo; echo "Finished"; echo
##########################################################################################
##################################################
exit 0
