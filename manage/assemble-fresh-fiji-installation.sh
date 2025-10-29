# reset the bash elapsed-seconds counter:
SECONDS=0

set -e # stop on errors

exit_usage() {
    echo "Usage:"
    echo
    echo "$0 ./list-of-update-sites.json platform"
    echo
    exit 1
}

# if [ -z "$*" ]; then
#     exit_usage
# fi
# if ! [ -r "$*" ]; then
#     exit_usage
# fi
if [ $# -lt 2 ]; then
    exit_usage
fi

UPD_SITES="$1"
PLATFORM="$2"

FIJI_DIR="Fiji.app"
if [ -d "$FIJI_DIR" ]; then
    echo "Found an existing Fiji directory, STOPPING!"
    # exit 1
fi

# # we only support Linux and Windows, and only 64 bit:
# if [ "$(uname)" == "Linux" ]; then
#     PLATFORM="linux64"
# else
#     PLATFORM="win64"
# fi
# echo "Detected platform: $PLATFORM"

echo ">>> Working for platform: $PLATFORM"
echo ">>> Version of the package: $NEW"
DL_BASE="https://downloads.imagej.net/fiji/latest"
PKG="fiji-${PLATFORM}.zip"
FIJI_DIR="Fiji.app-${PLATFORM}"
NOW=$(date +%Y-%m-%d)
ZIP_PATH=$FIJI_DIR'_'$NOW'.zip'
DL_URI="$DL_BASE/$PKG"
FIJI_CMD="./${FIJI_DIR}/ImageJ-${PLATFORM}"
if [ "$PLATFORM" == "win64" ]; then
    FIJI_CMD="$FIJI_CMD.exe"
fi
# if [ "$PLATFORM" == "macosx" ]; then
#     FIJI_CMD="./${FIJI_DIR}/Contents/MacOS/ImageJ-${PLATFORM}"
# fi

echo ">>> installing base ImageJ / Fiji package..."
if ! [ -r "$PKG" ]; then
    echo "Downloading the latest Fiji package: $DL_URI"
    echo
    curl -k "$DL_URI" -o $PKG
else
    echo "Using the existing fiji download package: [$PKG]"
fi
echo

echo -n "Extracting the package: "
unzip -Xq "$PKG"
mv "Fiji.app" $FIJI_DIR
echo -e "[DONE]\n"

#### sample images:
PKG_SAMPLES="imagej-sample-images.zip"
if [ -r "$PKG_SAMPLES" ]; then
    echo -n "Extracting sample images: "
    unzip -q "$PKG_SAMPLES" -d $FIJI_DIR
    echo -e "[DONE]\n"
else
    echo -e "Couldn't find [$PKG_SAMPLES], not extracting sample images!\n"
fi

echo ">>> adding required update sites..."
# SCRIPT_DIR="$(dirname "$0")"
set -x
$FIJI_CMD --ij2 --headless --console \
    --run "add-update-sites.py" \
    sites_collection=\'"$UPD_SITES"\'
set +x
echo
echo ">>> running updater..."
$FIJI_CMD --console --update update
$FIJI_CMD --console --update update
$FIJI_CMD --headless


echo
echo "DONE! Took $SECONDS seconds."
