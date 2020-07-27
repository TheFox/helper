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
	#local file_number="$2"

	if [[ "$url_basename" = media.ts ]] ; then
		url_basename=$(printf "media_%06d.ts" $file_number)
	fi

	if [[ ! -f "$url_basename" ]]; then
		echo -e "${GREEN} -> download ts file #${file_number}: '$url'${NO_COLOR}"
		wget -O "$tmp_file" "$url"
		mv "$tmp_file" "$url_basename"
	else
		echo -e "${YELLOW} -> WARNING: file already exists: '${url_basename}'${NO_COLOR}"
	fi
}

function download_playlist() {
	local tmp_dir="$1"
	local url="$2"
	local url_dirname=$(dirname "$url")
	
	echo -e "${GREEN}download playlist: '$url'${NO_COLOR}"
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
		echo "${RED}ERROR: download failed: '$url'${NO_COLOR}"
		exit 1
	fi
	
	local m3u_file1=$(mktemp "$tmp_dir/m3u1.XXXXXXXXXXXXX")
	grep .m3u8 "$pl_file2" > "$m3u_file1"
	while read -r line ; do
		echo " -> m3u line: $line"
		#download_playlist "$tmp_dir" "${url_dirname}/${line}"
		sleep 0.3
	done < "$m3u_file1"
	
	local ts_file1=$(mktemp "$tmp_dir/ts1.XXXXXXXXXXXXX")
	grep .ts "$pl_file2" > "$ts_file1"
	
	if [[ $(uniq -c "$ts_file1" | awk '{ print $1 }') -gt 1 ]] ; then
		echo "-> GREP"
		#local br_file1=$(mktemp "$tmp_dir/br1.XXXXXXXXXXXXX")
		local br_file1=br1.tmp
		grep -A 1 EXT-X-BYTERANGE "$pl_file1" > "$br_file1"
		echo "-> byte-range feil: ${br_file1}"
		split -l 300 "$br_file1" br1.part1_xxxx
		for split_file in ./br1.part1_* ; do
			echo "-> split file: ${split_file}"
			split -l 3 "$split_file" ${split_file}.part2_xxxxxx
			rm "${split_file}"
		done

		for split_file in ./br1*part2_* ; do
			#echo "-> split file B: ${split_file}"
			br_infos=$(grep EXT-X-BYTERANGE "${split_file}" | sed 's/#EXT-X-BYTERANGE://; s/@/ /')
			br_len=$(printf %d $br_infos)
			br_pos=$(echo $br_infos | awk '{ print $2 }')
			echo "-> byte-range len: '${br_len}'"
			echo "-> byte-range pos: '${br_pos}'"
			rm "${split_file}"
		done
	else
		first_ts_file=$(head -1 "$ts_file1")
		last_ts_file=$(tail -1 "$ts_file1")
		line_number=0
		while read -r line ; do
			echo " -> ts line #${line_number}: $line/$last_ts_file"
			#download_ts_file "${url_dirname}/${line}" $line_number
			#sleep 0.3
			let "line_number += 1"
		done < "$ts_file1"
		
		if [[ $(wc -l "$ts_file1" | awk '{ print $1 }') -gt 1 ]]; then
			echo -e "${YELLOW} -> first ts file: $first_ts_file${NO_COLOR}"
			echo -e "${YELLOW} -> last  ts file: $last_ts_file${NO_COLOR}"
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
echo "tmp dir: $tmp_dir"

download_playlist "$tmp_dir" "$url"
#youtube-dl "$url"

echo 'clean up'
rm -rf "$tmp_dir"
