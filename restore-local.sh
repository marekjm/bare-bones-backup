#!/usr/bin/env bash

set -e


INDEX_ID=$1


INDEX=archive.$INDEX_ID.index
if [[ ! -f $INDEX ]]; then
    echo "error: index is not a file: $INDEX"
    exit 1
fi


# Print out some reports.
ALL_BLOCKS=$(wc -l $INDEX | awk '{ print $1 }')
UNIQUE_BLOCKS=$(cat $INDEX | sort | uniq | wc -l)
echo "blocks (all):    $ALL_BLOCKS"
echo "blocks (unique): $UNIQUE_BLOCKS"


# If we're restoring from local block repository then we can easily
# check if required blocks exist.
# Let's do this!
for EACH in $(cat $INDEX); do
    if [[ ! -f "$EACH.block" ]]; then
        echo "error: missing block: $EACH"
        exit 1
    fi
done


# Create a named pipe that will be used for communication between
# the fetch-and-decrypt and untar lines of execution.
RESTORE_PIPE=/tmp/restore_pipe
rm -f $RESTORE_PIPE
mkfifo $RESTORE_PIPE


# Attach tar extractor to a pipe and
# run it in a subprocess.
# tail is needed to avoid crashing on EOF after the first block is
# decrypted and written to the pipe.
tail --follow --bytes=4M $RESTORE_PIPE | tar -xv &

for EACH in $(cat $INDEX); do
    echo "$EACH"
    gpg --decrypt $EACH.block 2> /dev/null | gzip -c --decompress - > $RESTORE_PIPE
done


# Cleanup.
rm $RESTORE_PIPE
