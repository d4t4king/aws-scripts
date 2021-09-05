#!/usr/bin/env python

import os
import datetime
from subprocess import check_output

today = datetime.datetime.today()

print("Today is the {0} of {1}, {2}.".format(today.day, today.month, today.year))

if today.day < 10:
    if today.weekday == 5:
        print("Run the full backup.")
        with open(os.devnull, 'w') as devnull:
            output = check_output(["/root/aws-scripts/backup_local.sh", "full"], stdout=devnull)
            print("output={0}".format(output))
    else:
        print("Today is not Saturday.  DOn't run the full backup.")
else:
    print("Not in the first week of the month.")

