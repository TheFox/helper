#!/usr/bin/env bash
###
### playlist_download.sh - Download .m3u8 playlists.
###
### Usage:
###   playlist_download.sh <url>
###
### Options:
###   <url>               URL to main playlist.
###   -h                  Show this message.

NO_COLOR='\033[0m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'

function download_ts_file() {
	local url="$1"
	local url_basename=$(basename "$url")
	local tmp_file="${url_basename}.tmp"
	local file_number="$2"
	local br_start="$3"
	local br_end="$4"

	local br_debug=""
	if [[ "$br_start" != "" ]]; then
		br_debug=" br=${br_start}-${br_end}"
	fi

	if ! echo "$url_basename" | grep -q \\d ; then
		echo "-> no number found in basename"
		url_basename=$(printf "media_%06d.ts" $file_number)
		echo "-> new basename: $url_basename"
		tmp_file="${url_basename}.tmp"
	fi

	if [[ ! -f "$url_basename" ]]; then
		echo -e "${GREEN}-> download ts file #${file_number}${br_debug}: '$url'${NO_COLOR}"
		
		if [[ "$br_start" != "" ]]; then
			wget -4 -c --header="Range: bytes=${br_start}-${br_end}" -O "$tmp_file" "$url"
		else
			wget -4 -O "$tmp_file" "$url"
		fi
		mv "$tmp_file" "$url_basename"
	else
		echo -e "${YELLOW}-> WARNING: file already exists: '${url_basename}'${NO_COLOR}"
	fi
}

function download_playlist() {
	local tmp_dir="$1"
	local url="$2"
	local url_dirname=$(dirname "$url")
	
	echo -e "-> ${GREEN}download playlist: '$url'${NO_COLOR}"
	# sleep 1
	
	local pl_file1=$(mktemp "$tmp_dir/pl1.XXXXXXXXXXXXX")
	
	#cp "$url" "$pl_file1"
	wget -O "$pl_file1" "$url"
	
	# echo "pl_file1: $pl_file1"
	# echo '----- pl1 -----'
	# head -10 "$pl_file1"
	# echo '---------------'
	# sleep 1
	
	local pl_file2=$(mktemp "$tmp_dir/pl2.XXXXXXXXXXXXX")
	if [[ -f "$pl_file1" ]]; then
		grep -v '^#' "$pl_file1" > "$pl_file2"
	else
		echo "${RED}-> ERROR: download failed: '$url'${NO_COLOR}"
		exit 1
	fi
	# echo '---- pl file1 ----'
	# cat "$pl_file1"
	# echo '---- -------- ----'
	
	local m3u_file1=$(mktemp "$tmp_dir/m3u1.XXXXXXXXXXXXX")
	grep .m3u8 "$pl_file2" > "$m3u_file1"
	while read -r line ; do
		echo "-> m3u line: $line"
		download_playlist "$tmp_dir" "${url_dirname}/${line}"
		sleep 0.3
	done < "$m3u_file1"
	
	local ts_file1=$(mktemp "$tmp_dir/ts1.XXXXXXXXXXXXX")
	grep .ts "$pl_file2" > "$ts_file1"

	# echo '---- ts file1 ----'
	# cat "$ts_file1"
	# echo '---- -------- ----'
	
	if [[ $(uniq -c "$ts_file1" | awk '{ print $1 }') -gt 1 ]] ; then
		echo "-> byte-range download"

		#local br_file1=$(mktemp "$tmp_dir/br1.XXXXXXXXXXXXX")
		local br_file1="$tmp_dir/br1"
		grep -A 1 EXT-X-BYTERANGE "$pl_file1" > "$br_file1"
		echo "-> byte-range file: ${br_file1}"

		split -l 300 "$br_file1" "$tmp_dir/br2_xxxx"
		for split_file in $tmp_dir/br2_* ; do
			echo "-> split file: ${split_file}"
			split -l 3 "$split_file" ${split_file}.br3_xxxxxx

			#rm "${split_file}"
			sleep 0.1
		done

		declare -i line_number=0
		for split_file in $tmp_dir/br2_*br3_* ; do
			echo "-> split file: ${split_file}"

			br_infos=$(grep EXT-X-BYTERANGE "${split_file}" | sed 's/#EXT-X-BYTERANGE://; s/@/ /')
			br_len=$(echo $br_infos | awk '{ print $1 }')
			br_pos=$(echo $br_infos | awk '{ print $2 }')
			br_end=$((br_pos + br_len))
			echo "-> byte-range len: '${br_len}'"
			echo "-> byte-range pos: '${br_pos}'"
			echo "-> byte-range end: '${br_end}'"

			file_name=$(grep .ts "${split_file}")
			echo "-> ts line #${line_number}: $file_name"
			
			download_ts_file "${url_dirname}/${file_name}" $line_number $br_pos $br_end
			echo "-> file: '${file_name}'"
			
			#rm "${split_file}"
			line_number=$((line_number + 1))
			sleep 0.1
		done
	else
		first_ts_file=$(head -1 "$ts_file1")
		last_ts_file=$(tail -1 "$ts_file1")
		declare -i line_number=0
		while read -r line ; do
			echo "-> ts line #${line_number}: $line/$last_ts_file"
			download_ts_file "${url_dirname}/${line}" $line_number
			#sleep 0.3
			line_number=$((line_number + 1))
		done < "$ts_file1"
		
		if [[ $(wc -l "$ts_file1" | awk '{ print $1 }') -gt 1 ]]; then
			echo -e "${YELLOW}-> first ts file: $first_ts_file${NO_COLOR}"
			echo -e "${YELLOW}-> last  ts file: $last_ts_file${NO_COLOR}"
		fi
	fi
}

which grep &> /dev/null || { echo 'ERROR: grep not found in PATH'; exit 1; }
which awk &> /dev/null || { echo 'ERROR: awk not found in PATH'; exit 1; }
which wget &> /dev/null || { echo 'ERROR: wget not found in PATH'; exit 1; }
which mktemp &> /dev/null || { echo 'ERROR: mktemp not found in PATH'; exit 1; }
which head &> /dev/null || { echo 'ERROR: head not found in PATH'; exit 1; }
which rm &> /dev/null || { echo 'ERROR: rm not found in PATH'; exit 1; }

help() {
    head -50 "$0" | grep '^###' | sed 's/^###//; s/^ //'
}

if [[ $# -lt 1 ]] || [[ "$1" == -h ]]; then
    help
    exit 1
fi

url="$1"

tmp_dir=$(mktemp -d -t 'playlist_downloader')
echo "-> tmp dir: $tmp_dir"

download_playlist "$tmp_dir" "$url"

echo '-> clean up'
rm -rf "$tmp_dir"

echo '-> done'
