#!/bin/bash

set -euo pipefail

# https://man7.org/linux/man-pages/man1/flock.1.html
lock="/run/lock/$(basename "$0").lock"
if [[ ${FLOCKER:-} != "$lock" ]]; then
	FLOCKER="$lock" exec flock --exclusive --nonblock --conflict-exit-code 99 "$lock" "$0" "$@"
fi

src_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
prog=${BASH_SOURCE[0]##*/}
timestamp_file="${src_dir}/.${prog}.timestamp"
top=10
since=0

function main() {
	local log_file=$1

	printf "Top %d IPs:\n" "$top"
	get_ips "$since" < "$log_file" | stats | head -n "$top"
	printf "\n"

	printf "Top %d URLs:\n" "$top"
	get_urls "$since" < "$log_file" | stats | head -n "$top"
	printf "\n"

	printf "Errors stats:\n"
	get_errors "$since" < "$log_file" | stats
	printf "\n"

	printf "HTTP codes:\n"
	get_codes "$since" < "$log_file" | stats

	date --iso-8601=seconds > "$timestamp_file"
}

function get_ips() {
	# shellcheck disable=SC2016
	TZ=UTC awk \
		-f "$src_dir/common.awk" \
		-v timestamp="$1" \
		-f <(echo '
			after($0, timestamp) {
				print $1
			}
		')
}

function get_urls() {
	# shellcheck disable=SC2016
	TZ=UTC awk -F'"' \
		-f "$src_dir/common.awk" \
		-v timestamp="$1" \
		-f <(echo '
			after($0, timestamp) {
				n = split($2, req_info, " ")
				if (n == 0) { print "<empty>"; next }
				if (n != 3) { print "<invalid>"; next }

				url = req_info[2]
				split(url, url_parts, /[?]/)
				print url_parts[1]
			}
		')
}

function get_errors() {
	# shellcheck disable=SC2016
	TZ=UTC awk -F'"' \
		-f "$src_dir/common.awk" \
		-v timestamp="$1" \
		-f <(echo '
			after($0, timestamp) {
				split($3, resp_info, " ")
				code = resp_info[1]
				if (code >= 400 && code < 500) { print "4xx" }
				if (code >= 500 && code < 600) { print "5xx" }
			}
		')
}

function get_codes() {
	# shellcheck disable=SC2016
	TZ=UTC awk -F'"' \
		-f "$src_dir/common.awk" \
		-v timestamp="$1" \
		-f <(echo '
			after($0, timestamp) {
				split($3, resp_info, " ")
				code = resp_info[1]
				print code
			}
		')
}

function stats() {
	sort |
		uniq --count |
		sort --key 1 --numeric-sort --reverse
}

parsed=$(getopt \
	--options "" \
	--longoptions "timestamp-file:,top:" \
	--name "$0" \
	-- "$@")
eval set -- "$parsed"
unset parsed

while true; do
	case $1 in
		--timestamp-file)
			timestamp_file=$2
			shift 2
			;;
		--top)
			top=$2
			shift 2
			;;
		--)
			shift
			break
			;;
		*)
			printf "Internal error: unhandled option %s\n" "$1" >&2
			exit 2
			;;
	esac
done

if [[ -f $timestamp_file ]]; then
	# don't use `read -r var` due to `set -e`
	timestamp=$(<"$timestamp_file")
	# date --date=' ' produces the begining of the current day
	if [[ $timestamp != *[^[:space:]]* ]] || ! since=$(date --date="$timestamp" +%s); then
		printf "Invalid date in timestamp file: %s\n" "$timestamp_file" >&2
		exit 1
	fi
fi

main "$@"
