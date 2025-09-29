#!/usr/bin/env bash

readonly SCRIPT_DIR=$(dirname "$0")
readonly LOG_FILE="$SCRIPT_DIR/$(basename "$0" .sh).log"
readonly MAX_ATTEMPTS=3

declare -i index=0
declare -a files=()

declare sudo_pwd
declare dir type since until


help() {
    cat << EOF
usage: source $0 --dir=<path> [--file-type=<type>]
        [--since=<date>] [--until=<date>] [-h | --help]
example: source $0 --dir="./my files" --file-type=txt --since=2025-01-01 --until=2025-12-31
EOF
}


check_parameters() {
    for param in "$@"; do
        case $param in
            -h | --help )   help; exit 0 ;;
            "--dir="* )     dir=${param#*=} ;;
            "--file-type="* | "--filetype="* )  type=${param#*=} ;;
            "--since="* )   since=${param#*=} ;; 
            "--until="* )   until=${param#*=} ;; 
            * ) echo unknown option: ‘"$param"’; help; exit 1 ;;
        esac
    done

    local -i attempts=0
    while [[ ! -d "$dir" ]]; do
        [[ -z "$dir" ]] || echo dir: no such directory ‘"$dir"’
        (( attempts < MAX_ATTEMPTS )) || { echo 3 incorrect attempts; exit 1; }
        read -rp "enter directory path: " dir
        ((attempts++))
    done

    attempts=0
    while [[ ! $type =~ ^[A-Za-z0-9]*$ ]]; do
        echo file-type: invalid file-type ‘"$type"’
        (( attempts < MAX_ATTEMPTS )) || { echo 3 incorrect attempts; exit 1; }
        read -rp "enter file type: " type
        ((attempts++))
    done
    [[ -z "$type" ]] || type=.$type

    attempts=0
    while ! ( [[ -z "$since" ]] || [[ $since =~ ^[0-9]+-[0-9]+-[0-9]+$ ]] && date -d "$since" >> "$LOG_FILE" 2>&1); do
        echo since: invalid date ‘"$since"’
        (( attempts < MAX_ATTEMPTS )) || { echo 3 incorrect attempts; exit 1; }
        read -rp "enter start date: " since
        ((attempts++))
    done
    [[ -z "$since" ]] || since=$(date -d "$since 00:00:00" +"%F %T")

    attempts=0
    while ! ( [[ -z "$until" ]] || [[ $until =~ ^[0-9]+-[0-9]+-[0-9]+$ ]] && date -d "$until" >> "$LOG_FILE" 2>&1); do
        echo until: invalid date ‘"$until"’
        (( attempts < MAX_ATTEMPTS )) || { echo 3 incorrect attempts; exit 1; }
        read -rp "enter end date: " until
        ((attempts++))
    done
    [[ -z "$until" ]] || until=$(date -d "$until 23:59:59" +"%F %T")

    read -rsp "[sudo] password for $(whoami): " sudo_pwd; echo
    attempts=1
    while ! echo "$sudo_pwd" | sudo -S true >> "$LOG_FILE" 2>&1; do
        echo incorrect password
        (( attempts < MAX_ATTEMPTS )) || { echo 3 incorrect attempts; exit 1; }
        read -rsp "[sudo] password for $(whoami): " sudo_pwd; echo
        ((attempts++))
    done

    echo "files: $dir/*$type, created/modified: [$since - $until]"
}


add_file_entry() {
    local filepath=$1
    local created_date modified_date

    created_date=$(stat "$filepath" -c '%w' | cut -d' ' -f1,2)
    modified_date=$(stat "$filepath" -c '%y' | cut -d' ' -f1,2)
    
    if [[ (-z "$since" || ! "$since" > "$created_date") \
        && (-z "$until" || ! "$created_date" > "$until") ]]; then
        files[index]="$filepath|$created_date|create"
        ((index++))
    fi
    if [[ (-z "$since" || ! "$since" > "$modified_date") \
        && (-z "$until" || ! "$modified_date" > "$until") \
        && (${created_date%%:*} < ${modified_date%%:*}) ]]; then
        files[index]="$filepath|$modified_date|update"
        ((index++))
    fi
}


declare -i commits=0 creates=0 updates=0

commit_on_date () {
    local filepath=$1
    local message=$2
    local datetime=$3

    git add "$filepath"
    # GIT_COMMITTER_DATE="$datetime" && git commit --date="$datetime" -m "$message"
    echo "$sudo_pwd" | sudo -S date -s "$datetime" >> "$LOG_FILE" 2>&1
    git commit -m "$message" # >> "$LOG_FILE"
    printf "=%.s" {1..50}; echo
    ((commits++))
    [[ ${message% *} == create ]] && ((creates++)) || ((updates++))
}


commit_all() {
    local -n list=$1
    local filename filepath datetime action

    for line in "${list[@]}"; do
        IFS='|' read -r filepath datetime action <<< "$line"
        filename=${filepath##*/}
        message="$action $filename"
        [[ $action == update ]] && { echo >> "$filepath"; touch -d "$datetime" "$filepath"; }
        echo "$filepath" "$message" "$datetime"
        commit_on_date "$filepath" "$message" "$datetime"
    done
}


cleanup() {
    local current_datetime=$(curl -sI google.com | grep -i '^date:' | cut -d' ' -f2-)
    echo "$sudo_pwd" | sudo -S date -s "$current_datetime" >> "$LOG_FILE" 2>&1
}
trap cleanup EXIT


main () {
    printf "==========\nlogs on %s:\n" "$(date)" >> "$LOG_FILE"
    check_parameters "$@"

    for file in "$dir"/*"$type"; do
        add_file_entry "$file"
    done

    local -a sorted=()
    IFS=$'\n' sorted=($(printf "%s\n" "${files[@]}" | sort -t'|' -k2))
    unset IFS
    # printf "%s\n" "${sorted[@]}"

    commit_all sorted
    echo "$commits commits ($creates creates + $updates updates)"
}

main "$@"