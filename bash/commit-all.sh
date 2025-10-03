#!/usr/bin/env bash
set -euo pipefail


readonly MAX_ATTEMPTS=3

declare -i index=0
declare -a files=()

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
    while ! [[ -v dir && -d "$dir" ]]; do
        [ -v dir ] && echo dir: no such directory ‘"$dir"’
        (( attempts++ < MAX_ATTEMPTS )) || { echo $MAX_ATTEMPTS incorrect attempts; exit 1; }
        read -rp "enter directory path: " dir
    done

    attempts=0
    [ -v type ] || type=""
    while ! [[ $type =~ ^[A-Za-z0-9]*$ ]]; do
        echo file-type: invalid file-type ‘"$type"’
        (( attempts++ < MAX_ATTEMPTS )) || { echo $MAX_ATTEMPTS incorrect attempts; exit 1; }
        read -rp "enter file type: " type
    done
    [ -z "$type" ] || type=.$type

    attempts=0
    while [ -v since ]; do
        if ! [[ $since =~ ^[0-9]+-[0-9]+-[0-9]+$ ]]; then
            echo date: invalid date ‘"$since"’
        else
            date -d "$since" +"%F" >/dev/null && break
        fi
        (( attempts++ < MAX_ATTEMPTS )) || { echo $MAX_ATTEMPTS incorrect attempts; exit 1; }
        read -rp "enter start-date: " since
    done
    [ -v since ] && since=$(date -d "$since 00:00:00" +"%F %T")

    attempts=0
    while [ -v until ]; do
        if ! [[ $until =~ ^[0-9]+-[0-9]+-[0-9]+$ ]]; then
            echo date: invalid date ‘"$until"’
        else
             date -d "$until" +"%F" >/dev/null && break
        fi
        (( attempts++ < MAX_ATTEMPTS )) || { echo $MAX_ATTEMPTS incorrect attempts; exit 1; }
        read -rp "enter end-date: " until
    done
    [ -v until ] && until=$(date -d "$until 23:59:59" +"%F %T")

    echo "files: $dir/*$type, time span: [${since:-big bang} - ${until:-eternity}]"
}


add_file_entry() {
    local filepath=$1
    local created_date modified_date

    created_date=$(stat "$filepath" -c '%w' | cut -d' ' -f1,2)
    modified_date=$(stat "$filepath" -c '%y' | cut -d' ' -f1,2)
    if [[ ! (-v since && "$since" > "$created_date") \
        && ! (-v until && "$created_date" > "$until") ]]; then
        files[index]="$filepath|$created_date|create"
        ((++index))
    fi
    if [[ ! (-v since && "$since" > "$modified_date") \
        && ! (-v until && "$modified_date" > "$until") \
        && (${created_date%%:*} < ${modified_date%%:*}) ]]; then
        files[index]="$filepath|$modified_date|update"
        ((++index))
    fi
}


declare -i commits=0 creates=0 updates=0

commit_on_date () {
    local filepath=$1 message=$2 datetime=$3

    git add "$filepath"
    # GIT_COMMITTER_DATE="$datetime" && git commit --date="$datetime" -m "$message"
    if faketime "$datetime" git commit -m "$message"; then
        printf "=%.s" {1..50}; echo
        ((++commits))
        ((++"${message% *}s"))
    else
        exit 1
    fi
}


commit_all() {
    local -n list=$1
    local filename filepath datetime action

    for line in "${list[@]}"; do
        IFS='|' read -r filepath datetime action <<< "$line"
        filename=${filepath##*/}
        message="$action $filename"
        [[ $action == update ]] && { echo >> "$filepath"; touch -d "$datetime" "$filepath"; }
        commit_on_date "$filepath" "$message" "$datetime"
    done
}


main () {
    check_parameters "$@"
    for file in "$dir"/*"$type"; do
        add_file_entry "$file"
    done

    local -a sorted=()
    mapfile -t sorted < <(printf "%s\n" "${files[@]}" | sort -t'|' -k2)

    commit_all sorted
    echo "$commits commits ($creates creates + $updates updates)"
}

main "$@"