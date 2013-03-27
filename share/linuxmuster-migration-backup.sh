#
# linuxmuster-migration-backup
# thomas@linuxmuster.net
# 20.03.2013
#

################################################################################
# check if current version is supported

echo
echo "####"
echo "#### Checking version"
echo "####"
match=false
for i in $BACKUPVERSIONS; do
 if stringinstring "$i" "$DISTFULLVERSION"; then
  match=true
  break
 fi
done
if [ "$match" = "true" ]; then
 echo "Source version: $DISTFULLVERSION."
else
 error "Version $DISTFULLVERSION is not supported."
fi


################################################################################
# computing needed backup space

echo
echo "####"
echo "#### Computing backup space"
echo "####"

# add all file sizes to SUM
ssum=0 ; tsum=0 ; s=0 ; t=0
BACKUP="$(grep ^/ "$INCONFTMP")"
for i in $BACKUP; do
 #  source space
 if [ -e "$i" ]; then
  # on this occasion write only the really existent files to INCONFILTERED for use with rsync
  echo "$i" >> "$INCONFILTERED"
  s="$(du -sk "$i" | awk '{ print $1 }')"
  ssum=$(( $s + $ssum ))
 fi
 # target space
 if [ -e "${BACKUPFOLDER}${i}" ]; then
  t="$(du -sk "${BACKUPFOLDER}${i}" | awk '{ print $1 }')"
  tsum=$(( $t + $tsum ))
 fi
done
# add 200 mb to backup size to be sure it fits
ssum=$(( $ssum + 200000 ))
echo " * total backup size      : $ssum kb"
echo " * already on target      : $tsum kb"

# free space on TARGETDIR
freespace="$(df -P $TARGETDIR | tail -1 | awk '{ print $4 }')"
echo " * free space on target   : $freespace kb"

# really needed space
needed=$(( $ssum - $tsum ))
echo " * needed space on target : $needed kb"

# decide whether it fits
if [ $freespace -lt $needed ]; then
 error "Sorry, does not fit!"
else
 echo "Great, that fits. :-)"
fi


################################################################################
# check for supported file system type

echo
echo "####"
echo "#### Checking filesystem type on target medium"
echo "####"

FSTYPE="$(stat -f -c %T $TARGETDIR)"

echo -n " * $FSTYPE ..."

if stringinstring "$FSTYPE" "$SUPPORTEDFS"; then
 echo " OK!"
else
 echo " NOT supported!"
 error "I'm sorry, supported filesystems are: $SUPPORTEDFS."
fi


################################################################################
# backup paedml base data

echo
echo "####"
echo "#### Backing up base data"
echo "####"

# dumps debconf values to file
echo -n " * debconf values ..."
debconf-show linuxmuster-base > "$BASEDATAFILE" ; RC="$?"
if [ "$RC" = "0" ]; then
 echo " OK!"
else
 error " Failed!"
fi

# save issue file because of version info
echo -n " * version info ..."
cp -f /etc/issue "$ISSUE" ; RC="$?"
if [ "$RC" = "0" ]; then
 echo " OK!"
else
 error " Failed!"
fi

# save number of quoted partitions
echo -n " * quota info ..."
mount | grep -c "usrquota,grpquota" > "$QUOTAPARTS"
echo " $(cat "$QUOTAPARTS") partition(s) are quoted."


################################################################################
# firewall settings, certificates etc.

# get firewall type from system
FIREWALL=ipcop
[ -n "$fwconfig" ] && FIREWALL="$fwconfig"

# backup firewall settings if not custom
if [ "$FIREWALL" != "custom" ]; then

 echo
 echo "####"
 echo "#### Backing up $FIREWALL settings"
 echo "####"

 echo -n " * creating and downloading $FWARCHIVE ..."

 RC=0
 if [ "$FIREWALL" = "ipcop" ]; then

  exec_ipcop /bin/tar czf /var/linuxmuster/backup.tar.gz --exclude=/var/$FIREWALL/ethernet/settings /etc /root/.ssh /var/$FIREWALL || RC=1
  get_ipcop /var/linuxmuster/backup.tar.gz "$FWARCHIVE" || RC=1

 else # ipfire

  for cmd in makedirs exclude; do
   exec_ipcop /usr/local/bin/backupctrl $cmd >/dev/null 2>&1 || RC=1
  done
  latest_ipf="$(ssh -p 222 root@${ipcopip} ls -1rt /var/ipfire/backup/*.ipf | tail -1)"
  if [ -n "$latest_ipf" ]; then
   get_ipcop $latest_ipf "$FWARCHIVE" || RC=1
  else
   RC=1
  fi

 fi

 if [ "$RC" = "0" ]; then
  echo " OK!"
 else
  error " Failed!"
 fi

fi

echo "$FIREWALL" > "$FWTYPE"


################################################################################
# package selections

echo
echo "####"
echo "#### Backing up package selections"
echo "####"

echo -n " * get selections ..."

dpkg --get-selections > "$SELECTIONS" ; RC="$?"

if [ "$RC" = "0" ]; then
 echo " OK!"
else
 error " Failed!"
fi


################################################################################
# save password hash of remoteadmin, if account is present

if id $REMOTEADMIN &> /dev/null; then
 echo
 echo "####"
 echo "#### Backing up $REMOTEADMIN"
 echo "####"

 echo -n " * saving password hash ..."

 if grep $REMOTEADMIN /etc/shadow | awk -F\: '{ print $2 }' > $REMOTEADMIN.hash; then
  echo " OK!"
 else
  echo " Failed!"
 fi

fi


################################################################################
# filesystem backup with rsync using include.conf and exclude.conf

echo
echo "####"
echo "#### Backing up filesystem"
echo "####"

RC=0

# stop services
start_stop_services stop

mkdir -p "$BACKUPFOLDER"
rsync -a -r -v --delete --delete-excluded "$INPARAM" "$EXPARAM" / "$BACKUPFOLDER/" || RC=1

# start services again
start_stop_services start

if [ "$RC" = "0" ]; then
 echo "Backup successfully completed!"
else
 error "An error ocurred during backup!"
fi


################################################################################
# dumping postgresql databases and users

echo
echo "####"
echo "#### Backing up postgresql databases"
echo "####"

# dumping all databases except postgres and templates
for i in `psql -t -l -U postgres | awk '{ print $1 }' | grep ^[a-zA-Z0-9]`; do

 case $i in
  postgres|template0|template1) continue ;;
 esac

 echo -n " * $i ..."

 if pg_dump --encoding=UTF8 -U postgres $i > $i.pgsql; then
  echo " OK!"
 else
  error " Failed!"
 fi

done

# metadata
echo -n " * metadata ..."

if pg_dumpall -U postgres --globals-only > "$PGSQLMETA"; then
 echo " OK!"
else
 error " Failed!"
fi


################################################################################
# dumping mysql databases and users

echo
echo "####"
echo "#### Backing up mysql databases"
echo "####"

for i in `LANG=C mysqlshow | grep ^"| "[0-9a-zA-Z] | grep -v ^"| mysql" | awk '{ print $2 }'`; do

 case $i in
  information_schema|performance_schema|test) continue ;;
 esac

 echo -n " * $i ..."

 if mysqldump --databases $i > $i.mysql; then
  echo " OK!"
 else
  error " Failed!"
 fi

done

echo -n " * metadata ..."
if mysqldump mysql user > "$MYSQLMETA"; then
 echo " OK!"
else
 error " Failed!"
fi


################################################################################
# dumping ldap tree

echo
echo "####"
echo "#### Backing up ldap tree"
echo "####"

/etc/init.d/slapd stop

echo -n " * dumping ..."
slapcat > "$LDIF" ; RC="$?"
if [ "$RC" = "0" ]; then
 echo " OK!"
else
 echo " Failed!"
fi

/etc/init.d/slapd start

[ "$RC" = "0" ] || error


################################################################################
# copying migration config files to TARGETDIR to have them in place for restore

if [ "${MIGCONFDIR%\/}" != "${TARGETDIR%\/}" ]; then

 echo
 echo "####"
 echo "#### Saving config files in $TARGETDIR"
 echo "####"

 for i in $MIGCONFDIR/*.conf; do

  echo -n " * `basename $i` ..."
  cp "$i" "$TARGETDIR"
  echo " Done!"

 done

fi


################################################################################
# end

echo
echo "####"
echo "#### `date`"
echo "#### Backup of migration data finished! :-)"
echo "####"

