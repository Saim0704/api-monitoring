#!/bin/bash

# File paths
api_file="services.txt"
recipient_file="recipient_of_services.txt"
email_notification_file="/tmp/api-morning-mail_notification.txt"
url_alias_mapping_file="service_alias.txt"

# Email settings
subject="Swachhatam Services Report"
sender_name="Services Monitoring Report"
#sender_email="indicsoftnoida@gmail.com"
mail_command="/usr/sbin/sendmail"


#INPUT FILES
HEADER=$(<header.html)
TOKEN=$(<token_file.txt)
FOOTER=$(<footer.html)

# Function to send email notification
send_email() {
#    echo "From: $sender_name <$sender_email>" > "$email_notification_file"
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

#Recipient List
IFS= read -r recipients <<< "$(cat "$recipient_file")"

MIDDLE=""
#Main Function
while IFS= read -r api; do

    alias_name="${url_alias_mapping[$api]:-$api}"
# Hit the URL and get the HTTP status code
    http_status=$(wget --dns-timeout=15 --server-response "$api" --header "Authorization: $TOKEN" --header 'content-type: application/json' -O output_file 2>&1 | awk '/HTTP/{print $2}' | grep -oP '\d+')
    recipient="${recipients[0]}"

    if [ "$http_status" -eq 200 ]; then
	echo "$alias_name is working (HTTP Status Code: $http_status). \n"
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
                text-align: center; color: green;">Service is Up and Running</p>
                </div>
            </div>
EOF
)
 
    else
	echo "$alias_name is not working (HTTP Status Code: $http_status). \n"
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
#    echo "$alias_name is not working (HTTP Status Code: $http_status). \n"
    fi
    echo
done < "$api_file"

#echo "Service Status Checking Ended Now"
#Storing the HTML FORMAT
message="$HEADER$MIDDLE$FOOTER"

#Sending MAIL
send_email "$message"

