#!/usr/bin/env bash

set -e


INDEX_ID=$1


CONFIG_FILE=~/.backup.config
if [[ ! -f $CONFIG_FILE ]]; then
    echo "error: config file not found"
    exit 1
fi


STORAGE_USER=$(grep -P '^storage_user=' $CONFIG_FILE | sed 's/storage_user=//')
STORAGE_HOST=$(grep -P '^storage_host=' $CONFIG_FILE | sed 's/storage_host=//')
STORAGE_ROOT=$(grep -P '^storage_root=' $CONFIG_FILE | sed 's/storage_root=//')

export STORAGE_USER
export STORAGE_HOST
export STORAGE_ROOT


# First, let's fetch the index.
# It is needed to know what blocks we need to fetch.
INDEX=archive.$INDEX_ID.index
scp $STORAGE_USER@$STORAGE_HOST:$STORAGE_ROOT/$INDEX .


# Print out some reports.
ALL_BLOCKS=$(wc -l $INDEX | awk '{ print $1 }')
UNIQUE_BLOCKS=$(cat $INDEX | sort | uniq | wc -l)
echo "blocks (all):    $ALL_BLOCKS"
echo "blocks (unique): $UNIQUE_BLOCKS"


# FIXME For now we operate under assumption that all required
# blocks *exist*.
# Maybe it would be a good idea to verify this assumption before
# downloading and unpacking a potentially terabyte-sized archive.


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


BLOCK_CACHE_DIRECTORY=/tmp/restore_blocks
mkdir -p $BLOCK_CACHE_DIRECTORY

for EACH in $(cat $INDEX); do
    echo "$EACH"
    BLOCK_FILE=$BLOCK_CACHE_DIRECTORY/$EACH.block

    # FIXME Fetching blocks one-by-one using a new connection is wildly inefficient, and
    # painfully slow (especially on bad Intenet connections). It is conceptually simple, though.
    # A set of most recently used N blocks is kept in cache to avoid redownloading.
    if [[ ! -f $BLOCK_FILE ]]; then
        scp $STORAGE_USER@$STORAGE_HOST:$STORAGE_ROOT/$EACH.block $BLOCK_FILE
    fi

    gpg --decrypt $BLOCK_FILE 2> /dev/null | gzip -c --decompress - > $RESTORE_PIPE

    if [[ $(ls -1 $BLOCK_CACHE_DIRECTORY/*.block | wc -l) -gt 128 ]]; then
        rm $BLOCK_CACHE_DIRECTORY/*.block
    fi
done


# Cleanup.
rm $INDEX
rm $RESTORE_PIPE
rm $BLOCK_CACHE_DIRECTORY/*.block
rmdir $BLOCK_CACHE_DIRECTORY/
