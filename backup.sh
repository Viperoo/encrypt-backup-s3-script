#!/usr/bin/env bash

# Ensure that all possible binary paths are checked
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

#Directory the script is in (for later use)
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Provides the 'log' command to simultaneously log to
# STDOUT and the log file with a single command
# NOTE: Use "" rather than \n unless you want a COMPLETELY blank line (no timestamp)
log() {
    echo -e "$(date -u +%Y-%m-%d-%H%M)" "$1" >> "${LOGFILE}"
    if [ "$2" != "noecho" ]; then
        echo -e "$1"
    fi
}

### LOAD IN CONFIG ###

# Prepare "new" settings that might not be in backup.cfg
SCPLIMIT=0

# Default config location
CONFIG="${SCRIPTDIR}"/backup.cfg


if [ "$1" == "--config" ]; then
    # Get config from specified file
    CONFIG="$2"
elif [ $# != 0 ]; then
    # Invalid arguments
    echo "Usage: $0 [--config filename]"
    exit
fi

# Check config file exists
if [ ! -e "${CONFIG}" ]; then
    echo "Couldn't find config file: ${CONFIG}"
    exit
fi

# Load in config
CONFIG=$( realpath "${CONFIG}" )
source "${CONFIG}"

### END OF CONFIG ###

### CHECKS ###

# This section checks for all of the binaries used in the backup
BINARIES=( cat cd command date dirname echo find openssl pwd realpath rm rsync scp ssh tar )

# Iterate over the list of binaries, and if one isn't found, abort
for BINARY in "${BINARIES[@]}"; do
    if [ ! "$(command -v "$BINARY")" ]; then
        log "$BINARY is not installed. Install it and try again"
        exit
    fi
done

# Check if the backup folders exist and are writeable
if [ ! -w "${LOCALDIR}" ]; then
    log "${LOCALDIR} either doesn't exist or isn't writable"
    log "Either fix or replace the LOCALDIR setting"
    exit
elif [ ! -w "${TEMPDIR}" ]; then
    log "${TEMPDIR} either doesn't exist or isn't writable"
    log "Either fix or replace the TEMPDIR setting"
    exit
fi


BACKUPDATE=$(date -u +%Y-%m-%d-%H%M)
STARTTIME=$(date +%s)
TARFILE="${LOCALDIR}""$(hostname)"-"${BACKUPDATE}".tgz
SQLFILE="${TEMPDIR}mysql_${BACKUPDATE}.sql"

cd "${LOCALDIR}" || exit

### END OF CHECKS ###

### MYSQL BACKUP ###

if [ ! "$(command -v mysqldump)" ]; then
    log "mysqldump not found, not backing up MySQL!"
elif [ -z "$ROOTMYSQL" ]; then
    log "MySQL root password not set, not backing up MySQL!"
else
    log "Starting MySQL dump dated ${BACKUPDATE}"
    mysqldump -u root -p"${ROOTMYSQL}" --all-databases > "${SQLFILE}"
    log "MySQL dump complete"; log ""

    #Add MySQL backup to BACKUP list
    BACKUP=(${BACKUP[*]} ${SQLFILE})
fi

### END OF MYSQL BACKUP ###

### TAR BACKUP ###

log "Starting tar backup dated ${BACKUPDATE}"
# Prepare tar command

# Check if there are any exclusions
if [[ "x${EXCLUDE[@]}" != "x" ]]; then
    # Add exclusions to front of command
    for i in "${EXCLUDE[@]}"; do
        TARCMD="--exclude $i ${TARCMD}"
    done
fi

# Run tar

WORKDIR="${LOCALDIR}/$(date -u +%Y-%m-%d-%H%M)"
$(mkdir -p $WORKDIR)

for i in "${BACKUP[@]}"; do
    TARCMD=" cz $i "
    log "[Tar] Pack file $(basename $i)"
    tar ${TARCMD} | split -b 1024m - "${WORKDIR}/$(basename $i)-$(date -u +%Y-%m-%d-%H%M%S).tar.gz."
done

# Encrypt tar file
for file in $WORKDIR/*
do
    log "[Encrypt] Encrypting backup file $(basename $file)"
    openssl enc -aes256 -in "$file" -out "$file".aes -pass pass:"${BACKUPPASS}" -md sha1
    # decrypt openssl enc -aes256 -pass pass:mysecurepassword -md sha1 -d -in git-2015-11-20-124455.tar.gz.ad.aes -out git-2015-11-20-124455.tar.gz.ad
    # Delete unencrypted tar
    rm "$file"

done

log "Encryption completed"
log "Send files to storage"

python "${SCRIPTDIR}"/s3.py "${WORKDIR}/"

### BACKUP DELETION ##

log "Checking for LOCAL backups to delete..."
bash "${SCRIPTDIR}"/deleteoldbackups.sh --config "${CONFIG}"
log ""
