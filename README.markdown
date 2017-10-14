# Backup

> *Embarassingly simple* backup solution.

You want to have a backup of your data, trust me.
Maybe you don't need it now, but you still want to have it.
Just in case.

Now that you have a backup on a separate drive inside your PC, and
another one on a disconnected drive stored securely in the corner of
your desk, you start looking for a more... distributed solution.
What you want is an off-site backup.
As it happens, you have a server with SSH access just sitting over
there, doing nothing, and you have some spare GBs on it.

This is exactly the scenario in which this repository becomes useful.
It is the most bare-bones off-site backup script you will probably find.

**Pros**:

- encrypted using GPG
- written in BASH so runs on pretty much anything
- uses SSH for transport between local machine and remote storage server
- performs rudimentary deduplication and compression

**Cons**:

- written in BASH so it has the usual quirks of BASH scripts
- uses SSH for transport so is kinda slow
- performs only rudimentary deduplication so your archive size roughly equals the real size of your data


#### WARNING!

Be warned that it is a prototype!
I wrote it to diversify my backups and published it in hope that it may be useful for other people, but
I cannot in good faith say that this is a rock solid software and will not fail.
Use at your own risk.

AND ALWAYS HAVE UP-TO-DATE BACKUP IN AT LEAST TWO LOCATIONS!


----

## Configuration

Put this in `~/.backup.config` file:

```
# Fingerprint of GPG key used to encrypt the backup.
gpg_key=ABC012DEADBEEFC0FFEE

# The script needs to know where to upload blocks and indexes.
storage_user=john.doe
storage_host=example.com
storage_root=/home/backup/johndoe
```

On the remote machine, in the `storage_root` directory you must create two subdirectories: `blocks` and
`indexes`.


----

## Usage

To create the backup use:

```
]$ cd ~
]$ B3_ARCHIVE_NAME=stuff create.sh ./Important/Stuff
```

To restore the backup use:

```
]$ cd ~
   # First operand is the name of the backup, and
   # the second is the timestamp of that backup you want to
   # restore.
]$ restore-remote.sh stuff 20171012T232347
```


----

### Details

The basic idea is to create a big tar archive split into 128K blocks of encrypted data,
deduplicate and compress it, and ship it off to some server.

This program is written in such a way that it never sees a full tar file; it is always
piping data, so the "working size" should not exceed a few megabytes for blocks.
It needs, however, to have a full archive index available during both the creation of the
backup (to store the order of blocks), and the restoration of the backup (to know which
blocks should be fetched and extracted).

While blocks should always be roughly ~128K in size, indexes can grow *big*.
The size of the index is about 1 byte for every 1KB of backup data (before encryption,
compression, and deduplication).
Blocks of data are identified by their SHA512 sums.
SHA512 has the convenient property that its hex digests are 128 bytes long, and
map nicely to the 128KB block size.


#### Pipelines

When creating a backup:

```
{local machine} -> tar -> split -> SHA512 -> gzip -> GPG -> scp -> {remote machine}
```

When restoring a backup:

```
{remote machine} -> scp -> GPG -> gzip -> tar -> {local machine}
```


----

## License

This is Free Software published under GNU GPL v3 or any later version of this license.
