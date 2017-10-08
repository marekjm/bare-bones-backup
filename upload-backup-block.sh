#!/usr/bin/env bash

set -e

HASHED=$1

# TODO Maybe employ wput to support FTP?

scp $HASHED.block $STORAGE_USER@$STORAGE_HOST:$STORAGE_ROOT/
rm $HASHED.block
