#!/bin/bash

# File paths
api_file="services.txt"
recipient_file="recipient_of_services.txt"
email_notification_file="/tmp/service_email_notification.txt"
url_alias_mapping_file="service_alias.txt"
counter_file="/tmp/api_counters.txt"

# Email settings
sender_name="Services Monitoring Report"
sender_email="indicsoftnoida@gmail.com"
subject="Swachhatam Service Down Report"
mail_command="/usr/sbin/sendmail"

#INPUT FILES
HEADER=$(<header.html)
TOKEN=$(<token_file.txt)
FOOTER=$(<footer.html)

# Function to send email notification
send_email() {
    echo "Subject: $subject" > "$email_notification_file"
    echo "To: $recipient" >> "$email_notification_file"
    echo "Content-Type: text/html; charset=utf-8" >> "$email_notification_file"
    echo -e "\n$1" >> "$email_notification_file"
    $mail_command -F "$sender_name" -f "$sender_email" -t < "$email_notification_file"
}

#ALIAS Name Function
declare -A url_alias_mapping
while IFS=' ' read -r url alias; do
    url_alias_mapping["$url"]=$alias
done < "$url_alias_mapping_file"

# Load counters or initialize if not exists
declare -A api_counters
if [ -e "$counter_file" ]; then
    source "$counter_file"
fi

#Recipient List
IFS= read -r recipients <<< "$(cat "$recipient_file")"

MIDDLE=""
#Main Function

at_least_one_not_working=false  # Flag to track whether at least one API is not working

while IFS= read -r api; do
    alias_name="${url_alias_mapping[$api]:-$api}"
    counter="${api_counters[$api]:-0}"

    max_retries=4
    while [ $max_retries -gt 0 ]; do   
        http_status=$(wget --dns-timeout=15 --server-response "$api" --header "Authorization: $TOKEN" --header 'content-type: application/json' -O output_file 2>&1 | awk '/HTTP/{print $2}' | grep -oP '\d+')
        # Check the exit code of wget
        if [ "$http_status" -eq 200 ]; then
            break  # Exit the loop if successful
        else
	    echo "check $max_retries"
            max_retries=$((max_retries - 1))
            sleep 20
        fi
    done

    #http_status=$(wget --dns-timeout=15 --server-response "$api" --header "Authorization: $TOKEN" --header 'content-type: application/json' -O output_file 2>&1 | awk '/HTTP/{print $2}' | grep -oP '\d+')
    recipient="${recipients[0]}"

    if [ "$http_status" -eq 200 ]; then
        echo "$alias_name is working (HTTP Status Code: $http_status). \n"
        api_counters["$api"]=0  # Reset counter if API is working    
    else
        echo "$alias_name is not working (HTTP Status Code: $http_status). \n"
        api_counters["$api"]=$((counter + 1))   # Increment the counter if API is not working
        if [ "${api_counters[$api]}" -eq 1 ]; then
            at_least_one_not_working=true  # Set the flag to true if at least one API is not working for the first time
            MIDDLE+=$(cat <<EOF
            <div class="col-lg-12" style="display: flex;" >
                <div class="col-md-6" style="width: 50%;">
                    <p style="border: 1px solid;margin: 0px;
                padding: 5px;
                text-align: center;">$alias_name</p>
                </div>
                <div class="col-md-6" style="width: 50%;">
                    <p style="border: 1px solid;
                padding: 5px;margin: 0px;
                text-align: center; color: red;">Service is Not Working</p>
                </div>
            </div>
EOF
)
        fi
    fi
    echo
done < "$api_file"

# Store counters
declare -p api_counters > "$counter_file"

#Storing the HTML FORMAT and sending email only if at least one API is not working
if [ "$at_least_one_not_working" = true ]; then
    message="$HEADER$MIDDLE$FOOTER"
    send_email "$message"
fi

