#!/bin/sh
#
# Created on September 18, 2015
#
# @author: sgoldsmith
#
# Install and configure ffmpeg for Ubuntu 14.04.3 (Desktop/Server 
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
. "$curdir"/config-ffmpeg.sh

# stdout and stderr for commands logged
logfile="$curdir/install-ffmpeg.log"
rm -f $logfile

# Ubuntu version
ubuntuver=$DISTRIB_RELEASE

# Simple logger
log(){
	timestamp=$(date +"%m-%d-%Y %k:%M:%S")
	echo "$timestamp $1"
	echo "$timestamp $1" >> $logfile 2>&1
}

log "Installing ffmpeg on Ubuntu $ubuntuver $arch..."

# Remove temp dir
log "Removing temp dir $tmpdir"
rm -rf "$tmpdir"
mkdir -p "$tmpdir"

# Remove existing ffmpeg, x264, and other dependencies (this removes a lot of other dependencies)
log "Removing pre-installed ffmpeg..."
apt-get -y autoremove ffmpeg x264 libav-tools libvpx-dev libx264-dev >> $logfile 2>&1
apt-get -y update >> $logfile 2>&1

# Install build dependenices
log "Installing build dependenices..."
#apt-get -y install autoconf automake git-core build-essential checkinstall cmake libass-dev libfreetype6-dev libsdl1.2-dev libtheora-dev libtool libva-dev libvdpau-dev libvorbis-dev libxcb1-dev libxcb-shm0-dev libxcb-xfixes0-dev pkg-config texi2html zlib1g-dev libx264-dev libfdk-aac-dev libmp3lame-dev libopus-dev libvpx-dev libopencore-amrnb-dev libopencore-amrwb-dev librtmp-dev >> $logfile 2>&1
apt-get -y install autoconf automake git-core build-essential checkinstall cmake libass-dev libfreetype6-dev libfaac-dev libgpac-dev libmp3lame-dev libopencore-amrnb-dev libopencore-amrwb-dev librtmp-dev libtheora-dev libvorbis-dev pkg-config texi2html zlib1g-dev librtmp-dev >> $logfile 2>&1

# Use shared lib?
if [ "$arch" = "i386" -o "$arch" = "i486" -o "$arch" = "i586" -o "$arch" = "i686" ]; then
	shared=0
	log "Not using shared libraries"
else
	shared=1
	log "Using shared libraries"
fi

# Install yasm
log "Removing yasm $yasmver..."
dpkg -r yasm
log "Installing yasm $yasmver..."
echo -n "Downloading $yasmurl to $tmpdir     "
wget --directory-prefix=$tmpdir --timestamping --progress=dot "$yasmurl" 2>&1 | grep --line-buffered "%" |  sed -u -e "s,\.,,g" | awk '{printf("\b\b\b\b%4s", $2)}'
echo
log "Extracting $tmpdir/$yasmarchive to $tmpdir"
tar -xf "$tmpdir/$yasmarchive" -C "$tmpdir"
cd "$tmpdir/$yasmver"
./configure >> $logfile 2>&1
make -j$(getconf _NPROCESSORS_ONLN) >> $logfile 2>&1
checkinstall --pkgname=yasm --pkgversion="1.2.0" --backup=no --deldoc=yes --fstrans=no --default >> $logfile 2>&1

# Install x264
log "Removing x264...\n"
dpkg -r x264
log "Installing x264...\n"
cd "$tmpdir"
git clone --depth 1 "$x264url"
cd "x264"
if [ $shared -eq 0 ]; then
	./configure --enable-static --disable-opencl >> $logfile 2>&1
else
	./configure --enable-shared --disable-opencl >> $logfile 2>&1
fi
make -j$(getconf _NPROCESSORS_ONLN) >> $logfile 2>&1
checkinstall --pkgname=x264 --pkgversion="3:$(./version.sh | awk -F'[" ]' '/POINT/{print $4"+git"$5}')" --backup=no --deldoc=yes --fstrans=no --default >> $logfile 2>&1

# Install ffmpeg
log "Removing ffmpeg..."
dpkg -r ffmpeg
log "Installing ffmpeg..."
cd "$tmpdir"
git clone "$ffmpegurl"
cd ffmpeg
if [ $shared -eq 0 ]; then
	./configure --enable-gpl --enable-libass --enable-libfdk-aac --enable-libfreetype --enable-libmp3lame --enable-libopencore-amrnb --enable-libopencore-amrwb --enable-librtmp --enable-libtheora --enable-libvorbis --enable-libvpx --enable-libx264 --enable-nonfree --enable-version3 >> $logfile 2>&1
else
	./configure --enable-gpl --enable-libass --enable-libfdk-aac --enable-libfreetype --enable-libmp3lame --enable-libopencore-amrnb --enable-libopencore-amrwb --enable-librtmp --enable-libtheora --enable-libvorbis --enable-libvpx --enable-libx264 --enable-nonfree --enable-version3 --enable-shared >> $logfile 2>&1
fi
make -j$(getconf _NPROCESSORS_ONLN) >> $logfile 2>&1
checkinstall --pkgname=ffmpeg --pkgversion="7:$(date +%Y%m%d%H%M)-git" --backup=no --deldoc=yes --fstrans=no --default >> $logfile 2>&1
hash -r >> $logfile 2>&1
ldconfig

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
log "Elapse time: $displaytime"
