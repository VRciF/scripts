#!/bin/bash
##!/bin/bash -x
##set -o xtrace



#filetreesha1db.sh [options] dbfile path

DBFILE=$1
WORKINGDIR=$2

STRUCTURE="CREATE TABLE IF NOT EXISTS files (path TEXT,filename TEXT, size INTEGER, inode INTEGER, modified TEXT, changed TEXT, sha1 TEXT, hashtime INTEGER, created TIMESTAMP DEFAULT CURRENT_TIMESTAMP);"
echo $STRUCTURE | sqlite3 $DBFILE || { echo >&2 "sqlite3 need to be installed.  Aborting."; exit 1; }

DBFILE=$(readlink -e $DBFILE)

pushd $WORKINGDIR
find -type f | while read fname; do
    echo $fname
    DBFILENAME=${fname##*/}
    DBPATH=$(dirname $fname)
    DBPATH="${DBPATH:1:${#DBPATH}}" # remove dot
    SIZE=`stat -c "%s" "$fname"`
    INODE=`stat -c "%i" "$fname"`
    MODIFIED=`stat -c "%y" "$fname"`
    CHANGED=`stat -c "%z" "$fname"`

    REHASH=1
    STATEMENT="SELECT count(*) FROM files WHERE path=\"$DBPATH\" AND filename=\"$DBFILENAME\";"
    CNT=`sqlite3 $DBFILE "$STATEMENT"`

    if [ "$CNT" -ne "0" ]; then
        STATEMENT="SELECT count(*) FROM files WHERE path=\"$DBPATH\" AND filename=\"$DBFILENAME\" AND size=\"$SIZE\" AND inode=\"$INODE\" AND modified=\"$MODIFIED\" AND changed=\"$CHANGED\";"
        CNT=`sqlite3 $DBFILE "$STATEMENT"`
        if [ "$CNT" -eq "0" ]; then
            REHASH=1
        else
            REHASH=0
        fi
    fi

    if [ "$REHASH" -eq "1" ]; then
        `sqlite3 $DBFILE "INSERT INTO files (path,filename,size,inode,modified,changed,sha1,hashtime) VALUES ('$DBPATH','$DBFILENAME', $SIZE, $INODE, '$MODIFIED', '$CHANGED', '', 0)"`

#        HASHTIMESTART=$(date +%s.%N)
        HASHTIMESTART=$(date +%s)
        HASH=`sha1sum "$fname"`
        HASH=$(echo $HASH | cut -d" " -f1)

#        HASHTIMEEND=$(date +%s.%N)
        HASHTIMEEND=$(date +%s)
        HASHTIMEDIFF=$(($HASHTIMEEND-$HASHTIMESTART))
#        HASHTIMEDIFF=$(echo "$HASHTIMEEND - $HASHTIMESTART" | bc)
        `sqlite3 $DBFILE "UPDATE files SET sha1='$HASH',hashtime='$HASHTIMEDIFF' WHERE path='$DBPATH' AND filename='$DBFILENAME'"`
    fi
done
popd

exit

tmpdir="/tmp"
logdir="/tmp"
statedir="/tmp"

pid=$$
scriptcmd=$1

newdirstmt="CREATE TABLE IF NOT EXISTS directory_[ID] (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,relpath TEXT,size INTEGER,sha1 TEXT,error TEXT,modified INTEGER,created INTEGER,rowupdatetime INTEGER,UNIQUE (relpath))"
dropstmt="DROP TABLE directory_[ID]"
insertmissingstmt='INSERT OR REPLACE INTO directory_[ID] (relpath,size,sha1,error,modified,created,rowupdatetime) values ("[relpath]",[size],"[sha1]","[error]",[modified],strftime("%s", CURRENT_TIME),strftime("%s", CURRENT_TIME));'
selectrelpsizemodstmt="SELECT relpath||';'||size||';'||modified FROM directory_[ID]"

usage()
{
cat << EOF
usage: $0 [CMD] [OPTIONS] SQLITEDBFILE

COMMANDS OPTIONS:
   update ABSOLUTEPATH              search for new or modified files and update sqlite database
   drop ABSOLUTEPATH                delete sqlite database table corresponding to ABSOLUTEPATH
EOF
}
echoerr()
{
echo "$@" 1>&2
}

# params: dbfilename, tblid
createdirtable(){
    dbfile=$1
    tblid=$2
    result=`sqlite3 $dbfile "${newdirstmt/\[ID\]/$tblid}" 2>&1`
    if [ "$?" -ne "0" ]; then
        echoerr "ERROR createdirtable $tblid failed:"
        echoerr $result
        exit -1
    fi
}

processcomm()
{
abspath=$1
tblid=$2
dbfile=$3
echo "compare $tmpdir/fts.$tblid.fslist $tmpdir/fts.$tblid.dblist"
comm -3 $tmpdir/fts.$tblid.fslist $tmpdir/fts.$tblid.dblist | while read line; do
    line=${line%;*}  # cut off the modification time  
    line=${line%;*}  # cut off the size

    size=`stat -c%s "$abspath/$line"`
    modseconds=`stat -c %Y "$abspath/$line"`
    error=""
    sha=`sha1sum "$abspath/$line" 2>&1`
    if [ "$?" -ne "0" ]; then
        error=sha
        sha=""
    else
        sha=`echo "$sha" | cut -f 1 -d " "`
    fi

    insertstmt="${insertmissingstmt/\[ID\]/$tblid}"
    insertstmt="${insertstmt/\[relpath\]/$line}"
    insertstmt="${insertstmt/\[size\]/$size}"
    insertstmt="${insertstmt/\[sha1\]/$sha}"
    insertstmt="${insertstmt/\[error\]/$error}"
    insertstmt="${insertstmt/\[modified\]/$modseconds}"

    echo "insert or update: $line with size $size modification time $modseconds checksum $sha error '$error'"
    echo $insertstmt | sqlite3 $dbfile
done
}

generatefilesystemlist()
{
abspath=$1
tblid=$2

echo 

echo "generate filesystem list for $abspath"
pushd $abspath >/dev/null
find -type f -exec stat --printf="%n;%s;%Y\\n" {} \; | cut -c3- | sort > $tmpdir/fts.$tblid.fslist
popd >/dev/null
}


drop()
{
abspath="$1"
dbfile="$2"

tblid=$( echo "$abspath" | sha1sum | cut -f 1 -d " " )

result=`sqlite3 $dbfile "${dropstmt/\[ID\]/$tblid}"`
    if [ "$?" -ne "0" ]; then
        echoerr "ERROR drop table $tblid failed:"
        echoerr $result
        exit -1
    fi
}

update()
{
abspath=${1%/}
dbfile="$2"

if [ ! -d "$abspath" ]; then
    echo "File not found!"
    usage
    exit -1
fi

tblid=$( echo "$abspath" | sha1sum | cut -f 1 -d " " )

createdirtable $dbfile $tblid

# first add file which are missing in the table
generatefilesystemlist $abspath $tblid
echo "generate db file list for $abspath:$tblid"
sqlite3 $dbfile "${selectrelpsizemodstmt/\[ID\]/$tblid}" | sort > $tmpdir/fts.$tblid.dblist

processcomm $abspath $tblid $dbfile

rm $tmpdir/fts.$tblid.fslist $tmpdir/fts.$tblid.dblist

}


trap 'echo "$pid|$scriptcmd|$FUNCNAME|$BASH_LINENO|$BASH_COMMAND" > $statedir/fts.$pid.state' DEBUG

 case $1 in
     update)
         update ${*:2}
         ;;
     drop)
         drop ${*:2}
         ;;
     *)
         usage
         ;;
 esac
exit
