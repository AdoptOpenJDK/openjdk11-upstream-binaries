#!/bin/bash
set -e

BRS_FILE=openjdk_build_deps.txt
BUILD_SCRIPT=build-openjdk11.sh

cat > $BRS_FILE <<EOF
autoconf
automake
alsa-lib-devel
binutils
cups-devel
fontconfig
freetype-devel
giflib-devel
gcc-c++
gtk2-devel
libjpeg-devel
libpng-devel
libxslt
libX11-devel
libXi-devel
libXinerama-devel
libXt-devel
libXtst-devel
pkgconfig
xorg-x11-proto-devel
zip
unzip
java-1.7.0-openjdk-devel
openssl
mercurial
wget
patch
gzip
tar
EOF

# Download and install boot JDK
#
# Originally boot-strapped with build-openjdk9.sh and build-openjdk10.sh
# For simplicity download a JDK 10 from AdoptOpenJDK
pushd /opt
wget "https://github.com/AdoptOpenJDK/openjdk10-releases/releases/download/jdk-10.0.2%2B13/OpenJDK10_x64_Linux_jdk-10.0.2%2B13.tar.gz"
tar -xf OpenJDK10_x64_Linux_jdk-10.0.2+13.tar.gz
/opt/jdk-10.0.2+13/bin/java -version
popd

yum -y install $(echo $(cat $BRS_FILE))
useradd openjdk

cat > $BUILD_SCRIPT <<EOF
#!/bin/bash
set -e

UPDATE="11.0.3"
BUILD=4
NAME="openjdk-11u-\${UPDATE}+\${BUILD}"
NAME_SUFFIX="ea-linux-x86_64"
SOURCE_NAME="\${NAME}-sources"
# Release string for the vendor. Use the GA date.
VENDOR="18.9"

CLONE_URL=https://hg.openjdk.java.net/jdk-updates/jdk11u
TAG="jdk-11.0.3+4"

clone() {
  url=\$1
  tag=\$2
  targetdir=\$3
  if [ -d \$targetdir ]; then
    echo "Target directory \$targetdir already exists. Skipping clone"
    return
  fi
  hg clone -u \$tag \$url \$targetdir
}

build() {
  rm -rf build

  # Add patch to be able to build on EL 6
  wget https://bugs.openjdk.java.net/secure/attachment/81704/JDK-8219879.jdk11.export.patch
  patch -p1 < JDK-8219879.jdk11.export.patch

  # Create a source tarball archive corresponding to the
  # binary build
  tar -c -z -f ../\$SOURCE_NAME.tar.gz --exclude-vcs --exclude='**.patch*' --exclude='overall-build.log' .

  for debug in release slowdebug; do
    bash configure \
       --with-boot-jdk="/opt/jdk-10.0.2+13/" \
       --with-debug-level="\$debug" \
       --with-conf-name="\$debug" \
       --enable-unlimited-crypto \
       --with-version-build=\$BUILD \
       --with-version-pre="" \
       --with-version-opt="" \
       --with-vendor-version-string="\$VENDOR" \
       --with-native-debug-symbols=external \
       --disable-warnings-as-errors
    target="bootcycle-images"
    if [ "\${debug}_" == "slowdebug_" ]; then
      target="images"
    fi
    make LOG=debug CONF=\$debug \$target
    # Package it up
    pushd build/\$debug/images
      if [ "\${debug}_" == "slowdebug_" ]; then
	NAME="\$NAME-\$debug"
      fi
      mv jdk \$NAME    
      tar -c -f \$NAME-\$NAME_SUFFIX.tar \$NAME --exclude='**.debuginfo'
      gzip \$NAME-\$NAME_SUFFIX.tar
      tar -c -f \$NAME-\$NAME_SUFFIX-debuginfo.tar \$(find \${NAME}/ -name \*.debuginfo)
      gzip \$NAME-\$NAME_SUFFIX-debuginfo.tar
      mv \$NAME jdk
    popd
  done
  mv ../\$SOURCE_NAME.tar.gz build/

  find \$(pwd)/build -name \*.tar.gz
}

clone \$CLONE_URL \$TAG jdk11u
pushd jdk11u
  build 2>&1 | tee overall-build.log
popd
ALL_ARTEFACTS="\$NAME-all-artefacts.tar"
tar -c -f \$ALL_ARTEFACTS \$(echo \$(find jdk11u/build -name \*.tar.gz) jdk11u/overall-build.log)
gzip \$ALL_ARTEFACTS
ls -lh \$(pwd)/*.tar.gz
EOF

cp $BUILD_SCRIPT /home/openjdk
chown -R openjdk /home/openjdk

# Drop privs and perform build
su -c "bash $BUILD_SCRIPT" - openjdk
