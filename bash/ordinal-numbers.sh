#!/usr/bin/env bash
set -euo pipefail


# Input: unsorted 100 ordinal numbers as a comma-separated string
declare unsorted_ord_nums="1st: First, 21st: Twenty-First, 41st: Forty-First, 61th: Sixty-First, 81st: Eighty-First, 2nd: Second, 22nd: Twenty-Second, 42nd: Forty-Second, 62nd: Sixty-Second, 82nd: Eighty-Second, 3rd: Third, 23rd: Twenty-Third, 43rd: Forty-Third, 63rd: Sixty-Third, 83rd: Eighty-Third, 4th: Fourth, 24th: Twenty-Fourth, 44th: Forty-Fourth, 64th: Sixty-Fourth, 84th: Eighty-Fourth, 5th: Fifth, 25th: Twenty-Fifth, 45th: Forty-Fifth, 65th: Sixty-Fifth, 85th: Eighty-Fifth, 6th: Sixth, 26th: Twenty-Sixth, 46th: Forty-Sixth, 66th: Sixty-Sixth, 86th: Eighty-Sixth, 7th: Seventh, 27th: Twenty-Seventh, 47th: Forty-Seventh, 67th: Sixty-Seventh, 87th: Eighty-Seventh, 8th: Eighth, 28th: Twenty-Eighth, 48th: Forty-Eighth, 68th: Sixty-Eighth, 88th: Eighty-Eighth, 9th: Ninth, 29th: Twenty-Ninth, 49th: Forty-Ninth, 69th: Sixty-Ninth, 89th: Eighty-Ninth, 10th: Tenth, 30th: Thirtieth, 50th: Fiftieth, 70th: Seventieth, 90th: Ninetieth, 11th: Eleventh, 31st: Thirty-First, 51st: Fifty-First, 71st: Seventy-First, 91st: Ninety-First, 12th: Twelfth, 32nd: Thirty-Second, 52nd: Fifty-Second, 72nd: Seventy-Second, 92nd: Ninety-Second, 13th: Thirteenth, 33rd: Thirty-Third, 53rd: Fifty-Third, 73rd: Seventy-Third, 93rd: Ninety-Third, 14th: Fourteenth, 34th: Thirty-Fourth, 54th: Fifty-Fourth, 74th: Seventy-Fourth, 94th: Ninety-Fourth, 15th: Fifteenth, 35th: Thirty-Fifth, 55th: Fifty-Fifth, 75th: Seventy-Fifth, 95th: Ninety-Fifth, 16th: Sixteenth, 36th: Thirty-Sixth, 56th: Fifty-Sixth, 76th: Seventy-Sixth, 96th: Ninety-Sixth, 17th: Seventeenth, 37th: Thirty-Seventh, 57th: Fifty-Seventh, 77th: Seventy-Seventh, 97th: Ninety-Seventh, 18th: Eighteenth, 38th: Thirty-Eighth, 58th: Fifty-Eighth, 78th: Seventy-Eighth, 98th: Ninety-Eighth, 19th: Nineteenth, 39th: Thirty-Ninth, 59th: Fifty-Ninth, 79th: Seventy-Ninth, 99th: Ninety-Ninth, 20th: Twentieth, 40th: Fortieth, 60th: Sixtieth, 80th: Eightieth, 100th: Hundredth"

readonly SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
readonly DEFAULT_OUTPUT_FILE=ordinal-numbers.txt

declare -a ordinals_short=(0th)
declare -a ordinals_long=(zeroth)


parse_ordinal_numbers() {
    local input=$1
    
    IFS=',' read -ra entries <<< "$input"
    for entry in "${entries[@]}"; do
        short=${entry%%:*}
        long=${entry#*: }; long=${long,,}
        num=${short//[^0-9]/}

        ordinals_short[num]=$short
        ordinals_long[num]=$long
    done

    (( ${#ordinals_short[@]} == ${#ordinals_long[@]} )) || { echo Error!; exit 1; }
}

main () {
    local output_file=${1:-"$SCRIPT_DIR/$DEFAULT_OUTPUT_FILE"}

    parse_ordinal_numbers "$unsorted_ord_nums"

    echo "${ordinals_short[@]}" > "$output_file"
    echo "${ordinals_long[@]}" >> "$output_file"
    echo "updated $output_file"
}

[[ "$0" == "${BASH_SOURCE[0]}" ]] && main "$@"
