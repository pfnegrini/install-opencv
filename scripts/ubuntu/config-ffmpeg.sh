#!/bin/sh
#
# Created on September 18, 2015
#
# @author: sgoldsmith
#
# Make sure you change this before running install-ffmpeg.sh script!
#
# Steven P. Goldsmith
# sgjava@gmail.com
#

# Get architecture
arch=$(uname -m)

# Source release info
. /etc/lsb-release

# Temp dir
tmpdir="$HOME/temp"

# x264
x264url="git://git.videolan.org/x264.git"

# fdk-aac
fdkaccurl="git://github.com/mstorsjo/fdk-aac.git"

# Opus
# Need to test opus-1.1.1-beta.tar.gz
opusurl="http://downloads.xiph.org/releases/opus/opus-1.1.tar.gz"
opusarchive="opus-1.1.tar.gz"
opusver="opus-1.1"

# libvpx
libvpxurl="https://chromium.googlesource.com/webm/libvpx"

# ffmpeg
ffmpegurl="git://source.ffmpeg.org/ffmpeg.git"
