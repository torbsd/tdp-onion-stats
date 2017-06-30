#!/bin/sh
# -*- mode:sh; indent-tabs-mode:t; tab-width:8; sh-basic-offset:8 -*-

# produce simple, point-in-time reports based on the JSON onionoo data
# not unlike the Q&D stats of old, just with better/newer data

#set -e

script="${script:-`basename $0`}"
www="${www:-$HOME/torbsd.github.io}"
rankitpl=${rankitpl-./rankit.pl}
bplate=${bplate-bplate}
outdir=${outdir-.}
indir=${indir-.}
details=details.json

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
	_nm=`optname "$1"`
	eval $_nm=1
}

# like setopt but with a --opt=val style argument
setoptval () {
	typeset _nm _vl
	_nm="`optname $1`"
	_vl="`optval $1`"
	eval $_nm=$_vl
}

# produce a fatal error message and quit
die () {
	echo "${script}: FATAL: $*" >&2
	exit 1
}

# generate one report; output filename is first param, rest are for rankit.pl
report () {
	typeset nm out
	nm=$1
	shift
	out="${outdir}/${nm}".txt
	if [ -f ${out} ]; then
	    echo ".. ${out} exists - skipping"
	else
		echo ":: generating ${out}"
		[ -f ${bplate}/top.txt ] && cat ${bplate}/top.txt > ${out}
		echo "Report Date: `date -u`" >> ${out}
		echo "Data Source: https://onionoo.torproject.org" >> ${out}
		[ -f ${bplate}/header_${nm}.txt ] && cat ${bplate}/header_${nm}.txt >> ${out}
		echo "" >> ${out}
		# pull wanted cols out of details.json but only for running relays
		# pipe the raw data into rankit.pl
		jq -c --raw-output \
		   '.relays[]|select(.running)|"\(.platform)|\(.observed_bandwidth)|\(.country)|\(.as_number)|\(.as_name)|\(.consensus_weight_fraction)"' \
		   < ${indir}/${details} | perl ${rankitpl} $* >>${out}
		echo "" >> ${out}
		[ -f ${bplate}/footer_${nm}.txt ] && cat ${bplate}/footer_${nm}.txt >> ${out}
		[ -f ${bplate}/bottom.txt ] && cat ${bplate}/bottom.txt >> ${out}
	fi
}

# parse command-line options
while [ $# -gt 0 ]; do
	case "$1" in
		--help)				 usage ;;
		--outdir=*|--indir=*|--bplate=*) setoptval "$1" ;;
		*)				 usage "bad argument" ;;
	esac
	shift
done

[ ! -f ${indir}/${details} ] && {
	die "could not find input file: ${indir}/${details}"
}
[ ! -d ${outdir} ] && {
	die "output directory does not exist: ${outdir}"
}

# by OS: total bandwidth, raw count, consensus_weight fraction
report bw-by-os		-O BANDWIDTH OS
report os-count		-ON COUNT OS
report cweight-by-os	-OI -v 5 CONSENSUS_WEIGHT_FRAC OS

# by Tor version: bw, count, cw_frac
report bw-by-vers	-V BANDWIDTH VERS
report vers-count	-VN COUNT VERS
report cweight-by-vers	-VI -v 5 CONSENSUS_WEIGHT_FRAC VERS

# by country: bandwidth, cw
report bw-by-cc		-l 2 BANDWIDTH COUNTRY
report cweight-by-cc	-I -l 2 -v 5 CONSENSUS_WEIGHT_FRAC COUNTRY

# by AS and ASN: bandwidth, cw
report bw-by-as		-l 3 BANDWIDTH AS
report bw-by-asn	-l 4 BANDWIDTH AS_NAME
report cweight-by-as	-I -l 3 -v 5 CONSENSUS_WEIGHT_FRAC AS
report cweight-by-asn	-I -l 4 -v 5 CONSENSUS_WEIGHT_FRAC AS_NAME
