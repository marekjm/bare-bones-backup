#!/usr/bin/env bash

set -e


INDEX_ID=$1


INDEX=archive.$INDEX_ID.index
if [[ ! -f $INDEX ]]; then
    echo "error: index is not a file: $INDEX"
    exit 1
fi

ALL_BLOCKS=$(wc -l $INDEX | awk '{ print $1 }')
UNIQUE_BLOCKS=$(cat $INDEX | sort | uniq | wc -l)
echo "blocks (all):    $ALL_BLOCKS"
echo "blocks (unique): $UNIQUE_BLOCKS"

for EACH in $(cat $INDEX); do
    if [[ ! -f "$EACH.block" ]]; then
        echo "error: missing block: $EACH"
        exit 1
    fi
done

RESTORE_FILE=restore.tar
rm -f $RESTORE_FILE
touch $RESTORE_FILE

for EACH in $(cat $INDEX); do
    echo "$EACH"
    gpg --decrypt $EACH.block 2> /dev/null | gzip -c --decompress - >> $RESTORE_FILE
done

tar -xvf $RESTORE_FILE
