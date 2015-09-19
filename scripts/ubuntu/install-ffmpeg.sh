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
apt-get -y install autoconf automake git-core build-essential yasm checkinstall cmake libtool libfaac-dev libgpac-dev libmp3lame-dev libopencore-amrnb-dev libopencore-amrwb-dev librtmp-dev libtheora-dev libvorbis-dev pkg-config texi2html zlib1g-dev >> $logfile 2>&1

# Use shared lib?
if [ "$arch" = "i386" -o "$arch" = "i486" -o "$arch" = "i586" -o "$arch" = "i686" ]; then
	shared=0
	log "Not using shared libraries"
else
	shared=1
	log "Using shared libraries"
fi

# Install x264
log "Removing x264...\n"
dpkg -r x264
log "Installing x264...\n"
cd "$tmpdir"
git clone --depth 1 "$x264url"
cd "x264"
if [ $shared -eq 0 ]; then
	./configure --enable-static >> $logfile 2>&1
else
	./configure --enable-shared >> $logfile 2>&1
fi
make -j$(getconf _NPROCESSORS_ONLN) >> $logfile 2>&1
checkinstall --pkgname=x264 --pkgversion="3:$(./version.sh | awk -F'[" ]' '/POINT/{print $4"+git"$5}')" --backup=no --deldoc=yes --fstrans=no --default >> $logfile 2>&1

# Install fdk-aac
log "Removing fdk-aac (AAC audio encoder)...\n"
dpkg -r fdk-aac
log "Installing fdk-aac (AAC audio encoder)...\n"
cd "$tmpdir"
git clone --depth 1 "$fdkaccurl"
cd "fdk-aac"
autoreconf -fiv >> $logfile 2>&1
if [ $shared -eq 0 ]; then
	./configure --disable-shared >> $logfile 2>&1
else
	./configure --enable-shared >> $logfile 2>&1
fi
make -j$(getconf _NPROCESSORS_ONLN) >> $logfile 2>&1
checkinstall --pkgname=fdk-aac --pkgversion="$(date +%Y%m%d%H%M)-git" --backup=no --deldoc=yes --fstrans=no --default >> $logfile 2>&1

# Install libvpx (VP8/VP9 video encoder and decoder)
# ARM build failed because Cortex A* wasn't supported
if [ "$arch" != "armv7l" ]; then
	log "Removing libvpx (VP8/VP9 video encoder and decoder)...\n"
	dpkg -r libvpx	
	log "Installing libvpx (VP8/VP9 video encoder and decoder)...\n"
	cd "$tmpdir"
	git clone --depth 1 "$libvpxurl"
	cd libvpx
	if [ $shared -eq 0 ]; then
		./configure --disable-examples --disable-unit-tests >> $logfile 2>&1
	else
		./configure --disable-examples --disable-unit-tests --enable-shared >> $logfile 2>&1
	fi
	make -j$(getconf _NPROCESSORS_ONLN) >> $logfile 2>&1
	checkinstall --pkgname=libvpx --pkgversion="1:$(date +%Y%m%d%H%M)-git" --backup=no --deldoc=yes --fstrans=no --default >> $logfile 2>&1
fi

# Install ffmpeg
log "Removing ffmpeg..."
dpkg -r ffmpeg
log "Installing ffmpeg..."
cd "$tmpdir"
git clone "$ffmpegurl"
cd ffmpeg
if [ $shared -eq 0 ]; then
	./configure --enable-gpl --enable-libfaac --enable-libmp3lame --enable-libopencore-amrnb --enable-libopencore-amrwb --enable-librtmp --enable-libtheora --enable-libvorbis --enable-libvpx --enable-libx264 --enable-nonfree --enable-version3 >> $logfile 2>&1
else
	./configure --enable-gpl --enable-libfaac --enable-libmp3lame --enable-libopencore-amrnb --enable-libopencore-amrwb --enable-librtmp --enable-libtheora --enable-libvorbis --enable-libvpx --enable-libx264 --enable-nonfree --enable-version3 --enable-shared >> $logfile 2>&1
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
