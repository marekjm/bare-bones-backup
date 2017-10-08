#!/usr/bin/env bash

SOURCE=$1


CONFIG_FILE=~/.backup.config
if [[ ! -f $CONFIG_FILE ]]; then
    echo "error: config file not found"
    exit 1
fi


# ID of the GPG key used to encrypt the archive's blocks.
# It can be obtainer by looking at the output of:
#
#       ]$ gpg --list-public-keys
#       pub    rsa4096 2017-10-06 [SC]
#       ABCXYZ
#       uid            [ unknown] John Doe <john.doe@example.com>
#       sub rsa4096 2017-10-06 [E]
#
# You need the 'ABCXYZ' part.
# Keep in mind that you *MUST NOT* lose the key, or
# you will not be able to decrypt your archives.
GPG_KEY_ID=$(grep -P '^gpg_key=' $CONFIG_FILE | sed 's/gpg_key=//')
if [[ $GPG_KEY_ID == '' ]]; then
    echo "error: no GPG key"
    exit 1
fi


# This is the size of a block Amazon S3 supports.
# We use it as a sane default.
BLOCK_SIZE=128K


# 16 hexadecimal characters.
# Splitting a 1PB archive into 128K blocks takes 8589934592 blocks, and
# this number (converted to hexadecimal) is 11 digits long.
# If you have archives larger than 1PB you may simply adjust this number.
SUFFIX_LENGTH=16


# Create an empty index file.
# It will be needed to recover the archive.
TIMESTAMP=$(date '+%Y%m%dT%H%M%S')
INDEX_FILE=archive.$TIMESTAMP.index
echo -n '' > $INDEX_FILE


# Create blocks for the archive.
# The current method is ridiculously inefficient, since to build a backup of N bytes, it needs
# at least (N + Tar header) bytes of free buffer space.
#
# FIXME It would be great if there was a way to invoke a shell script after each finished "split".
#       Then the amount of space needed would most probably be lower (it would be equal to the
#       final amount of storage used, after deduplication and encryption).
tar -cvf - $SOURCE | split --bytes $BLOCK_SIZE --additional-suffix .new.block --hex-suffixes=0 \
    --suffix-length $SUFFIX_LENGTH - ''


# Gather some data for statistics presentation later.
BLOCKS_BEFORE_DEDUPLICATION=$(ls -1 *.block | wc -l)


# Deduplicate and encrypt every new block created.
for EACH in *.new.block; do
    EACH_ID=$(echo "$EACH" | sed 's/\.new\.block$//')
    HASHED=$(sha512sum $EACH | cut -d' ' -f1)
    echo "block: $EACH_ID -> $HASHED"
    if [[ ! -f $HASHED.block ]]; then
        gzip -S .gz $EACH
        mv $EACH.gz $HASHED.block
    else
        rm $EACH
    fi
    gpg --encrypt --recipient $GPG_KEY_ID $HASHED.block
    mv $HASHED.block.gpg $HASHED.block
    echo "$HASHED" >> $INDEX_FILE
done
echo ''


# Gather some data for statistics presentation later.
BLOCKS_AFTER_DEDUPLICATION=$(ls -1 *.block | wc -l)


# Present the summary of what happened.
echo "blocks (before deduplication): $BLOCKS_BEFORE_DEDUPLICATION"
echo "blocks (after deduplication):  $BLOCKS_AFTER_DEDUPLICATION"
echo "index file: $INDEX_FILE"
