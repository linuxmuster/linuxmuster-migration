# $Id$

################################################################################
# are all necessary files present?

echo
echo "####"
echo "#### Checking for essential restore files"
echo "####"
for i in "$BACKUPFOLDER" "$BASEDATAFILE" "$LDIF" "$FWTYPE" "$FWARCHIVE" "$ISSUE" "$PGSQLMETA" "$MYSQLMETA" "$SELECTIONS" "$QUOTAPARTS"; do
 if [ -e "$i" ]; then
  echo " * $i ... OK!"
 else
  error " * $i does not exist!"
 fi
done


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
  if ! (expr match "$COUNTRY" '\([ABCDEFGHIJKLMNOPQRSTUVWXYZ][ABCDEFGHIJKLMNOPQRSTUVWXYZ]\)'); then
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

fi


################################################################################
# save firewall's network settings

echo
echo "####"
echo "#### Saving $FIREWALL's external network settings"
echo "####"

echo -n " * downloading settings file ..."
if get_ipcop /var/$FIREWALL/ethernet/settings $FWSETTINGS; then
 echo " OK!"
else
 error " Failed!"
fi


################################################################################
# version check

echo
echo "####"
echo "#### Checking for supported versions"
echo "####"

OLDVERSION="$(awk '{ print $3 }' "$ISSUE")"
echo " * Target version: $DISTFULLVERSION"
echo " * Source version: $OLDVERSION"
if ! stringinstring "$DISTFULLVERSION" "$RESTOREVERSIONS"; then
 error "Target version $DISTFULLVERSION is not supported. Please upgrade your distribution."
fi
if ! stringinstring "$OLDVERSION" "$BACKUPVERSIONS"; then
 error "I'm sorry! Source version $OLDVERSION is not supported."
fi


################################################################################
# ipcop and other passwords

echo
echo "####"
echo "#### Passwords"
echo "####"

if [ -n "$ipcoppw" ]; then
 echo "Firewall password was already set on commandline."
else
 while true; do
  stty -echo
  read -p "Please enter $FIREWALL's root password: " ipcoppw; echo
  stty echo
  stty -echo
  read -p "Please re-enter $FIREWALL's root password: " ipcoppwre; echo
  stty echo
  [ "$ipcoppw" = "$ipcoppwre" ] && break
  echo "Passwords do not match!"
  sleep 2
 done
fi

echo -n " * saving firewall password ..."
# saves firewall password in debconf database
if RET=`echo set linuxmuster-base/ipcoppw "$ipcoppw" | debconf-communicate`; then
 echo " OK!"
else
 error " Failed!"
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
# restore setup data

echo
echo "####"
echo "#### Restoring setup data"
echo "####"

# restore setup values
for i in $BASEDATA; do
 v="$(grep "linuxmuster-base/$i" "$BASEDATAFILE" | sed -e 's|\*||' | awk '{ print $2 }')"
 echo -n " * $i = $v ... "
 echo set linuxmuster-base/$i "$v" | debconf-communicate
done

# keep firewall's external network configuration

echo -n " * reading $FIREWALL settings file ..."
if . $FWSETTINGS; then
 echo " OK!"
else
 error " Failed!"
fi

RC=0
# externtype
if [ -n "$RED_TYPE" ]; then
 RED_TYPE="$(echo "$RED_TYPE" | tr A-Z a-z)"
 echo -n " * externtype = $RED_TYPE ..."
else
 error -n " * externtype = <not set> ..."
fi
echo set linuxmuster-base/externtype "$RED_TYPE" | debconf-communicate || RC=1

# externip
if [ -n "$RED_ADDRESS" ]; then
 echo -n " * externip = $RED_ADDRESS ..."
else
 echo -n " * externip = <not set> ..."
fi
echo set linuxmuster-base/externip "$RED_ADDRESS" | debconf-communicate || RC=1

# externmask
if [ -n "$RED_NETMASK" ]; then
 echo -n " * externmask = $RED_NETMASK ..."
else
 echo -n " * externmask = <not set> ..."
fi
echo set linuxmuster-base/externmask "$RED_NETMASK" | debconf-communicate || RC=1

# gatewayip
if [ -n "$DEFAULT_GATEWAY" ]; then
 echo -n " * gatewayip = $DEFAULT_GATEWAY ..."
else
 echo -n " * gatewayip = <not set> ..."
fi
echo set linuxmuster-base/gatewayip "$DEFAULT_GATEWAY" | debconf-communicate || RC=1

# dnsforwarders
if [ -n "$DNS1" -a -n "$DNS2" ]; then
 dnsforwarders="$DNS1 $DNS2"
elif [ -n "$DNS1" -a -z "$DNS2" ]; then
 dnsforwarders="$DNS1"
elif [ -z "$DNS1" -a -n "$DNS2" ]; then
 dnsforwarders="$DNS2"
fi
if [ -n "$dnsforwarders" ]; then
 echo -n " * dnsforwarders = $dnsforwarders ..."
else
 echo -n " * dnsforwarders = <not set> ..."
fi
echo set linuxmuster-base/dnsforwarders "$dnsforwarders" | debconf-communicate || RC=1

[ "$RC" = "0" ] || error "Restoring of setup data failed!"


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
sed -e "s|^SID=.*|SID=\"$sambasid\"|" -i /etc/smbldap-tools/smbldap.conf


################################################################################
# prepare firewall ssh connection

echo
echo "####"
echo "#### Preparing $FIREWALL for ssh connection"
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


################################################################################
# linuxmuster-setup

echo
echo "####"
echo "#### Linuxmuster-Setup (first)"
echo "####"
$SCRIPTSDIR/linuxmuster-patch --first


# refresh environment
. $HELPERFUNCTIONS

# restore previously backed up settings for ipcop

echo
echo "####"
echo "#### Restoring $FIREWALL"
echo "####"

echo -n " * uploading $FWARCHIVE ..."
if put_ipcop "$FWARCHIVE" /var/linuxmuster/backup.tar.gz; then
 echo " OK!"
else
 error " Failed!"
fi

echo -n " * unpacking $FWARCHIVE  ..."
if exec_ipcop "/bin/tar xzf /var/linuxmuster/backup.tar.gz -C / && /sbin/reboot"; then
 echo " OK!"
else
 error " Failed!"
fi

echo " * rebooting, please wait 60s."
sleep 60


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
[ "${OLDVERSION:0:3}" = "4.0" ] && upgrade40_horde


################################################################################
# restore package selections

echo
echo "####"
echo "#### Restoring package selections"
echo "####"

# put apt into unattended mode
export DEBIAN_FRONTEND=noninteractive
export DEBIAN_PRIORITY=critical
export DEBCONF_TERSE=yes
export DEBCONF_NOWARNINGS=yes
echo 'DPkg::Options {"--force-configure-any";"--force-confmiss";"--force-confold";"--force-confdef";"--force-bad-verify";"--force-overwrite";};' > /etc/apt/apt.conf.d/99upgrade
echo 'APT::Get::AllowUnauthenticated "true";' >> /etc/apt/apt.conf.d/99upgrade
echo 'APT::Install-Recommends "0";' >> /etc/apt/apt.conf.d/99upgrade
echo 'APT::Install-Suggests "0";' >> /etc/apt/apt.conf.d/99upgrade

# rename various packages, whose names have changed
SELTMP="/tmp/selections.$$"
sed -e 's|^linuxmuster-pykota|linuxmuster-pk|
        s|nagios2|nagios3|g
        s|cupsys|cups|g
        s|^postgresql-7.4|postgresql-8.3|
        s|^postgresql-client-7.4|postgresql-client-8.3|
        s|^postgresql-8.1|postgresql-8.3|
        s|^postgresql-client-8.1|postgresql-client-8.3|
        s|^cpp-4.1|cpp-4.3|g
        s|^gcc-4.1|gcc-4.3|g' "$SELECTIONS" > "$SELTMP"

# first do an upgrade
aptitude update
aptitude -y dist-upgrade

# filter out garbage and reinstall selections
grep -v tex "$SELTMP" | grep -v libldap | grep -v python | grep -v avahi | grep -v recode | dpkg --set-selections
apt-get -y -u dselect-upgrade
rm "$SELTMP"

# be sure all essential packages are installed
linuxmuster-task --unattended --install=common
linuxmuster-task --unattended --install=server
imaging="$(echo get linuxmuster-base/imaging | debconf-communicate | awk '{ print $2 }')"
linuxmuster-task --unattended --install=imaging-$imaging


################################################################################
# restore filesystem

# upgrade 4.0.x configuration
upgrade40() {
 echo
 echo "####"
 echo "#### Upgrading $OLDVERSION configuration"
 echo "####"
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
   [ -e "$targetcfg" ] && cp $targetcfg $targetcfg.lenny-upgrade
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
 # horde 3
 echo " * horde3 ..."
 servername="$(hostname | awk -F\. '{ print $1 }')"
 domainname="$(dnsdomainname)"
 CONF=/etc/horde/horde3/registry.php
 HORDDYNTPLDIR=$DYNTPLDIR/21_horde3
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
 # imp
 CONF=/etc/horde/imp4/conf.php
 cp $CONF $CONF.migration
 cp $STATICTPLDIR/$CONF $CONF
 CONF=/etc/horde/imp4/servers.php
 cp $CONF $CONF.migration
 sed -e "s/'@@servername@@.@@domainname@@'/'$servername.$domainname'/g
         s/'@@domainname@@'/'$domainname'/g
         s/'@@cyradmpw@@'/'$cyradmpw'/" $HORDDYNTPLDIR/imp4.`basename $CONF` > $CONF
 # ingo
 CONF=/etc/horde/ingo1/conf.php
 cp $CONF $CONF.migration
 cp $STATICTPLDIR/$CONF $CONF
 # kronolith
 CONF=/etc/horde/kronolith2/conf.php
 cp $CONF $CONF.migration
 sed -e "s/\$conf\['storage'\]\['default_domain'\] =.*/\$conf\['storage'\]\['default_domain'\] = '$domainname';/
         s/\$conf\['reminder'\]\['server_name'\] =.*/\$conf\['reminder'\]\['server_name'\] = '$servername.$domainname';/
         s/\$conf\['reminder'\]\['from_addr'\] =.*/\$conf\['reminder'\]\['from_addr'\] = '$WWWADMIN@$domainname';/" $STATICTPLDIR/$CONF > $CONF
 # mnemo
 CONF=/etc/horde/mnemo2/conf.php
 cp $CONF $CONF.migration
 cp $STATICTPLDIR/$CONF $CONF
 # nag
 CONF=/etc/horde/nag2/conf.php
 cp $CONF $CONF.migration
 cp $STATICTPLDIR/$CONF $CONF
 # turba
 CONF=/etc/horde/turba2/conf.php
 cp $CONF $CONF.migration
 cp $STATICTPLDIR/$CONF $CONF
 # fixing backup.conf
 echo " * backup ..."
 CONF=/etc/linuxmuster/backup.conf
 cp $CONF $CONF.migration
 sed -e 's|postgresql-8.1|postgresql-8.3|g
         s|cupsys|cups|g
         s|nagios2|nagios3|g' -i $CONF
} # upgrade40

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

# save quota.txt
CONF=/etc/sophomorix/user/quota.txt
cp "$CONF" "$CONF.migration.old"

# stop services
for i in /etc/rc0.d/K*; do
 for s in $SERVICES; do
  stringinstring "$s" "$i" && /etc/init.d/$s stop;
 done
done

# sync back
rsync -a -r -v --delete "$INPARAM" "$EXPARAM" "$BACKUPFOLDER/" / || RC=1
if [ "$RC" = "0" ]; then
 echo "Restore successfully completed!"
else
 echo "Restore finished with error!"
fi

# upgrade 4.0.x configuration
OLDVERSION="$(awk '{ print $3 }' "$ISSUE")"
[ "${OLDVERSION:0:3}" = "4.0" -a "$RC" = "0" ] && upgrade40

# repair permissions
chown cyrus:mail /var/spool/cyrus -R
chown cyrus:mail /var/lib/cyrus -R
chgrp ssl-cert /etc/ssl/private -R
chown root:www-data /etc/horde -R
find /etc/horde -type f -exec chmod 440 '{}' \;

# start services again
for i in /etc/rc2.d/S*; do
 for s in $SERVICES; do
  stringinstring "$s" "$i" && /etc/init.d/$s start;
 done
done
/etc/init.d/ssh restart

[ "$RC" = "0" ] || error


################################################################################
# restore ldap

echo
echo "####"
echo "#### Restoring ldap tree"
echo "####"

# stop service
/etc/init.d/slapd stop

# delete old ldap tree
rm -rf /etc/ldap/slapd.d
mkdir -p /etc/ldap/slapd.d
chattr +i /var/lib/ldap/DB_CONFIG
rm /var/lib/ldap/* &> /dev/null
chattr -i /var/lib/ldap/DB_CONFIG

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

if [ "$imaging" = "linbo" ]; then

 echo
 echo "####"
 echo "#### Reinstalling LINBO"
 echo "####"

 aptitude -y reinstall linuxmuster-linbo

fi


################################################################################
# recreate remoteadmin

if [ -s "$REMOTEADMIN.hash" ]; then

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
  RET=`echo get linuxmuster-base/$i | debconf-communicate`
  RET=${RET#[0-9] }
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

 if [ -n "$changed" ]; then
  echo "Applying setup modifications, starting linuxmuster-setup (modify) ..."
  RET=`echo set linuxmuster-base/ipcoppw "$ipcoppw" | debconf-communicate`
  $SCRIPTSDIR/linuxmuster-patch --modify
 fi

fi # custom


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
sophomorix-quota


################################################################################
# final tasks

echo
echo "####"
echo "#### Final tasks"
echo "####"

echo -n "removing apt's unattended config ..."
rm -f /etc/apt/apt.conf.d/99upgrade
echo " OK!"

# reconfigure firewall package
dpkg-reconfigure linuxmuster-$FIREWALL

# be sure samba runs
/etc/init.d/samba restart

# reconfigure base package
dpkg-reconfigure linuxmuster-base

# finally be sure workstations are up to date
import_workstations


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

