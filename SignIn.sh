#!/bin/bash

DEVICE=392QBFCC222C6
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
LOG_FILE="$SCRIPT_DIR/err.log"

function PrintUsage() {
    echo "usage:  $0 {-i|-u|-p|-s}"
    echo "        -i  init Python library"
    echo "        -u  update Python library"
    echo "        -p  setup cron jobs for auto signin"
    echo "        -s  execute signin now"
}

function debug_print() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

function handle_error() {
    echo "$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    exit 1
}

if [ "$#" -ne 1 ]; then
    PrintUsage
    handle_error "Invalid number of arguments."
fi

function get_rand() {
    echo $((RANDOM % ($2 - $1 + 1) + $1))
}

function generate_random_minutes() {
    local -n array=$1
    while [ "${#array[@]}" -lt 3 ]; do
        local new_random=$(get_rand 30 50)
        [[ ! " ${array[*]} " =~ " $new_random " ]] && array+=("$new_random")
    done
}

function InitWork () {
    if python3 -c "import chinese_calendar" &> /dev/null; then
        echo "chinesecalendar library is already installed."
    else
        echo "Installing chinesecalendar library..."
        pip install chinesecalendar
    fi
}

function UpdateLibWork () {
    pip install -U chinesecalendar
}

function PreWork() {
    command -v crontab &> /dev/null || handle_error "crontab command not found."

    local morning_minutes=() evening_minutes=()
    generate_random_minutes morning_minutes
    generate_random_minutes evening_minutes

    IFS=$'\n' sorted_morning_minutes=($(sort -n <<<"${morning_minutes[*]}"))
    IFS=$'\n' sorted_evening_minutes=($(sort -n <<<"${evening_minutes[*]}"))

    local morning_minutes_str=$(IFS=,; echo "${sorted_morning_minutes[*]}")
    local evening_minutes_str=$(IFS=,; echo "${sorted_evening_minutes[*]}")

    is_workday=$(python3 $SCRIPT_DIR/CheckWorkDay.py)
    status=$?

    case "$status" in
        1) handle_error "Run with -i to initialize the Python library." ;;
        2) handle_error "Run with -u to update the chinesecalendar library." ;;
        0)
            echo "30 1 * * * $SCRIPT_DIR/SignIn.sh -p" > "$SCRIPT_DIR/crontab_self"
            if [[ "$is_workday" == "true" ]]; then
                echo "$morning_minutes_str 8 * * * $SCRIPT_DIR/SignIn.sh -s" >> "$SCRIPT_DIR/crontab_self"
                echo "$evening_minutes_str 18 * * * $SCRIPT_DIR/SignIn.sh -s" >> "$SCRIPT_DIR/crontab_self"
            fi
            crontab "$SCRIPT_DIR/crontab_self" || handle_error "Failed to update crontab."
            ;;
        *) handle_error "ret=[$status] is unknown error"
    esac
}

function SignInWork() {
    command -v adb &> /dev/null || handle_error "adb command not found."

    dimensions=$(adb -s "$DEVICE" shell wm size | sed -n 's/.*: //;s/x/ /;p')
    read -r width height <<< "$dimensions"

    local middle_x=$((width / 2))
    local signin_y=$((height * 66 / 100))

    local actions_and_sleep_times=(
        "input keyevent KEYCODE_POWER:1"
        "input keyevent 82:1"
        "input swipe $middle_x $((height * 4 / 10)) $middle_x $((height * 80 / 100)) 500:1"
        "input tap $((width * 3 / 4 + width / 8)) $((height * 91 / 100)):255"
        "input tap $middle_x $signin_y:2"
        "input keyevent KEYCODE_APP_SWITCH:1"
        "input swipe $middle_x $signin_y $middle_x $((height / 5)) 200:1"
        "input keyevent KEYCODE_POWER:1"
    )

    for item in "${actions_and_sleep_times[@]}"; do
        IFS=':' read -r action sleep_time <<< "$item"
        adb -s "$DEVICE" shell "$action" || handle_error "Failed to execute action: $action"
        [[ "$sleep_time" == "255" ]] && sleep $(get_rand 8 15) || sleep "$sleep_time"
    done
}

case "$1" in
    -i) InitWork ;;
    -u) UpdateLibWork ;;
    -p) PreWork ;;
    -s) SignInWork ;;
    *) PrintUsage ;;
esac

exit 0
