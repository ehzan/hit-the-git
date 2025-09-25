#!/usr/bin/env bash
# set -euo pipefail
# set -x pipefail


help() {
    cat << EOF
usage: source $0 --dir=<path>  --start_date=<date> --days=<number>
        --base-time=<time> [--interval=<minutes> (default: 60)] [-h | --help]
example: source $0 --dir="./my files" --start-date=2025-01-01 --days=100 --base-time=12:00 --interval=120
EOF
}


declare ordinal_numbers_file=ordinal-numbers.txt
declare -a ordinals_short=()
declare -a ordinals_long=()
declare -i file_count=0
declare -i update_count=0
declare -i initial_file_count=10
declare -A p_work=( [Fri]=1 [Thu]=3 [other]=5 )

declare sudo_pwd
declare dir start_date base_time
declare -i days interval

check_parameters() {
    for param in "$@"; do
        case $param in
            -h | --help )       help; exit 0 ;;
            "--dir="* )         dir=${param#*=} ;;
            "--start-date="* )  start_date=${param#*=} ;;
            "--days="* )        days=${param#*=} ;;
            "--base-time="* )   base_time=${param#*=} ;;
            "--interval="* )    interval=${param#*=} ;;
            * ) echo unknown option: ‘"$param"’; help; exit 1 ;;
        esac
    done

    local -i attempts=0
    while ! mkdir -p "$dir" >> "$0.log" 2>&1; do
        [[ -z "$dir" ]] || echo dir: cannot find or create directory ‘"$dir"’
        (( attempts < 3 )) || { echo 3 incorrect attempts; exit; }
        read -rp "enter directory path: " dir
        ((attempts++))
    done

    attempts=0
    while ! ( [[ $start_date =~ ^[0-9]+-[0-9]+-[0-9]+$ ]] && date -d "$start_date" >> "$0.log" 2>&1); do
        [[ -z "$start_date" ]] || echo start-date: invalid date ‘"$start_date"’
        (( attempts < 3 )) || { echo 3 incorrect attempts; exit 1; }
        read -rp "enter start date: " start_date
        ((attempts++))
    done
    start_date=$(date -d "$start_date" +"%F")

    attempts=0
    while ! [[ $days =~ ^[0-9]+$ && $days -gt 0 ]]; do
        [[ -z "$days" ]] || echo days: invalid value ‘"$days"’
        (( attempts < 3 )) || { echo 3 incorrect attempts; exit 1; }
        read -rp "enter number of days: " days
        ((attempts++))
    done
    days=$((10#$days))

    attempts=0
    while ! ( [[ $base_time =~ ^[0-9]{1,2}(:[0-9]+){0,2}$ ]] && date -d "$base_time" >> "$0.log" 2>&1); do
        [[ -z "$base_time" ]] || echo base-time: invalid time ‘"$base_time"’
        (( attempts < 3 )) || { echo 3 incorrect attempts; exit 1; }
        read -rp "enter base time: " base_time
        ((attempts++))
    done
    base_time=$(date -d "$base_time" +"%T")

    attempts=0
    while [[ ! $interval =~ ^[0-9]*$ ]]; do
        echo interval: invalid value ‘"$interval"’
        (( attempts < 3 )) || { echo 3 incorrect attempts; exit 1; }
        read -rp "enter interval (minutes): " interval
        ((attempts++))
    done
    [[ -z "$interval" ]] && interval=60 || interval=$((10#$interval))

    read -rsp "[sudo] password for $(whoami): " sudo_pwd; echo
    attempts=1
    while ! echo "$sudo_pwd" | sudo -S true >> "$0.log" 2>&1; do
        echo incorrect password
        (( attempts < 3 )) || { echo 3 incorrect attempts; exit 1; }
        read -rsp "[sudo] password for $(whoami): " sudo_pwd; echo
        ((attempts++))
    done

    echo "dir: $dir", "start-date: $start_date", "days: $days", "time: $base_time +[0,$interval] minutes"
}


load_ordinals() {
    local ordinals_file=$1
    local -a lines=()  
    mapfile -t lines < "$ordinals_file"
    IFS=' ' read -ra ordinals_short <<< "${lines[0]}"
    IFS=' ' read -ra ordinals_long <<< "${lines[1]}"
}


create_file() {
    local filename=$1
    local datetime=$2

    filepath="$dir/$filename"
    rm -f "$filepath"   # : > "$filepath"
    echo "$sudo_pwd" | sudo -S date -s "$datetime" >> "$0.log" 2>&1
    for l in $(seq 1 5); do
        echo "This is the ${ordinals_short[$l]} line." >> "$filepath"
    done
    ((file_count++))
    # echo $filepath created on $datetime.
}


update_file() {
    local filename=$1
    local datetime=$2

    filepath="$dir/$filename"
    nl=$(( 1 + $(wc -l < "$filepath") ))
    echo Update: "This is the ${ordinals_short[nl]} line." >> "$filepath"
    touch -d "$datetime" "$filepath";
    ((update_count++))
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


main () {
    printf "==========\nlogs on %s:\n" "$(date)" >> "$0.log"
    check_parameters "$@"

    load_ordinals "$ordinal_numbers_file"
    create_primary_files $initial_file_count

    local -i p
    for i in $(seq 1 $days); do
        read -r date wd <<< "$(date -d "$start_date +$i day" +"%F %a")"
        p=${p_work[$wd]:-${p_work[other]}}  # echo $i: $date, $wd, $p;
        [[ $((RANDOM % 10)) -lt $p ]] && work "$date"
    done
    echo $file_count new files + $update_count updates
    # ls -ltr "$dir"
}

main "$@"