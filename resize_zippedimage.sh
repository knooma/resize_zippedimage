#!/bin/bash
#Usage: 
# resize_zippedimage <archive_filename>
# if no filename are given, handle *.{zip,rar,7z,cbz}

ORGDIR="org"

ARCHIVE_SIZE_MAX=$((3*1024*1024*1024)) #3GB
ARCHIVE_SIZE_MIN=$((3*1024*1024)) #3MB

TMPDIR=`mktemp -d /tmp/resize_zippedimage.XXXXXXXX`
trap "error SIGINT" SIGINT

RESIZE_HEIGHT=2048



# error <message>
error() {
    rm -rf $TMPDIR
    [ "$1" != "" ] && echo $1
    exit 1
}

# extract <file> to $TMPDIR/$(basename <file>)
# envs: TMPDIR, DIRNAME, BASENAME, EXTRACTDIR
extract() {
    if [ "$EXT" == "rar" ]; then
        # Use 'unrar' for rar file becuase 'unar' sometimes fails to extract rar file.
        ABSPATH="$(cd ${DIRNAME} && pwd)/${BASENAME}"
        mkdir "$EXTRACTDIR" || error
        pushd "$EXTRACTDIR" > /dev/null || error
        unrar -r x "$ABSPATH" > /dev/null || error 'fail to unrar'
        popd > /dev/null || error
    else
        # 'unar' supports recursize extraction and char-code handling
        unar -q -d -o "$TMPDIR" "$1" || error 'fail to unar'
    fi
}

#archive <zipfile> <directory>
archive() {
    pushd "$2" > /dev/null || error
    zip -q -m "$1" -r -- *
    ZIPSTAT=$?
    popd > /dev/null || error

    return $ZIPSTAT
}

# rezieArchive <archive>
resizeArchive() {
    if [ ! -f "$1" ]; then
        echo "WARNING: No such file. Skipped."
        return
    fi

    echo "$1"

    DIRNAME=`dirname "$1"`
    BASENAME=`basename "$1"`

    # Must be zip/rar/cbz
    FILE=${BASENAME%.*}
    EXT=${BASENAME##*.}
    if [ "$EXT" != "zip" ] && [ "$EXT" != "rar" ] && [ "$EXT" != "cbz" ] && [ "$EXT" != "7z" ]; then
        echo "Skipped. Unsupported extension."
        return
    fi

    # Check min and max file size
    SIZE=`wc -c < "$1"`
    if [ $SIZE -lt $ARCHIVE_SIZE_MIN ] || [ $ARCHIVE_SIZE_MAX -lt $SIZE ]; then
        echo "Skipped. Unsupported file size ($((SIZE/1024/1024))MB)."
        return
    fi

    ORGDIR="${DIRNAME}/org"
    if [ -f "${ORGDIR}/${FILE}.zip" ]; then
        echo "Skipped. The file has already been processed."
        return
    fi
    mkdir -p "$ORGDIR" || error

    # Check if the archive has any jpg/png files
    if ! lsar "$1" | egrep '\.(jpg|JPG|jpeg|JPEG|png|PNG)$' > /dev/null; then
        echo "WARNING: Skipped. The archive doesn't have jpg/png file."
        return
    fi

    # Initial check has been passed.

    # extract archive file
    EXTRACTDIR="${TMPDIR}/${FILE}"
    extract "$1"

    # resize jpg files
    find "$EXTRACTDIR" -type f -a \( -iname "*.jpg" -o -iname "*.jpeg" \) -print0 | xargs --no-run-if-empty -0 mogrify -resize "x${RESIZE_HEIGHT}>" -quality 90 || error 'fail to convert jpg'

    # resize & convert png files into jpg
    find "$EXTRACTDIR" -type f -iname "*.png" -print0 | xargs --no-run-if-empty -0 mogrify -format jpg -resize "x${RESIZE_HEIGHT}>" -quality 90 || error 'fail to convert png'

    # delte png files
    find "$EXTRACTDIR" -type f -iname "*.png" -print0 | xargs --no-run-if-empty -0 rm || error

    NEWFILE="${TMPDIR}/${FILE}.zip"

    # Make new zip archive
    if ! archive "$NEWFILE" "$EXTRACTDIR"; then
        echo "WARNING: Can't archive. Skipped."
        rm "$NEWFILE"
        rm -rf "$EXTRACTDIR" || error
        return
    fi

    # Check size of new archve file
    NEWSIZE=`wc -c < "$NEWFILE"` || error
    SIZEMESSAGE="$(($SIZE/1024/1024))MB to $(($NEWSIZE/1024/1024))MB ($(($NEWSIZE*100/$SIZE))%)"
    if [ "$EXT" = "zip" ] && [ $(($SIZE*90/100)) -lt $NEWSIZE ]; then
        echo "Skipped. Size is not shrinked enough: $SIZEMESSAGE"
        rm "$NEWFILE" || error
        rm -rf "$EXTRACTDIR" || error
        return
    elif [ $SIZE -lt $NEWSIZE ]; then
        echo "Just convert to zip. Size is not shrinked: $SIZEMESSAGE"

        rm "$NEWFILE" || error
        rm -r "$EXTRACTDIR" || error

        extract "$1"

        if ! archive "$NEWFILE" "$EXTRACTDIR"; then
            echo "WARNING: Can't archive. Skipped."
            rm "$NEWFILE"
            rm -rf "$EXTRACTDIR" || error
            return
        fi
    else
        echo "OK. Shrinked from $SIZEMESSAGE"
    fi

    # move original archive into $ORGDIR
    mv "$1" "$ORGDIR" || error "Failed to move $1 to $ORGDIR"
    mv "$NEWFILE" "$DIRNAME" || error "FATAL: Failed to move new archive ${NEWFILE} ${DIRNAME}"

    rm -rf "$EXTRACTDIR" || error
}

main() {
    mapfile -t SORTED < <(sort < <(printf "%s\n" "$@"))
    local NUM=${#SORTED[@]}

    local i
    for (( i=0; i<${NUM}; i++ )); do
        resizeArchive "${SORTED[i]}"
        shift
    done
}

if ! pushd . > /dev/null; then
    error "You must run this script on bash."
fi
popd

if ! mogrify -version > /dev/null; then
    error "IamgeMagick must be installed."
fi

if ! zip -v > /dev/null; then
    error "'zip' must be installed."
fi

if ! unar -v > /dev/null; then
    error "'unar' must be installed."
fi

if ! unrar -v > /dev/null; then
    error "'unrar' must be installed."
fi

echo "temp dir: ${TMPDIR}"

if [ $# = 0 ]; then
    shopt -s nullglob
    main *.{zip,rar,cbz,7z}
else
    main $* 
fi

rm -rf $TMPDIR
