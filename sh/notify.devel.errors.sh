#!/bin/bash
#set -x

declare -A LOGFILES
LOGFILES[/var/log/apache2/access.log]="[^(?:(?! 200 ).)*$]"  # access log files not containing 200 response code
LOGFILES[/var/log/apache2/error.log]=".*"
LOGFILES[/tmp/php_errors.log]=".*"

declare -A LASTLINES
for LOGFILE in "${!LOGFILES[@]}"
do
   LASTLINES[$LOGFILE]=""
done

while true; do
  MESSAGE=""
  for LOGFILE in "${!LOGFILES[@]}"
  do
    LASTLINE=`tail -n 1 ${LOGFILE}`
    if [[ ${#LASTLINES[$LOGFILE]} -eq 0 ]] ; then
        LASTLINES[$LOGFILE]=${LASTLINE}
    fi

    PREVLINE=${LASTLINES[$LOGFILE]}
    if [ "$LASTLINE" != "$PREVLINE" ] ; then
      if [[ $LASTLINE =~ ${LOGFILES[$LOGFILE]} ]] ; then
        # regex matches
        MESSAGE="${MESSAGE}${LOGFILE}: ${LASTLINE}\n"
        LASTLINES[$LOGFILE]=${LASTLINE}
      fi
    fi
  done
  if [ ${#MESSAGE} -gt 0 ] ; then
    notify-send -t 3000 "Devel Errors" "$MESSAGE"
  fi
  sleep 3
done

