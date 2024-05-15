# !/bin/bash
url="https://devuploads.com/api/upload/server"

# take user args -f for file path and -k for api key and -h for help

file_path=""
api_key=""
sess_id=""
server_url=""

# parse args
while getopts ":f:k:h" opt; do
    case $opt in
        f)
            file_path="$OPTARG"
            ;;
        k)
            api_key="$OPTARG"
            ;;
        h)
            echo
            printf "\e[90m \e[0m \e[40m -f \e[0m\e[34m file path\e[0m\e[90m to upload\e[0m"
            echo
            printf "\e[90m \e[0m \e[40m -k \e[0m\e[34m api key\e[0m\e[90m to use\e[0m"
            echo
            printf "\e[90m \e[0m \e[40m -h \e[0m\e[90m to show this help\e[0m"
            echo
            echo
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            exit 1
            ;;
    esac
done



# if api key is not defined
if [ -z "$sess_id" ]; then
    res_status=400
    while [ "$res_status" -ne 200 ]; do
        # default value api_key if not entered by user
        if [ ! -z "$api_key" ]; then
            res_json=$(curl -s -X GET "$url?key=$api_key")
            res_status=$(echo "$res_json" | grep -o '"status":[0-9]*' | awk -F ':' '{print $2}')
            sess_id=$(echo "$res_json" | grep -o '"sess_id":"[^"]*"' | awk -F ':' '{print $2}' | tr -d '"')
            server_url=$(echo $res_json | sed -n 's/.*"result":"\([^"]*\).*/\1/p')
            if [ "$res_status" -eq 200 ]; then
                break
            else
                printf "\e[31mYou API KEY $api_key is not valid\e[0m"
                echo
                api_key=''
                continue
            fi
        else
            printf "\e[90mEnter api key: \e[0m"
        fi
        read user_api_key
        
        # if user have not entered api key use default value
        if [ -z "$user_api_key" ]; then
            user_api_key="$api_key"
        fi
        
        res_json=$(curl -s -X GET "$url?key=$user_api_key")
        res_status=$(echo "$res_json" | grep -o '"status":[0-9]*' | awk -F ':' '{print $2}')
        sess_id=$(echo "$res_json" | grep -o '"sess_id":"[^"]*"' | awk -F ':' '{print $2}' | tr -d '"')
        server_url=$(echo $res_json | sed -n 's/.*"result":"\([^"]*\).*/\1/p')
        if [ "$res_status" -ne 200 ]; then
            printf "\e[31mYour API KEY $user_api_key is not valid\e[0m"
            echo
        fi
    done
fi

# check if path is a file
if [ ! -f "$file_path" ]; then
    # enter file path until it's valid and show error if not valid
    while [ ! -f "$file_path" ]; do
        if [ ! -z "$file_path" ]; then
            printf "\e[31mFile $file_path not found\e[0m"
            echo
        fi
        printf "\e[90mEnter file path: \e[0m"
        read file_path
        file_path=$(realpath "$file_path") # abs path
    done
fi

# valid api key check icon
printf "\e[30m ✓ Api key is valid.\e[0m"
echo
# tokens fetched check icon
printf "\e[30m ✓ Tokens fetched.\e[0m"
echo
# valid file path check icon
printf "\e[30m ✓ File path $file_path is valid.\e[0m"
echo

echo

# url="https://du3.devuploads.com/cgi-bin/upload.cgi"
url="$server_url"
echo "Uploading file $file_path to $url"

res_file_name=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 | awk '{print "u"$0".json"}')

# make request using curl use -o flag with file name to save file
curl -X POST -o "$res_file_name" \
-F "sess_id=$sess_id" \
-F "utype=reg" \
-F "file=@$file_path" \
"$url"

# get file content with grep -o '"file_code":"[^"]*"' | awk -F ':' '{print $2}' | tr -d '"'
file_code=$(cat "$res_file_name" | grep -o '"file_code":"[^"]*"' | awk -F ':' '{print $2}' | tr -d '"')

# remove the file
rm "$res_file_name"

# print file code
prefix_url="https://devuploads.com/"
echo
printf "\e[32m$prefix_url$file_code\e[0m"
echo
echo


# set it up the main.sh as a command devupload
# chmod +x main.sh
# sudo mv main.sh /usr/bin/devupload

# usage
