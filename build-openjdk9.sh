#!/bin/bash
set -e

UPDATE="9.0.4"
BUILD=12
NAME="openjdk-9u${UPDATE}-b${BUILD}"

CLONE_URL=https://hg.openjdk.java.net/jdk-updates/jdk9u
TAG=tip

BOOT_JDK=/usr/lib/jvm/java-1.8.0-openjdk.x86_64/
ARCH="$(uname -m)"
if [ "${ARCH}_" == "aarch64_" ]; then
  BOOT_JDK=/usr/lib/jvm/java-1.8.0-openjdk
fi

clone() {
  url=$1
  tag=$2
  targetdir=$3
  if [ -d $targetdir ]; then
    echo "Target directory $targetdir already exists. Skipping clone"
    return
  fi
  hg clone -u $tag $url $targetdir
  pushd $targetdir
    for i in corba hotspot jaxws jaxp jdk langtools nashorn; do
      hg clone -u $tag $url/$i
    done
  popd
}

build() {
  rm -rf build

  # Add patch to be able to build on EL 6
  wget https://bugs.openjdk.java.net/secure/attachment/81657/JDK-8219879.jdk9.export.patch
  patch -p1 < JDK-8219879.jdk9.export.patch

  bash common/autoconf/autogen.sh

  for debug in release slowdebug; do
    bash configure \
       --with-boot-jdk="$BOOT_JDK" \
       --with-debug-level="$debug" \
       --with-conf-name="$debug" \
       --enable-unlimited-crypto \
       --with-version-build=$BUILD \
       --with-version-pre="" \
       --with-version-opt="" \
       --with-native-debug-symbols=external \
       --with-cacerts-file=/etc/pki/java/cacerts
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

clone $CLONE_URL $TAG jdk9u
pushd jdk9u
  build
popd
