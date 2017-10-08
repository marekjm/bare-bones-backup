#!/usr/bin/env bash

set -e

cat > $FILE

BLOCK_ID=$(echo "$FILE" | sed 's/\.new\.block$//')
HASHED=$(sha512sum $FILE | cut -d' ' -f1)
echo -n "block: $BLOCK_ID -> $HASHED"

if [[ $(grep -P "$HASHED" $INDEX_FILE | wc -l) -eq 0 ]]; then
    echo " compress"
    gzip -S .gz $FILE
    mv $FILE.gz $HASHED.block

    gpg --encrypt --recipient $GPG_KEY_ID $HASHED.block
    mv $HASHED.block.gpg $HASHED.block

    $(dirname $0)/upload-backup-block.sh $HASHED
else
    echo " reuse"
    rm $FILE
fi

echo "$HASHED" >> $INDEX_FILE
