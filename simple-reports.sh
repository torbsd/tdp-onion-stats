#!/bin/sh

# produce simple, point-in-time reports based on the JSON onionoo data
# not unlike the Q&D stats of old, just with better/newer data

script="${script:-$(basename $0)}"
www="${www:-$HOME/torbsd.github.io}"
rankitpl=${rankitpl-./rankit.pl}

# set some defaults
bplate=${bplate-bplate}
outdir=${outdir-.}
indir=${indir-.}
details=details.json
rtype=plain
uri_base=/oostats/
noclear=0
overwrite=0
date=
report_date=

# spit out a helpful message, possibly with an error, and then exit
usage () {
	typeset _xit
	_xit=0
	[ -n "$1" ] && {
		echo "$0: $*"
		_xit=1
	}
	echo "usage: ${script} [--options] [args]"
	echo "    --help            this message"
	echo "    --noclear         dont clear old temp files at startup"
	echo "    --overwrite       overwrite existing output files"
	echo "    --outdir=dir      drop output files in dir, default is ${outdir}"
	echo "    --indir=dir       find input files in dir, default is ${indir}"
	echo "    --bplate=dir      find report boilerplate in dir, default is ${bplate}"
	echo "    --rtype=type      report type: plain, linked, default is ${rtype}"
	echo "    --uri-base=base   base for report uris, default is ${uri_base}"
	echo "    --date=date       set report date, default is today"
	exit $_xit
}

# transform --foo into foo
optname () {
	echo "$1" | sed -e 's/^--//' -e 's/=.*$//' -e 's/`/_/g' -e 's/-/_/'
}

# sanitize a value for --foo=val
optval () {
	echo "$1" | sed -e 's/^--.*=//' -e 's/`/_/g'
}

# set an option's corresponding sh variable
setopt () {
	typeset _nm
	_nm=$(optname "$1")
	eval $_nm=1
}

# like setopt but with a --opt=val style argument
setoptval () {
	typeset _nm _vl
	_nm="$(optname $1)"
	_vl="$(optval $1)"
	eval $_nm=$_vl
}

# produce a fatal error message and quit
die () {
	echo "${script}: FATAL: $*" >&2
	exit 1
}

# produce a warning message on stderr
warn () {
	echo "${script}: $*" >&2
}

# plain text reports
#
# report_plain bridges details bw-by-os "...jq query..." rankit_opts
# report_plain relays details bw-by-os "...jq query..." rankit_opts
report_plain () {
	typeset what fn nm q out whatuc
	what=$1
	shift
	fn=$1
	shift
	nm=$1
	shift
	q="$1"
	shift
	rankopts="$*"
	whatuc="$(echo ${what} | tr a-z A-Z)"
	out="${outdir}/${what}-${nm}".txt
	if [ -f ${out} -a ${overwrite} -eq 0 ]; then
		echo ".. ${out} exists - skipping"
	else
		echo ":: generating ${out}"
		[ -f ${bplate}/top.txt ] && cat ${bplate}/top.txt > ${out}
		echo "Report Type: ${whatuc}" >> ${out}
		echo "Report Date: $(date -u)" >> ${out}
		echo "Data Source: https://onionoo.torproject.org/${fn}" \
		     >> ${out}
		[ -f ${bplate}/header_${nm}.txt ] && \
			cat ${bplate}/header_${nm}.txt >> ${out}
		echo "" >> ${out}
		# if we haven't run this jq query yet, do so
		tmp=${what}-${fn}.raw
		if [ ! -f ${indir}/${tmp} ]; then
			echo "::: generating ${tmp} from ${fn}.json"
			jq -c --raw-output "${q}" \
			   < ${indir}/${fn}.json > ${indir}/${tmp}
		fi
		perl ${rankitpl} ${rankopts} < ${indir}/${tmp} >>${out}
		echo "" >> ${out}
		[ -f ${bplate}/footer_${nm}.txt ] && \
			cat ${bplate}/footer_${nm}.txt >> ${out}
		[ -f ${bplate}/bottom.txt ] && \
			cat ${bplate}/bottom.txt >> ${out}
	fi
}

# given foo=bar, return foo
name_of () {
	echo $1 | sed -E -e 's/^(.*)=.*$/\1/'
}

# given foo=bar, return bar
val_of () {
	echo $1 | sed -E -e 's/^.*=(.*)$/\1/'
}

# s/${name}/val/ in $1 using patterns in $2...
# e.g. suss_file filename.html "title=a title" date=$(date +%Y%m%d)
# will change all occurances of ${title} in filename.html to
# "a title" (w/o quotes), etc.
suss_file () {
	typeset args cmd n v filename
	filename=$1
	shift
	args=""
	while [ $# -gt 0 ]; do
		n=$(name_of "$1")
		v=$(val_of "$1")
		shift
		cmd="-e 's/\\\${"$n"}/${v}/'"
		args="${args} ${cmd}"
	done
	[ -n "${args}" ] && {
#		echo "::: sed -E -i ${args} ${filename}"
		eval sed -E -i ${args} ${filename}
	}
}

# like report_plain but generates marginal html reports that link
# together by date, e.g. each report has a link to the previous one
report_linked () {
	typeset what fn nm q out whatuc date prev out_link prev_date title \
		prev_uri out_rel out_name
	what=$1
	shift
	fn=$1
	shift
	nm=$1
	shift
	q="$1"
	shift
	rankopts="$*"
	date=$(date +%Y%m%d)
	mkdir -p ${outdir}/${report_date}
	whatuc="$(echo ${what} | tr a-z A-Z)"
	out_name="${what}-${nm}.html"
	out_link="${outdir}/${out_name}"
	out_rel="${report_date}/${out_name}"
	out="${outdir}/${out_rel}"
	# if the symlink exists already, read it for the previous date
	if [ -L ${out_link} ]; then
		prev=$(readlink ${out_link})
		prev_date=$(basename $(dirname ${prev}))
		[ ${prev_date} = ${report_date} ] && {
			prev_date=""
		}
	fi
	# if no symlink was there, we need to come up with the
	# previous date if there was one
	if [ -z "${prev_date}" ]; then
		prev_date=$((cd ${outdir}; find . -maxdepth 1 -type d \
		     -name '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' \
			    -exec basename {} \;) | \
				    sort | tail -1)
		if [ ${prev_date} = ${report_date} ]; then
			prev_date=$((cd ${outdir}; find . -maxdepth 1 -type d \
		 -name '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' \
				    -exec basename {} \;) | \
				    sort | tail -2 | head -1)
		fi
		if [ -z "${prev_date}" ]; then
			echo "::: no by-date subdirs in ${outdir}"
			mkdir -p ${outdir}/${report_date}
		fi
		if [ "${prev_date}" = "${report_date}" ]; then
			prev_date=""
		fi
	fi
	if [ -f ${out} -a ${overwrite} -eq 0 ]; then
		echo ".. ${out} exists - skipping"
	else
		echo ":: generating ${out}"
		# start with boilerplate for top
		[ -f ${bplate}/top.html.txt ] && cat ${bplate}/top.html.txt \
						     > ${out}
		# guts of report in a <pre> for now
		echo "<pre>" >> ${out}
		echo 'Report Type: ${type}' >> ${out}
		if [ -z "${prev_date}" ]; then
			echo 'Report Date: ${date}' >> ${out}
		else
			prev_uri="${uri_base}${prev_date}/${out_name}"
			echo 'Report Date: ${date} [<a href="'${prev_uri}'">previous report</a>]' >> ${out}
		fi
		echo 'Data Source: <a href="https://onionoo.torproject.org/'${fn}'">onionoo.torproject.org/'${fn}'</a>' >> ${out}
		if [ -f ${bplate}/header_${nm}.html.txt ]; then
			cat ${bplate}/header_${nm}.html.txt >> ${out}
		elif [ -f ${bplate}/header_${nm}.txt ]; then
			cat ${bplate}/header_${nm}.txt >> ${out}
		fi
		echo "" >> ${out}
		# if we haven't run this jq query yet, do so
		tmp=${what}-${fn}.raw
		if [ ! -f ${indir}/${tmp} ]; then
			echo "::: generating ${tmp} from ${fn}.json"
			jq -c --raw-output "${q}" \
			   < ${indir}/${fn}.json > ${indir}/${tmp}
		fi
		perl ${rankitpl} ${rankopts} < ${indir}/${tmp} >>${out}
		echo "" >> ${out}
		echo "</pre>" >> ${out}
		# report done, bottom matter
		if [ -f ${bplate}/footer_${nm}.html.txt ]; then
			cat ${bplate}/footer_${nm}.html.txt >> ${out}
		elif [ -f ${bplate}/footer_${nm}.txt ]; then
			cat ${bplate}/footer_${nm}.txt >> ${out}
		fi
		if [ -f ${bplate}/bottom.html.txt ]; then
			cat ${bplate}/bottom.html.txt >> ${out}
		elif [ -f ${bplate}/bottom.txt ]; then
			cat ${bplate}/bottom.txt >> ${out}
		fi
		# s/// the output file's ${token} things: title, date, type
		title="${whatuc}: ${nm}"
		suss_file ${out} \
			  "title=${title}" "date=${report_date}" "type=${whatuc}"
		# finally make the symlink
		(cd ${outdir}; ln -sf ${out_rel} ${out_name})
	fi
}

# generate one report; output filename is first param, rest are for rankit.pl
relays () {
	typeset nm
	nm=$1
	shift
	report_${rtype} relays details ${nm} '.relays[]|select(.running)|"\(.platform)|\(.observed_bandwidth)|\(.country)|\(.as_number)|\(.as_name)|\(.consensus_weight_fraction)"' $*
}

bridges () {
	typeset nm fn
	nm=$1
	shift
	report_${rtype} bridges details ${nm} '.bridges[]|select(.running)|"\(.platform)|\(.advertised_bandwidth)|\(.transports)"' $*
}

# parse command-line options
while [ $# -gt 0 ]; do
	case "$1" in
		--help)				 usage ;;
		--noclear|--overwrite)		 setopt "$1" ;;
		--outdir=*|--indir=*|--bplate=*|--rtype=*|--uri-base=*|--date=*)
						 setoptval "$1" ;;
		*)				 usage "bad argument" ;;
	esac
	shift
done

[ "${rtype}" != plain -a "${rtype}" != linked ] && {
	die "--rtype=${rtype} invalid; must be plain or linked"
}
[ -z "${date}" ] && {
	case ${indir} in
		[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9])
			date=${indir}
			;;
		*)
			date=$(date +%Y%m%d)
			;;
	esac
	echo "::: report date: ${date}"
}
report_date=${date}
[ ! -f ${indir}/details.json ] && {
	die "could not find input file: ${indir}/details.json"
}
[ ! -d ${outdir} ] && {
	die "output directory does not exist: ${outdir}"
}

## Relay Reports

# by OS: total bandwidth, raw count, consensus_weight fraction
relays bw-by-os		-O BANDWIDTH OS
relays os-count		-NO COUNT OS
relays cweight-by-os	-IO -v 5 CONSENSUS_WEIGHT_FRAC OS

# by Tor version: bw, count, cw_frac
relays bw-by-vers	-V BANDWIDTH VERS
relays vers-count	-NV COUNT VERS
relays cweight-by-vers	-IV -v 5 CONSENSUS_WEIGHT_FRAC VERS

# by Country: bandwidth, cw
relays bw-by-cc		-l 2 BANDWIDTH COUNTRY
relays cweight-by-cc	-I -l 2 -v 5 CONSENSUS_WEIGHT_FRAC COUNTRY

# by AS and ASN: bandwidth, cw
relays bw-by-as		-l 3 BANDWIDTH AS
relays bw-by-asn	-l 4 BANDWIDTH AS_NAME
relays cweight-by-as	-I -l 3 -v 5 CONSENSUS_WEIGHT_FRAC AS
relays cweight-by-asn	-I -l 4 -v 5 CONSENSUS_WEIGHT_FRAC AS_NAME

## Bridge Reports

# by OS: bandwidth, raw count, transports, transports per OS
bridges bw-by-os	-O BANDWIDTH OS
bridges os-count	-NO COUNT OS
bridges trans-count	-LN -l 2 COUNT TRANSPORT
bridges trans-os	-OU -l 0 -v 2 COUNT OS:TRANSPORT
