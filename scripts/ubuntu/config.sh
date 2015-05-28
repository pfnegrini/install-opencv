#!/bin/sh
#
# Created on Dec 18, 2013
#
# @author: sgoldsmith
#
# Make sure you set these before running any script!
#
# Steven P. Goldsmith
# sgjava@gmail.com
#

# Get architecture
arch=$(uname -m)

# Source release info
. /etc/lsb-release

# OpenCV version
opencvurl="https://github.com/Itseez/opencv.git"
opencvver="3.0.0"

# Relative path to gen_java.py
genjava="/modules/java/generator/gen_java.py"

# Relative path to core+Mat.java
mat="/modules/core/misc/java/src/java/core+Mat.java"

# Relative path to Imgproc.java
imgproc="/build/src/org/opencv/imgproc/Imgproc.java"

# Relative path to Converters.java
converters="/modules/java/generator/src/java/utils+Converters.java"

# Relative path to jdhuff.c
jdhuff="/3rdparty/libjpeg/jdhuff.c"

# Relative path to jdmarker.c
jdmarker="/3rdparty/libjpeg/jdmarker.c"

# Temp dir
tmpdir="$HOME/opencv-$opencvver-libs"

# Set to True to install Java
installjava="True"

# Oracle JDK
javahome=/usr/lib/jvm/jdk1.8.0

if [ $installjava = "True" ]; then
	if [ "$arch" = "x86_64" ]; then
		jdkurl="http://download.oracle.com/otn-pub/java/jdk/8u45-b14/"
		jdkver="jdk1.8.0_45"
		jdkarchive="jdk-8u45-linux-x64.tar.gz"
	elif [ "$arch" = "i586" ] || [ "$arch" = "i686" ]; then
		jdkurl="http://download.oracle.com/otn-pub/java/jdk/8u45-b14/"
		jdkver="jdk1.8.0_45"
		jdkarchive="jdk-8u45-linux-i586.tar.gz"
	elif [ "$arch" = "armv7l" ]; then
		jdkurl="http://download.oracle.com/otn-pub/java/jdk/8u33-b05/"
		jdkver="jdk1.8.0_33"
		jdkarchive="jdk-8u33-linux-arm-vfp-hflt.tar.gz"
	else
		echo "\nNo supported architectures detected!"
		exit 1
	fi
	# Apache Ant
	anturl="http://www.us.apache.org/dist/ant/binaries/"
	antarchive="apache-ant-1.9.4-bin.tar.gz"
	antver="apache-ant-1.9.4"
	anthome="/opt/ant"
	antbin="/opt/ant/bin"
fi

# Set to True to remove existing ffmpeg, x264, and other dependencies (this removes a lot of other dependencies you may want)
removelibs="False"

# yasm
yasmurl="http://www.tortall.net/projects/yasm/releases/yasm-1.3.0.tar.gz"
yasmarchive="yasm-1.3.0.tar.gz"
yasmver="yasm-1.3.0"

# x264
x264url="git://git.videolan.org/x264.git"

# fdk-aac
fdkaccurl="git://github.com/mstorsjo/fdk-aac.git"

# Opus
opusurl="http://downloads.xiph.org/releases/opus/opus-1.1.tar.gz"
opusarchive="opus-1.1.tar.gz"
opusver="opus-1.1"

# libvpx
libvpxurl="https://chromium.googlesource.com/webm/libvpx"

# ffmpeg
ffmpegurl="git://source.ffmpeg.org/ffmpeg.git"
