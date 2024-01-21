#!/bin/bash

basepath=/opt/scripts/nwfl
domain=$(hostname -d)
date_now=$(date "+%d %b %Y %H:%M")

monitor_pattern='/soap/BatchRequest.*name=.*account=.*protocol=soap.*invalid password;'

while true; do
    # Debugging: Print a message for each iteration
    echo "Debug: Iteration - $(date)"

    # Tail the log file for 30 seconds
    timeout 30s tail -f /opt/zimbra/log/audit.log | grep -E "$monitor_pattern" | \
        awk '{print $9, $5}' | sed -n 's/.*account=\([^;]*\);.*oip=\([0-9.]*\);.*/\1 \2/p' | \
        sort -n | uniq -c | sort -nr | head -40 > "$basepath/mktemp"

    # Check if the count exceeds 3
    while read value account ip; do
        if [ "$value" ] && [ "$value" -gt 3 ]; then
            login=$account
            ip_address=$ip

            # Construct email subject and body using a here document
            email_content=$(cat <<EOF
Subject: Failed login
From: admin@$domain
To: mail@myhaldin.com

Login: $login
IP: $ip_address
Date: $date_now
Atemp: $value
EOF
            )

            # Send the email
            echo -e "$email_content" | /opt/zimbra/common/sbin/sendmail -f admin@$domain mail@mail.com

            # Debugging: Print a message after the email is sent
            echo "Debug: Email sent - $(date)"

            # Reset the count and exit the loop
            break
        fi
    done < "$basepath/mktemp"

    # Sleep for a short duration before the next iteration
    sleep 1
done
