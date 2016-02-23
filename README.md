# encrypt-backup-s3-script

This is fork of [this script](https://github.com/Pricetx/backup/), added simple upload backups to Amazon S3 with boto and tar dividing.

### s3.py

This file has separate configuration.


### Example crontab

```
0 23 * * * root /usr/bin/sh /path/to/scripts/backup/backup.sh
```
