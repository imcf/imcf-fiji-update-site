#!/usr/bin/env bash
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

echo "$(uname)"

# we only support Linux and Windows, and only 64 bit:
if [ "$(uname)" == "Linux" ]; then
    PLATFORM="linux"
    PLATFORM_NUMBERED="linux64"
else
    PLATFORM="windows"
    PLATFORM_NUMBERED="win64"
fi

echo ">>> Working for platform: $PLATFORM"
DL_BASE="https://downloads.imagej.net/fiji/latest"
PKG="fiji-latest-${PLATFORM_NUMBERED}-jdk.zip"
FIJI_DIR="Fiji.app-${PLATFORM}"

DL_URI="$DL_BASE/$PKG"

FIJI_CMD="./${FIJI_DIR}/fiji-${PLATFORM}-x64"
if [ "$PLATFORM" == "win" ]; then
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
    echo "Downloaded the latest Fiji package: [$PKG]"
else
    echo "Using the existing fiji download package: [$PKG]"
fi
echo

echo -n "Extracting the package: "
# Do not attempt to restore UID/GID (-X) or timestamps (-DD) when extracting,
# because setting ownership/timestamps can fail for non-root users and
# produces warnings like "cannot set UID ... Operation not permitted".
unzip -q -DD "$PKG"
mv "Fiji" "$FIJI_DIR"
echo -e "[DONE]\n"

#### sample images:
PKG_SAMPLES="imagej-sample-images.zip"
if [ -r "$PKG_SAMPLES" ]; then
    echo -n "Extracting sample images: "
    # Avoid restoring timestamps for the sample images as well.
    unzip -q -DD "$PKG_SAMPLES" -d "$FIJI_DIR"
    echo -e "[DONE]\n"
else
    echo -e "Couldn't find [$PKG_SAMPLES], not extracting sample images!\n"
fi

echo ">>> adding required update sites..."
# SCRIPT_DIR="$(dirname "$0")"
set -x
$FIJI_CMD \
    --run "add-update-sites.py" \
    sites_collection=\'"$UPD_SITES"\'
set +x
echo
echo ">>> running updater..."
$FIJI_CMD --update update
# Maybe got improved and not needed to be ran twice now ?
# $FIJI_CMD --update update
# $FIJI_CMD --headless


echo
echo "DONE! Took $SECONDS seconds."
