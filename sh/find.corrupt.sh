#/bin/bash

# by definition: a file is called corrupt if the size, inode number and modification date didn't change
#                but it's checksum changed
# thus this script generates a list of regular files in a given path and their stats (size,inode,modificationdate)
# and compares the list with a previously generated list
# if stat's changed, the checksum is regenerated
# if not AND -c parameter is given the file's checksum is newly created and compared to the previously created one
# if the checksum's differ the file is called corrupt and it's filename including relative path is printed to stdout
# usage:
# o) find.corrupt.sh DIRECTORY
#    recalculates the checksum's of all files in directory
#    as this could take very long one can use the following
# o) find.corrupt.sh -c DIRECTORY
#    to prevent recalculation of all checksum's - only new files are recalculated and deleted files are dropped
# o) find.corrupt.sh -c -u DIRECTORY
#    in case a corrupt file is found, it's NEWly calculated checksum is saved, causing the next run of find.corrupt.sh not detect the file to be corrupt

#set -x

function show_help {
    >&2 echo "$0 [-h] [-c] [-u] DIRECTORY"
    >&2 echo "Options are:"
    >&2 echo "-c used to NOT force recalculate of all checksum's"
    >&2 echo "-u used to update checksums of corrupt checksum's so they dont get reported in the future"
    exit 1
}

FORCESHA1=1
UPDATESHA1=0
BASEDIR=""

while getopts "h?cu" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    c)  FORCESHA1=0
        ;;
    u)  UPDATESHA1=1
        ;;
    esac
done

shift $((OPTIND-1))
if [ ! -z "$1" ]; then
    BASEDIR=$1
else
    >&2 echo "ERROR: Directory parameter missing"
    show_help
fi

if [ ! -d "${BASEDIR}" ]; then
    >&2 echo "ERROR: given directory ${BASEDIR} doesnt exist"
    show_help
fi

pushd $BASEDIR >/dev/null

NOW=`date +%s`

mkdir -p ".nas"

# cleanup stage
STATSF=""
ls -1r .nas/files.stats.* 2>/dev/null | while read filename
do
  if [ "$STATSF" == "" ]; then
      STATSF="${filename}"
      continue;
  fi

  rm "${filename}"
done

# first generate a file containing the stats filename:inode:size in bytes:modification time in seconds
#echo "Gathering file stats"
#date
find . -mount -type f ! -path "./.nas/*" -exec stat -c "%n:%i:%s:%Y" {} \; | sort > ".nas/files.stats.${NOW}"
#date

# now find every file whose stats differ
# different stats means, that the file has changed and thus previously calculated sha1sum is now obsolete
touch ".nas/files.sha1sum"

cat ".nas/files.stats.${NOW}" | while read line
do
    IFS=':' read -a parts <<< "$line"
    cnt=${#parts[@]}
    stats=(${parts[$(($cnt-3))]} ${parts[$(($cnt-2))]} ${parts[$(($cnt-1))]})
    unset parts[$(($cnt-1))]
    unset parts[$(($cnt-2))]
    unset parts[$(($cnt-3))]
    filename=$(printf ":%s" "${parts[@]}")
    filename=${filename:1}
    unset parts

    stats2=(0 0 0)
    if [ "$STATSF" != "" ]; then
        STATSLINE=`grep "${filename}" "${STATSF}"`
        if [ "${#STATSLINE}" -gt "0" ]; then
            IFS=':' read -a parts <<< "$STATSLINE"
            cnt=${#parts[@]}
            stats2=(${parts[$(($cnt-3))]} ${parts[$(($cnt-2))]} ${parts[$(($cnt-1))]})
            unset parts
        fi
    fi
    SHA1SUM=""
    if [ "${FORCESHA1}" -eq "1" ] || [ "${stats[0]}" != "${stats2[0]}" ] || [ "${stats[1]}" != "${stats2[1]}" ] || [ "${stats[2]}" != "${stats2[2]}" ]; then
        SHA1SUM=`cat "${filename}" | sha1sum -b | tr -d "-" | tr -d "*" | tr -d " "`
        if [ "${#SHA1SUM}" -eq "0" ]; then
            SHA1SUM="0"
        fi
    fi
    # if checksum length is zero
    if [ "${#SHA1SUM}" -eq "0" ]; then
        # clone the checksum line into a new file
        grep "${filename}:" ".nas/files.sha1sum" >> .nas/files.sha1sum.new
        continue;
    fi
    # a checksum has been generated OR the checksum generation failed and thus is set to string "0"
    # failing checksum means the storage device seems to be broken, e.g. bad sector's on disk

    SHA1LINE=""
    SHA1SUM2=$SHA1SUM
    if [ -f ".nas/files.sha1sum" ]; then
        SHA1LINE=`grep "${filename}:" ".nas/files.sha1sum"`
        IFS=':' read -a parts <<< "$SHA1LINE"
        if [ ${#parts[@]} -gt 0 ]; then
            cnt=${#parts[@]}
            SHA1SUM2=${parts[@]:$(($cnt-1)):1}
        fi
    fi
    if [ "${SHA1SUM}" != "${SHA1SUM2}" ]; then
        >&2 echo "${filename}"
        if [ "${UPDATESHA1}" == "1" ]; then
            # use newly calculated checksum
            echo "${filename}:${SHA1SUM}" >> .nas/files.sha1sum.new
        else
            # save the old checksum
            echo "${filename}:${SHA1SUM2}" >> .nas/files.sha1sum.new
        fi
    else
        echo "${filename}:${SHA1SUM}" >> .nas/files.sha1sum.new
    fi
done
sort .nas/files.sha1sum.new > .nas/files.sha1sum
rm .nas/files.sha1sum.new

popd >/dev/null

