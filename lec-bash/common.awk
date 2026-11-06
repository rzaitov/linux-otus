BEGIN {
 	 split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", names, " ")
 	 for (i = 1; i <= 12; i++) months[names[i]] = i
}

function after(rec, timestamp) {
	# \[ ... \] - match literals
	# [^]] - match anything but ]
	# if a match is found, RSART and RLENGTH are set
	return match(rec, /\[[^]]+\]/) && \
				 nginx_timestamp(substr(rec, RSTART+1, RLENGTH-2)) > timestamp
}


# [14/Aug/2019:04:12:10 +0300]
#  1  2   3    4  5  6  7
function nginx_timestamp(str_timestamp) {
	split(str_timestamp, _parts, /[\/: ]/)

	# mktime("YYYY MM DD HH MM SS [DST]")
	_date_spec = sprintf("%04d %02d %02d %02d %02d %02d",
			_parts[3], months[_parts[2]], _parts[1],
			_parts[4], _parts[5], _parts[6])

	_sign = substr(_parts[7], 1, 1) == "-" ? -1 : 1
	_offset = 3600 * substr(_parts[7], 2, 2) + 60 * substr(_parts[7], 4, 2)


  # 14/Aug/2019:04:12:10 +0300 - local time, UTC+3
  # 14/Aug/2019:01:12:10 +0000 - UTC
  return mktime(_date_spec) - _sign * _offset
}
