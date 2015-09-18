#!/bin/sh
#
# Created on September 17, 2015
#
# @author: sgoldsmith
#
# Install and configure JDK 8 for Ubuntu 14.04.3 (Desktop/Server 
# x86/x86_64 bit/armv7l). Please note that since some of the operations change
# configurations, etc. I cannot guarantee it will work on future or previous
# versions of Ubuntu. All testing was performed on Ubuntu 14.04.3
# LTS x86_64,x86 and armv7l with the latest updates applied. Most likely
# this will work on newer versions as well. 
#
# WARNING: This script has the ability to install/remove Ubuntu packages and it also
# installs some libraries from source. This could potentially screw up your system,
# so use with caution! I suggest using a VM for testing before using it on your
# physical systems.
#
# Steven P. Goldsmith
# sgjava@gmail.com
# 
# Prerequisites:
#
# o Install Ubuntu 14.04.3, update (I used VirtualBox for testing) and
#   make sure to select OpenSSH Server during install. Internet connection is
#   required to download libraries, frameworks, etc.
#    o sudo apt-get update
#    o sudo apt-get upgrade
#    o sudo apt-get dist-upgrade
# o Set variables in config-java.sh before running.
# o sudo ./install-java.sh
#

# Get start time
dateformat="+%a %b %-eth %Y %I:%M:%S %p %Z"
starttime=$(date "$dateformat")
starttimesec=$(date +%s)

# Get current directory
curdir=$(cd `dirname $0` && pwd)

# Source config file
. "$curdir"/config-java.sh

# stdout and stderr for commands logged
logfile="$curdir/install-java.log"
rm -f $logfile

# Ubuntu version
ubuntuver=$DISTRIB_RELEASE

# Simple logger
log(){
	timestamp=$(date +"%m-%d-%Y %k:%M:%S")
	echo "$timestamp $1"
	echo "$timestamp $1" >> $logfile 2>&1
}

log "Installing Java $jdkver on Ubuntu $ubuntuver $arch..."

# Remove temp dir
log "Removing temp dir $tmpdir"
rm -rf "$tmpdir"
mkdir -p "$tmpdir"

# Install Oracle Java JDK
echo -n "Downloading $jdkurl$jdkarchive to $tmpdir     "
wget --directory-prefix=$tmpdir --timestamping --progress=dot --no-cookies --no-check-certificate --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" "$jdkurl$jdkarchive" 2>&1 | grep --line-buffered "%" |  sed -u -e "s,\.,,g" | awk '{printf("\b\b\b\b%4s", $2)}'
echo
log "Extracting $tmpdir/$jdkarchive to $tmpdir"
tar -xf "$tmpdir/$jdkarchive" -C "$tmpdir"
log "Removing $javahome"
rm -rf "$javahome"
mkdir -p /usr/lib/jvm
log "Moving $tmpdir/$jdkver to $javahome"
mv "$tmpdir/$jdkver" "$javahome"
update-alternatives --quiet --install "/usr/bin/java" "java" "$javahome/bin/java" 1
update-alternatives --quiet --install "/usr/bin/javac" "javac" "$javahome/bin/javac" 1
# ARM JVM doesn't have Java WebStart
if [ "$arch" != "armv7l" ]; then
	update-alternatives --quiet --install "/usr/bin/javaws" "javaws" "$javahome/bin/javaws" 1
fi
# See if JAVA_HOME exists and if not add it to /etc/environment
if grep -q "JAVA_HOME" /etc/environment; then
	log "JAVA_HOME already exists"
else
	# Add JAVA_HOME to /etc/environment
	log "Adding JAVA_HOME to /etc/environment"
	echo "JAVA_HOME=$javahome" >> /etc/environment
	. /etc/environment
	log "JAVA_HOME = $JAVA_HOME"
fi
# Latest ANT without all the junk from  install ant
log "Installing Ant $antver..."
echo -n "Downloading $anturl$antarchive to $tmpdir     "
wget --directory-prefix=$tmpdir --timestamping --progress=dot "$anturl$antarchive" 2>&1 | grep --line-buffered "%" |  sed -u -e "s,\.,,g" | awk '{printf("\b\b\b\b%4s", $2)}'
echo
log "Extracting $tmpdir/$antarchive to $tmpdir"
tar -xf "$tmpdir/$antarchive" -C "$tmpdir"
log "Removing $anthome"
rm -rf "$anthome"
# In case /opt doesn't exist
mkdir -p "$anthome"
log "Moving $tmpdir/$antver to $anthome"
mv "$tmpdir/$antver" "$anthome"
# See if ANT_HOME exists and if not add it to /etc/environment
if grep -q "ANT_HOME" /etc/environment; then
	log "ANT_HOME already exists"
else
	# OpenCV make will not find ant by ANT_HOME, so create link to where it's looking
	ln -s "$antbin/ant" /usr/bin/ant
	# Add ANT_HOME to /etc/environment
	log "Adding ANT_HOME to /etc/environment"
	echo "ANT_HOME=$anthome" >> /etc/environment
	# Add $ANT_HOME/bin to PATH
	sed -i 's@games@&'":$anthome/bin"'@g' /etc/environment
	. /etc/environment
	log "ANT_HOME = $ANT_HOME"
	log "PATH = $PATH"
fi

log "Removing $tmpdir"
rm -rf "$tmpdir" 

# Get end time
endtime=$(date "$dateformat")
endtimesec=$(date +%s)

# Show elapse time
elapsedtimesec=$(expr $endtimesec - $starttimesec)
ds=$((elapsedtimesec % 60))
dm=$(((elapsedtimesec / 60) % 60))
dh=$((elapsedtimesec / 3600))
displaytime=$(printf "%02d:%02d:%02d" $dh $dm $ds)
