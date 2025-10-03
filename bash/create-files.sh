#!/usr/bin/env bash
set -euo pipefail
# set -x pipefail


readonly ORDINAS_FILE="$(dirname "$0")/ordinal-numbers.txt"
readonly MAX_ATTEMPTS=3

declare -A p_work=( [Fri]=1 [Thu]=3 [default]=5 )
declare -a ordinals_short=() ordinals_long=()
declare -i ini_count=10 file_count=0 update_count=0

declare sudo_pwd
declare dir days start_date base_time interval
declare date_changed=false


help() {
    cat << EOF
usage: source $0 --dir=<path> [-c | --clear] --start_date=<date> --days=<number>
        --base-time=<time> [--interval=<minutes> (default: 60)] [-h | --help]
example: source $0 --dir="./my files" --clear --start-date=2025-01-01 --days=100 --base-time=12:00 --interval=120
EOF
}


check_parameters() {
    for param in "$@"; do
        case $param in
            -h | --help )       help; exit 0 ;;
            "--dir="* )         dir=${param#*=} ;;
            -c | --clear )      clear=true ;;
            "--days="* )        days=${param#*=} ;;
            "--start-date="* )  start_date=${param#*=} ;;
            "--base-time="* )   base_time=${param#*=} ;;
            "--interval="* )    interval=${param#*=} ;;
            * ) echo unknown option: ‘"$param"’; help; exit 1 ;;
        esac
    done

    local -i attempts=0
    while ! ( [[ -v dir && -n $dir ]] &&  mkdir -p "$dir"); do
        (( attempts++ < MAX_ATTEMPTS )) || { echo $MAX_ATTEMPTS incorrect attempts; exit 1; }
        read -rp "enter directory path: " dir
    done

    if [[ -v clear && $clear == true ]]; then
        rm -rf "${dir:?}"/{*,.[!.]*,..?*}
    fi
 
    attempts=0
    while ! [[ -v days && $days =~ ^[0-9]+$ && $days -gt 0 ]]; do
        [ -v days ] && echo days: invalid value ‘"$days"’
        (( attempts++ < MAX_ATTEMPTS )) || { echo $MAX_ATTEMPTS incorrect attempts; exit 1; }
        read -rp "enter number of days: " days
    done
    days=$((10#$days))
   
    attempts=0
    while :; do
        if ! [[ -v start_date && $start_date =~ ^[0-9]+-[0-9]+-[0-9]+$ ]]; then
            [ -v start_date ] && echo date: invalid date ‘"$start_date"’
        else
            date -d "$start_date" +"%F" >/dev/null && break
        fi
        (( attempts++ < MAX_ATTEMPTS )) || { echo $MAX_ATTEMPTS incorrect attempts; exit 1; }
        read -rp "enter start-date: " start_date
    done
    start_date=$(date -d "$start_date" +"%F")

    attempts=0
    while :; do
        if ! [[ -v base_time && $base_time =~ ^[0-9]{1,2}(:[0-9]+){0,2}$ ]]; then
            [ -v base_time ] && echo time: invalid time ‘"$base_time"’
        else
            date -d "$start_date" +"%T" >/dev/null && break
        fi
        (( attempts++ < MAX_ATTEMPTS )) || { echo $MAX_ATTEMPTS incorrect attempts; exit 1; }
        read -rp "enter base-time: " base_time
    done
    base_time=$(date -d "$base_time" +"%T")

    attempts=0
    [ -v interval ] || interval=60
    while ! [[ $interval =~ ^[0-9]+$ ]]; do
        echo interval: invalid value ‘"$interval"’
        (( attempts++ < MAX_ATTEMPTS )) || { echo $MAX_ATTEMPTS incorrect attempts; exit 1; }
        read -rp "enter interval (minutes): " interval
    done
    interval=$((10#$interval))

    read -rsp "[sudo] password for $(whoami): " sudo_pwd; echo
    attempts=1
    while ! echo "$sudo_pwd" | sudo -S -k true 2>/dev/null; do
        (( attempts++ < MAX_ATTEMPTS )) || { echo $MAX_ATTEMPTS incorrect attempts; exit 1; }
        read -rsp "[sudo] password for $(whoami): " sudo_pwd; echo
    done

    echo "dir: $dir", "start-date: $start_date", "days: $days", "time: $base_time +[0,$interval] minutes"
}


load_ordinals() {
    local ordinals_file=$1
    local -a lines=()

    [ -f "$ordinals_file" ] || { echo ‘"$ordinals_file"’ not found; exit 1; }
    mapfile -t lines < "$ordinals_file"
    IFS=' ' read -ra ordinals_short <<< "${lines[0]}"
    IFS=' ' read -ra ordinals_long <<< "${lines[1]}"
}


create_file() {
    local filename=$1 datetime=$2

    filepath="$dir/$filename"
    rm -f "$filepath"   # : > "$filepath"
    echo "$sudo_pwd" | sudo -S date -s "$datetime" >/dev/null 2>&1 && date_changed=true
    touch "$filepath"
    for l in $(seq 1 5); do
        echo "This is the ${ordinals_short[$l]} line." >> "$filepath"
    done
    ((++file_count))
    # echo $filepath created on $datetime.
}


update_file() {
    local filename=$1 datetime=$2

    filepath="$dir/$filename"
    nl=$(( 1 + $(wc -l < "$filepath") ))
    echo Update: "This is the ${ordinals_short[nl]} line." >> "$filepath"
    touch -d "$datetime" "$filepath"
    ((++update_count))
    # echo $filepath updated on $datetime. [$nl lines]
}


create_primary_files () {
    local -i n=$1
    for i in $(seq 1 $n); do
        datetime=$(date -d "$start_date $base_time $i minutes" +"%F %T")
        create_file "${ordinals_long[i]}.txt" "$datetime"
    done
}


work() {
    local date=$1

    for m in $(shuf -n3 -i0-$interval | sort); do
        datetime=$(date -d "$date $base_time $m min $((RANDOM % 60)) sec" +"%F %T")
        if (( RANDOM % 2)); then
            f=$((file_count - RANDOM % 20 % file_count))
            filename=${ordinals_long[f]:-$f}.txt
            update_file "$filename" "$datetime"
        else
            filename=${ordinals_long[file_count+1]:-$((file_count+1))}.txt
            create_file "$filename" "$datetime"
        fi
    done
}


show_progress() {
    local -i current=$1 total=$2 file_count=$3 update_count=$4
    local -i percent=$((100*current/total)) end=$((20*current/total))

    printf "\rnew files: %s, updates: %s   [%-20s] %d%%" \
    $file_count $update_count "$(printf "#%.0s" $(seq 1 $end))" $percent
}


cleanup() {
    local current_datetime
    [[ $date_changed == false ]] && exit 0
    current_datetime=$(curl -sI google.com | grep -i '^date:' | cut -d' ' -f2-)
    echo "$sudo_pwd" | sudo -S date -s "$current_datetime" >/dev/null 2>&1
}
trap cleanup EXIT


main () {
    check_parameters "$@"
    load_ordinals "$ORDINAS_FILE"
    create_primary_files $ini_count

    local -i i p
    for i in $(seq 1 $days); do
        read -r date wd <<< "$(date -d "$start_date +$i day" +"%F %a")"
        p=${p_work[$wd]:-${p_work[default]}}
        [ $((RANDOM % 10)) -lt $p ] && work "$date"
        show_progress $i $days $file_count $update_count
    done
    echo
}

main "$@"