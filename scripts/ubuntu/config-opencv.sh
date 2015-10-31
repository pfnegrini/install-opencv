#!/bin/sh
#
# Created on September 18, 2015
#
# @author: sgoldsmith
#
# Make sure you change this before running install-opencv.sh script!
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

# OpenCV version
opencvver="3.0.0"
# git clone --depth 1 -b 3.0.0 https://github.com/Itseez/opencv.git
opencvcmd="git clone --depth 1 https://github.com/Itseez/opencv.git"
# Set installcontrib to True to add to cmake
installcontrib="True"
opencvcontribcmd="git clone --depth 1 https://github.com/Itseez/opencv_contrib.git"

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

# Oracle JDK
javahome=/usr/lib/jvm/jdk1.8.0

