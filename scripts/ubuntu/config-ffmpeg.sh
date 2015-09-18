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

# yasm
yasmurl="http://www.tortall.net/projects/yasm/releases/yasm-1.3.0.tar.gz"
yasmarchive="yasm-1.3.0.tar.gz"
yasmver="yasm-1.3.0"

# ffmpeg
ffmpegurl="git://source.ffmpeg.org/ffmpeg.git"
