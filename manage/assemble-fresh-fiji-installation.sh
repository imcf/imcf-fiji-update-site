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
# test
unzip -q -DD "$PKG"
mv "Fiji" "$FIJI_DIR"
echo -e "[DONE]\n"

# Ensure launcher and jaunch helper are executable (some zip extractions
# may lose the executable bit in CI environments). This avoids the
# "Failed to execute the jaunch configurator" / out_argc errors.
chmod +x "$FIJI_DIR"/fiji-* "$FIJI_DIR"/fiji || true
chmod +x "$FIJI_DIR"/config/jaunch/jaunch-* || true

# Detect and verify the Fiji/ImageJ launcher. Some update sites contain
# installer or helper binaries (e.g. timestamped ImageJ-* files or jaunch
# stubs). We must pick the real launcher that accepts `--headless` args.
run_with_xvfb_fallback() {
    # Run command, retry under xvfb if it fails and xvfb-run is present.
    if "$@"; then
        return 0
    fi
    rc=$?
    echo "Command failed with exit code $rc"
    if command -v xvfb-run >/dev/null 2>&1; then
        echo "Retrying under xvfb-run..."
        xvfb-run -a --auto-servernum --server-args='-screen 0 1024x768x24' "$@"
        return $?
    fi
    return $rc
}

echo "Detecting Fiji executable in $FIJI_DIR"
FIJI_CMD=""
for pattern in ImageJ-* ImageJ fiji-* fiji; do
    for f in "$FIJI_DIR"/$pattern; do
        if [ -f "$f" ] && [ -x "$f" ]; then
            echo "Trying candidate: $f"
            if run_with_xvfb_fallback "$f" --headless --version >/dev/null 2>&1; then
                FIJI_CMD="./$f"
                break 2
            else
                echo "Candidate $f rejected (did not respond as launcher)"
            fi
        fi
    done
done

if [ -z "${FIJI_CMD}" ]; then
    # Fallback: pick any executable file at top-level and verify it.
    candidate=$(find "$FIJI_DIR" -maxdepth 1 -type f -perm /111 | head -n 1 || true)
    if [ -n "${candidate}" ]; then
        echo "Trying fallback candidate: ${candidate}"
        if run_with_xvfb_fallback "$candidate" --headless --version >/dev/null 2>&1; then
            FIJI_CMD="./${candidate}"
        fi
    fi
fi

if [ -z "${FIJI_CMD}" ]; then
    echo "ERROR: Could not find a valid Fiji/ImageJ launcher in $FIJI_DIR"
    echo "Top-level listing:"; ls -la "$FIJI_DIR"
    echo "Executable files (file output):"
    find "$FIJI_DIR" -maxdepth 2 -type f -perm /111 -exec file {} \; || true
    exit 2
fi

echo "Using Fiji command: $FIJI_CMD"

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

echo ">> Downloading Mexican_Hat_Filter.class to $FIJI_DIR/plugins/"
MEXICAN_HAT_URL="https://imagej.net/ij/plugins/mexican-hat/Mexican_Hat_Filter.class"
if curl -L --fail -sS "$MEXICAN_HAT_URL" -o "$FIJI_DIR/plugins/Mexican_Hat_Filter.class"; then
    chmod 644 "$FIJI_DIR/plugins/Mexican_Hat_Filter.class" || true
else
    echo "Warning: failed to download Mexican_Hat_Filter.class"
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
