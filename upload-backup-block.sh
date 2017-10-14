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

HASHED=$1

# TODO Maybe employ wput to support FTP?
# TODO Add support for rsync

function upload_one_block {
    scp $1.block $STORAGE_USER@$STORAGE_HOST:$STORAGE_ROOT/
    rm $1.block
}

function upload_all_blocks {
    scp *.block $STORAGE_USER@$STORAGE_HOST:$STORAGE_ROOT/
    rm *.block
}

if [[ $B3_UPLOAD_BATCH_SIZE == '' ]]; then
    B3_UPLOAD_BATCH_SIZE=0
fi

if [[ $B3_UPLOAD_BATCH_SIZE -eq 0 ]]; then
    upload_one_block $HASHED
elif [[ $B3_UPLOAD_BATCH_SIZE -lt $(ls -1 *.block | wc -l) ]]; then
    upload_all_blocks
elif [[ $B3_UPLOAD_FINISHING == 'yes' ]]; then
    upload_all_blocks
fi
