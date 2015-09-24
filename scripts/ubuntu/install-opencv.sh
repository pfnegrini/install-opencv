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
# o sudo ./install-opencv.sh
#

# Get start time
dateformat="+%a %b %-eth %Y %I:%M:%S %p %Z"
starttime=$(date "$dateformat")
starttimesec=$(date +%s)

# Get current directory
curdir=$(cd `dirname $0` && pwd)

# Source config file
. "$curdir"/config-opencv.sh

# stdout and stderr for commands logged
logfile="$curdir/install-opencv.log"
rm -f $logfile

# Ubuntu version
ubuntuver=$DISTRIB_RELEASE

# Simple logger
log(){
	timestamp=$(date +"%m-%d-%Y %k:%M:%S")
	echo "$timestamp $1"
	echo "$timestamp $1" >> $logfile 2>&1
}

log "Installing OpenCV $opencvver on Ubuntu $ubuntuver $arch..."

# Remove temp dir
log "Removing temp dir $tmpdir"
rm -rf "$tmpdir"
mkdir -p "$tmpdir"

# Make sure root picks up JAVA_HOME for this process
export JAVA_HOME=$javahome
log "JAVA_HOME = $JAVA_HOME"

log "Installing OpenCV dependenices..."
# Install build tools
apt-get -y install autoconf automake git-core build-essential checkinstall cmake libtool
# Install Image I/O libraries 
apt-get -y install libtiff4-dev libjpeg-dev libjasper-dev >> $logfile 2>&1
# Install Video I/O libraries, support for Firewire video cameras and video streaming libraries
apt-get -y install libav-tools libavcodec-dev libavformat-dev libswscale-dev libxine-dev libgstreamer0.10-dev libgstreamer-plugins-base0.10-dev libv4l-dev v4l-utils v4l-conf >> $logfile 2>&1
# Install the Python development environment and the Python Numerical library
apt-get -y install python-dev python-numpy >> $logfile 2>&1
# Install the parallel code processing library (the Intel tbb library)
apt-get -y install libtbb-dev >> $logfile 2>&1
# Install the Qt dev library
apt-get -y install libqt4-dev libgtk2.0-dev >> $logfile 2>&1
# Install other dependencies (if need be it would upgrade current version of the packages)
apt-get -y install patch subversion ruby librtmp0 librtmp-dev libfaac-dev libmp3lame-dev libopencore-amrnb-dev libopencore-amrwb-dev libvpx-dev libxvidcore-dev >> $logfile 2>&1
# Install optional packages
apt-get -y install libdc1394-utils libdc1394-22-dev libdc1394-22 libjpeg-dev libpng-dev libtiff-dev libjasper-dev ocl-icd-opencl-dev >> $logfile 2>&1

# Uninstall OpenCV if it exists
opencvhome="$HOME/opencv-$opencvver"
if [ -d "$opencvhome" ]; then
	log "Uninstalling OpenCV"
	cd "$opencvhome/build"
	make uninstall >> $logfile 2>&1
fi

# Download OpenCV source
cd "$tmpdir"
eval "$opencvcmd"
log "Removing $opencvhome"
rm -rf "$opencvhome"
log "Copying $tmpdir/opencv to $opencvhome"
cp -r "$tmpdir/opencv" "$opencvhome"

# Patch source pre-compile
log "Patching source pre-compile"

# Patch jdhuff.c to remove "Invalid SOS parameters for sequential JPEG" warning
sed -i 's~WARNMS(cinfo, JWRN_NOT_SEQUENTIAL);~//WARNMS(cinfo, JWRN_NOT_SEQUENTIAL);\n      ; // NOP~g' "$opencvhome$jdhuff"

# Patch jdmarker.c to remove "Corrupt JPEG data: xx extraneous bytes before marker 0xd9" warning
#sed -i 's~WARNMS2(cinfo, JWRN_EXTRANEOUS_DATA~//WARNMS2(cinfo, JWRN_EXTRANEOUS_DATA~g' "$opencvhome$jdmarker"

# Patch gen_java.py to generate VideoWriter by removing from class_ignore_list
# This shouldn't be needed any more see https://github.com/Itseez/opencv/pull/5255
sed -i 's/\"VideoWriter\",/'\#\"VideoWriter\",'/g' "$opencvhome$genjava"

# Patch gen_java.py to generate constants by removing from const_ignore_list
sed -i 's/\"CV_CAP_PROP_FPS\",/'\#\"CV_CAP_PROP_FPS\",'/g' "$opencvhome$genjava"
sed -i 's/\"CV_CAP_PROP_FOURCC\",/'\#\"CV_CAP_PROP_FOURCC\",'/g' "$opencvhome$genjava"
sed -i 's/\"CV_CAP_PROP_FRAME_COUNT\",/'\#\"CV_CAP_PROP_FRAME_COUNT\",'/g' "$opencvhome$genjava"

# Patch gen_java.py to generate nativeObj as not final, so it can be modified by free() method
sed -i ':a;N;$!ba;s/protected final long nativeObj/protected long nativeObj/g' "$opencvhome$genjava"

# Patch gen_java.py to generate free() instead of finalize() methods
sed -i ':a;N;$!ba;s/@Override\n    protected void finalize() throws Throwable {\n        delete(nativeObj);\n    }/public void free() {\n        if (nativeObj != 0) {\n            delete(nativeObj);\n            nativeObj = 0;\n        }    \n    }/g' "$opencvhome$genjava"

# Patch gen_java.py to generate Mat.free() instead of Mat.release() methods
sed -i 's/mat.release()/mat.free()/g' "$opencvhome$genjava"

# Patch core+Mat.java remove final fron nativeObj, so new free() method can change
sed -i 's~public final long nativeObj~public long nativeObj~g' "$opencvhome$mat"

# Patch core+Mat.java to replace finalize() with free() method
sed -i ':a;N;$!ba;s/@Override\n    protected void finalize() throws Throwable {\n        n_delete(nativeObj);\n        super.finalize();\n    }/public void free() {\n        if (nativeObj != 0) {\n            release();\n            n_delete(nativeObj);\n            nativeObj = 0;\n        }    \n    }/g' "$opencvhome$mat"

# Patch utils+Converters.java to replace mi.release() with mi.free()
sed -i 's/mi.release()/mi.free()/g' "$opencvhome$converters"

# Compile OpenCV
log "Compile OpenCV..."
cd "$opencvhome"
mkdir build
cd build

#
# Change cmake as needed for custom build.
#

# If ARM then compile with multi-core, FPU and NEON extensions
if [ "$arch" = "armv7l" ]; then
    # Added -D CMAKE_CXX_FLAGS_RELEASE="-Wa,-mimplicit-it=thumb" to fix "Error: thumb conditional instruction should be in IT block"
    cmake -D CMAKE_BUILD_TYPE=RELEASE -D CMAKE_INSTALL_PREFIX=/usr/local -D WITH_CUBLAS=ON -D WITH_CUFFT=ON -D WITH_EIGEN=ON -D WITH_OPENGL=ON -D WITH_QT=OFF -D WITH_TBB=ON -D BUILD_SHARED_LIBS=ON -D BUILD_DOCS=ON -D BUILD_EXAMPLES=ON -D BUILD_TESTS=ON -D BUILD_JPEG=ON -D ENABLE_VFPV3=ON -D ENABLE_NEON=ON -D CMAKE_CXX_FLAGS_RELEASE="-Wa,-mimplicit-it=thumb" .. >> $logfile 2>&1	
else
    cmake -D CMAKE_BUILD_TYPE=RELEASE -D CMAKE_INSTALL_PREFIX=/usr/local -D WITH_CUBLAS=ON -D WITH_CUFFT=ON -D WITH_EIGEN=ON -D WITH_OPENGL=ON -D WITH_QT=OFF -D WITH_TBB=ON -D BUILD_SHARED_LIBS=ON -D BUILD_DOCS=ON -D BUILD_EXAMPLES=ON -D BUILD_TESTS=ON -D BUILD_JPEG=ON .. >> $logfile 2>&1	
fi
make -j$(getconf _NPROCESSORS_ONLN) >> $logfile 2>&1
make install >> $logfile 2>&1
echo "/usr/local/lib" > /etc/ld.so.conf.d/opencv.conf
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
