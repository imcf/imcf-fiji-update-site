#!/bin/bash

NEXUS_SERVER="https://maven.scijava.org"
CONTENT_PATH="service/local/artifact/maven/content"

function download_jar() {
    JAR_NAME="$1"
    JAR_VERSION="${2:-LATEST}"
    NEXUS_REPO="releases"
    [ "$JAR_VERSION" = "LATEST" ] && NEXUS_REPO="snapshots"
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
    echo "Downloading JAR from [$URI]..."
    wget -O tmp.jar "$URI"
    unzip tmp.jar META-INF/MANIFEST.MF
    JAR_VERSION=$(
        grep "^Implementation-Version:" META-INF/MANIFEST.MF |
            cut -d ' ' -f 2
    )
    FINAL_NAME="${JAR_NAME}-${JAR_VERSION}.jar"
    mv -v tmp.jar "$OLDPWD/Fiji.app/jars/$FINAL_NAME"
}

echo "Copying 🚚 extra script 📃 files to Fiji..."
# cp -rv ./extra/Fiji.app/* ./Fiji.app/

download_jar "python-imcflibs"
download_jar "python-imcflibs" "1.4.0"
