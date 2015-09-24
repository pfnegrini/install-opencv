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
# o sudo ./install-ffmpeg.sh
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

# Install ffmpeg from PPA if installppa True
# I've only tested PPA on X86_64 platform
if [ $installppa = "True" ]; then
	log "Installing ffmpeg from PPA on Ubuntu $ubuntuver $arch..."
	log "Removing pre-installed ffmpeg..."
	apt-get -y autoremove ffmpeg x264 libav-tools libvpx-dev libx264-dev >> $logfile 2>&1
	add-apt-repository -y  ppa:kirillshkrogalev/ffmpeg-next >> $logfile 2>&1
	apt-get updatev >> $logfile 2>&1
	apt-get -y install ffmpeg >> $logfile 2>&1
else
	log "Installing ffmpeg from source on Ubuntu $ubuntuver $arch..."
	mkdir -p "$tmpdir"

	# Remove existing ffmpeg, x264, and other dependencies (this removes a lot of other dependencies)
	log "Removing pre-installed ffmpeg..."
	apt-get -y autoremove ffmpeg x264 libav-tools libvpx-dev libx264-dev >> $logfile 2>&1
	apt-get -y update >> $logfile 2>&1

	# Install build dependenices
	log "Installing build dependenices..."
	apt-get -y install autoconf build-essential checkinstall cmake git mercurial libass-dev libfaac-dev libgpac-dev libjack-jackd2-dev libmp3lame-dev libopencore-amrnb-dev libopencore-amrwb-dev librtmp-dev libsdl1.2-dev libtheora-dev libtool libva-dev libvdpau-dev libvorbis-dev libx11-dev libxext-dev libxfixes-dev pkg-config texi2html zlib1g-dev >> $logfile 2>&1

	# Use shared lib?
	if [ "$arch" = "i386" -o "$arch" = "i486" -o "$arch" = "i586" -o "$arch" = "i686" ]; then
		shared=0
		log "Not using shared libraries"
	else
		shared=1
		log "Using shared libraries"
	fi
	
	# Install yasm
	if which yasm >/dev/null; then
		yasminstver=$(yasm --version | grep "yasm 1.3.0")
	else
		yasminstver=""
	fi
	if [ "${yasminstver}" != "yasm 1.3.0" ]; then	
		log "Removing yasm $yasmver...\n"
		apt-get -y autoremove yasm >> $logfile 2>&1
		dpkg -r yasm
		log "Installing yasm $yasmver...\n"
		cd "$tmpdir"
		rm -rf "$yasmver"
		echo -n "Downloading $yasmurl to $tmpdir     "
		wget --directory-prefix=$tmpdir --timestamping --progress=dot "$yasmurl" 2>&1 | grep --line-buffered "%" |  sed -u -e "s,\.,,g" | awk '{printf("\b\b\b\b%4s", $2)}'
		echo "\nExtracting $tmpdir/$yasmarchive to $tmpdir"
		tar -xf "$tmpdir/$yasmarchive" -C "$tmpdir"
		rm -f "$yasmarchive"
		cd "$tmpdir/$yasmver"
		./configure >> $logfile 2>&1
		make >> $logfile 2>&1
		checkinstall --pkgname=yasm --pkgversion="1.3.0" --backup=no --deldoc=yes --fstrans=no --default >> $logfile 2>&1
	fi

	# Install x264
	log "Removing x264...\n"
	dpkg -r x264
	log "Installing x264...\n"
	cd "$tmpdir"
	rm -rf "x264"
	git clone --depth 1 "$x264url"
	cd "x264"
	if [ $shared -eq 0 ]; then
		./configure --enable-static >> $logfile 2>&1
	else
		./configure --enable-shared >> $logfile 2>&1
	fi
	make -j$(getconf _NPROCESSORS_ONLN) >> $logfile 2>&1
	checkinstall --pkgname=x264 --pkgversion="3:$(./version.sh | awk -F'[" ]' '/POINT/{print $4"+git"$5}')" --backup=no --deldoc=yes --fstrans=no --default >> $logfile 2>&1

	# Install x265
	if [ -d "$tmpdir/x265" ]; then
		log "Removing x265...\n"
		cd "$tmpdir/x265/build/linux"
		make uninstall >> $logfile 2>&1
		rm -rf "$tmpdir/x265"
	fi
	cd "$tmpdir"
	eval "$x265cmd"	
	cd "x265/build/linux"
	if [ $shared -eq 0 ]; then
		cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$tmpdir" -DENABLE_SHARED:bool=off ../../source >> $logfile 2>&1
	else
		cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$tmpdir" -DENABLE_SHARED:bool=on ../../source >> $logfile 2>&1
	fi
	make -j$(getconf _NPROCESSORS_ONLN) >> $logfile 2>&1
	make install >> $logfile 2>&1

	# Install fdk-aac
	log "Removing fdk-aac (AAC audio encoder)...\n"
	dpkg -r fdk-aac
	log "Installing fdk-aac (AAC audio encoder)...\n"
	cd "$tmpdir"
	rm -rf "fdk-aac"
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
	log "Removing libvpx (VP8/VP9 video encoder and decoder)...\n"
	dpkg -r libvpx	
	log "Installing libvpx (VP8/VP9 video encoder and decoder)...\n"
	cd "$tmpdir"
	rm -rf "libvpx"
	git clone --depth 1 "$libvpxurl"
	cd libvpx
	if [ $shared -eq 0 ]; then
		./configure --disable-examples --disable-unit-tests >> $logfile 2>&1
	else
		./configure --disable-examples --disable-unit-tests --enable-shared >> $logfile 2>&1
	fi
	make -j$(getconf _NPROCESSORS_ONLN) >> $logfile 2>&1
	checkinstall --pkgname=libvpx --pkgversion="1:$(date +%Y%m%d%H%M)-git" --backup=no --deldoc=yes --fstrans=no --default >> $logfile 2>&1

	# Install ffmpeg
	log "Removing ffmpeg..."
	dpkg -r ffmpeg
	log "Installing ffmpeg..."
	cd "$tmpdir"
	rm -rf "ffmpeg"
	git clone "$ffmpegurl"
	cd ffmpeg
	if [ $shared -eq 0 ]; then
		./configure --enable-gpl --enable-libass --enable-libfaac --enable-libfdk-aac --enable-libmp3lame --enable-libopencore-amrnb --enable-libopencore-amrwb --enable-librtmp --enable-libtheora --enable-libvorbis --enable-libvpx --enable-x11grab --enable-libx264 --enable-nonfree --enable-version3 >> $logfile 2>&1
	else
		./configure --enable-gpl --enable-libass --enable-libfaac --enable-libfdk-aac --enable-libmp3lame --enable-libopencore-amrnb --enable-libopencore-amrwb --enable-librtmp --enable-libtheora --enable-libvorbis --enable-libvpx --enable-x11grab --enable-libx264 --enable-nonfree --enable-version3 --enable-shared >> $logfile 2>&1
	fi
	make -j$(getconf _NPROCESSORS_ONLN) >> $logfile 2>&1
	checkinstall --pkgname=ffmpeg --pkgversion="7:$(date +%Y%m%d%H%M)-git" --backup=no --deldoc=yes --fstrans=no --default >> $logfile 2>&1
	hash -r >> $logfile 2>&1
	ldconfig
fi

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
