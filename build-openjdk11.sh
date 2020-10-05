#!/bin/bash
set -e

# Determine platform name. Currently supported:
#
# x86_64 => x64_linux
# aarch64 => aarch64_linux
#
platform_name() {
  arch=$(uname -m)
  case $arch in
  x86_64)
    echo "x64_linux"
    ;;
  aarch64)
    echo "aarch64_linux"
    ;;
  *)
    echo "Unsupported platform '$arch'" 1>&2
    exit 1
    ;;
  esac
}

UPDATE="11.0.9"
BUILD=10
NAME="openjdk-${UPDATE}_${BUILD}"
JRE_NAME="${NAME}-jre"
TEST_IMAGE_NAME="${NAME}-test-image"
TARBALL_BASE_NAME="OpenJDK11U"
EA_SUFFIX="_ea"
PLATFORM="$(platform_name)"
TARBALL_VERSION="${UPDATE}_${BUILD}${EA_SUFFIX}"
PLATFORM_VERSION="${PLATFORM}_${TARBALL_VERSION}"
TARBALL_NAME="${TARBALL_BASE_NAME}-jdk_${PLATFORM_VERSION}"
TARBALL_NAME_JRE="${TARBALL_BASE_NAME}-jre_${PLATFORM_VERSION}"
TARBALL_NAME_TEST_IMAGE="${TARBALL_BASE_NAME}-testimage_${PLATFORM_VERSION}"
TARBALL_NAME_STATIC_LIBS="${TARBALL_BASE_NAME}-static-libs_${PLATFORM_VERSION}"
SOURCE_NAME="${TARBALL_BASE_NAME}-sources_${TARBALL_VERSION}"
# Release string for the vendor. Use the GA date.
VENDOR="18.9"

CLONE_URL=https://hg.openjdk.java.net/jdk-updates/jdk11u
TAG="jdk-${UPDATE}+${BUILD}"

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
  # On some systems the per user process limit is set too low
  # by default (e.g. 1024). This may make the build fail on
  # systems with many cores (e.g. 64). Raise the limit to 1/2
  # of the maximum amount of threads allowed by the kernel.
  if [ -e /proc/sys/kernel/threads-max ]; then
    ulimit -u $(( $(cat /proc/sys/kernel/threads-max) / 2))
  fi

  rm -rf build

  # Add patch to be able to build on EL 6
  wget https://bugs.openjdk.java.net/secure/attachment/81704/JDK-8219879.jdk11.export.patch
  patch -p1 < JDK-8219879.jdk11.export.patch
  
  # Create a source tarball archive corresponding to the
  # binary build
  tar -c -z -f ../${SOURCE_NAME}.tar.gz --transform "s|^|${NAME}-sources/|" --exclude-vcs --exclude='**.patch*' --exclude='overall-build.log' .

  VERSION_PRE=""
  if [ "${EA_SUFFIX}_" != "_" ]; then
    VERSION_PRE="ea"
  fi

  # NOTE: Boot JDK downloaded from AdoptOpenJDK. Originally
  # bootstrapped with relevant build-openjdkXX.sh scripts.
  for debug in release slowdebug; do
    bash configure \
       --with-boot-jdk="/opt/openjdk-11.0.4+11/" \
       --with-debug-level="$debug" \
       --with-conf-name="$debug" \
       --enable-unlimited-crypto \
       --with-version-build=$BUILD \
       --with-version-pre="$VERSION_PRE" \
       --with-version-opt="" \
       --with-vendor-version-string="$VENDOR" \
       --with-native-debug-symbols=external \
       --disable-warnings-as-errors
    targets="bootcycle-images legacy-images test-image static-libs-image"
    if [ "${debug}_" == "slowdebug_" ]; then
      targets="images"
    fi
    make LOG=debug CONF=$debug $targets
    # Package it up
    pushd build/$debug/images
      if [ "${debug}_" == "slowdebug_" ]; then
        NAME="$NAME-$debug"
        TARBALL_NAME="$TARBALL_NAME-$debug"
      fi
      # JDK package
      mv jdk $NAME
      tar -c -f ${TARBALL_NAME}.tar --exclude='**.debuginfo' $NAME
      gzip ${TARBALL_NAME}.tar
      tar -c -f ${TARBALL_NAME}-debuginfo.tar $(find ${NAME}/ -name \*.debuginfo)
      gzip ${TARBALL_NAME}-debuginfo.tar
      mv $NAME jdk
      # JRE package produced via legacy-images (release only)
      if [ "${debug}_" == "release_" ]; then
        mv jre $JRE_NAME
        tar -c -f ${TARBALL_NAME_JRE}.tar --exclude='**.debuginfo' $JRE_NAME
        gzip ${TARBALL_NAME_JRE}.tar
        tar -c -f ${TARBALL_NAME_JRE}-debuginfo.tar $(find ${JRE_NAME}/ -name \*.debuginfo)
        gzip ${TARBALL_NAME_JRE}-debuginfo.tar
        mv $JRE_NAME jre
        # Test image (release-only: needed for after-the-fact testing with native libs)
        mv "test" $TEST_IMAGE_NAME
        tar -c -f ${TARBALL_NAME_TEST_IMAGE}.tar $TEST_IMAGE_NAME
        gzip ${TARBALL_NAME_TEST_IMAGE}.tar
        mv $TEST_IMAGE_NAME "test"
        # Static libraries (release-only: needed for building graal vm with native image)
        # Tar as overlay
        tar --transform "s|^static-libs/*|${NAME}/|" -c -f ${TARBALL_NAME_STATIC_LIBS}.tar "static-libs"
        gzip ${TARBALL_NAME_STATIC_LIBS}.tar
      fi
    popd
  done
  mv ../${SOURCE_NAME}.tar.gz build/
  find $(pwd)/build -name \*.tar.gz
}

clone $CLONE_URL $TAG jdk11u
pushd jdk11u
  build
popd
