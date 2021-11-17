	@echo on
	setlocal EnableDelayedExpansion

	if not defined source_dir (
		rem this is a local build
		set source_dir=
		set spec_dir=
		set DOWNLOAD_TOOLS=1
		set DOWNLOAD_JDK_SOURCE=1
		set CONFIGURE_JDK=1
		set BUILD_JDK=1
		set BUILD_STATIC_LIBS=1
		set BUILD_JRE=1
		set BUILD_JDK_TESTIMAGE=1
		set BUILD_JDK_SHENANDOAH=1
		set BUILD_DEMOS=1
		set PACKAGE_RELEASE=1
		set BUILD_GRAAL_JDK=
		set BUILD_GRAAL=
		set JDK_GIT_REPO=
	)
	
	rem define source version
	set UPDATE=11.0.14
	set BUILD=3
	set MILESTONE=openjdk
	set RELEASE_DATE=
	set OJDK_MILESTONE=11u
	set VENDOR_VERSION_STRING=18.9
	set OJDK_UPDATE=%UPDATE%
	set OJDK_BUILD=%BUILD%
	set OJDK_TAG=jdk-%OJDK_UPDATE%+%OJDK_BUILD%

	rem comment out for GA builds
	set EARLY_ACCESS=_ea
	rem if x%EARLY_ACCESS% == x set OJDK_TAG=jdk-%OJDK_UPDATE%-ga

	rem uncomment to retrieve from jdk11u-dev repository
	rem DEV_REPO=-dev

	rem uncomment and define to fetch OpenJDK source from GIT repo
	set JDK_GIT_REPO=https://github.com/openjdk/jdk11u%DEV_REPO%.git

	rem define build characteristics

	rem define to clean the build before compile
	set CLEAN_BUILD=

	rem valid choices: release slowdebug fastdebug
	set OJDK_DEBUG_LEVEL=release

	rem log level for JDK 'make': valid choices info debug
	set LOG_LEVEL=info
	
	rem extra flags to config - developer
	set CONFIG_EXTRA_FLAGS=

	rem extra flags to config - build system (set blank; will change during build)
	set CONFIG_PASS_FLAGS=

	rem try to shorten paths for cygwin
	rem perform all work in cygwin /tmp directory
	rem use forward slashes
	if not defined source_dir (
		rem batch file build
		set WORK_DIR=C:/tmp/build-11
		set source_dir=!WORK_DIR!
		set spec_dir=%~dp0
	) else (
		rem cloud build
		set WORK_DIR=C:/tmp/build-11
		echo ** SPEC_DIR is %SPEC_DIR% **
		if not defined spec_dir (
			set spec_dir=%source_dir:\=/%
		)
	)
	if not exist %WORK_DIR% mkdir "%WORK_DIR%"

	rem CPU build or regular vanilla upstream
	set CPU_MODE=

	rem Git/HG checkout of OpenJDK source
	set USE_SCS=1
	if defined JDK_GIT_REPO (
		set USE_GIT=1
		set USE_MERCURIAL=
	) else (
		set USE_GIT=
		set USE_MERCURIAL=1
	)

	rem JDK 11 can use JDK 10 (standard) or JDK 11 (required by 11.0.6+5 only)
	set BOOTSTRAP_JDK_VERSION=10

	rem define to enable JDK testing
	rem set JTREG_HOME=c:/jtreg
	
	rem JDK configure script options

	if defined JTREG_HOME (
		set OJDK_DEBUG_LEVEL=fastdebug
	)

	set OJDK_CONF=win64-%OJDK_DEBUG_LEVEL%

	rem if set, delete debug files
	if ".%OJDK_DEBUG_LEVEL%" == ".release" (
		set DELETE_DEBUG_FILES=1
	)

	if defined BUILD_JDK (
		if defined JTREG_HOME (
			set TEST_JDK=1
		)
	)

	rem define build tools repo and version
	set OJDKBUILD_REPOBASE=https://github.com/ojdkbuild
	set OJDKBUILD_TAG=b7bc723e18deefef701752b57dbd25c0072ef4a7

	set PATH=C:/Windows/system32;C:/Windows
	set PATH=C:/cygwin64/bin;%PATH%

	rem comment out to disable AV scan
	rem set CLAMSCAN=C:/cygwin64/bin/clamscan.exe

	rem local directory for build toolchain, tools and libraries
	set OJDKBUILD_DIR=%WORK_DIR%/ojdkbuild

	rem local directory to clone JDK repo into
	set OJDK_SRC_DIR=jdk%OJDK_MILESTONE%%DEV_REPO%
	set OJDK_SRC_PATH=%WORK_DIR%/%OJDK_SRC_DIR%

	rem the remote repo for JDK sources
	if defined JDK_GIT_REPO (
		set OJDK_REMOTE_REPO=%JDK_GIT_REPO%
	) else (
		set OJDK_REMOTE_REPO_PROTOCOL=https://
		set OJDK_REMOTE_REPO=hg.openjdk.java.net/jdk-updates/jdk%OJDK_MILESTONE%%DEV_REPO%
	)

	rem ZIP_DIR_NAME is the directory the zipfile (RELEASE_ZIPFILE) will unpack into
	if defined BUILD_JDK (
		set ZIP_DIR_NAME=openjdk-%OJDK_UPDATE%_%OJDK_BUILD%
		set RELEASE_ZIPFILE=OpenJDK%OJDK_MILESTONE%-jdk_x64_windows_%OJDK_UPDATE%_%OJDK_BUILD%%EARLY_ACCESS%.zip
		@echo final JDK product will be !RELEASE_ZIPFILE! directory !ZIP_DIR_NAME!
	)

	if defined BUILD_STATIC_LIBS (
		set RELEASE_STATIC_LIB_ZIPFILE=OpenJDK%OJDK_MILESTONE%-static-libs_x64_windows_%OJDK_UPDATE%_%OJDK_BUILD%%EARLY_ACCESS%.zip
		set STATIC_LIB_DIR=lib/static/windows-amd64
	)

	if defined BUILD_JRE (
		set ZIP_JRE_DIR_NAME=openjdk-%OJDK_UPDATE%_%OJDK_BUILD%-jre
		set RELEASE_JRE_ZIPFILE=OpenJDK%OJDK_MILESTONE%-jre_x64_windows_%OJDK_UPDATE%_%OJDK_BUILD%%EARLY_ACCESS%.zip
		@echo final JRE product will be !RELEASE_JRE_ZIPFILE! directory !ZIP_JRE_DIR_NAME!
	)

	if defined BUILD_JDK_TESTIMAGE (
		set ZIP_TESTIMAGE_DIR_NAME=openjdk-%OJDK_UPDATE%_%OJDK_BUILD%-test-image
		set RELEASE_TESTIMAGE_ZIPFILE=OpenJDK%OJDK_MILESTONE%-testimage_x64_windows_%OJDK_UPDATE%_%OJDK_BUILD%%EARLY_ACCESS%.zip
		@echo final TESTIMAGE product will be !RELEASE_TESTIMAGE_ZIPFILE! directory !ZIP_TESTIMAGE_DIR_NAME!
	)
	
	rem fix all names if graal JDK being produced
	if defined BUILD_GRAAL_JDK (
		set ZIP_DIR_NAME=openjdk%OJDK_MILESTONE%-graal
		set RELEASE_ZIPFILE=openjdk%OJDK_MILESTONE%-graal.zip
		@echo final JDK product will be !RELEASE_ZIPFILE! directory !ZIP_DIR_NAME!
		set RELEASE_STATIC_LIB_ZIPFILE=openjdk%OJDK_MILESTONE%-graal-static-libs
		set ZIP_JRE_DIR_NAME=openjdk%OJDK_MILESTONE%-graal-jre
		set RELEASE_JRE_ZIPFILE=openjdk%OJDK_MILESTONE%-graal-jre.zip
		set ZIP_TESTIMAGE_DIR_NAME=openjdk%OJDK_MILESTONE%-graal-testimage
		set RELEASE_TESTIMAGE_ZIPFILE=openjdk%OJDK_MILESTONE%-graal-testimage
	)

	rem always download git/hg as these tools need to be set up correctly
	call :download_git || exit /b 1
	if defined USE_MERCURIAL (
		call :download_mercurial || exit /b 1
	)

	set SAVEPATH=%PATH% 
	if defined DOWNLOAD_TOOLS ( 
		call :download_ojdkbuild || exit /b 1
	) else (
		@echo *** skipping JDK tool downloads
	)

	if defined DOWNLOAD_JDK_SOURCE (
		if defined BUILD_JVMCI (
			call :checkout_lab_jdk_source || exit /b 1
		) else (
			call :checkout_jdk_source || exit /b 1
		)
	)
	
	if not defined RELEASE_DATE (
		pushd "%OJDK_SRC_PATH%" || exit /b 1
		FOR /F "tokens=* USEBACKQ" %%F IN (`\cygwin64\bin\bash -c ". ./make/autoconf/version-numbers ; echo $DEFAULT_VERSION_DATE"`) DO (
			SET RELEASE_DATE=%%F
		)
		popd
		@echo *** release date from version-numbers is !RELEASE_DATE!
	)

	if defined CLEAN_BUILD (
		call :clean_jdk || exit /b 1
	)
	
	if defined CONFIGURE_JDK (
		call :configure_jdk_build || exit /b 1
	)

	if defined BUILD_JDK (
		set CONFIG_PASS_FLAGS=
		call :build_jdk || exit /b 1
		call :test_jdk_version || exit /b 1
		if defined BUILD_JDK_TESTIMAGE (
			call :build_testimage_zip
		)
		if defined PACKAGE_RELEASE (
			call :build_jdk_zip || exit /b 1
		)
		if defined BUILD_JRE (
			call :build_jre_zip || exit /b 1
		)
		if defined BUILD_STATIC_LIBS (
			call :build_static_lib_zip || exit /b 1
		)
		@echo *** JDK build completed
	) else (
		@echo *** skipping jdk build
	)

	echo *** BUILD_JDK_SHENANDOAH = %BUILD_JDK_SHENANDOAH% ***
	if defined BUILD_JDK_SHENANDOAH (
		set OJDK_CONF=ojdk-shenandoah
		set ZIP_DIR_NAME=openjdk-%OJDK_UPDATE%_%OJDK_BUILD%
		set RELEASE_ZIPFILE=OpenJDK%OJDK_MILESTONE%-jdk-shenandoah_x64_windows_%OJDK_UPDATE%_%OJDK_BUILD%%EARLY_ACCESS%.zip
		@echo final shenandoah JDK product will be !RELEASE_ZIPFILE! directory !ZIP_DIR_NAME!
		set ZIP_JRE_DIR_NAME=openjdk-%OJDK_UPDATE%_%OJDK_BUILD%-jre
		set RELEASE_JRE_ZIPFILE=OpenJDK%OJDK_MILESTONE%-jre-shenandoah_x64_windows_%OJDK_UPDATE%_%OJDK_BUILD%%EARLY_ACCESS%.zip
		@echo final shenandoah JRE product will be !RELEASE_JRE_ZIPFILE! directory !ZIP_JRE_DIR_NAME!
		set ZIP_TESTIMAGE_DIR_NAME=openjdk-%OJDK_UPDATE%_%OJDK_BUILD%-test-image
		set RELEASE_TESTIMAGE_ZIPFILE=OpenJDK%OJDK_MILESTONE%-testimage-shenandoah_x64_windows_%OJDK_UPDATE%_%OJDK_BUILD%%EARLY_ACCESS%.zip
		@echo final shenandoah TESTIMAGE product will be !RELEASE_TESTIMAGE_ZIPFILE! directory !ZIP_TESTIMAGE_DIR_NAME!
		set CONFIG_PASS_FLAGS=--with-jvm-features=shenandoahgc
		call :configure_jdk_build || exit /b 1
		call :build_jdk || exit /b 1
		call :test_jdk_version || exit /b 1
		if defined BUILD_JDK_TESTIMAGE (
			call :build_testimage_zip
		)
		call :build_jdk_zip || exit /b 1
		if defined BUILD_JRE (
			call :build_jre_zip || exit /b 1
		)
		if defined BUILD_STATIC_LIBSxx (
			call :build_static_lib_zip || exit /b 1
		)
		@echo *** shenandoah JDK build completed
	)

	if defined TEST_JDK (
		call :setsdkenv
		call :test_jdk || exit /b 1
	) else (
		@echo *** skipping jdk testing
	)

	@echo *** all done ***
	exit /b 0

	:checkout_lab_jdk_source
	@echo *** checkout the JDK used to build Graal
	set PATH=%OJDKBUILD_DIR%/tools/cygwin_jdk11/bin;%PATH%
	if not exist "%OJDK_SRC_PATH%" (
		cd %WORK_DIR%
		%GIT% clone https://github.com/graalvm/labs-openjdk-11.git %OJDK_SRC_DIR% || exit /b 1
		@echo ** fix ownership and permissions
		takeown /f "%OJDK_SRC_PATH:/=\%" /r > nul || exit /b 1
		icacls "%OJDK_SRC_PATH:/=\%" /reset /T /Q || exit /b 1
	)
	exit /b 0

	:checkout_jdk_source
	@echo *** checkout the JDK
	@echo *** fetch JDK base repo
	rem set PATH=%OJDKBUILD_DIR%/tools/cygwin_jdk11/bin;%PATH%
	if not exist "%OJDK_SRC_PATH%" (
		cd "%WORK_DIR%"
		if defined USE_GIT (
			%GIT% clone %OJDK_REMOTE_REPO% %OJDK_SRC_DIR% || exit /b 1
			if defined OJDK_TAG (
				cd %OJDK_SRC_DIR% || exit /b 1
				%GIT% checkout "%OJDK_TAG%" || exit /b 1
			)
		)
		if defined USE_MERCURIAL (
			if defined OJDK_TAG (
				%HG% clone -u %OJDK_TAG% %OJDK_REMOTE_REPO_PROTOCOL%%OJDK_REMOTE_REPO% %OJDK_SRC_DIR% 
			) else (
				%HG% clone %OJDK_REMOTE_REPO_PROTOCOL%%OJDK_REMOTE_REPO% %OJDK_SRC_DIR% || exit /b 1
			)
		)
	) else (
		pushd "%OJDK_SRC_PATH%" || exit /b 1
		if defined USE_GIT (
			%GIT% fetch origin || exit /b 1
			if defined OJDK_TAG %GIT% checkout "%OJDK_TAG%" || exit /b 1
		)
		if defined USE_MERCURIAL (
			%HG% pull -u || exit /b 1
			if defined OJDK_TAG %HG% update --rev %OJDK_TAG% || exit /b 1
		)
		popd
	)
	rem print out the SCS ID of what we are building
	rem call :setsdkenv
	pushd "%OJDK_SRC_PATH%"
	if defined USE_GIT (
		%GIT% log -1
	)
	if defined USE_MERCURIAL (
		%HG% id || exit /b 1
	)
	popd
	@echo ** fix ownership and permissions
	rem takeown /f "%OJDK_SRC_PATH:/=\%" /r > nul || exit /b 1
	rem icacls "%OJDK_SRC_PATH:/=\%" /reset /T /Q || exit /b 1
	exit /b 0

	:revert_jdk_repo
	@echo *** revert JDK base repo
	set PATH=%OJDKBUILD_DIR%/tools/cygwin_jdk11/bin;%PATH%
	pushd "%OJDK_SRC_PATH%" || exit /b 1
	if defined USE_GIT (
		%GIT% restore . || exit /b 1
	)
	if defined USE_MERCURIAL (
		%HG% revert --all || exit /b 1
	)
	popd
	exit /b 0

	:configure_jdk_build
	@echo *** configure JDK build
	rem create this file so that the JDK configure script can see it and confirm the existence of a VS toolchain
	rem if not exist %OJDKBUILD_DIR%/tools/toolchain/vs2010e/VC/bin/x86_amd64/vcvarsx86_amd64.bat (
		rem echo "rem placeholder for JDK configure script toolchain detection" >%OJDKBUILD_DIR%/tools/toolchain/vs2010e/VC/bin/x86_amd64/vcvarsx86_amd64.bat
	rem )

	set CFGARGS=--enable-unlimited-crypto=yes
	set CFGARGS=%CFGARGS% --with-conf-name=%OJDK_CONF%
	set CFGARGS=%CFGARGS% --with-debug-level=%OJDK_DEBUG_LEVEL%
	set CFGARGS=%CFGARGS% --with-boot-jdk=%OJDKBUILD_DIR%/tools/bootjdk%BOOTSTRAP_JDK_VERSION%
	set CFGARGS=%CFGARGS% --with-toolchain-path=%OJDKBUILD_DIR%/tools/toolchain
	set CFGARGS=%CFGARGS% --with-toolchain-version=2017
	set CFGARGS=%CFGARGS% %CONFIG_PASS_FLAGS% %CONFIG_EXTRA_FLAGS%
	set CFGARGS=%CFGARGS% --with-num-cores=2
	if defined EARLY_ACCESS (
		set CFGARGS=%CFGARGS% --with-version-pre="ea"
	) else (
		set CFGARGS=%CFGARGS% --with-version-pre=""
	)
	set CFGARGS=%CFGARGS% --disable-hotspot-gtest
	set CFGARGS=%CFGARGS% --disable-warnings-as-errors
	rem we can not use --with-ucrt-dll-dir because of https://bugs.openjdk.java.net/browse/JDK-8216354
	rem set CFGARGS=%CFGARGS% --with-ucrt-dll-dir=%OJDKBUILD_DIR:/=\%\tools\toolchain\sdk10_1607\Redist\ucrt\DLLs\x64
	set DEVKIT_UCRT_DLL_DIR=%OJDKBUILD_DIR:/=\%\tools\toolchain\sdk10_1607\Redist\ucrt\DLLs\x64
	set CFGARGS=%CFGARGS% --with-log=info
	set CFGARGS=%CFGARGS% --with-native-debug-symbols=external
	set CFGARGS=%CFGARGS% --with-version-build=%OJDK_BUILD%
	set CFGARGS=%CFGARGS% --with-version-opt=""
	set CFGARGS=%CFGARGS% --with-vendor-version-string="%VENDOR_VERSION_STRING%"
	call :setsdkenv
	path %OJDKBUILD_DIR%/tools/cygwin_jdk11/bin;%PATH%
	pushd "%OJDK_SRC_PATH%"
	bash configure %CFGARGS% || exit /b 1
	popd || exit /b 1
	exit /b 0

	:build_jdk
	@echo *** build JDK
	call :setsdkenv
	path %OJDKBUILD_DIR%/tools/cygwin_jdk11/bin;%PATH%
	pushd "%OJDK_SRC_PATH%"
	bash -c "rm -f /dev/fd"
	bash -c "ln -s /proc/self/fd /dev/fd"
	if not ".%OJDK_DEBUG_LEVEL%" == ".release" (
		set JDK_TARGETS=images
	) else (
		set JDK_TARGETS=bootcycle-images legacy-images
		if defined BUILD_JDK_TESTIMAGE (
			set JDK_TARGETS=!JDK_TARGETS! test-image
		)
	)
	if defined BUILD_STATIC_LIBS (
		set JDK_TARGETS=%JDK_TARGETS% static-libs-image
	)
	if defined BUILD_GRAAL_JDK (
		set JDK_TARGETS=graal-builder-image
	)
	rem set DEBUG_MAKE_LOG=debug
	make %DEBUG_MAKE_LOG% CONF=%OJDK_CONF% %JDK_TARGETS% || exit /b 1
	popd || exit /b 1
	@echo *** JDK build completed: JDK in "%OJDK_SRC_PATH%/build/%OJDK_CONF%/images/jdk"
	exit /b 0

	:test_jdk_version
	@echo testing JDK version strings
	rem EA build:
	rem  $ java -version
	rem  openjdk version "11.0.6-ea" 2020-01-14
	rem  OpenJDK Runtime Environment 18.9 (build 11.0.6-ea+5)
	rem  OpenJDK 64-Bit Server VM 18.9 (build 11.0.6-ea+5, mixed mode)
	rem 
	rem GA build:
	rem  $ java -version
	rem  openjdk version "11.0.6" 2020-01-14
	rem  OpenJDK Runtime Environment 18.9 (build 11.0.6+5)
	rem  OpenJDK 64-Bit Server VM 18.9 (build 11.0.6+5, mixed mode)
	rem 
	set TEMPDIR=%WORK_DIR:/=\%
	set EXPECTED_VERSION_FILE=%TEMPDIR%\expected_version.txt
	set ACTUAL_VERSION_FILE=%TEMPDIR%\actual_version.txt
	if defined EARLY_ACCESS (
		echo openjdk version "%OJDK_UPDATE%-ea" %RELEASE_DATE%>%EXPECTED_VERSION_FILE% || exit /b 1
		echo OpenJDK Runtime Environment 18.9 (build %OJDK_UPDATE%-ea+%OJDK_BUILD%^) >>%EXPECTED_VERSION_FILE%
		echo OpenJDK 64-Bit Server VM 18.9 (build %OJDK_UPDATE%-ea+%OJDK_BUILD%, mixed mode^) >>%EXPECTED_VERSION_FILE%
	) else (
		echo openjdk version "%OJDK_UPDATE%" %RELEASE_DATE%>%EXPECTED_VERSION_FILE% || exit /b 1
		echo OpenJDK Runtime Environment 18.9 (build %OJDK_UPDATE%+%OJDK_BUILD%^) >>%EXPECTED_VERSION_FILE%
		echo OpenJDK 64-Bit Server VM 18.9 (build %OJDK_UPDATE%+%OJDK_BUILD%, mixed mode^) >>%EXPECTED_VERSION_FILE%
	)
	set JDK_HOME=
	if exist "%OJDK_SRC_PATH%/build/%OJDK_CONF%/images/%ZIP_DIR_NAME%" (
		set JDK_HOME=%OJDK_SRC_PATH%/build/%OJDK_CONF%/images/%ZIP_DIR_NAME%
	)
	if exist "%OJDK_SRC_PATH%/build/%OJDK_CONF%/images/jdk" (
		set JDK_HOME=%OJDK_SRC_PATH%/build/%OJDK_CONF%/images/jdk
	)
	if not defined JDK_HOME (
		@echo *** no JDK_HOME found in %OJDK_SRC_PATH%/build/%OJDK_CONF%/images
		dir "%OJDK_SRC_PATH:/=\%\build\%OJDK_CONF%\images"
		exit /b 1
	)
	%JDK_HOME:/=\%\bin\java -version 2>%ACTUAL_VERSION_FILE% || exit /b 1
	c:\cygwin64\bin\diff -b %EXPECTED_VERSION_FILE% %ACTUAL_VERSION_FILE%
	if not %ERRORLEVEL% == 0 (
		echo "*** Version strings do not match."
		echo "expected:"
		type %EXPECTED_VERSION_FILE%
		echo "actual:"
		type %ACTUAL_VERSION_FILE%
		exit /b 1
	) else (
		echo "version string passes test:"
		type %ACTUAL_VERSION_FILE%
	)
	exit /b 0

	:test_jdk
	@echo *** testing the JDK
	set JTREG_HOME=c:\jtreg
	set JAVA_HOME=
	set JDK_HOME=
	if exist "%OJDK_SRC_PATH%/build/%OJDK_CONF%/images/%ZIP_DIR_NAME%" (
		set JDK_HOME=%OJDK_SRC_PATH%/build/%OJDK_CONF%/images/%ZIP_DIR_NAME%
	)
	if exist "%OJDK_SRC_PATH%/build/%OJDK_CONF%/images/jdk" (
		set JDK_HOME=%OJDK_SRC_PATH%/build/%OJDK_CONF%/images/jdk
	)
	if not defined JDK_HOME (
		@echo *** no JDK_HOME found in %OJDK_SRC_PATH%/build/%OJDK_CONF%/images
		exit /b 1
	)
	call :setsdkenv
	rem the version of Cygwin can cause tests to fail; see LocalProviders.sh
	path %JTREG_HOME%/bin;%OJDKBUILD_DIR%/tools/cygwin_jdk11/bin;%PATH%
	rem path %JTREG_HOME%/bin;c:\cygwin64\bin;%PATH%
	pushd "%OJDK_SRC_PATH%"
	rem make CONF=%OJDK_CONF% test TEST="tier1" JT_HOME=%JTREG_HOME%
	if  not exist "%WORK_DIR%/jtreg" (
		mkdir -p "%WORK_DIR%/jtreg"
	)
	rem example test
	set TESTS=%OJDK_SRC_PATH%/jdk/test/javax/xml
	bash -c "jtreg -w %WORK_DIR%/jtreg/work -r %WORK_DIR%/jtreg/report -jdk:%JDK_HOME% %TESTS%"
	popd || exit /b 1
	exit /b 0

	:build_jdk_zip
	@echo *** zip JDK release
	if exist %source_dir%\%RELEASE_ZIPFILE% del %source_dir%\%RELEASE_ZIPFILE%
	if defined BUILD_GRAAL_JDK (
		set JDK_IMAGE_DIR=graal-builder-jdk
	) else (
		set JDK_IMAGE_DIR=jdk
	)
	pushd "%OJDK_SRC_PATH%/build/%OJDK_CONF%/images/"
	if exist "%JDK_IMAGE_DIR%" (
		if defined DELETE_DEBUG_FILES (
			@echo *** remove debug files
			bash -c "find %JDK_IMAGE_DIR% -name \*.diz -exec rm {} \;"
			bash -c "find %JDK_IMAGE_DIR% -name \*.pdb -exec rm {} \;"
			bash -c "find %JDK_IMAGE_DIR% -name \*.map -exec rm {} \;"
		)
		if exist %ZIP_DIR_NAME% (
			rd /q/s %ZIP_DIR_NAME% || exit /b 1
		)
		ren %JDK_IMAGE_DIR% %ZIP_DIR_NAME% || exit /b 1
	)
	if not exist "%ZIP_DIR_NAME%" (
		@echo "no jdk image found"
		exit /b 1
	)
	bash -c "zip -r %source_dir:\=/%/%RELEASE_ZIPFILE% ./%ZIP_DIR_NAME%"
	rem restore the old directory name
	ren %ZIP_DIR_NAME% %JDK_IMAGE_DIR% || exit /b 1
	popd || exit /b 1
	exit /b 0

	:build_static_lib_zip
	@echo *** zip static libs
	if exist %source_dir%\%RELEASE_STATIC_LIB_ZIPFILE% del %source_dir%\%RELEASE_STATIC_LIB_ZIPFILE%
	pushd "%OJDK_SRC_PATH%/build/%OJDK_CONF%/images/static-libs"
	if exist %ZIP_DIR_NAME% (
		rd /q/s %ZIP_DIR_NAME% || exit /b 1
	)
	mkdir %ZIP_DIR_NAME:/=\%\%STATIC_LIB_DIR:/=\% || exit /b 1
	move lib\*.* %ZIP_DIR_NAME:/=\%\%STATIC_LIB_DIR:/=\% || exit /b 1
	rd lib
	bash -c "zip -r %source_dir:\=/%/%RELEASE_STATIC_LIB_ZIPFILE% ."
	mkdir lib
	move %ZIP_DIR_NAME:/=\%\%STATIC_LIB_DIR:/=\%\*.* lib || exit /b 1
	rd /q/s %ZIP_DIR_NAME% || exit /b 1
	popd || exit /b 1
	exit /b 0

	:build_testimage_zip
	@echo *** zip TESTIMAGE release
	if exist %source_dir%\%RELEASE_TESTIMAGE_ZIPFILE% del %source_dir%\%RELEASE_TESTIMAGE_ZIPFILE%
	pushd "%OJDK_SRC_PATH%/build/%OJDK_CONF%/images/"
	if exist %ZIP_TESTIMAGE_DIR_NAME% (
		rd /q/s %ZIP_TESTIMAGE_DIR_NAME% || exit /b 1
	)
	ren test %ZIP_TESTIMAGE_DIR_NAME% || exit /b 1
	bash -c "zip -r %source_dir:\=/%/%RELEASE_TESTIMAGE_ZIPFILE% ./%ZIP_TESTIMAGE_DIR_NAME%"
	ren %ZIP_TESTIMAGE_DIR_NAME% test || exit /b 1
	popd || exit /b 1
	exit /b 0

	:build_jre_zip
	@echo *** zip JRE release
	if exist %source_dir%\%RELEASE_JRE_ZIPFILE% del %source_dir%\%RELEASE_JRE_ZIPFILE%
	pushd "%OJDK_SRC_PATH%/build/%OJDK_CONF%/images/" || exit /b 1
	if exist jre (
		if defined DELETE_DEBUG_FILES (
	        @echo *** remove debug files
			bash -c "find jre -name \*.diz -exec rm {} \;"
			bash -c "find jre -name \*.pdb -exec rm {} \;"
			bash -c "find jre -name \*.map -exec rm {} \;"
		)
		if exist %ZIP_JRE_DIR_NAME% (
			rd /q/s %ZIP_JRE_DIR_NAME% || exit /b 1
		)
		ren jre %ZIP_JRE_DIR_NAME% || exit /b 1
	)
	if not exist "%ZIP_JRE_DIR_NAME%" (
		@echo "no jdk image found"
		exit /b 1
	)
	bash -c "zip -r %source_dir:\=/%/%RELEASE_JRE_ZIPFILE% ./%ZIP_JRE_DIR_NAME%"
	ren %ZIP_JRE_DIR_NAME% jre || exit /b 1
	popd || exit /b 1
	
	@echo *** symlink for QA
	pushd "%source_dir%" || exit /b 1
	rem Only Windows 10 Creators Update and later can use mklink as non-admin so instead do a copy here.
	rem mklink java-11-openjdk-%OJDK_UPDATE%.%OJDK_BUILD%-1.windows.upstream.x86_64.zip %RELEASE_ZIPFILE%
	copy %RELEASE_ZIPFILE% java-11-openjdk-%OJDK_UPDATE%.%OJDK_BUILD%-1.windows.upstream.x86_64.zip
	popd
	exit /b 0

	:remove_debug_files
	@echo *** remove debug files
	cd "%OJDK_SRC_PATH%/build/%OJDK_CONF%/images/"
	bash -c "find jdk jre -name \*.diz -exec rm {} \;"
	bash -c "find jdk jre -name \*.pdb -exec rm {} \;"
	bash -c "find jdk jre -name \*.map -exec rm {} \;"
	exit /b 0

	:download_ojdkbuild
	@echo *** fetch and check ojdkbuild
	if not exist %WORK_DIR%/ojdkbuild (
		set OJDKBUILD_REPO=%OJDKBUILD_REPOBASE%/ojdkbuild.git
		pushd "%WORK_DIR%" || exit /b 1
		%GIT% clone -q !OJDKBUILD_REPO! ojdkbuild || exit /b 1
		cd ojdkbuild || exit /b 1
		%GIT% reset --hard %OJDKBUILD_TAG% || exit /b 1
		popd
	)
	@echo *** fetch ojdkbuild submodules
	cd "%OJDKBUILD_DIR%"
	set modules=tools/zip
	if defined BUILD_JDK (
		set modules=!modules! tools/bootjdk%BOOTSTRAP_JDK_VERSION% tools/cmake tools/cygwin_jdk11 tools/make
		set modules=!modules! tools/toolchain/directx tools/toolchain/msvcr100 tools/toolchain/sdk10_1607 tools/toolchain/vs2017bt
	)
	if not exist %OJDKBUILD_DIR%/deps      mkdir %OJDKBUILD_DIR:/=\%\deps
	if not exist %OJDKBUILD_DIR%/external  mkdir %OJDKBUILD_DIR:/=\%\external
	if not exist %OJDKBUILD_DIR%/lookaside mkdir %OJDKBUILD_DIR:/=\%\lookaside
	if not exist %OJDKBUILD_DIR%/tools     mkdir %OJDKBUILD_DIR:/=\%\tools
	for %%G in (%modules%) do (
		set module=%%G
		set repo=!module:/=_!
		rem if exist %%G rmdir /S/Q !module:/=\!
		if not exist %%G/.git (
			%GIT% clone -q %OJDKBUILD_REPOBASE%/!repo! %%G || exit /b 1
		)
	)
	rem unzip modules file in the boot JDK (github will not store > 100mb files)
	if exist "%OJDKBUILD_DIR%/tools/bootjdk%BOOTSTRAP_JDK_VERSION%/lib/modules.zip" (
		cd "%OJDKBUILD_DIR%/tools/bootjdk%BOOTSTRAP_JDK_VERSION%/lib" || exit /b 1
		if exist modules del modules
		unzip modules.zip || exit /b 1
		del modules.zip
	)
	PATH C:/cygwin64/bin;%PATH%

	@echo *** check and update cygwin
	cd "%OJDKBUILD_DIR%/tools/cygwin_jdk11" || exit /b 1
	%GIT% checkout master || exit /b 1
	%GIT% pull || exit /b 1
	cd "%WORK_DIR%" || exit /b 1
	
	@echo ** fix permissions part 1
	takeown /f "%OJDKBUILD_DIR:/=\%" /r > nul || exit /b 1
	@echo ** fix permissions part 2 (can give errors)
	icacls "%OJDKBUILD_DIR:/=\%" /reset /T /Q /C
	@echo ** fix permissions part 3
	if defined CLAMSCAN %CLAMSCAN% --quiet --recursive ojdkbuild
	@echo ** tools checked out sucessfully
	exit /b 0

	:clean_jdk
	@echo *** clean JDK
	call :setsdkenv
	path %OJDKBUILD_DIR%/tools/cygwin_jdk11/bin;%PATH%
	pushd "%OJDK_SRC_PATH%"
	make CONF=%OJDK_CONF% clean
	popd || exit /b 1
	exit /b 0

	:download_mercurial
	@echo *** install mercurial
	set HG=call :hg_cmd
	exit /b 0
	
	:hg_cmd
	@echo calling mercurial %*
	c:\cygwin64\bin\bash -c "/bin/hg %*" || exit /b 1
	exit /b 0

	:download_git
	@echo *** set git global options and path
	git config --global core.autocrlf input || exit /b 1
	git config --global http.sslverify false || exit /b 1
	set GIT="C:/cygwin64/bin/git.exe"
	exit /b 0

	:settoolpaths
	call :setsdkenv
	PATH %WORK_DIR%/mx;%PATH%
	PATH %OJDKBUILD_DIR%/tools/python27;%PATH%
	PATH %JDK11_DIR%/bin;%PATH%
	set MX=call mx.cmd
	exit /b 0

	:setsdkenv
	@echo *** set MSVC SDK10 and VS2017 environment
	set PATH=C:/Windows/system32;C:/Windows

	rem tools dirs
	set VSINSTALLDIR=%OJDKBUILD_DIR%/tools/toolchain/vs2017bt
	set WindowsSdkDir=%OJDKBUILD_DIR%/tools/toolchain/sdk10_1607

	rem set compiler environment manually
	set DevEnvDir=%VSINSTALLDIR%/Common7/IDE/
	set ExtensionSdkDir=%WindowsSdkDir%/ExtensionSDKs
	set INCLUDE=%VSINSTALLDIR%/VC/Tools/MSVC/14.12.25827/include;%WindowsSdkDir%/include/10.0.14393.0/ucrt;
	set INCLUDE=%INCLUDE%;%WindowsSdkDir%/include/10.0.14393.0/shared;%WindowsSdkDir%/include/10.0.14393.0/um;%WindowsSdkDir%/include/10.0.14393.0/winrt;
	set LIB=%VSINSTALLDIR%/VC/Tools/MSVC/14.12.25827/lib/x64;%WindowsSdkDir%/lib/10.0.14393.0/ucrt/x64;%WindowsSdkDir%/lib/10.0.14393.0/um/x64;
	set LIBPATH=%VSINSTALLDIR%/VC/Tools/MSVC/14.12.25827/lib/x64;%VSINSTALLDIR%/VC/Tools/MSVC/14.12.25827/lib/x86/store/references;
	set LIBPATH=%LIBPATH%;%WindowsSdkDir%/UnionMetadata;%WindowsSdkDir%/References;
	set Platform=x64
	set PROCESSOR_ARCHITECTURE=AMD64
	set VCIDEInstallDir=%VSINSTALLDIR%/Common7/IDE/VC/
	set VCINSTALLDIR=%VSINSTALLDIR%/VC/
	set VCToolsInstallDir=%VSINSTALLDIR%/VC/Tools/MSVC/14.12.25827/
	set VCToolsRedistDir=%VSINSTALLDIR%/VC/Redist/MSVC/14.12.25810/
	set VCToolsVersion=14.12.25827
	set VisualStudioVersion=15.0
	set VS150COMNTOOLS=%VSINSTALLDIR%/Common7/Tools/
	set VSCMD_ARG_app_plat=Desktop
	set VSCMD_ARG_HOST_ARCH=x86
	set VSCMD_ARG_TGT_ARCH=x64
	set VSCMD_VER=15.0
	set WindowsSdkBinPath=%WindowsSdkDir%/bin/
	set WindowsSDKLibVersion=10.0.14393.0/
	set WindowsSDKVersion=10.0.14393.0/

	rem set path
	set PATH=%OJDKBUILD_DIR%/tools/cygwin_jdk11/bin/path_prepend
	set PATH=%PATH%;%VSINSTALLDIR%/VC/Tools/MSVC/14.12.25827/bin/HostX86/x64;%VSINSTALLDIR%/VC/Tools/MSVC/14.12.25827/bin/HostX86/x86
	set PATH=%PATH%;%WindowsSdkDir%/bin/x86;%VSINSTALLDIR%/Common7/Tools/;%VSINSTALLDIR%/VC/Redist/MSVC/14.12.25810/x64/Microsoft.VC141.CRT/
	set PATH=%PATH%;%WindowsSdkDir%/Redist/ucrt/DLLs/x64;%WindowsSdkDir%/Redist/ucrt/DLLs/x86;
	set PATH=%PATH%;C:/Windows/system32;C:/Windows;C:/Windows/System32/Wbem
	set PATH=%PATH%;%OJDKBUILD_DIR%/tools/cmake/bin
	set PATH=%PATH%;%OJDKBUILD_DIR%/tools/pkgconfig/bin
	set PATH=%PATH%;%OJDKBUILD_DIR%/tools/nasm
	set PATH=%PATH%;%OJDKBUILD_DIR%/tools/cygwin_jdk11/bin
	set PATH=%PATH%;%OJDKBUILD_DIR%/tools/maven/bin
	set PATH=%PATH%;%OJDKBUILD_DIR%/resources/scripts
	set PATH=%OJDKBUILD_DIR%/tools/cygwin_jdk11/bin;%PATH%
	set SAVEPATH=%PATH%
	exit /b 0

