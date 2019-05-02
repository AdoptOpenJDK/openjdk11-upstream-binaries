#!/bin/bash
set -e

UPDATE="10.0.1"
BUILD=10
NAME="openjdk-10u-${UPDATE}-b${BUILD}"

CLONE_URL=https://hg.openjdk.java.net/jdk-updates/jdk10u
TAG=tip

clone() {
  url=$1
  tag=$2
  targetdir=$3
  if [ -d $targetdir ]; then
    echo "Target directory $targetdir already exists. Skipping clone"
    return
  fi
  hg clone -u $tag $url $targetdir
}

build() {
  rm -rf build

  # Add patch to be able to build on EL 6
  wget https://bugs.openjdk.java.net/secure/attachment/81677/JDK-8219879.jdk10.export.patch
  patch -p1 < JDK-8219879.jdk10.export.patch
  # Pragmas not allowed inside functions
  wget https://bugs.openjdk.java.net/secure/attachment/81678/JDK-8220086.jdk10.export.patch
  patch -p1 < JDK-8220086.jdk10.export.patch

  bash make/autoconf/autogen.sh

  # Note: Boot JDK 9 built on RHEL with build-openjdk9.sh
  # 
  # $ cd /opt && sudo tar -xf openjdk-9u9.0.4-b12.tar.gz
  for debug in release slowdebug; do
    bash configure \
       --with-boot-jdk="/opt/openjdk-9u9.0.4-b12" \
       --with-debug-level="$debug" \
       --with-conf-name="$debug" \
       --enable-unlimited-crypto \
       --with-version-build=$BUILD \
       --with-version-pre="" \
       --with-version-opt="" \
       --with-native-debug-symbols=external \
       --with-cacerts-file=/etc/pki/java/cacerts \
       --disable-warnings-as-errors
    target="bootcycle-images"
    if [ "${debug}_" == "slowdebug_" ]; then
      target="images"
    fi
    make LOG_LEVEL=debug CONF=$debug $target
    # Package it up
    pushd build/$debug/images
      if [ "${debug}_" == "slowdebug_" ]; then
	NAME="$NAME-$debug"
      fi
      mv jdk $NAME    
      tar -c -f $NAME.tar $NAME --exclude='**.debuginfo'
      gzip $NAME.tar
      tar -c -f $NAME-debuginfo.tar $(find ${NAME}/ -name \*.debuginfo)
      gzip $NAME-debuginfo.tar
      mv $NAME jdk
    popd
  done

  find $(pwd)/build -name \*.tar.gz
}

clone $CLONE_URL $TAG jdk10u
pushd jdk10u
  build
popd
