#!/bin/bash

set -o errexit
set -o nounset

NEXUS_SERVER="https://maven.scijava.org"
CONTENT_PATH="service/local/artifact/maven/content"

function download_jar() {
    ### Download a JAR from SciJava Nexus.
    # Param $1: the name of the JAR.
    # Param $2 (optional): the name of the Nexus repo (default=`snapshots`)
    # Param $3 (optional): the JAR version (default=`LATEST`).
    JAR_NAME="$1"
    NEXUS_REPO="${2:-snapshots}"
    JAR_VERSION="${3:-LATEST}"
    URI="$NEXUS_SERVER/$CONTENT_PATH?r=$NEXUS_REPO"
    GAV="g=ch.unibas.biozentrum.imcf&a=${JAR_NAME}&v=${JAR_VERSION}"
    URI="${URI}&${GAV}"

    TMPDIR=$(mktemp --directory --tmpdir=.)
    # shellcheck disable=SC2164
    cd "$TMPDIR"

    # NOTE: `wget --content-disposition` would give us the JAR with the exact
    # name as it is stored in the Nexus repo (e.g. something like
    # `python-imcflibs-1.5.0-20250113.125343-1.jar`), but for now we prefer to
    # have the files named in the same way as a maven build would call them (so
    # `python-imcflibs-1.5.0-SNAPSHOT.jar` for this example). Therefore we
    # download the file to a temp name and derive the final name from metadata.
    echo -e "--\nDownloading 🌍 📥 JAR for [$JAR_NAME]..."
    echo "URI: $URI"

    # The `--content-disposition` switch will use the file name that is provided
    # by the server to name the downloaded artifact:
    wget --quiet --content-disposition "$URI"
    ARTIFACT="$(find . -mindepth 1 -maxdepth 1 -name "$JAR_NAME-*.jar")"
    mv -v "$ARTIFACT" "$OLDPWD/Fiji.app/jars/"
    # shellcheck disable=SC2164
    cd "$OLDPWD"
    rm -r "$TMPDIR"
    echo -e "Downloading 🌍 📥 JAR for [$JAR_NAME]: ✅\n--"
}

function exit_usage() {
    echo -e "\nUsage: $0 <Update-Site-Name>\n"
    exit 1
}

[ $# -lt 1 ] && exit_usage
UPDATE_SITE="$1"
SITE_SETTINGS="$(dirname "$0")/../site-settings/$UPDATE_SITE"
if ! [ -d "$SITE_SETTINGS" ]; then
    echo "ERROR: can't find directory [$SITE_SETTINGS]!"
    exit 2
fi

echo -e "--\nCopying 🚚 extra script 📃 files to Fiji..."
cp -rv "$SITE_SETTINGS/extra/Fiji.app"/* ./Fiji.app/
echo -e "Copying 🚚 extra script 📃 files to Fiji: ✅\n--"

for FILE in $(find "$SITE_SETTINGS/jars/" -name '*.inc.sh'); do
    # empty vars to prevent mixups between loops:
    JAR_NAME=""
    JAR_VERSION=""
    NEXUS_REPO=""
    source "$FILE"
    download_jar "$JAR_NAME" "$NEXUS_REPO" "$JAR_VERSION"
done
