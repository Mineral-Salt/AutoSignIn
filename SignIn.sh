#!/bin/bash

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
LOG_FILE="$SCRIPT_DIR/err.log"
CONFIG_FILE="$SCRIPT_DIR/device.conf"

function print_usage() {
    cat <<EOF
usage:  $0 {-i|-u|-p|-s}
        -i  初始化Python依赖库
        -u  更新Python依赖库
        -p  设置自动签到定时任务
        -s  立即执行签到操作
EOF
}

function log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp - $1" >> "$LOG_FILE"
    echo "$1"
}

function handle_error() {
    log "ERROR: $1"
    exit 1
}

function validate_config() {
    [ -f "$CONFIG_FILE" ] || {
        log "检测到首次运行，需要创建设备配置文件"
        read -p "请输入ADB设备序列号（可通过 adb devices 查看）: " DEVICE_SN
        [ -z "$DEVICE_SN" ] && handle_error "设备序列号不能为空"
        
        cat > "$CONFIG_FILE" <<EOF
DEVICE=$DEVICE_SN
MORNING_START=8:30
MORNING_END=9:00
EVENING_START=18:30
EVENING_END=19:00
EOF
        log "配置文件已创建: $CONFIG_FILE"
    }
    
    source "$CONFIG_FILE"
    [ -z "$DEVICE" ] && handle_error "配置错误：请检查$CONFIG_FILE中的DEVICE设置"
}

function get_random_number() {
    echo $((RANDOM % ($2 - $1 + 1) + $1))
}

function generate_time_slots() {
    local -n array=$1
    local start_time end_time
    
    if [ "$1" == "morning_minutes" ]; then
        start_time=$MORNING_START
        end_time=$MORNING_END
    else
        start_time=$EVENING_START
        end_time=$EVENING_END
    fi

    IFS=':' read -r hour minute <<< "$start_time"
    local start_minutes=$((hour * 60 + minute))
    IFS=':' read -r hour minute <<< "$end_time"
    local end_minutes=$((hour * 60 + minute))

    while [ "${#array[@]}" -lt 3 ]; do
        local random_minutes=$(get_random_number $start_minutes $end_minutes)
        local new_hour=$((random_minutes / 60))
        local new_minute=$((random_minutes % 60))
        local new_slot="$new_minute $new_hour"
        [[ ! " ${array[*]} " =~ " $new_slot " ]] && array+=("$new_slot")
    done
}

function init_python_deps() {
    command -v pip &> /dev/null || handle_error "未找到pip命令，请先安装pip"

    if ! python3 -c "import chinese_calendar" &> /dev/null; then
        log "正在安装chinesecalendar库..."
        pip install chinesecalendar || handle_error "安装chinesecalendar库失败"
    fi
    log "Python依赖库已就绪"
}

function update_python_deps() {
    command -v pip &> /dev/null || handle_error "未找到pip命令，请先安装pip"

    log "正在更新chinesecalendar库..."
    pip install -U chinesecalendar || handle_error "更新chinesecalendar库失败"
    log "Python依赖库已更新"
}

function setup_cron_jobs() {
    command -v crontab &> /dev/null || handle_error "未找到crontab命令"

    local morning_minutes=() evening_minutes=()
    generate_time_slots morning_minutes
    generate_time_slots evening_minutes

    local is_workday=$(python3 "$SCRIPT_DIR/CheckWorkDay.py")
    local status=$?

    case "$status" in
        1) handle_error "请使用 -i 参数初始化Python库" ;;
        2) handle_error "请使用 -u 参数更新chinesecalendar库" ;;
        0)
            {
                echo "30 1 * * * $SCRIPT_DIR/SignIn.sh -p"
                if [[ "$is_workday" == "true" ]]; then
                    for time in "${morning_minutes[@]}"; do
                        echo "$time * * * $SCRIPT_DIR/SignIn.sh -s"
                    done
                    for time in "${evening_minutes[@]}"; do
                        echo "$time * * * $SCRIPT_DIR/SignIn.sh -s"
                    done
                fi
            } > "$SCRIPT_DIR/crontab_self"
            
            crontab "$SCRIPT_DIR/crontab_self" || handle_error "更新crontab失败"
            log "定时任务设置成功"
            ;;
        *) handle_error "未知错误: ret=[$status]"
    esac
}

function perform_sign_in() {
    command -v adb &> /dev/null || handle_error "未找到adb命令"

    local dimensions=$(adb -s "$DEVICE" shell wm size | sed -n 's/.*: //;s/x/ /;p')
    read -r width height <<< "$dimensions"

    local middle_x=$((width / 2))
    local signin_y=$((height * 66 / 100))

    local actions=(
        "input keyevent KEYCODE_POWER:1"
        "input keyevent 82:1"
        "input text \"${DEVICE_PSW}\":1"
        "input tap $((width * 3 / 4 + width / 8)) $((height * 91 / 100)):255"
        "input tap $middle_x $signin_y:2"
        "input keyevent KEYCODE_APP_SWITCH:1"
        "input swipe $middle_x $signin_y $middle_x $((height / 5)) 200:1"
        "input keyevent KEYCODE_POWER:1"
    )

    for item in "${actions[@]}"; do
        IFS=':' read -r action sleep_time <<< "$item"
        adb -s "$DEVICE" shell "$action" || handle_error "执行操作失败: $action"
        [[ "$sleep_time" == "255" ]] && sleep $(get_random_number 8 15) || sleep "$sleep_time"
    done
    
    log "签到操作完成"
}

# 主程序入口
validate_config

if [ "$#" -ne 1 ]; then
    print_usage
    handle_error "参数数量不正确"
fi

case "$1" in
    -i) init_python_deps ;;
    -u) update_python_deps ;;
    -p) setup_cron_jobs ;;
    -s) perform_sign_in ;;
    *) print_usage; handle_error "无效参数: $1" ;;
esac

exit 0