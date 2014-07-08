#
# thomas@linuxmuster.net
# 07.07.2014
# GPL v3
#


################################################################################
# are all necessary files present?

echo
echo "####"
echo "#### Checking for essential restore files"
echo "####"
for i in "$BACKUPFOLDER" "$BASEDATAFILE" "$LDIF" "$FWTYPE" "$FWARCHIVE" "$ISSUE" "$PGSQLMETA" "$MYSQLMETA" "$SELECTIONS" "$QUOTAPARTS"; do
 if [ -e "$i" ]; then
  echo " * `basename $i` ... OK!"
 else
  if [ "$i" = "$FWARCHIVE" -a "$FWTYPE" = "custom" ]; then
   echo " * `basename $i` ... skipped!"
  else
   error " * `basename $i` does not exist!"
  fi
 fi
done

# get firewall from source system
SOURCEFW="$(cat $FWTYPE)"


################################################################################
# if custom.conf is used, check for modified setup values

if [ -s "$MIGCONFDIR/custom.conf" ]; then

 echo
 echo "####"
 echo "#### Verifying config values defined in custom.conf"
 echo "####"

 echo -n " * INTERNSUBRANGE: "
 if [ -n "$INTERNSUBRANGE" ]; then
  if stringinstring "$INTERNSUBRANGE" "$SUBRANGES"; then
   echo "$INTERNSUBRANGE"
   touch "$CUSTOMFLAG"
  else
   error "$INTERNSUBRANGE is not a valid value!"
  fi
 else
  echo "not set!"
 fi

 echo -n " * SCHOOLNAME: "
 if [ -n "$SCHOOLNAME" ]; then
  if check_string "$SCHOOLNAME"; then
   echo "$SCHOOLNAME"
   touch "$CUSTOMFLAG"
  else
   error "$SCHOOLNAME contains illegal characters!"
  fi
 else
  echo "not set!"
 fi

 echo -n " * LOCATION: "
 if [ -n "$LOCATION" ]; then
  if check_string "$LOCATION"; then
   echo "$LOCATION"
   touch "$CUSTOMFLAG"
  else
   error "$LOCATION contains illegal characters!"
  fi
 else
  echo "not set!"
 fi

 echo -n " * STATE: "
 if [ -n "$STATE" ]; then
  if check_string "$STATE"; then
   echo "$STATE"
   touch "$CUSTOMFLAG"
  else
   error "$STATE contains illegal characters!"
  fi
 else
  echo "not set!"
 fi

 echo -n " * COUNTRY: "
 if [ -n "$COUNTRY" ]; then
  if (expr match "$COUNTRY" '\([ABCDEFGHIJKLMNOPQRSTUVWXYZ][ABCDEFGHIJKLMNOPQRSTUVWXYZ]\)'); then
   echo "$COUNTRY"
   touch "$CUSTOMFLAG"
  else
   error "$COUNTRY contains illegal characters!"
  fi
 else
  echo "not set!"
 fi

 echo -n " * WORKGROUP: "
 if [ -n "$WORKGROUP" ]; then
  if check_string "$WORKGROUP"; then
   echo "$WORKGROUP"
   touch "$CUSTOMFLAG"
  else
   error "$WORKGROUP contains illegal characters!"
  fi
 else
  echo "not set!"
 fi

 echo -n " * SERVERNAME: "
 if [ -n "$SERVERNAME" ]; then
  if validhostname "$SERVERNAME"; then
   echo "$SERVERNAME"
   touch "$CUSTOMFLAG"
  else
   error "$SERVERNAME is no valid hostname!"
  fi
 else
  echo "not set!"
 fi

 echo -n " * DOMAINNAME: "
 if [ -n "$DOMAINNAME" ]; then
  if validdomain "$DOMAINNAME"; then
   echo "$DOMAINNAME"
   touch "$CUSTOMFLAG"
  else
   error "$DOMAINNAME is no valid domainname!"
  fi
 else
  echo "not set!"
 fi

 echo -n " * FWCONFIG: "
 if [ -n "$FWCONFIG" ]; then
  case "$FWCONFIG" in
   ipcop|ipfire|custom)
    echo "$FWCONFIG"
    touch "$CUSTOMFLAG"
    ;;
   *) "$FWCONFIG is no valid firewall!" ;;
  esac
 else
  echo "not set!"
 fi

fi

# get target firewall type
if [ -n "$FWCONFIG" ]; then
 TARGETFW="$FWCONFIG"
else
 TARGETFW="$CURRENTFW"
fi


################################################################################
# save firewall's network settings

# only for ipcop
if [ "$TARGETFW" = "ipcop" -a "$SOURCEFW" = "ipcop" ]; then

 echo
 echo "####"
 echo "#### Saving $TARGETFW's external network settings"
 echo "####"

 echo -n " * downloading settings file ..."
 if get_ipcop /var/$TARGETFW/ethernet/settings $FWSETTINGS; then
  echo " OK!"
 else
  error " Failed!"
 fi

fi # FWTYPE


################################################################################
# version check

echo
echo "####"
echo "#### Checking for supported versions"
echo "####"

# get source version
if grep -q linuxmuster.net "$ISSUE"; then
 OLDVERSION="$(awk '{ print $2 }' "$ISSUE")"
else
 OLDVERSION="$(awk '{ print $3 }' "$ISSUE")"
fi
echo " * Target version: $DISTFULLVERSION"
echo " * Source version: $OLDVERSION"

# test if target version is supported
match=false
for i in $RESTOREVERSIONS; do
 if stringinstring "$i" "$DISTFULLVERSION"; then
  match=true
  break
 fi
done
[ "$match" = "true" ] || error "Sorry, target version $DISTFULLVERSION is not supported."

# test if source version is supported
match=false
for i in $BACKUPVERSIONS; do
 if stringinstring "$i" "$OLDVERSION"; then
  match=true
  break
 fi
done
[ "$match" = "true" ] || error "Sorry, source version $OLDVERSION is not supported."

# test if target version is newer
[ "$OLDVERSION" \< "$DISTFULLVERSION" -o "$OLDVERSION" = "$DISTFULLVERSION" ] || error "Sorry, source version is newer than target."

# get postgresql version from target system
if [ "$MAINVERSION" = "6" ]; then
 PGOLD="8.3"
 PGNEW="9.1"
else
 PGOLD="8.1"
 PGNEW="8.3"
fi


################################################################################
# firewall and other passwords, opsi stuff

echo
echo "####"
echo "#### Passwords"
echo "####"

if [ -n "$ipcoppw" ]; then
 echo "Firewall password was already set on commandline."
elif [ "$TARGETFW" = "ipcop" -o "$TARGETFW" = "ipfire" ]; then
 while true; do
  stty -echo
  read -p "Please enter $TARGETFW's root password: " ipcoppw; echo
  stty echo
  stty -echo
  read -p "Please re-enter $TARGETFW's root password: " ipcoppwre; echo
  stty echo
  [ "$ipcoppw" = "$ipcoppwre" ] && break
  echo "Passwords do not match!"
  sleep 2
 done
fi

if [ "$TARGETFW" = "ipcop" -o "$TARGETFW" = "ipfire" ]; then
 echo -n " * saving firewall password ..."
 # saves firewall password in debconf database
 if RET=`echo set linuxmuster-base/ipcoppw "$ipcoppw" | debconf-communicate`; then
  echo " OK!"
 else
  error " Failed!"
 fi
fi

# opsi
if [ -n "$opsiip" ]; then
 if [ -n "$opsipw" ]; then
  echo "Opsi password was already set on commandline."
 else
  while true; do
   stty -echo
   read -p "Please enter Opsi's root password: " opsipw; echo
   stty echo
   stty -echo
   read -p "Please re-enter Opsi's root password: " opsipwre; echo
   stty echo
   [ "$opsipw" = "$opsipwre" ] && break
   echo "Passwords do not match!"
   sleep 2
  done
 fi
 echo -n " * saving Opsi password ..."
 # saves opsi password in debconf database
 if RET=`echo set linuxmuster-base/opsipw "$opsipw" | debconf-communicate`; then
  echo " OK!"
 else
  error " Failed!"
 fi
 # save opsi workstations entry
 opsientry="$(grep ^[a-zA-Z0-9] $WIMPORTDATA | grep ";$opsiip;" | tail -1)"
 opsiroom="$(echo "$opsientry" | awk -F\; '{ print $1 }')"
 opsigroup="$(echo "$opsientry" | awk -F\; '{ print $3 }')"
 opsimac="$(echo "$opsientry" | awk -F\; '{ print $4 }')"
fi

# saves dummy password
echo -n " * saving dummy password for admins ..."
RC=0
for i in adminpw pgmadminpw wwwadminpw; do
  RET=`echo set linuxmuster-base/$i "muster" | debconf-communicate` || RC=1
done
if [ "$RC" = "0" ]; then
 echo " OK!"
else
 error " Failed!"
fi


################################################################################
# install optional linuxmuster packages

echo
echo "####"
echo "#### Installing optional linuxmuster packages"
echo "####"

# put apt into unattended mode
export DEBIAN_FRONTEND=noninteractive
export DEBIAN_PRIORITY=critical
export DEBCONF_TERSE=yes
export DEBCONF_NOWARNINGS=yes

# tweak apt to be noninteractive
write_aptconftweak(){
 echo 'DPkg::Options {"--force-configure-any";"--force-confmiss";"--force-confold";"--force-confdef";"--force-bad-verify";"--force-overwrite";};' > "$APTCONFTWEAK"
 echo 'APT::Get::AllowUnauthenticated "true";' >> "$APTCONFTWEAK"
 echo 'APT::Install-Recommends "0";' >> "$APTCONFTWEAK"
 echo 'APT::Install-Suggests "0";' >> "$APTCONFTWEAK"
}

write_aptconftweak

# first do an upgrade
aptitude update || exit 1
aptitude -y dist-upgrade

# remove deinstalled packages from list
SELTMP="/tmp/selections.$$"
grep -v deinstall "$SELECTIONS" > "$SELTMP"

# add kde and other obsolete packages to filter variable for linuxmuster.net 6
if [ "$MAINVERSION" = "6" ]; then
 grep -q ^kde "$SELECTIONS" && PKGFILTER="k sysv ttf x $PKGFILTER"
fi

# remove obsolete packages from selections
for i in $PKGFILTER; do
 sed "/^$i/d" -i "$SELTMP"
done

# rename various packages, whose names have changed
sed -e 's|^linuxmuster-pykota|linuxmuster-pk|
        s|nagios2|nagios3|g' -i "$SELTMP"

# remove firewall packages from list
[ "$CURRENTFW" = "ipfire" -o "$CURRENTFW" = "custom" ] && sed '/ipcop/d' -i "$SELTMP"
[ "$CURRENTFW" = "ipcop" -o "$CURRENTFW" = "custom" ] && sed '/ipfire/d' -i "$SELTMP"

# purge nagios stuff if migrating from prior versions to versions >= 6
if [ "$MAINVERSION" -ge "6" -a "$OLDVERSION" \< "6" ]; then
 apt-get -y purge `dpkg -l | grep nagios | awk '{ print $2 }'`
 rm -rf /etc/nagios*
fi

# now install optional linuxmuster packages
aptitude -y install `grep ^linuxmuster $SELTMP | awk '{ print $1 }'`

# remove linuxmuster pkgs from selections
sed "/^linuxmuster/d" -i "$SELTMP"


################################################################################
# restore setup data

echo
echo "####"
echo "#### Restoring setup data"
echo "####"

# restore setup values
touch "$SOURCEDIR/debconf.cur" || exit 1
debconf-show linuxmuster-base > "$SOURCEDIR/debconf.cur"
for i in $BASEDATA; do
 if  grep -q "linuxmuster-base/$i" "$SOURCEDIR/debconf.cur"; then
  v="$(grep "linuxmuster-base/$i" "$BASEDATAFILE" | sed -e 's|\*||' | awk '{ print $2 }')"
  echo -n " * $i = $v ... "
  echo set linuxmuster-base/$i "$v" | debconf-communicate
 else
  echo -n " * $i = not on target system ... "
 fi
done

# firewall
if [ "$TARGETFW" != "$fwconfig" ]; then
 echo -n " * fwconfig = $TARGETFW ... "
 echo set linuxmuster-base/fwconfig "$TARGETFW" | debconf-communicate
 sed -e "s|^fwconfig.*|fwconfig=\"$TARGETFW\"|" -i $NETWORKSETTINGS
 fwconfig="$TARGETFW"
fi


################################################################################
# restore samba sid

echo
echo "####"
echo "#### Restoring Samba SID"
echo "####"

rm -f /var/lib/samba/secrets.tdb
sambasid="$(echo get linuxmuster-base/sambasid | debconf-communicate | awk '{ print $2 }')"
net setlocalsid "$sambasid"
net setdomainsid "$sambasid"
smbpasswd -w `cat /etc/ldap.secret`


################################################################################
# prepare firewall ssh connection

# only for ipfire|ipcop
if [ "$CURRENTFW" != "custom" ]; then

 echo
 echo "####"
 echo "#### Preparing $CURRENTFW for ssh connection"
 echo "####"

 # change ips on firewall if internal network has changed
 internsubrange="$(echo get linuxmuster-base/internsubrange | debconf-communicate | awk '{ print $2 }')"
 if [ "$internsubrange_old" != "$internsubrange" ]; then

  internsub=`echo $internsubrange | cut -f1 -d"-"`
  internsub_old=`echo $internsubrange_old | cut -f1 -d"-"`

  echo -n " * changing network address from 10.$internsub_old to 10.$internsub ..."
  if exec_ipcop /var/linuxmuster/patch-ips.sh $internsub_old $internsub; then
   echo " OK!"
  else
   error " Failed!"
  fi

  echo -n " * moving away authorized_keys file and trying to reboot ..."
  if exec_ipcop "/bin/rm -f /root/.ssh/authorized_keys && /sbin/reboot"; then
   echo " OK!"
  else
   error " Failed!"
  fi

  echo " * rebooting, please wait 60s."
  sleep 60

 else

  echo -n  " * moving away authorized_keys file ..."
  if exec_ipcop /bin/rm -f /root/.ssh/authorized_keys; then
   echo " OK!"
  else
   error " Failed!"
  fi

 fi

fi # custom


################################################################################
# linuxmuster-setup

echo
echo "####"
echo "#### Linuxmuster-Setup (first)"
echo "####"

$SCRIPTSDIR/linuxmuster-patch --first

# refresh environment
. $HELPERFUNCTIONS


################################################################################
# restore firewall settings

# only for ipcop/ipfire
if [ "$TARGETFW" != "custom" ]; then

 # if source and target are different and there are openvpn certs then restore only openvpn settings and certs
 if [ "$TARGETFW" = "$SOURCEFW" ]; then
  ovpnmsg="complete $SOURCEFW settings"
 else
  ovpncerts="$(tar -O -xzf $FWARCHIVE var/$SOURCEFW/ovpn/ovpnconfig | wc -l)"
  if [ $ovpncerts -gt 0 ]; then
   # extract openvpn stuff from archive and create a new one
   ovpnmsg="$SOURCEFW openvpn settings"
   curdir="$(pwd)"
   tmpdir="/var/tmp/migration.$$"
   mkdir -p "$tmpdir"
   tar -xzpf "$FWARCHIVE" -C "$tmpdir"
   cd "$tmpdir"
   mkdir -p "var/$TARGETFW"
   mv "var/$SOURCEFW/ovpn" "var/$TARGETFW"
   sed -e "s|$SOURCEFW|$TARGETFW|g" -i "var/$TARGETFW/ovpn/server.conf"
   [ -s "var/$TARGETFW/ovpn/openssl/ovpn.cnf" ] && sed -e "s|$SOURCEFW|$TARGETFW|g" -i "var/$TARGETFW/ovpn/openssl/ovpn.cnf"
   FWARCHIVE="/tmp/ovpn.$$.tar.gz"
   tar -czpf "$FWARCHIVE" "var/$TARGETFW"
   cd "$curdir"
   rm -rf "$tmpdir"
  fi
 fi

 if [ -n "$ovpnmsg" ]; then

  echo
  echo "####"
  echo "#### Restoring $ovpnmsg"
  echo "####"

  echo -n " * uploading $FWARCHIVE ..."
  if put_ipcop "$FWARCHIVE" /var/linuxmuster/backup.tar.gz; then
   echo " OK!"
  else
   error " Failed!"
  fi

  echo -n " * unpacking $FWARCHIVE ..."
  if exec_ipcop "/bin/tar --exclude=etc/fstab -xzpf /var/linuxmuster/backup.tar.gz -C / && /sbin/reboot"; then
   echo " OK!"
  else
   error " Failed!"
  fi

  echo " * rebooting, please wait 120s."
  sleep 120

 fi # ovpnmsg

fi # TARGETFW

 
################################################################################
# restore postgresql databases

echo
echo "####"
echo "#### Restoring postgresql databases"
echo "####"

# first restore metadata
echo -n " * metadata ..."
if psql -U postgres template1 < "$PGSQLMETA" &> "$PGSQLMETA.log"; then
 echo " OK!"
else
 error " Failed! See $PGSQLMETA.log for details!"
fi

# sets servername in ldap db
cp ldap.pgsql ldap.pgsql.bak
sed -e 's|\\\\\\\\.*\\\\|\\\\\\\\'"$servername"'\\\\|g' -i ldap.pgsql

# iterate over pgsql files
for dbfile in *.pgsql; do

 dbname="$(echo $dbfile | sed -e 's|\.pgsql||')"
 dblog="$dbname.log"
 echo -n " * $dbname ..."

 # drop an existent database
 psql -U postgres -c "\q" $dbname &> /dev/null && dropdb -U postgres $dbname

 # define db user
 case $dbname in
  pykota)
   dbuser=pykotaadmin
  ;;
  *)
   # if a user with same name as db is defined use db name as user name
   if grep -q "ALTER ROLE $dbname " "$PGSQLMETA"; then
    dbuser=$dbname
   else
    # in the other case use postgres as dbuser
    dbuser=postgres
   fi
  ;;
 esac

 echo -n " with user $dbuser ..."

 # create empty db
 createdb -U postgres -O $dbuser $dbname &> $dblog || error " Failed! See $dblog for details!"

 # dump database back
 if psql -U postgres $dbname < $dbfile 2>> $dblog 1>> $dblog; then
  echo " OK!"
 else
  error " Failed! See $dblog for details!"
 fi

done


################################################################################
# restore mysql databases

# function for upgrading horde databases, called if source system was 4.0.6
upgrade40_horde() {
 echo "Upgrading horde3 database ..."
 HORDEUPGRADE=/usr/share/doc/horde3/examples/scripts/upgrades/3.1_to_3.2.mysql.sql
 KRONOUPGRADE=/usr/share/doc/kronolith2/examples/scripts/upgrades/2.1_to_2.2.sql
 MNEMOUPGRADE=/usr/share/doc/mnemo2/examples/scripts/upgrades/2.1_to_2.2.sql
 NAGUPGRADE=/usr/share/doc/nag2/examples/scripts/upgrades/2.1_to_2.2.sql
 TURBAUPGRADE=/usr/share/doc/turba2/examples/scripts/upgrades/2.1_to_2.2_add_sql_share_tables.sql
 for i in $HORDEUPGRADE $KRONOUPGRADE $MNEMOUPGRADE $NAGUPGRADE $TURBAUPGRADE; do
  t="$(echo $i | awk -F\/ '{ print $5 }')"
  if [ -s "$i" ]; then
   echo " * $t ..."
   mysql horde < $i
  fi
 done
 # create missing columns (#477)
 echo 'ALTER TABLE nag_tasks ADD task_creator VARCHAR(255)' | mysql -D horde &> /dev/null
 echo 'ALTER TABLE nag_tasks ADD task_assignee VARCHAR(255)' | mysql -D horde &> /dev/null
 echo 'ALTER TABLE kronolith_events ADD COLUMN event_recurcount INT' | mysql -D horde &> /dev/null
 echo 'ALTER TABLE kronolith_events ADD COLUMN event_private INT DEFAULT 0 NOT NULL' | mysql -D horde &> /dev/null
 echo
}

# function for upgrading horde databases, called if source system was 5.x.x
upgrade5_horde() {
 echo "Upgrading horde3 database ..."
 KRONOUPGRADE=/usr/share/doc/kronolith2/examples/scripts/upgrades/2.2_to_2.3.sql
 MNEMOUPGRADE1=/usr/share/doc/mnemo2/examples/scripts/upgrades/2.2_to_2.2.1.sql
 MNEMOUPGRADE2=/usr/share/doc/mnemo2/examples/scripts/upgrades/2.2.1_to_2.2.2.sql
 NAGUPGRADE=/usr/share/doc/nag2/examples/scripts/upgrades/2.2_to_2.3.sql
 TURBAUPGRADE=/usr/share/doc/turba2/examples/scripts/upgrades/2.2.1_to_2.3.sql
 for i in $KRONOUPGRADE $MNEMOUPGRADE1 $MNEMOUPGRADE2 $NAGUPGRADE $TURBAUPGRADE; do
  t="$(echo $i | awk -F\/ '{ print $5 }')"
  if [ -s "$i" ]; then
   echo " * $t ..."
   mysql horde < $i
  fi
 done
}

echo
echo "####"
echo "#### Restoring mysql databases"
echo "####"

echo -n " * metadata ..."
if mysql mysql < "$MYSQLMETA" &> "$MYSQLMETA.log"; then
 echo " OK!"
else
 error " Error! See $MYSQLMETA.log for details!"
fi

for dbfile in *.mysql; do

 dbname="$(echo $dbfile | sed -e 's|\.mysql||')"
 dblog="$dbname.log"
 echo -n " * $dbname ..."

 # drop an existing database
 mysqlshow | grep -q " $dbname " && mysqladmin -f drop $dbname &> "$dblog"

 # create an empty one
 mysqladmin create $dbname 2>> "$dblog" 1>> "$dblog" || error " Failed! See $dblog for details!"

 # dump db back
 if mysql $dbname < $dbfile 2>> "$dblog" 1>> "$dblog"; then
  echo " OK!"
 else
  error " Failed! See $dblog for details!"
 fi

done

# 4.0 upgrade: horde db update
if [ "${OLDVERSION:0:3}" = "4.0" ]; then
 upgrade40_horde
 [ "$MAINVERSION" = "6" ] && upgrade5_horde
fi

# 5.0 upgrade: horde db update
[ "${OLDVERSION:0:1}" = "5" -a "$MAINVERSION" = "6" ] && upgrade5_horde


################################################################################
# install additional packages which were installed on source system
# and essential pkgs from tasks

echo
echo "####"
echo "#### Installing additional and mandatory packages"
echo "####"

# be sure all essential packages are installed
linuxmuster-task --unattended --install=common
linuxmuster-task --unattended --install=server
# imaging task is in 6.x.x obsolete
if [ "$MAINVERSION" != "6" ]; then
 imaging="$(echo get linuxmuster-base/imaging | debconf-communicate | awk '{ print $2 }')"
 linuxmuster-task --unattended --install=imaging-$imaging
fi

# write it again because it was deleted by linuxmuster-setup
write_aptconftweak

# install additional packages from list
aptitude -y install `awk '{ print $1 }' $SELTMP`
rm "$SELTMP"


################################################################################
# only for ipfire: repeat ssh connection stuff

if [ "$TARGETFW" = "ipfire" ]; then
 
 # only if ssh link works
 if ssh -oNumberOfPasswordPrompts=0 -oStrictHostKeyChecking=no -p222 $ipcopip "echo -n"; then

  echo
  echo "####"
  echo "#### Preparing once more $TARGETFW for ssh connection"
  echo "####"

  echo -n  " * moving away authorized_keys file ..."
  if exec_ipcop /bin/rm -f /root/.ssh/authorized_keys; then
   echo " OK!"
  else
   error " Failed!"
  fi
 
 fi
 
fi


################################################################################
# restore filesystem

# upgrade configuration
upgrade_configs() {

echo
 echo "####"
 echo "#### Upgrading $OLDVERSION configuration"
 echo "####"

 ### common stuff - begin ###
 
 # slapd
 echo " * slapd ..."
 CONF=/etc/ldap/slapd.conf
 LDAPDYNTPLDIR=$DYNTPLDIR/15_ldap
 cp $CONF $CONF.migration
 ldapadminpw=`grep ^rootpw $CONF | awk '{ print $2 }'`
 sed -e "s/@@message1@@/${message1}/
         s/@@message2@@/${message2}/
         s/@@message3@@/${message3}/
         s/@@basedn@@/${basedn}/g
         s/@@ipcopip@@/${ipcopip}/g
         s/@@serverip@@/${serverip}/g
         s/@@ldappassword@@/${ldapadminpw}/" $LDAPDYNTPLDIR/`basename $CONF` > $CONF
 chown root:openldap /etc/ldap/slapd.conf*
 chmod 640 /etc/ldap/slapd.conf*
 chown openldap:openldap /var/lib/ldap -R
 chmod 700 /var/lib/ldap
 chmod 600 /var/lib/ldap/*
 
 # smbldap-tools
 echo " * smbldap-tools ..."
 CONF=/etc/smbldap-tools/smbldap.conf
 cp $CONF $CONF.migration
 sed -e "s/@@sambasid@@/${sambasid}/
         s/@@workgroup@@/${workgroup}/
         s/@@basedn@@/${basedn}/" $LDAPDYNTPLDIR/`basename $CONF` > $CONF
 CONF=/etc/smbldap-tools/smbldap_bind.conf
 cp $CONF $CONF.migration
 sed -e "s/@@message1@@/${message1}/
         s/@@message2@@/${message2}/
         s/@@message3@@/${message3}/
         s/@@basedn@@/${basedn}/g
         s/@@ldappassword@@/${ldapadminpw}/g" $LDAPDYNTPLDIR/`basename $CONF` > $CONF
 chmod 600 ${CONF}*
 
 # horde 3
 echo " * horde3 ..."
 servername="$(hostname | awk -F\. '{ print $1 }')"
 domainname="$(dnsdomainname)"
 HORDDYNTPLDIR=$DYNTPLDIR/21_horde3
 # horde (static)
 CONF=/etc/horde/horde3/registry.php
 cp $CONF $CONF.migration
 cp $STATICTPLDIR/$CONF $CONF
 CONF=/etc/horde/horde3/conf.php
 cp $CONF $CONF.migration
 hordepw="$(grep "^\$conf\['sql'\]\['password'\]" $CONF | awk -F\' '{ print $6 }')"
 sed -e "s/\$conf\['auth'\]\['admins'\] =.*/\$conf\['auth'\]\['admins'\] = array\('$WWWADMIN'\);/
         s/\$conf\['problems'\]\['email'\] =.*/\$conf\['problems'\]\['email'\] = '$WWWADMIN@$domainname';/
         s/\$conf\['mailer'\]\['params'\]\['localhost'\] =.*/\$conf\['mailer'\]\['params'\]\['localhost'\] = '$servername.$domainname';/
         s/\$conf\['problems'\]\['maildomain'\] =.*/\$conf\['problems'\]\['maildomain'\] = '$domainname';/
         s/\$conf\['sql'\]\['password'\] =.*/\$conf\['sql'\]\['password'\] = '$hordepw';/" $STATICTPLDIR/$CONF > $CONF
 # kronolith (static)
 CONF=/etc/horde/kronolith2/conf.php
 cp $CONF $CONF.migration
 sed -e "s/\$conf\['storage'\]\['default_domain'\] =.*/\$conf\['storage'\]\['default_domain'\] = '$domainname';/
         s/\$conf\['reminder'\]\['server_name'\] =.*/\$conf\['reminder'\]\['server_name'\] = '$servername.$domainname';/
         s/\$conf\['reminder'\]\['from_addr'\] =.*/\$conf\['reminder'\]\['from_addr'\] = '$WWWADMIN@$domainname';/" $STATICTPLDIR/$CONF > $CONF
 # imp, turba (dynamic templates)
 for i in imp4.servers.php turba2.sources.php; do
  TPL="$HORDDYNTPLDIR/$i"
  if [ -e "$TPL" ]; then
   CONF="$(cat $TPL.target)"
   cp "$CONF" "$CONF.migration"
   sed -e "s/'@@servername@@.@@domainname@@'/'$servername.$domainname'/g
           s/'@@domainname@@'/'$domainname'/g
           s/'@@schoolname@@'/'$schoolname'/g
           s/'@@basedn@@'/'$basedn'/g
           s/'@@cyradmpw@@'/'$cyradmpw'/" "$TPL" > "$CONF"
  fi
 done
 # ingo, mnemo, nag, turba, gollem (static templates)
 for i in ingo1/conf.php mnemo2/conf.php nag2/conf.php turba2/conf.php gollem/prefs.php; do
  CONF="/etc/horde/$i"
  TPL="${STATICTPLDIR}${CONF}"
  if [ -e "$TPL" ]; then
   cp "$CONF" "$CONF.migration"
   cp "$TPL" "$CONF"
  fi
 done

 # fixing backup.conf
 echo " * backup ..."
 CONF=/etc/linuxmuster/backup.conf
 cp $CONF $CONF.migration
 sed -e "s|postgresql-$PGOLD|postgresql-$PGNEW|g
         s|cupsys|cups|g
         s|nagios2|nagios3|g" -i $CONF
 
 ### common stuff - end ###
 
 ### versions before 5 stuff - begin ###
  
 if [ $OLDVERSION \< 5 ]; then

  # freeradius
  CONF=/etc/freeradius/clients.conf
  FREEDYNTPLDIR=$DYNTPLDIR/55_freeradius
  if [ -s "$CONF" -a -d "$FREEDYNTPLDIR" ]; then
   echo " * freeradius ..."
   # fetch radiussecret
   found=false
   while read line; do
    if [ "$line" = "client $ipcopip {" ]; then
     found=true
     continue
    fi
    if [ "$found" = "true" -a "${line:0:6}" = "secret" ]; then
     radiussecret="$(echo "$line" | awk -F\= '{ print $2 }' | awk '{ print $1 }')"
    fi
    [ -n "$radiussecret" ] && break
   done <$CONF
   # patch configuration
   for i in $FREEDYNTPLDIR/*.target; do
    targetcfg=`cat $i`
    sourcetpl=`basename $targetcfg`
    [ -e "$targetcfg" ] && cp $targetcfg $targetcfg.migration
    sed -e "s|@@package@@|linuxmuster-freeradius|
            s|@@date@@|$NOW|
            s|@@radiussecret@@|$radiussecret|
            s|@@ipcopip@@|$ipcopip|
            s|@@ldappassword@@|$ldapadminpw|
            s|@@basedn@@|$basedn|" $FREEDYNTPLDIR/$sourcetpl > $targetcfg
    chmod 640 $targetcfg
    chown root:freerad $targetcfg
   done # targets
  fi

 fi

 ### versions before 5 stuff - end ###

 ### version 6 stuff - begin ###
 
 if [ "$MAINVERSION" = "6" ]; then

  # schulkonsole css img directory
  CONF="/etc/linuxmuster/schulkonsole/apache2.conf"
  cp "$CONF" "$CONF.migration"
  sed -e "s|Alias /schulkonsole/img/ .*|Alias /schulkonsole/img/ /usr/share/schulkonsole/css/img/|g
          s|Alias /favicon.ico .*|Alias /favicon.ico /usr/share/schulkonsole/css/img/favicon.ico|g" -i "$CONF"

 fi

 ### version 6 stuff - end ###
 
} # upgrade_configs

echo
echo "####"
echo "#### Restoring files and folders"
echo "####"

RC=0
servername="$(hostname -s)"
domainname="$(dnsdomainname)"
cyradmpw="$(cat /etc/imap.secret)"

# filter out non existing files from include.conf
BACKUP="$(grep ^/ "$INCONFTMP")"
for i in $BACKUP; do
 [ -e "${BACKUPFOLDER}${i}" ] && echo "$i" >> "$INCONFILTERED"
done

# filter out /etc/mysql on 6.x.x systems
[ "$MAINVERSION" = "6" ] && sed "/^\/etc\/mysql/d" -i "$INCONFILTERED"

# save quota.txt
CONF=/etc/sophomorix/user/quota.txt
cp "$CONF" "$CONF.migration.old"

# stop services
start_stop_services stop
        
# purge nagios stuff if migrating from prior versions to versions >= 6
[ "$MAINVERSION" -ge "6" -a "$OLDVERSION" \< "6" ] && rm -f /etc/nagios3/conf.d/*

# sync back
rsync -a -r -v "$INPARAM" "$EXPARAM" "$BACKUPFOLDER/" / || RC=1
if [ "$RC" = "0" ]; then
 echo "Restore successfully completed!"
else
 echo "Restore finished with error!"
fi

# upgrade configuration files
upgrade_configs

# restore opsi workstations entry
. "$NETWORKSETTINGS"
opsiip="$(echo $serverip | sed 's|.1.1|.1.2|')"
if [ -n "$opsiroom" -a -n "$opsigroup" -a -n "$opsimac" -a -n "$opsiip" ]; then
 if ! grep ^[a-zA-Z0-9] $WIMPORTDATA | grep -q ";$opsiip;"; then
  echo "Restoring opsi's workstations entry."
  opsientry="$opsiroom;opsi;$opsigroup;$opsimac;$opsiip;;1;1;1;0;0"
  echo "$opsientry" >> $WIMPORTDATA
 fi
fi

# repair permissions
chown cyrus:mail /var/spool/cyrus -R
chown cyrus:mail /var/lib/cyrus -R
chown cyrus:mail /var/spool/sieve/ -R
chgrp ssl-cert /etc/ssl/private -R
chown root:www-data /etc/horde -R
chown www-data:www-data /var/log/horde -R
find /etc/horde -type f -exec chmod 440 '{}' \;
[ -d /etc/pykota ] && chown pykota:www-data /etc/pykota -R

# start services again
start_stop_services start
if [ -e "/etc/init/ssh.conf" ]; then
 restart ssh
else
 /etc/init.d/ssh restart
fi

[ "$RC" = "0" ] || error


################################################################################
# only for ipfire: repeat ssh connection stuff part 2
# meanwhile root's ssh key has changed

if [ "$TARGETFW" = "ipfire" ]; then

 echo
 echo "####"
 echo "#### Restoring $TARGETFW ssh connection"
 echo "####"

 echo -n  " * uploading root's ssh key ... "
 mykey="$(cat /root/.ssh/id_dsa.pub)"
 [ -z "$mykey" ] && error
 if [ -s /root/.ssh/known_hosts ]; then
  for i in ipfire ipcop "$ipcopip"; do
   ssh-keygen -f "/root/.ssh/known_hosts" -R ["$i"]:222 &> /dev/null
  done
 fi
 # upload root's public key
 echo "$ipcoppw" | "$SCRIPTSDIR/sshaskpass.sh" ssh -oStrictHostKeyChecking=no -p222 "$ipcopip" "mkdir -p /root/.ssh && echo "$mykey" > /root/.ssh/authorized_keys"
 
fi


################################################################################
# restore ldap

echo
echo "####"
echo "#### Restoring ldap tree"
echo "####"

# stop service
if [ -e "/etc/init/slapd.conf" ]; then
 stop slapd
else
 /etc/init.d/slapd stop
fi

# delete old ldap tree
rm -rf /etc/ldap/slapd.d
mkdir -p /etc/ldap/slapd.d
chattr +i /var/lib/ldap/DB_CONFIG
rm /var/lib/ldap/* &> /dev/null
chattr -i /var/lib/ldap/DB_CONFIG

# sets servername and basedn in sambaHomePath
basedn_old="dc=$(grep /domainname "$BASEDATAFILE" | awk -F\: '{ print $2 }' | awk '{ print $1 }' | sed -e 's|\.|,dc=|g')"
cp "$LDIF" "$LDIF.bak"
sed -e 's|^sambaHomePath: \\\\.*\\|sambaHomePath: \\\\'"$servername"'\\|g
        s|'"$basedn_old"'|'"$basedn"'|g' -i "$LDIF"

# restore from ldif file
echo -n " * adding $LDIF ..."
if slapadd < "$LDIF"; then
 echo " OK!"
 RC=0
else
 echo " Failed!"
 RC=1
fi

# repair permissions
chown openldap:openldap /var/lib/ldap -R

# test
if [ "$RC" = "0" ]; then
 echo -n " * testing configuration ..."
 if slaptest -f /etc/ldap/slapd.conf -F /etc/ldap/slapd.d 2>> "$MIGRESTLOG" 1>> "$MIGRESTLOG"; then
  echo " OK!"
 else
  echo " Failed!"
  RC=1
 fi
fi

# repair permissions
chown -R openldap:openldap /etc/ldap

# start service again
/etc/init.d/slapd start

# exit with error
[ "$RC" = "0" ] || error


################################################################################
# reinstall linbo, perhaps it was overwritten

imaging="$(echo get linuxmuster-base/imaging | debconf-communicate | awk '{ print $2 }')"

if [ "$imaging" = "linbo" -o "$MAINVERSION" = "6" ]; then

 echo
 echo "####"
 echo "#### Reinstalling LINBO"
 echo "####"

 aptitude -y reinstall linuxmuster-linbo

fi


################################################################################
# recreate remoteadmin (not on linuxmuster.net >= 6.0)

if [ -s "$REMOTEADMIN.hash" -a $MAINVERSION -lt 6 ]; then

 echo
 echo "####"
 echo "#### Recreating $REMOTEADMIN"
 echo "####"

 id $REMOTEADMIN &> /dev/null || NOPASSWD=yes linuxmuster-remoteadmin --create
 cp /etc/shadow shadow.tmp
 sed -e "s|^$REMOTEADMIN\:\!\:|$REMOTEADMIN\:$(cat $REMOTEADMIN.hash)\:|" shadow.tmp > /etc/shadow
 rm -f shadow.tmp
 chown root:shadow /etc/shadow
 chmod 640 /etc/shadow

fi


################################################################################
# activate torrent
if [ "$TORRENT" = "1" ]; then

 echo
 echo "####"
 echo "#### Activating LINBO's torrent"
 echo "####"

 changed=""
 msg="Working on configfiles:"
 CONF=/etc/default/bittorrent
 . $CONF
 if [ "$START_BTTRACK" != "1" ]; then
  echo "$msg"
  changed=yes
  echo -n " * `basename $CONF` ..."
  cp $CONF $CONF.migration
  if sed -e 's|^START_BTTRACK=.*|START_BTTRACK=1|' -i $CONF; then
   echo " OK!"
  else
   echo " Failed!"
  fi
 fi

 CONF=/etc/default/linbo-bittorrent
 . $CONF
 if [ "$START_BITTORRENT" != "1" ]; then
  if [ -z "$changed" ]; then
   echo "$msg"
   changed=yes
  fi
  echo -n " * `basename $CONF` ..."
  cp $CONF $CONF.migration
  if sed -e 's|^START_BITTORRENT=.*|START_BITTORRENT=1|' -i $CONF; then
   echo " OK!"
  else
   echo " Failed!"
  fi
 fi

 trange="6881:6969"
 if ! grep -q ^tcp $ALLOWEDPORTS | grep "$trange"; then
  if [ -z "$changed" ]; then
   echo "$msg"
   changed=yes
  fi
  echo -n " * `basename $ALLOWEDPORTS` ..."
  newports="$(grep ^tcp $ALLOWEDPORTS | awk '{ print $2 }'),$trange"
  cp $ALLOWEDPORTS $ALLOWEDPORTS.migration
  if sed -e "s|^tcp .*|tcp $newports|" -i $ALLOWEDPORTS; then
   echo " OK!"
  else
   echo " Failed!"
  fi
 fi

 mkdir -p $LINBODIR/backup
 for i in $LINBODIR/start.conf.*; do
  dltype="$(grep -i ^downloadtype $i | awk -F\= '{ print $2 }' | awk '{ print $1 }' | tr A-Z a-z)"
  if [ "$dltype" != "torrent" ]; then
   if [ -z "$changed" ]; then
    echo "$msg"
    changed=yes
   fi
   echo -n " `basename $i` ..."
   cp "$i" "$LINBODIR/backup"
   if sed -e "s|^\[[Dd][Oo][Ww][Nn][Ll][Oo][Aa][Dd][Tt][Yy][Pp][Ee]\].*|DownloadType = torrent |g" -i $i; then  
    echo " OK!"
   else
    echo " Failed!"
   fi
  fi
 done

fi


################################################################################
# change config values defined in custom.conf

if [ -e "$CUSTOMFLAG" ]; then

 echo
 echo "####"
 echo "#### Custom setup"
 echo "####"

 rm -f "$CUSTOMFLAG"

 echo -n "Reading current configuration ..."
 for i in country state location workgroup servername domainname schoolname dsluser dslpasswd smtprelay \
          internsubrange fwconfig externtype externip externmask gatewayip dnsforwarders imaging; do
  RET="$(echo get linuxmuster-base/$i | debconf-communicate 2> /dev/null | awk '{ print $2 }')"
  oldvalue="${i}_old"
  echo "$oldvalue=\"$RET\"" >> $OLDVALUES
  unset RET
 done
 chmod 600 $OLDVALUES
 . $OLDVALUES
 echo " Done!"

 echo "Looking for modifications ..."
 changed=""

 if [ -n "$COUNTRY" -a "$COUNTRY" != "$country_old" ]; then
  echo " * COUNTRY: $country_old --> $COUNTRY"
  echo set linuxmuster-base/country "$COUNTRY" | debconf-communicate &> /dev/null
  changed=yes
 fi

 if [ -n "$STATE" -a "$STATE" != "$state_old" ]; then
  echo " * STATE: $state_old --> $STATE"
  echo set linuxmuster-base/state "$STATE" | debconf-communicate &> /dev/null
  changed=yes
 fi

 if [ -n "$LOCATION" -a "$LOCATION" != "$location_old" ]; then
  echo " * LOCATION: $location_old --> $LOCATION"
  echo set linuxmuster-base/location "$LOCATION" | debconf-communicate &> /dev/null
  changed=yes
 fi

 if [ -n "$SCHOOLNAME" -a "$SCHOOLNAME" != "$schoolname_old" ]; then
  echo " * SCHOOLNAME: $schoolname_old --> $SCHOOLNAME"
  echo set linuxmuster-base/schoolname "$SCHOOLNAME" | debconf-communicate &> /dev/null
  changed=yes
 fi

 if [ -n "$WORKGROUP" -a "$WORKGROUP" != "$workgroup_old" ]; then
  echo " * WORKGROUP: $workgroup_old --> $WORKGROUP"
  echo set linuxmuster-base/workgroup "$WORKGROUP" | debconf-communicate &> /dev/null
  changed=yes
 fi

 if [ -n "$SERVERNAME" -a "$SERVERNAME" != "$servername_old" ]; then
  echo " * SERVERNAME: $servername_old --> $SERVERNAME"
  echo set linuxmuster-base/servername "$SERVERNAME" | debconf-communicate &> /dev/null
  changed=yes
 fi

 if [ -n "$DOMAINAME" -a "$DOMAINAME" != "$domainname_old" ]; then
  echo " * DOMAINAME: $domainname_old --> $DOMAINAME"
  echo set linuxmuster-base/domainname "$DOMAINAME" | debconf-communicate &> /dev/null
  changed=yes
 fi

 if [ -n "$SMTPRELAY" -a "$SMTPRELAY" != "$smtprelay_old" ]; then
  echo " * SMTPRELAY: $smtprelay_old --> $SMTPRELAY"
  echo set linuxmuster-base/smtprelay "$SMTPRELAY" | debconf-communicate &> /dev/null
  changed=yes
 fi

 if [ -n "$INTERNSUBRANGE" -a "$INTERNSUBRANGE" != "$internsubrange_old" ]; then
  echo " * INTERNSUBRANGE: $internsubrange_old --> $INTERNSUBRANGE"
  echo set linuxmuster-base/internsubrange "$INTERNSUBRANGE" | debconf-communicate &> /dev/null
  changed=yes
 fi

 if [ -n "$FWCONFIG" -a "$FWCONFIG" != "$fwconfig_old" ]; then
  echo " * FWCONFIG: $fwconfig_old --> $FWCONFIG"
  echo set linuxmuster-base/fwconfig "$FWCONFIG" | debconf-communicate &> /dev/null
  changed=yes
 fi

 if [ -n "$changed" ]; then
  echo "Applying setup modifications, starting linuxmuster-setup (modify) ..."
  RET=`echo set linuxmuster-base/ipcoppw "$ipcoppw" | debconf-communicate`

  $SCRIPTSDIR/linuxmuster-patch --modify
 fi

fi # custom


################################################################################
# renew server certificate (if incompatible, version 6 or greater) (#107)

RENEWCERT="$(openssl x509 -noout -text -in $SERVERCERT | grep $REQENCRMETHOD)"

if [ $MAINVERSION -ge 6 -a -z "$RENEWCERT" ]; then

 echo
 echo "####"
 echo "#### Renewing server certificate"
 echo "####"
 
 $SCRIPTSDIR/create-ssl-cert.sh
 
 echo
 echo "IMPORTANT: Browser and E-Mail-Clients have to reimport the new certificate!"

fi

################################################################################
# quota

echo
echo "####"
echo "#### Checking quota"
echo "####"

# determine number of quoted partitions on target
quotaparts="$(mount | grep -c "usrquota,grpquota")"
[ $quotaparts -gt 2 ] && quotaparts=2
if [ $quotaparts -gt 0 ]; then

 # get number of quoted partitions from source
 quotaparts_old="$(cat "$QUOTAPARTS")"
 if [ $quotaparts -ne $quotaparts_old ]; then

  echo "Your quota configuration is different from source."
  echo "Quota partition(s) on source: $quotaparts_old."
  echo "Quota partition(s) on target: $quotaparts."
  echo "We try to adjust it accordingly."
  echo "Please check your quota settings after migration has finished."
  sleep 3

  CONF=/etc/sophomorix/user/quota.txt
  TCONF=/etc/sophomorix/user/lehrer.txt
  cp "$CONF" "$CONF.migration"
  cp "$TCONF" "$TCONF.migration"

  if [ $quotaparts_old -eq 0 ]; then
   # copy default quota.txt if no quota were set on source
   echo -n " * using defaults for $quotaparts partition(s) ..."
   if cp "${STATICTPLDIR}${CONF}.$quotaparts" "$CONF"; then
    echo " OK!"
   else
    error " Failed!"
   fi

  elif [ $quotaparts -eq 1 ]; then
   # reduce quota to one partition

   # work on quota.txt
   echo -n "Checking `basename "$CONF"` ..."
   changed=""
   grep ^[a-zA-Z] "$CONF.migration" | while read line; do
    user="$(echo "$line" | awk -F \: '{ print $1 }')"
    quota_old="$(echo "$line" | awk -F \: '{ print $2 }' | awk '{ print $1 }')"
    quota1="$(echo "$quota_old" | awk -F \+ '{ print $1 }')"
    quota2="$(echo "$quota_old" | awk -F \+ '{ print $2 }')"
    [ -z "$quota2" ] && continue
    if ! quota_new=$(( $quota1 +  $quota2 )); then
     error " Failed!"
    fi
    if [ -z "$changed" ]; then
     echo
     changed=yes
    fi
    echo -n " * $user: $quota_old --> $quota_new ..."
    if sed -e "s|^${user}:.*|${user}: $quota_new|" -i "$CONF"; then
     echo " OK!"
    else
     error " Failed!"
    fi
   done
   [ -z "$changed" ] && echo " nothing to do."

   # work on lehrer.txt
   echo -n "Checking `basename "$TCONF"` ..."
   changed=""
   grep ^[a-zA-Z] "$TCONF.migration" | while read line; do
    user="$(echo "$line" | awk -F \; '{ print $5 }' | awk '{ print $1 }')"
    quota_old="$(echo "$line" | awk -F \; '{ print $8 }' | awk '{ print $1 }')"
    quota1="$(echo "$quota_old" | awk -F \+ '{ print $1 }')"
    quota2="$(echo "$quota_old" | awk -F \+ '{ print $2 }')"
    [ -z "$quota2" ] && continue
    if ! quota_new=$(( $quota1 +  $quota2 )); then
     error " Failed!"
    fi
    line_new="$(echo "$line" | sed -e "s|\;${quota_old}|\;${quota_new}|")"
    if [ -z "$changed" ]; then
     echo
     changed=yes
    fi
    echo -n " * $user: $quota_old --> $quota_new ..."
    if sed -e "s|$line|$line_new|" -i "$TCONF"; then
     echo " OK!"
    else
     error " Failed!"
    fi
   done
   [ -z "$changed" ] && echo " nothing to do."

  else # expand quota for second partition

   # work on quota.txt
   echo -n "Checking `basename "$CONF"` ..."

   # get teachers default quota for second partition from previously backed up config
   TDEFAULT="$(grep ^standard-lehrer "$CONF.migration.old" | awk -F \: '{ print $2 }' | awk -F\+ '{ print $2 }')"
   [ -z "$TDEFAULT" ] && TDEFAULT=100

   changed=""
   grep ^[a-zA-Z] "$CONF.migration" | while read line; do
    user="$(echo "$line" | awk -F \: '{ print $1 }')"
    quota_old="$(echo "$line" | awk -F \: '{ print $2 }' | awk '{ print $1 }')"
    stringinstring "+" "$quota_old" && continue

    case "$user" in
     standard-lehrer) quota_new="${quota_old}+$TDEFAULT" ;;
     www-data) quota_new="0+${quota_old}" ;;
     *) quota_new="${quota_old}+0" ;;
    esac

    if [ -z "$changed" ]; then
     echo
     changed=yes
    fi
    echo -n " * $user: $quota_old --> $quota_new ..."
    if sed -e "s|^${user}:.*|${user}: $quota_new|" -i "$CONF"; then
     echo " OK!"
    else
     error " Failed!"
    fi
   done
   [ "$changed" = "yes" ] || echo " nothing to do."

   # work on lehrer.txt
   echo -n "Checking `basename "$TCONF"` ..."
   changed=""

   grep ^[a-zA-Z] "$TCONF.migration" | while read line; do
    user="$(echo "$line" | awk -F \; '{ print $5 }' | awk '{ print $1 }')"
    quota_old="$(echo "$line" | awk -F \; '{ print $8 }' | awk '{ print $1 }')"

    stringinstring "+" "$quota_old" && continue
    isinteger "$quota_old" || continue

    quota_new="${quota_old}+$TDEFAULT"
    line_new="$(echo "$line" | sed -e "s|\;${quota_old}|\;${quota_new}|")"

    if [ -z "$changed" ]; then
     echo
     changed=yes
    fi
    echo -n " * $user: $quota_old --> $quota_new ..."
    if sed -e "s|$line|$line_new|" -i "$TCONF"; then
     echo " OK!"
    else
     error " Failed!"
    fi
   done
   [ "$changed" = "yes" ] || echo " nothing to do."

  fi

 fi

fi

# quota update
sophomorix-quota --set


################################################################################
# final tasks

echo
echo "####"
echo "#### Final tasks"
echo "####"

echo -n "removing apt's unattended config ..."
rm -f "$APTCONFTWEAK"
echo " OK!"

# be sure samba runs
if [ -e /etc/init/smbd.conf ]; then
 restart smbd
else
 /etc/init.d/samba restart
fi

# repair cyrus db (#107)
/etc/init.d/cyrus-imapd stop
rm -f /var/lib/cyrus/db/*
rm -f /var/lib/cyrus/deliver.db
su -c '/usr/sbin/ctl_cyrusdb -r' cyrus
/etc/init.d/cyrus-imapd start

# reconfigure linuxmuster-pkgs finally
pkgs="base linbo schulkonsole nagios-base"
[ "$TARGETFW" != "custom" ] && pkgs="$pkgs $TARGETFW"
for i in $pkgs; do
 dpkg-reconfigure linuxmuster-$i
done

# finally be sure workstations are up to date
touch /tmp/.migration
import_workstations
rm -f /tmp/.migration

# opsi setup
if [ -n "$opsipw" ]; then
 if ping -c 2 $opsiip &> /dev/null; then
  linuxmuster-opsi --setup --first --password="$opsipw"
  linuxmuster-opsi --wsimport --quiet
  ssh "$opsiip" reboot
 else
  echo "Opsi is not available! Be sure to run"
  echo "# linuxmuster-opsi --setup --first --reboot --password=<password>"
  echo "ASAP after the migration is done."
  sleep 10
 fi
fi

# recreate aliases db
newaliases


################################################################################
# end
echo
echo "####"
echo "#### `date`"
echo -n "#### Finished."
if [ "$REBOOT" = "1" ]; then
 echo " Rebooting as requested!"
 echo "####"
 /sbin/reboot
else
 echo " Please reboot the server so the changes take effect!"
 echo "####"
fi

