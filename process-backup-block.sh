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

BLOCK_FILE=$B3_TMP_DIR/$FILE
cat > $BLOCK_FILE

BLOCK_ID=$(echo "$FILE" | sed 's/\.new\.block$//')
HASHED=$(sha512sum $BLOCK_FILE | cut -d' ' -f1)
echo -n "block: $BLOCK_ID -> $HASHED"

if [[ $(grep -P "$HASHED" $INDEX_FILE | wc -l) -eq 0 ]]; then
    echo " compress"
    gzip -S .gz $BLOCK_FILE
    mv $BLOCK_FILE.gz $B3_TMP_DIR/$HASHED.block

    gpg --encrypt --recipient $GPG_KEY_ID $B3_TMP_DIR/$HASHED.block
    mv $B3_TMP_DIR/$HASHED.block.gpg $B3_TMP_DIR/$HASHED.block

    $(dirname $0)/upload-backup-block.sh $HASHED
else
    echo " reuse"
    rm $BLOCK_FILE
fi

echo "$HASHED" >> $INDEX_FILE
