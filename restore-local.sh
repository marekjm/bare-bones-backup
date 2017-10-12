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
