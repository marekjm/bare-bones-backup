#!/usr/bin/env bash
#
#   Copyright (C) 2017 Marek Marecki
#
#   This file is part of Viua VM.
#
#   Viua VM is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   Viua VM is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with Viua VM.  If not, see <http://www.gnu.org/licenses/>.
#

# SOURCE is the directory or file of which you want to backup.
# FIXME Support backups that span more than one directory/file.
SOURCE=$1

# B3_ARCHIVE_NAME is the name of the backup: 'configs', 'documents', 'music', etc.
# Choose something meaningful to make it easier for yourself when you will
# be restoring the backups.
if [[ "$B3_ARCHIVE_NAME" == '' ]]; then
    B3_ARCHIVE_NAME=archive
fi


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
export GPG_KEY_ID


STORAGE_USER=$(grep -P '^storage_user=' $CONFIG_FILE | sed 's/storage_user=//')
STORAGE_HOST=$(grep -P '^storage_host=' $CONFIG_FILE | sed 's/storage_host=//')
STORAGE_ROOT=$(grep -P '^storage_root=' $CONFIG_FILE | sed 's/storage_root=//')

export STORAGE_USER
export STORAGE_HOST
export STORAGE_ROOT


# B3_TRANSPORT_TOOL is a parameter passed via an environment variable.
if [[ "$B3_TRANSPORT_TOOL" == '' ]]; then
    B3_TRANSPORT_TOOL=scp
fi
if [[ $B3_TRANSPORT_TOOL == 'scp' ]]; then
    # check for 'scp' support
    if [[ ! $(command -v scp) ]]; then
        echo "error: transport tool unavailable: 'scp'"
        exit 1
    fi

    if [[ ! $(ssh -q -oBatchMode=yes $STORAGE_USER@$STORAGE_HOST echo test) ]]; then
        echo "error: failed to login to remote storage: $STORAGE_USER@$STORAGE_HOST"
        exit 1
    fi
elif [[ $B3_TRANSPORT_TOOL == 'rsync' ]]; then
    # check for 'rsync' support
    if [[ ! $(command -v rsync) ]]; then
        echo "error: transport tool unavailable: 'rsync'"
        exit 1
    fi

    if [[ ! $(ssh -q -oBatchMode=yes $STORAGE_USER@$STORAGE_HOST echo test) ]]; then
        echo "error: failed to login to remote storage: $STORAGE_USER@$STORAGE_HOST"
        exit 1
    fi
elif [[ $B3_TRANSPORT_TOOL == 'wput' ]]; then
    # check for 'wput' support
    if [[ ! $(command -v wput) ]]; then
        echo "error: transport tool unavailable: 'wput'"
        exit 1
    fi

    # TODO
    echo "error: transport tool not implemented: 'wput'"
    exit 1
elif [[ $B3_TRANSPORT_TOOL == 'cp' ]]; then
    # do nothing, 'cp' tool is always supported
    true
else
    echo "error: unsupported transport tool: '$B3_TRANSPORT_TOOL'"
    echo "note: supported transport tools are: scp, rsync, wput, cp"
    echo "note: choose the one that will be able to copy blocks to your remote storage"
    echo "note: the 'cp' tool is always available but able to copy blocks only between"
    echo "note: local disks"
    exit 1
fi


# This is the size of a block Amazon S3 supports.
# We use it as a sane default.
if [[ $B3_BLOCK_SIZE == '' ]]; then
    B3_BLOCK_SIZE=128K
fi


# 16 hexadecimal characters.
# Splitting a 1PB archive into 128K blocks takes 8589934592 blocks, and
# this number (converted to hexadecimal) is 11 digits long.
# If you have archives larger than 1PB you may simply adjust this number.
SUFFIX_LENGTH=16


B3_TMP_DIR="/tmp/b3_$B3_ARCHIVE_NAME""__$(dd if=/dev/urandom bs=1K count=1 2>/dev/null | sha1sum | cut -d' ' -f1)"
mkdir -p $B3_TMP_DIR
export B3_TMP_DIR


# Create an empty index file.
# It will be needed to recover the archive.
TIMESTAMP=$(date '+%Y%m%dT%H%M%S')
INDEX_NAME=$B3_ARCHIVE_NAME.$TIMESTAMP.index
INDEX_FILE=$B3_TMP_DIR/$INDEX_NAME
echo -n '' > $INDEX_FILE

export INDEX_FILE


if [[ $B3_DEBUG == 'yes' ]]; then
    echo "debug: upload batch size:    $B3_UPLOAD_BATCH_SIZE"
    echo "debug: backup tmp directory: $B3_TMP_DIR"
    echo "debug: archive index file:   $INDEX_FILE"
fi


B3_BLOCK_COUNT_PRE_UPLOAD=$(ssh $STORAGE_USER@$STORAGE_HOST "cd $STORAGE_ROOT/blocks/ && find . -type f | wc -l")


# Create blocks for the archive.
if [[ $B3_DRY_RUN != 'true' ]]; then
    tar -cvf - $SOURCE | split --bytes $B3_BLOCK_SIZE --additional-suffix .new.block --hex-suffixes=0 \
        --suffix-length $SUFFIX_LENGTH --filter=$(dirname $0)/process-backup-block.sh - ''
fi


# If using B3_UPLOAD_BATCH_SIZE some blocks have not be copied during archive creation.
# These leftover blocks are copied here.
EMPTY_SHA512='00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'
if [[ $B3_DRY_RUN != 'true' ]]; then
    B3_UPLOAD_FINISHING=yes $(dirname $0)/upload-backup-block.sh $EMPTY_SHA512
fi


if [[ $B3_DRY_RUN != 'true' ]]; then
    scp $INDEX_FILE $STORAGE_USER@$STORAGE_HOST:$STORAGE_ROOT/indexes/
fi


# Present the summary of what happened.
BLOCKS_BEFORE_DEDUPLICATION=$(wc -l $INDEX_FILE | awk '{ print $1 }')
BLOCKS_AFTER_DEDUPLICATION=$(cat $INDEX_FILE | sort | uniq | wc -l)
B3_BLOCK_COUNT_POST_UPLOAD=$(ssh $STORAGE_USER@$STORAGE_HOST "cd $STORAGE_ROOT/blocks/ && find . -type f | wc -l")
B3_NEW_BLOCKS=$(dc -e "$B3_BLOCK_COUNT_POST_UPLOAD $B3_BLOCK_COUNT_PRE_UPLOAD -p")
echo "blocks in this archive (before deduplication): $BLOCKS_BEFORE_DEDUPLICATION"
echo "blocks in this archive (after deduplication):  $BLOCKS_AFTER_DEDUPLICATION"
echo "total blocks (pre upload):  $B3_BLOCK_COUNT_PRE_UPLOAD"
echo "total blocks (post upload): $B3_BLOCK_COUNT_POST_UPLOAD"
echo "new blocks: $B3_NEW_BLOCKS"
echo "index name: $INDEX_NAME"

rm $INDEX_FILE
rm -r $B3_TMP_DIR
