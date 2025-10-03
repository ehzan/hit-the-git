#!/usr/bin/env bash
set -euo pipefail


readonly MAX_ATTEMPTS=3

declare -i index=0
declare -a files=()

declare dir file_type since until username email


help() {
    cat << EOF
usage: bash ${BASH_SOURCE[0]} --dir=<path> [--file-type=<type>] [--since=<date>] [--until=<date>]
            --user=<username> --email=<email>
            [-h | --help]
options:
    --dir=<path>        directory containing files to process
    --file-type=<type>  file extension to filter (e.g. txt)
    --since=<date>      start date (YYYY-MM-DD)
    --until=<date>      end date (YYYY-MM-DD)
    --user=<username>   username of the committer
    --email=<email>     email of the committer
    -h, --help          show this help message

example: bash ${BASH_SOURCE[0]} --dir="./my files" --file-type=txt --until=2025-12-31 --user=John --email=john@gmail.com
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

pars_args() {
    echo
    local arg
    for arg in "$@"; do
        case $arg in
            -h | --help )   help; exit 0 ;;
            --dir=* )       dir=${arg#*=} ;;
            --file-type=* ) file_type=${arg#*=} ;;
            --since=* )     since=${arg#*=} ;; 
            --until=* )     until=${arg#*=} ;; 
            --user=* )      username=${arg#*=} ;; 
            --email=* )     email=${arg#*=} ;; 
            * ) echo "❌ unknown option '$arg'" >&2; help; exit 1 ;;
        esac
    done

    validate_input  dir "enter directory path" "[[ -d \$dir ]]"
    validate_input  file_type "enter file type" "[[ \$file_type =~ ^[A-Za-z0-9]*$ ]]"
    validate_input  since "enter start date (YYYY-MM-DD)" \
                    "[[ -z \$since ]] || [[ \$since =~ ^[0-9]+(-[0-9]+){2} ]] && date -d \"\$since\" &>/dev/null"
    validate_input  until "enter end date (YYYY-MM-DD)" \
                    "[[ -z \$until ]] || [[ \$until =~ ^[0-9]+(-[0-9]+){2} ]] && date -d \"\$until\" &>/dev/null"
    validate_input  username "enter username" "[[ \$username =~ ^[A-Za-z0-9_]+$ ]]"
    validate_input  email "enter user's email" \
                    "[[ \$email =~ ^[A-Za-z0-9._-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]"

    [[ -z $file_type ]] || file_type=.$file_type
    [[ -z $since ]] || since=$(date -d "$since 00:00:00" +"%F %T")
    [[ -z $until ]] || until=$(date -d "$until 23:59:59" +"%F %T")

    echo "--- configuration ---"
    echo "files:     $dir/*$file_type"
    echo "time span: [${since:-big bang} - ${until:-eternity}]"
    echo "user: $username <$email>"
    echo "---------------------"
}


add_file_entry() {
    local filepath=$1
    local created_date modified_date

    created_date=$(stat "$filepath" -c '%w' | cut -d' ' -f1,2)
    modified_date=$(stat "$filepath" -c '%y' | cut -d' ' -f1,2)

    if [[ -z $since || ! "$since" > "$created_date" ]] \
        && [[ -z $until || ! "$created_date" > "$until" ]]; then
        files[index]="$filepath|$created_date|create"
        ((++index))
    fi
    if [[ ${created_date%%:*} < ${modified_date%%:*} ]] \
        && [[ -z $since || ! "$since" > "$modified_date" ]] \
        && [[ -z $until || ! "$modified_date" > "$until" ]]; then
        files[index]="$filepath|$modified_date|update"
        ((++index))
    fi
}


declare -i commits=0 creates=0 updates=0

commit_on_date () {
    local filepath=$1 message=$2 datetime=$3

    git add "$filepath"
    # GIT_COMMITTER_DATE="$datetime" && git commit --date="$datetime" -m "$message"
    if faketime "$datetime" git -c user.name="$username" -c user.email="$email" commit -qm "$message"; then
        # printf "=%.s" {1..50}; echo
        ((++commits))
        ((++"${message% *}s"))
    else
        exit 1
    fi
}


commit_all() {
    local -n list=$1
    local line filename filepath datetime action message

    for line in "${list[@]}"; do
        IFS='|' read -r filepath datetime action <<< "$line"
        filename=${filepath##*/}
        message="$action $filename"
        [[ $action == update ]] && { echo >> "$filepath"; touch -d "$datetime" "$filepath"; }
        commit_on_date "$filepath" "$message" "$datetime"
    done
}


main () {
    pars_args "$@"

    for file in "$dir"/*"$file_type"; do
        add_file_entry "$file"
    done

    mapfile -t < <(printf "%s\n" "${files[@]}" | sort -t'|' -k2)
    commit_all MAPFILE

    echo "$commits commits ($creates creates + $updates updates)"
}

[[ "$0" == "${BASH_SOURCE[0]}" ]] && main "$@"