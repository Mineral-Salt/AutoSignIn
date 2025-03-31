#!/bin/bash

function PrintUsage() {
    echo "usage:  $0 {-i|-u|-p|-s}"
    echo "        -i  初始化Python依赖库"
    echo "        -u  更新Python依赖库"
    echo "        -p  设置自动签到定时任务"
    echo "        -s  立即执行签到操作"
}

function debug_print() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

function handle_error() {
    echo "$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    exit 1
}

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
LOG_FILE="$SCRIPT_DIR/err.log"
CONFIG_FILE="$SCRIPT_DIR/device.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "检测到首次运行，需要创建设备配置文件"
    read -p "请输入ADB设备序列号（可通过 adb devices 查看）: " DEVICE_SN
    [ -z "$DEVICE_SN" ] && handle_error "设备序列号不能为空"
    echo "DEVICE=$DEVICE_SN" > "$CONFIG_FILE" || handle_error "配置文件创建失败"
    # 添加时间范围配置
    echo "MORNING_START=8:30" >> "$CONFIG_FILE"
    echo "MORNING_END=9:00" >> "$CONFIG_FILE"
    echo "EVENING_START=18:30" >> "$CONFIG_FILE"
    echo "EVENING_END=19:00" >> "$CONFIG_FILE"
    echo "配置文件已创建: $CONFIG_FILE"
fi

source "$CONFIG_FILE"
[ -z "$DEVICE" ] && handle_error "配置错误：请检查$CONFIG_FILE中的DEVICE设置"

if [ "$#" -ne 1 ]; then
    PrintUsage
    handle_error "Invalid number of arguments."
fi

function get_rand() {
    echo $((RANDOM % ($2 - $1 + 1) + $1))
}

function generate_random_minutes() {
    local -n array=$1
    local start_time end_time hour minute
    
    if [ "$1" == "morning_minutes" ]; then
        IFS=':' read -r hour minute <<< "$MORNING_START"
        local start_minutes=$((hour * 60 + minute))
        IFS=':' read -r hour minute <<< "$MORNING_END"
        local end_minutes=$((hour * 60 + minute))
    else
        IFS=':' read -r hour minute <<< "$EVENING_START"
        local start_minutes=$((hour * 60 + minute))
        IFS=':' read -r hour minute <<< "$EVENING_END"
        local end_minutes=$((hour * 60 + minute))
    fi

    while [ "${#array[@]}" -lt 3 ]; do
        local random_minutes=$(get_rand $start_minutes $end_minutes)
        local new_hour=$((random_minutes / 60))
        local new_minute=$((random_minutes % 60))
        local new_random="$new_minute $new_hour"
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

    is_workday=$(python3 $SCRIPT_DIR/CheckWorkDay.py)
    status=$?

    case "$status" in
        1) handle_error "Run with -i to initialize the Python library." ;;
        2) handle_error "Run with -u to update the chinesecalendar library." ;;
        0)
            echo "30 1 * * * $SCRIPT_DIR/SignIn.sh -p" > "$SCRIPT_DIR/crontab_self"
            if [[ "$is_workday" == "true" ]]; then
                for time in "${morning_minutes[@]}"; do
                    echo "$time * * * $SCRIPT_DIR/SignIn.sh -s" >> "$SCRIPT_DIR/crontab_self"
                done
                for time in "${evening_minutes[@]}"; do
                    echo "$time * * * $SCRIPT_DIR/SignIn.sh -s" >> "$SCRIPT_DIR/crontab_self"
                done
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
