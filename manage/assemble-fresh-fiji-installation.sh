#!/usr/bin/env bash
# reset the bash elapsed-seconds counter:
SECONDS=0

set -e # stop on errors

# Print the current working directory for debugging/traceability
echo "Current directory: $(pwd)"
echo "$(ls)"

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

UPD_SITES=$1
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
FIJI_DIR="Fiji-${PLATFORM}"

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
# test
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

echo
echo

# Try to fetch the latest OMERO_ij jar from GitHub releases (pure Bash)
OMERO_OWNER="ome"
OMERO_REPO="omero-insight"
MATCH_RE='^omero_ij-.*\.jar$'

if command -v curl >/dev/null 2>&1; then
    echo "Looking up latest OMERO_ij release for ${OMERO_OWNER}/${OMERO_REPO}..."

    find_asset_url() {
        # $1: raw JSON
        local json="$1"
        local line name url
        # extract only name and browser_download_url tokens in order
        echo "$json" | grep -oE '"name"\s*:\s*"[^"]+"|"browser_download_url"\s*:\s*"[^"]+"' | \
        while read -r line; do
            if [[ $line =~ \"name\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
                name="${BASH_REMATCH[1]}"
                # normalize to lowercase for case-insensitive matching
                name_lc=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')
            elif [[ $line =~ \"browser_download_url\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
                url="${BASH_REMATCH[1]}"
                if [[ $name_lc =~ $MATCH_RE ]]; then
                    printf '%s' "$url"
                    return 0
                fi
            fi
        done
        return 1
    }

    asset_url=""
    json=$(curl -s "https://api.github.com/repos/${OMERO_OWNER}/${OMERO_REPO}/releases/latest")
    asset_url=$(find_asset_url "$json" || true)

    if [ -z "$asset_url" ]; then
        # fallback: scan recent releases
        json=$(curl -s "https://api.github.com/repos/${OMERO_OWNER}/${OMERO_REPO}/releases")
        asset_url=$(find_asset_url "$json" || true)
    fi

    if [ -n "$asset_url" ]; then
        echo "Found OMERO asset: $asset_url"
        asset_name=$(basename "$asset_url")
        target_dir="$FIJI_DIR/plugins"
        mkdir -p "$target_dir"
        echo "Downloading $asset_name to $target_dir/"
        if curl -L --fail -sS "$asset_url" -o "$target_dir/$asset_name"; then
            chmod 644 "$target_dir/$asset_name" || true
        else
            echo "Warning: failed to download $asset_url"
        fi
    else
        echo "No OMERO_ij jar found in releases."
    fi
else
    echo "Skipping OMERO_ij download: 'curl' not available."
fi

echo ">>> adding required update sites..."
# Ensure we log command output
set -x
# enable headless Java and detect Xvfb for non-GUI execution environments
export JAVA_TOOL_OPTIONS="-Djava.awt.headless=true ${JAVA_TOOL_OPTIONS:-}"

$FIJI_CMD \
    --headless --run manage/add-update-sites.py \
    "sites_collection='$UPD_SITES'"
set +x
echo
echo ">>> running updater..."
$FIJI_CMD --headless --update update

echo
echo "DONE! Took $SECONDS seconds."
