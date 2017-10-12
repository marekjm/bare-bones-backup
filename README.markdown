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
It is the most bare-bones off-set backup script you will probably find.

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


----

## Usage

To create the backup use:

```
]$ create.sh ~/Important/Stuff
```

To restore the backup use:

```
]$ cd ~
]$ restore-remote.sh 20171012T232347    # timestamp of the backup you want to restore
```


----

## License

This is Free Software published under GNU GPL v3 or any later version of this license.
