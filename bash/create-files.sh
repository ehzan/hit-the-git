#!/usr/bin/env bash
set -euo pipefail
# set -x pipefail


readonly SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
readonly ORDINALS_FILE="${SCRIPT_DIR}/ordinal-numbers.txt"
readonly MAX_ATTEMPTS=3

declare -A p_work=( [Fri]=1 [Thu]=3 [default]=5 )
declare -a ordinals_short=() ordinals_long=()
declare -i ini_count=10 file_count=0 update_count=0

declare sudo_pwd
declare dir clear_dir=false start_date days base_time interval=60
declare date_changed=false


help() {
    cat <<EOF
usage: bash ${BASH_SOURCE[0]} --dir=<path> [-c | --clear]
            --start-date=<date> --days=<number> --base-time=<time> [--interval=<minutes>]
            [-h | --help]
options:
    --dir=<path>          target directory for files
    --clear, -c           clear the target directory before starting
    --start-date=<date>   start date (YYYY-MM-DD)
    --days=<number>       number of days to simulate
    --base-time=<time>    base time (HH:MM)
    --interval=<minutes>  interval for random numbers (default: 60)
    -h, --help            show this help message

example: bash ${BASH_SOURCE[0]} --dir="./my-files" --clear --start-date=2025-01-01 --days=100 --base-time=12:00 --interval=120
EOF
}


validate_input() {
    local -n param=$1
    local param_name=$1 prompt_text="$2" validation_cmd="$3"

    param="${param-}"
    local -i attempts=0
    while ! eval "$validation_cmd"; do
        [[ -n $param ]] && echo "$param_name: invalid value '$param'" >&2
        ((++attempts > MAX_ATTEMPTS)) && { echo "$MAX_ATTEMPTS incorrect attempts, exiting..." >&2; exit 1; }
        read -rp "$prompt_text: " param
    done
}


parse_args() {
    echo
    local arg
    for arg in "$@"; do
        case $arg in
            -h | --help )    help; exit 0 ;;
            --dir=* )        dir=${arg#*=} ;;
            -c | --clear )   clear_dir=true ;;
            --start-date=* ) start_date=${arg#*=} ;;
            --days=* )       days=${arg#*=} ;;
            --base-time=* )  base_time=${arg#*=} ;;
            --interval=* )   interval=${arg#*=} ;;
            * ) echo "❌ unknown option '$arg'" >&2; help; exit 1 ;;
        esac
    done

    validate_input  dir "enter directory path" "[[ -n \$dir ]] && mkdir -p \"\$dir\" "
    validate_input  start_date "enter start date (YYYY-MM-DD)" \
                    "[[ \$start_date =~ ^[0-9]+(-[0-9]+){2} ]] && date -d \"\$start_date\" &>/dev/null"
    validate_input  days "enter number of days" "[[ \$days =~ ^[0-9]+$ && \$days -gt 0 ]]"
    validate_input  base_time "enter base time (HH:MM)" \
                    "[[ \$base_time =~ ^[0-9]+(:[0-9]+){0,2}$ ]] && date -d \"\$base_time\" &>/dev/null"
    validate_input  interval "enter interval (minutes)" "[[ \$interval =~ ^[0-9]+$ ]]"

    [[ $clear_dir == true ]] && rm -rf "${dir:?}"/{*,.[!.]*,..?*}
    start_date=$(date -d "$start_date" +"%F")
    days=$((10#$days))
    base_time=$(date -d "$base_time" +"%T")
    interval=$((10#$interval))
    
    echo "--- configuration ---"
    echo "directory:    $dir"
    echo "date range:   $start_date for $days days"
    echo "time:         $base_time + [0, $interval] minutes"
    echo "---------------------"
}


get_sudo_password() {
    read -rsp "[sudo] password for $(whoami): " sudo_pwd; echo
    attempts=1
    while ! echo "$sudo_pwd" | sudo -S -kv 2>/dev/null; do
        ((++attempts > MAX_ATTEMPTS)) && { echo "$MAX_ATTEMPTS incorrect attempts, exiting..." >&2; exit 1; }
        read -rsp "[sudo] password for $(whoami): " sudo_pwd; echo
    done
}


load_ordinals() {
    local ordinals_file="$1"

    [ -f "$ordinals_file" ] || { echo "❌ '$ordinals_file' not found" >&2; exit 1; }
    mapfile -t < "$ordinals_file"
    IFS=' ' read -ra ordinals_short <<< "${MAPFILE[0]}"
    IFS=' ' read -ra ordinals_long <<< "${MAPFILE[1]}"
}


create_file() {
    local filename="$1" datetime="$2"
    local filepath="$dir/$filename"

    rm -f "$filepath"   # : > "$filepath"
    echo "$sudo_pwd" | sudo -S date -s "$datetime" &>/dev/null && date_changed=true
    touch "$filepath"
    for l in $(seq 1 5); do
        echo "This is the ${ordinals_short[$l]} line." >> "$filepath"
    done
    ((++file_count))
    # echo $filepath created on $datetime.
}


update_file() {
    local filename="$1" datetime="$2"
    local filepath="$dir/$filename"

    nl=$(( 1 + $(wc -l < "$filepath") ))
    echo Update: "This is the ${ordinals_short[nl]} line." >> "$filepath"
    touch -d "$datetime" "$filepath"
    ((++update_count))
    # echo $filepath updated on $datetime. [$nl lines]
}


create_primary_files () {
    local -i n=$1
    local datetime

    for i in $(seq 1 $n); do
        datetime=$(date -d "$start_date $base_time $i min" +"%F %T")
        create_file "${ordinals_long[i]}.txt" "$datetime"
    done
}


simulate_workday() {
    local date="$1"
    local datetime

    mapfile -t < <(for i in {1..5}; do shuf -n1 -i0-$interval; done | sort -n)
    for m in "${MAPFILE[@]}"; do
        datetime=$(date -d "$date $base_time $m minutes $((RANDOM % 60)) sec" +"%F %T")
        if (( RANDOM % 3)); then
            local -i file_index=$((file_count - RANDOM % 20 % file_count))
            local filename=${ordinals_long[file_index]:-$file_index}.txt
            update_file "$filename" "$datetime"
        else
            local filename=${ordinals_long[file_count+1]:-$((file_count+1))}.txt
            create_file "$filename" "$datetime"
        fi
    done
}


show_progress() {
    local -i current=$1 total=$2 file_count=$3 update_count=$4
    local -i percent=$((100*current/total)) end=$((20*current/total))

    printf "\rnew files: %d, updates: %d   [%-20s] %d%%" \
    $file_count $update_count "$(printf "#%.0s" $(seq 1 $end))" $percent
}


cleanup() {
    [[ $date_changed == false ]] && exit 0
    local current_datetime
    current_datetime=$(curl -sI google.com | grep -i '^date:' | cut -d' ' -f2-)
    echo "$sudo_pwd" | sudo -S date -s "$current_datetime" &>/dev/null
}
trap cleanup EXIT


main () {
    parse_args "$@"
    get_sudo_password
    load_ordinals "$ORDINALS_FILE"
    create_primary_files $ini_count

    local -i i p
    local current_date wd
    for i in $(seq 1 $days); do
        read -r current_date wd <<< "$(date -d "$start_date +$i day" +"%F %a")"
        p=${p_work[$wd]:-${p_work[default]}}
        [ $((RANDOM % 10)) -lt $p ] && simulate_workday "$current_date"
        show_progress $i $days $file_count $update_count
    done
    echo
}

[[ "$0" == "${BASH_SOURCE[0]}" ]] && main "$@"