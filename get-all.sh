#!/bin/sh

# download all the current data into a date-stamped directory
# produce an xz-compressed tarball of the resulting dir

# N.B. we run this script on OpenBSD, c.f. https://man.openbsd.org/ftp

torsrc=https://onionoo.torproject.org
now=`date +%Y%m%d`
[ ! -d ${now} ] && mkdir ${now}
if [ $# -eq 0 ]; then
    types="summary details bandwidth weights clients uptime"
else
    types="$*"
fi
for type in ${types}; do
    echo $type ...
    ftp -vo ${now}/${type}.json ${torsrc}/${type}
done
du -sh ${now}
echo packing up ...
tar -cf - ${now} | xz > stats-${now}.tar.xz
du -sh stats-${now}.tar.xz
