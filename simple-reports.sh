#!/bin/sh

# produce simple, point-in-time reports based on the JSON onionoo data
# not unlike the Q&D stats of old, just with better/newer data

script="${script:-$(basename $0)}"
www="${www:-$HOME/torbsd.github.io}"
rankitpl=${rankitpl-./rankit.pl}
bplate=${bplate-bplate}
outdir=${outdir-.}
indir=${indir-.}
details=details.json
noclear=0
overwrite=0

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
	exit $_xit
}

# transform --foo into foo
optname () {
	echo "$1" | sed -e 's/^--//' -e 's/=.*$//' -e 's/`/_/g' -e 's/-/_/'
}

# sanitize a value for --foo val
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

# report bridges details bw-by-os "...jq query..." rankit_opts
# report relays details bw-by-os "...jq query..." rankit_opts
report () {
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

# generate one report; output filename is first param, rest are for rankit.pl
relays () {
	typeset nm
	nm=$1
	shift
	report relays details ${nm} '.relays[]|select(.running)|"\(.platform)|\(.observed_bandwidth)|\(.country)|\(.as_number)|\(.as_name)|\(.consensus_weight_fraction)"' $*
}

bridges () {
	typeset nm fn
	nm=$1
	shift
	report bridges details ${nm} '.bridges[]|select(.running)|"\(.platform)|\(.advertised_bandwidth)|\(.transports)"' $*
}

# parse command-line options
while [ $# -gt 0 ]; do
	case "$1" in
		--help)				 usage ;;
		--noclear|--overwrite)		 setopt "$1" ;;
		--outdir=*|--indir=*|--bplate=*) setoptval "$1" ;;
		*)				 usage "bad argument" ;;
	esac
	shift
done

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
