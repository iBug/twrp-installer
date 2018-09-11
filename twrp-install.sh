#!/system/bin/sh

e_info() {
  echo -e "\033[36;1m[INFO]\033[0m $*" >&2
}

e_warning() {
  echo -e "\033[33;1m[WARNING]\033[0m $*" >&2
}

e_error() {
  echo -e "\033[31;1m[ERROR]\033[0m $*" >&2
}

echo "*************************"
echo "* Manual TWRP installer *"
echo "*        by iBug        *"
echo "*************************"
echo

# Check for root access
if [ "$(id -u)" != "0" ]; then
  e_error "Root is required to install TWRP"
fi

# Parse arguments
while [ $# -ne 0 ]; do
  case $1 in
    -d)  # Extracted TWRP installer ZIP
      SOURCEDIR=$2
      shift
      ;;
    -z)  # TWRP installer ZIP
      TWRPZIP=$2
      e_info "ZIP is not supported now, please extract manually and specify -d"
      exit 3
      ;;
    -t)  # Specify install target
      TARGET=$2
      shift
      ;;
    *)
      e_error "Unknown option \"$1\""
      exit 1
      ;;
  esac
  shift
done

# Process arguments
if [ -z "$SOURCEDIR" -a -z "$TWRPZIP" ]; then
  e_error "Please specify either -d or -t"
  exit 1
fi
case $TARGET in
  a|A|boot_a) TARGET=A;;
  b|B|boot_b) TARGET=B;;
  *)  # Target is file
    if [ ! -r "$TARGET" ]; then
      e_error "$TARGET not found"
      exit 1
    fi
    ;;
esac

# Check files
TOOL=${SOURCEDIR%/}/magiskboot
CPIO=${SOURCEDIR%/}/ramdisk-twrp.cpio
if [ ! -r "$TOOL" ]; then
  e_error "$TOOL not found"
  exit 1
elif [ ! -r "$CPIO" ]; then
  e_error "$CPIO not found"
  exit 1
fi

# Construct environment
if [ ! -d "/sbin" ]; then
  mkdir -p /sbin
fi
if [ ! -x "/sbin/linker" ]; then
  ln -s /system/bin/linker /sbin/linker
fi
if [ ! -x "/sbin/linker64" ]; then
  ln -s /system/bin/linker64 /sbin/linker64
fi
cp -f "$TOOL" /sbin/magiskboot
chmod 755 /sbin/magiskboot
TOOL=/sbin/magiskboot

if [ -d "/tmp" ]; then
  D=/tmp/twrp
else
  D=/data/local/tmp/twrp
fi
mkdir -p "$D"

# Obtain boot.img
echo "Extracting boot.img"
if [ "$TARGET" = "A" ]; then
  dd if=/dev/block/bootdevice/by-name/boot_a of="$D/boot.img"
elif [ "$TARGET" = "B" ]; then
  dd if=/dev/block/bootdevice/by-name/boot_b of="$D/boot.img"
else
  cat "$TARGET" > "$D/boot.img"
fi

# Patch boot.img
echo "Patching boot.img"
cd "$D"
"$TOOL" --unpack "$D/boot.img"
cat "$CPIO" > "$D/ramdisk.cpio"
"$TOOL" --repack "$D/boot.img"

# Flash new-boot.img
echo "Flashing new-boot.img"
if [ "$TARGET" = "A" ]; then
  dd if="$D/new-boot.img" of=/dev/block/bootdevice/by-name/boot_a
elif [ "$TARGET" = "B" ]; then
  dd if="$D/new-boot.img" of=/dev/block/bootdevice/by-name/boot_b
else
  cp "$D/new-boot.img" "${TARGET%%.img}-twrp.img"
fi

echo "Done."
