#!/bin/bash -e
#
# This part of the script is to be used inside the build-container
# to collect the build-results before they are going
# to be exposed via HTTP.
#
# Until exposure happens automatically, you can call this
# script after a successful build in the container to
# get a directory like this:
#
# ./2015-02-19-205642-thintze
# ./2015-02-19-205642-thintze/core-image-example-vmware.iso
# ./2015-02-19-205642-thintze/core-image-example-vmware.ova
# ./2015-02-19-205642-thintze/cooker-logs.tar.gz
# ./2015-02-19-205642-thintze/package-logs.tar.gz
# ./2015-02-19-205642-thintze/packages.tar
#
# This contains packages, images, logs.
#

BUILDID=`cat /REDO/source/BUILDID`
RESULTID=`cat /REDO/source/BUILDID`
RESULTBASEDIR="/REDO/results"
RESULTDIR="$RESULTBASEDIR/$RESULTID"

i=1

while true;
do
    IFS='-' read -ra RESULTID <<< "$RESULTID"
    if [ -d "$RESULTDIR" ]; then
        RESULTID="$BUILDID-$i"
        RESULTDIR="$RESULTBASEDIR/$RESULTID"
    else
        break
    fi
    i=$((i+1))
done

mkdir -pv "$RESULTDIR"

[ ! -d /REDO/build/tmp/deploy/ipk ] && echo "no ipk directory found" && exit 1
[ ! -d /REDO/build/tmp/deploy/images ] && echo "no images directory found" && exit 1
[ ! -d /REDO/build/tmp/log/cooker ] && echo "no cooker log directory found" && exit 1
[ ! -d /REDO/build/tmp/work ] && echo "no work directory found" && exit 1

(
cd /REDO/build/tmp/deploy/images

find /REDO/build/tmp/deploy/images -type l -name "core-image*.iso" -exec ln -s {} "$RESULTDIR/" ';'
find /REDO/build/tmp/deploy/images -type l -name "core-image*.ova" -exec ln -s {} "$RESULTDIR/" ';'
)

(
	echo "creating archive of cooker logs..."
	cd /REDO/build/tmp/log
	tar czf $RESULTDIR/cooker-logs.tar.gz cooker
	echo "[$RESULTDIR/cooker-logs.tar.gz] completed."
)

cd /REDO/build/tmp/work
find . -mindepth 1 -maxdepth 1 -type d | while read i
do
	echo "adding $i package logs to archive..."
	( cd "$i" && find . -name "log*" -type f | tar rf $RESULTDIR/package-logs.tar -T - )
done
gzip $RESULTDIR/package-logs.tar
echo "[$RESULTDIR/package-logs.tar.gz] completed."

echo "DONE:"
echo
find $RESULTDIR
echo

python /REDO/results/result_httpd.py 80 /REDO/results/$BUILDID /REDO/build/tmp/deploy/ipk
