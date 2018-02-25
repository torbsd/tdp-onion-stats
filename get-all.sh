#!/bin/sh

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
    ftp -o ${now}/${type}.json ${torsrc}/${type}
done
du -sh ${now}
#echo packing up ...
#tar -cf - ${now} | xz > stats-${now}.tar.xz
#du -sh stats-${now}.tar.xz
