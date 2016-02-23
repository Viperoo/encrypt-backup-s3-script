#!/usr/bin/python

import datetime
import os
import string
import tarfile

from boto.s3.connection import S3Connection

from boto.s3.key import Key
import boto
boto.config.add_section('Boto')
boto.config.set('Boto','http_socket_timeout','10')

from datetime import timedelta
from os.path import normpath, basename
import sys
from dateutil.parser import parse


# Configuration

aws_access_key = ''
aws_secret_key = ''
aws_bucket = ''
aws_host = 'e24files.com'

workdir = sys.argv[1]
# Establish S3 Connection
s3 = S3Connection(aws_access_key, aws_secret_key, host=aws_host, is_secure=False)

today = datetime.date.today()
previous = today - timedelta(days = 3)

from boto.s3.bucket import Bucket

b = Bucket(s3, aws_bucket)

print "[S3] Upload files "

files_in_dir = os.listdir(sys.argv[1])
for file in files_in_dir:
    print "[S3] Uploading " + file
    k = Key(b)
    k.key = file
    k.set_contents_from_filename(workdir + file, policy="public-read")

print "[S3] Upload complete "
print "[S3] Deleting old files "

for key in b:

       d = parse(key.last_modified)

       if datetime.datetime(d.year, d.month, d.day) <= datetime.datetime(previous.year, previous.month, previous.day):
           print "[S3] Deleting " + key.name
           b.delete_key(key)

sys.exit(0)
