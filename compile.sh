#! /bin/sh

baseDirForScriptSelf=$(cd "$(dirname "$0")"; pwd)

# Read bellow and setup all that stuff correctly.
# Get the Android SDK Platform 2.1, 2.2 and 2.3 API : version 7, 8 and (9 or 10)
# or modify numbers in configure.sh and vlc-android/default.properties.
# Create an AVD with this platform.

# XXX : important!
cat << EOF
If you plan to use a device without NEON (e.g. the emulator), you need a build without NEON:
$ export NO_NEON=1
Make sure it is set throughout the entire process.

The script will attempt to automatically detect if you have NDK v7, but you can override this.
If you do not have NDK v7 or later:
export NO_NDK_V7=1
or if you are sure you have NDK v7:
export NO_NDK_V7=

EOF

# Set arm or mips here.
# If export TARGET_ARCH replace MY_TARGET_ARCH here, make in vlc/contrib/android will cause error,
# I still don't know why. Li Zheng <flyskywhy@gmail.com> 2012.03.30
export MY_TARGET_ARCH=arm

# Under Linux, if USE_MINGW is set here manually, or
# under Windows, it will build Windows application.
#
# On all modern variants of Windows (including Cygwin and Wine)
# the OS environment variable is defined to 'Windows_NT'
if [ -z ${USE_MINGW} ]; then
if [ 777${OS} = 777"Windows_NT" ]; then
export USE_MINGW=1
else
export USE_MINGW=
fi
fi

export NO_NEON=1

# If your CPU doesn't support hardware float well, disable it.
#export MSOFT_FLOAT=1

export GIT_SERVER='git@192.0.7.177:'
export VLC_BRANCH=

if [ -z `uname -m | grep 64` ]; then
export JAVA_HOME=${baseDirForScriptSelf}/../eps/mydroid/jdk1.6.0_27
else
export JAVA_HOME=${baseDirForScriptSelf}/../eps/mydroid/jdk1.6.0_27-amd64
fi
export ANDROID_NDK=${baseDirForScriptSelf}/../android-ndk-r7b
export ANDROID_SDK=${baseDirForScriptSelf}/../android-sdk

HOST_NDK_TOOLCHAINS=arm-linux-androideabi
NDK_TOOLCHAINS=${HOST_NDK_TOOLCHAINS}-4.4.3
if test ${MY_TARGET_ARCH} = "mips"; then
HOST_NDK_TOOLCHAINS=mips-linux-android
NDK_TOOLCHAINS=${HOST_NDK_TOOLCHAINS}-4.4.3
fi
export HOST_NDK_TOOLCHAINS
export NDK_TOOLCHAINS

if [ -z "$ANDROID_NDK" -o -z "$ANDROID_SDK" ]; then
   echo "You must define ANDROID_NDK and ANDROID_SDK before starting."
   echo "They must point to your NDK and SDK directories."
   exit 1
fi

if [ -z "$NO_NDK_V7" ]; then
    # try to detect NDK version
    REL=$(grep -i "r7" $ANDROID_NDK/RELEASE.TXT)
    if [ -z $REL ]; then
        export NO_NDK_V7=1
    fi
fi

# Add the NDK toolchain to the PATH, needed both for contribs and for building
# stub libraries
UNAME=`uname -s`
if [ ${UNAME} = Linux ]; then
    HOST_TAG=linux-x86
elif [ ${UNAME} = Darwin ]; then
    HOST_TAG=darwin-x86
else
    HOST_TAG=windows
fi
export PATH=${ANDROID_NDK}/toolchains/${NDK_TOOLCHAINS}/prebuilt/${HOST_TAG}/bin:${PATH}

# 1/ libvlc, libvlccore and its plugins
if [ -n "$VLC_BRANCH" ]; then

#TESTED_HASH=544af798
if [ ! -d "vlc" ]; then
    echo "VLC source not found, cloning"
    #git clone git://git.videolan.org/vlc.git vlc
    #git checkout -B android ${TESTED_HASH}
    git clone ${GIT_SERVER}/pub/gittrees/apps/vlc.git vlc
    cd vlc
    git checkout ${VLC_BRANCH}
    cd -
else
    echo "VLC source found, updating"
    cd vlc
    git fetch origin
    #git checkout -B android ${TESTED_HASH}
    git checkout ${VLC_BRANCH}
    cd -
fi

echo "Applying the patches"
cd vlc
git am ../patches/*.patch || git am --abort

echo "Building the contribs"
mkdir contrib/android; cd contrib/android

../bootstrap --host=${HOST_NDK_TOOLCHAINS} --disable-disc --disable-sout --enable-small \
    --disable-sdl \
    --disable-SDL_image \
    --disable-fontconfig \
    --disable-ass \
    --disable-freetyp2 \
    --disable-fribidi \
    --disable-zvbi \
    --disable-kate \
    --disable-caca \
    --disable-gettext \
    --disable-mpcdec \
    --disable-upnp \
    --disable-gme \
    --disable-tremor \
    --disable-vorbis \
    --disable-sidplay2 \
    --disable-samplerate

# TODO: mpeg2, dts, theora

make fetch
make

cd ../.. && mkdir -p android && cd android

if test ! -s "../configure" ; then
    echo "Bootstraping"
    ../bootstrap
fi

if test ! -s "config.h" ; then
    echo "Configuring"
    sh ../extras/package/android/configure.sh
fi

echo "Building"
make

cd ../../

fi


# 2/ VLC android UI and specific code

echo "Building Android"
export ANDROID_SYS_HEADERS_GINGERBREAD=${baseDirForScriptSelf}/android-headers-gingerbread
export ANDROID_SYS_HEADERS_ICS=${baseDirForScriptSelf}/android-headers-ics
export ANDROID_SYS_HEADERS=${ANDROID_SYS_HEADERS_GINGERBREAD}

export ANDROID_LIBS=${baseDirForScriptSelf}/android-libs
export HOST_LIBS=${baseDirForScriptSelf}/host-libs
export VLC_BUILD_DIR=vlc/android

if [ ! -f ${HOST_LIBS}/libcutils.a ]; then
    echo ""
    echo "If you get link error in host c code, try below:"
    echo "cd ${HOST_LIBS}"
    echo "./gen-libs.sh"
    echo "cd -"
    echo "then run compile.sh again"
    echo ""
    
fi

if [ -z $1 ]; then
    if [ ! -d vlc-android ]; then
        export SRC=.
    fi
else
    export SRC=$1
fi

#make -f ${baseDirForScriptSelf}/Makefile distclean
make -f ${baseDirForScriptSelf}/Makefile
