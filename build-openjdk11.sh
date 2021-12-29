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

#
# Mapping for static-libs packaging
#
# x86_64 => amd64
# aarch64 => aach64
#
staticlibs_arch() {
  arch=$(uname -m)
  case $arch in
  x86_64)
    echo "amd64"
    ;;
  aarch64)
    echo "aarch64"
    ;;
  *)
    echo "Unsupported platform '$arch'" 1>&2
    exit 1
    ;;
  esac
}

UPDATE="11.0.14"
BUILD=8
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
TARBALL_NAME_SHENANDOAH="${TARBALL_BASE_NAME}-jdk-shenandoah_${PLATFORM_VERSION}"
TARBALL_NAME_SHENANDOAH_JRE="${TARBALL_BASE_NAME}-jre-shenandoah_${PLATFORM_VERSION}"
TARBALL_NAME_TEST_IMAGE="${TARBALL_BASE_NAME}-testimage_${PLATFORM_VERSION}"
TARBALL_NAME_SHENANDOAH_TEST_IMAGE="${TARBALL_BASE_NAME}-testimage-shenandoah_\${PLATFORM_VERSION}"
TARBALL_NAME_STATIC_LIBS="${TARBALL_BASE_NAME}-static-libs_${PLATFORM_VERSION}"
STATICLIBS_ARCH="$(staticlibs_arch)"
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
  for debug in release shenandoah slowdebug; do
    if [ "$debug" == "shenandoah" ]; then
       flag="--with-jvm-features=shenandoahgc"
       dbg_level="release"
    else
       flag=""
       dbg_level="$debug"
    fi
    bash configure \
       --with-boot-jdk="/opt/openjdk-11.0.4+11/" \
       "\$flag" \
       --with-debug-level="$dbg_level" \
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
    archive_name="$TARBALL_NAME"
    jre_archive_name="$TARBALL_NAME_JRE"
    testimage_archive_name="$TARBALL_NAME_TEST_IMAGE"
    if [ "${debug}_" == "shenandoah_" ]; then
      archive_name="$TARBALL_NAME_SHENANDOAH"
      jre_archive_name="$TARBALL_NAME_SHENANDOAH_JRE"
      testimage_archive_name="$TARBALL_NAME_SHENANDOAH_TEST_IMAGE"
    fi
    # Package it up
    pushd build/$debug/images
      if [ "${debug}_" == "slowdebug_" ]; then
        NAME="$NAME-$debug"
        TARBALL_NAME="$TARBALL_NAME-$debug"
      fi
      # JDK package
      mv jdk $NAME
      tar -c -f ${archive_name}.tar --exclude='**.debuginfo' $NAME
      gzip ${archive_name}.tar
      tar -c -f ${archive_name}-debuginfo.tar $(find ${NAME}/ -name \*.debuginfo)
      gzip ${archive_name}-debuginfo.tar
      mv $NAME jdk
      # JRE package produced via legacy-images (release only)
      if [ "${debug}_" == "release_" || "${debug}_" == "shenandoah_"]; then
        mv jre $JRE_NAME
        tar -c -f ${jre_archive_name}.tar --exclude='**.debuginfo' $JRE_NAME
        gzip ${jre_archive_name}.tar
        tar -c -f ${jre_archive_name}-debuginfo.tar $(find ${JRE_NAME}/ -name \*.debuginfo)
        gzip ${jre_archive_name}-debuginfo.tar
        mv $JRE_NAME jre
        # Test image (release-only: needed for after-the-fact testing with native libs)
        mv "test" $TEST_IMAGE_NAME
        tar -c -f ${testimage_archive_name}.tar $TEST_IMAGE_NAME
        gzip ${testimage_archive_name}.tar
        mv $TEST_IMAGE_NAME "test"
        # Static libraries (release-only: needed for building graal vm with native image)
        # Tar as overlay
        tar --transform "s|^static-libs/lib/*|${NAME}/lib/static/linux-${STATICLIBS_ARCH}/glibc/|" -c -f ${TARBALL_NAME_STATIC_LIBS}.tar "static-libs/lib"
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
