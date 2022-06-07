#!/usr/bin/env bash
###
### ts_files_to_mp4.sh - Convert .ts files to one .mp4 file using ffmpeg.
###
### Usage:
###   ts_files_to_mp4.sh <format> <seq_start> <seq_end> <output_file>
###
### Options:
###   <format>            File format: media_%d.ts
###   <seq_start>         Sequence Begin
###   <seq_end>           Sequence End
###   <output_file>       Output File: media.mp4
###   -h                  Show this message.

NO_COLOR='\033[0m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'

which ffmpeg &> /dev/null || { echo 'ERROR: ffmpeg not found in PATH'; exit 1; }
which mktemp &> /dev/null || { echo 'ERROR: mktemp not found in PATH'; exit 1; }

ffmpeg --help 2> /dev/null || { echo 'ERROR: ffmpeg does not work'; exit 1; }

help() {
    head -50 "$0" | grep '^###' | sed 's/^###//; s/^ //'
}

if [[ $# -lt 4 ]] || [[ "$1" == -h ]]; then
    help
    exit 1
fi

file_format="$1"
seq_start="$2"
seq_end="$3"
output_file="$4"

echo "-> work dir: '${PWD}'"

tmp_dir=$(mktemp -d)
echo "-> tmp dir: '${tmp_dir}'"

input_file="${tmp_dir}/input.ts"
echo "->  input file: '${input_file}'"
echo "-> output file: '${output_file}'"

# Reset input file.
if [[ -f "${input_file}" ]] ; then
	rm "${input_file}"
fi

# Concat files.
echo -e "${GREEN}-> concat files: ${seq_start} to ${seq_end}${NO_COLOR}"
for n in $(seq ${seq_start} ${seq_end}) ; do
	file=$(printf "$file_format" $n)
	if [[ -f "${file}" ]] ; then
		#echo "input file: ${file}"
		cat "${file}" >> "${input_file}"
	else
		echo -e "${RED}ERROR: file missing: '${file}'${NO_COLOR}"
		exit 1
	fi
done

# Convert ts to .mp4
echo -e "${GREEN}-> convert ts to mp4 (x264)${NO_COLOR}"
ffmpeg -hide_banner -loglevel quiet -i "${input_file}" -c:v libx264 "${output_file}"

echo '-> clean up'
rm -rf "${tmp_dir}"

echo '-> done'
