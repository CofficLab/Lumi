# Get the script's directory and set REPO_ROOT to the parent (project root)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export REPO_ROOT="$SCRIPT_DIR/.."
export TEMP_DIR="$REPO_ROOT/temp"
export DOWNLOADS_DIR="$TEMP_DIR/downloads"

set -e

echo "🚀 Starting LibGit2 framework build script..."
echo "📁 Script directory: $SCRIPT_DIR"
echo "📁 Repository root: $REPO_ROOT"
echo "📁 Temp directory: $TEMP_DIR"

echo "🧹 Cleaning up previous build artifacts..."
# Create temp directory structure, preserving downloads
mkdir -p $TEMP_DIR
mkdir -p $DOWNLOADS_DIR
# Remove build artifacts but keep downloaded source packages
rm -rf $TEMP_DIR/install*
rm -rf $TEMP_DIR/openssl-*
rm -rf $TEMP_DIR/libssh2-*
rm -rf $TEMP_DIR/libgit2-*
rm -rf $REPO_ROOT/Sources/Clibgit2.xcframework
echo "✅ Cleanup completed (preserved downloaded files in $DOWNLOADS_DIR)"

AVAILABLE_PLATFORMS=(iphoneos iphonesimulator maccatalyst maccatalyst-arm64 macosx-arm64 macosx)

### Setup common environment variables to run CMake for a given platform
### Usage:      setup_variables PLATFORM INSTALLDIR
### where PLATFORM is the platform to build for and should be one of
###    iphoneos            (implicitly arm64)
###    iphonesimulator     (implicitly x86_64)
###    maccatalyst, maccatalyst-arm64
###    macosx, macosx-arm64
###
### After this function is executed, the variables
###    $PLATFORM
###    $ARCH
###    $SYSROOT
###    $CMAKE_ARGS
### providing basic/common CMake options will be set.
function setup_variables() {
    cd $TEMP_DIR
    PLATFORM=$1

    echo "⚙️  Setting up build environment for platform: $PLATFORM"
    CMAKE_ARGS=(-DBUILD_SHARED_LIBS=NO \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER_WORKS=ON \
        -DCMAKE_CXX_COMPILER_WORKS=ON \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=12.4 \
        -DCMAKE_INSTALL_PREFIX=$TEMP_DIR/$2/$PLATFORM)

    case $PLATFORM in
        "iphoneos")
            ARCH=arm64
            SYSROOT=`xcodebuild -version -sdk iphoneos Path`
            CMAKE_ARGS+=(-DCMAKE_OSX_ARCHITECTURES=$ARCH \
                -DCMAKE_OSX_SYSROOT=$SYSROOT);;

        "iphonesimulator")
            ARCH=$(arch)
            SYSROOT=`xcodebuild -version -sdk iphonesimulator Path`
            CMAKE_ARGS+=(-DCMAKE_OSX_ARCHITECTURES=$ARCH -DCMAKE_OSX_SYSROOT=$SYSROOT);;

        "maccatalyst")
            ARCH=x86_64
            SYSROOT=`xcodebuild -version -sdk macosx Path`
            CMAKE_ARGS+=(-DCMAKE_C_FLAGS=-target\ $ARCH-apple-ios14.1-macabi -DCMAKE_OSX_ARCHITECTURES=$ARCH);;

        "maccatalyst-arm64")
            ARCH=arm64
            SYSROOT=`xcodebuild -version -sdk macosx Path`
            CMAKE_ARGS+=(-DCMAKE_C_FLAGS=-target\ $ARCH-apple-ios14.1-macabi -DCMAKE_OSX_ARCHITECTURES=$ARCH);;

        "macosx")
            ARCH=x86_64
            CMAKE_ARGS+=(-DCMAKE_OSX_ARCHITECTURES=$ARCH)
            SYSROOT=`xcodebuild -version -sdk macosx Path`;;

        "macosx-arm64")
            ARCH=arm64
            SYSROOT=`xcodebuild -version -sdk macosx Path`
            CMAKE_ARGS+=(-DCMAKE_OSX_ARCHITECTURES=$ARCH);;

        *)
            echo "Unsupported or missing platform! Must be one of" ${AVAILABLE_PLATFORMS[@]}
            exit 1;;
    esac

    echo "✅ Build environment setup completed for platform: $PLATFORM (ARCH: $ARCH)"
}

### Build libpcre for a given platform
function build_libpcre() {
    echo "📝 Building PCRE 8.45 for platform: $1"
    setup_variables $1 install

    echo "📦 Downloading and setting up PCRE..."
    rm -rf pcre-8.45
    git clone https://github.com/light-tech/PCRE.git pcre-8.45
    cd pcre-8.45

    echo "🔧 Configuring PCRE build..."
    rm -rf build && mkdir build && cd build
    CMAKE_ARGS+=(-DPCRE_BUILD_PCRECPP=NO \
        -DPCRE_BUILD_PCREGREP=NO \
        -DPCRE_BUILD_TESTS=NO \
        -DPCRE_SUPPORT_LIBBZ2=NO)

    echo "⚙️  Running CMake for PCRE..."
    cmake "${CMAKE_ARGS[@]}" .. >/dev/null 2>/dev/null

    echo "🔨 Building and installing PCRE..."
    cmake --build . --target install >/dev/null 2>/dev/null
    echo "✅ PCRE build completed"
}

### Build openssl for a given platform
function build_openssl() {
    version="3.0.14"
    echo "🔐 Building OpenSSL $version for platform: $1"
    setup_variables $1 install-openssl

    # It is better to remove and redownload the source since building make the source code directory dirty!
    echo "📦 Downloading and extracting OpenSSL..."
    rm -rf openssl-$version
    if [ ! -f "$DOWNLOADS_DIR/openssl-$version.tar.gz" ]; then
        echo "⬇️  Downloading OpenSSL $version..."
        wget -q -O "$DOWNLOADS_DIR/openssl-$version.tar.gz" https://www.openssl.org/source/openssl-$version.tar.gz
    else
        echo "📦 Using cached OpenSSL $version archive"
    fi
    tar xzf "$DOWNLOADS_DIR/openssl-$version.tar.gz"
    cd openssl-$version
    echo "📦 OpenSSL source ready"

    case $PLATFORM in
        "iphoneos")
            TARGET_OS=ios64-cross
            export CFLAGS="-isysroot $SYSROOT -arch $ARCH -mios-version-min=13.0";;

        "iphonesimulator")
            TARGET_OS=iossimulator-xcrun
            export CFLAGS="-isysroot $SYSROOT -miphonesimulator-version-min=13.0";;

        "maccatalyst"|"maccatalyst-arm64")
            TARGET_OS=darwin64-$ARCH-cc
            export CFLAGS="-isysroot $SYSROOT -target $ARCH-apple-ios14.1-macabi -mmacosx-version-min=12.4";;

        "macosx"|"macosx-arm64")
            TARGET_OS=darwin64-$ARCH-cc
            export CFLAGS="-isysroot $SYSROOT -mmacosx-version-min=12.4";;

        *)
            echo "Unsupported or missing platform!";;
    esac

    echo "🔧 Configuring OpenSSL build for $TARGET_OS..."
    # See https://wiki.openssl.org/index.php/Compilation_and_Installation
    ./Configure --prefix=$TEMP_DIR/install-openssl/$PLATFORM \
        --openssldir=$TEMP_DIR/install-openssl/$PLATFORM \
        $TARGET_OS no-shared no-dso no-hw no-engine >/dev/null 2>/dev/null

    echo "🔨 Building OpenSSL..."
    make >/dev/null 2>/dev/null
    echo "📦 Installing OpenSSL..."
    make install_sw install_ssldirs >/dev/null 2>/dev/null
    export -n CFLAGS
    echo "✅ OpenSSL build completed"
}

### Build libssh2 for a given platform (assume openssl was built)
function build_libssh2() {
    version="1.11.1"
    echo "🔐 Building libssh2 $version for platform: $1"
    setup_variables $1 install-libssh2

    echo "📦 Downloading and extracting libssh2..."
    rm -rf libssh2-$version
    if [ ! -f "$DOWNLOADS_DIR/libssh2-$version.tar.gz" ]; then
        echo "⬇️  Downloading libssh2 $version..."
        wget -q -O "$DOWNLOADS_DIR/libssh2-$version.tar.gz" https://www.libssh2.org/download/libssh2-$version.tar.gz
    else
        echo "📦 Using cached libssh2 $version archive"
    fi
    tar xzf "$DOWNLOADS_DIR/libssh2-$version.tar.gz"
    cd libssh2-$version

    echo "🔧 Configuring libssh2 build..."
    rm -rf build && mkdir build && cd build

    CMAKE_ARGS+=(-DCRYPTO_BACKEND=OpenSSL \
        -DOPENSSL_ROOT_DIR=$TEMP_DIR/install-openssl/$PLATFORM \
        -DBUILD_EXAMPLES=OFF \
        -DBUILD_TESTING=OFF)

    echo "⚙️  Running CMake for libssh2..."
    cmake "${CMAKE_ARGS[@]}" ..

    echo "🔨 Building and installing libssh2..."
    cmake --build . --target install
    echo "✅ libssh2 build completed"
}

### Build libgit2 for a single platform (given as the first and only argument)
### See @setup_variables for the list of available platform names
### Assume openssl and libssh2 was built
function build_libgit2() {
    version="1.9.2"
    echo "📚 Building libgit2 v$version for platform: $1"
    setup_variables $1 install

    echo "📦 Downloading and extracting libgit2..."
    rm -rf libgit2-$version
    if [ ! -f "$DOWNLOADS_DIR/libgit2-v$version.zip" ]; then
        echo "⬇️  Downloading libgit2 v$version..."
        wget -q -O "$DOWNLOADS_DIR/libgit2-v$version.zip" https://github.com/libgit2/libgit2/archive/refs/tags/v$version.zip
    else
        echo "📦 Using cached libgit2 v$version archive"
    fi
    ditto -x -k --sequesterRsrc --rsrc "$DOWNLOADS_DIR/libgit2-v$version.zip" ./
    cd libgit2-$version

    echo "🔧 Configuring libgit2 build..."
    rm -rf build && mkdir build && cd build

    # The CMake function that determines if `libssh2_userauth_publickey_frommemory` is defined doesn't
    # work when everything is statically linked. Manually override GIT_SSH_MEMORY_CREDENTIALS.
    # Also include PCRE path to avoid linking against system PCRE dylib.
    # Disable tests and examples to avoid iOS build issues.
    # Enable SSH support with libssh2
    CMAKE_ARGS+=(-DBUILD_TESTS=OFF -DBUILD_EXAMPLES=OFF -DGIT_SSH_MEMORY_CREDENTIALS=1 -DUSE_SSH=ON -DCMAKE_PREFIX_PATH="$TEMP_DIR/install-libssh2/$PLATFORM;$TEMP_DIR/install-openssl/$PLATFORM;$TEMP_DIR/install/$PLATFORM")

    echo "⚙️  Running CMake for libgit2..."
    cmake "${CMAKE_ARGS[@]}" ..

    echo "🔨 Building and installing libgit2..."
    cmake --build . --target install >/dev/null 2>/dev/null
    echo "✅ libgit2 build completed"
}

### Create xcframework for a given library
function build_xcframework() {
    local FWNAME=$1
    local INSTALLDIR=$2
    local XCFRAMEWORKNAME=$3
    shift 3
    local PLATFORMS=( "${AVAILABLE_PLATFORMS[@]}" )
    local FRAMEWORKS_ARGS=()

    echo "📦 Creating XCFramework for $FWNAME..."

    echo "🔧 Creating fat binary for macOS..."
    mkdir -p "$INSTALLDIR/macosx-fat/lib"
    lipo "$INSTALLDIR/macosx/lib/$FWNAME.a" "$INSTALLDIR/macosx-arm64/lib/$FWNAME.a" -create -output "$INSTALLDIR/macosx-fat/lib/$FWNAME.a"
    FRAMEWORKS_ARGS+=("-library" "$INSTALLDIR/macosx-fat/lib/$FWNAME.a" "-headers" "$INSTALLDIR/macosx/include")

    echo "🔧 Creating fat binary for Mac Catalyst..."
    mkdir -p "$INSTALLDIR/maccatalyst-fat/lib"
    lipo "$INSTALLDIR/maccatalyst/lib/$FWNAME.a" "$INSTALLDIR/maccatalyst-arm64/lib/$FWNAME.a" -create -output "$INSTALLDIR/maccatalyst-fat/lib/$FWNAME.a"
    FRAMEWORKS_ARGS+=("-library" "$INSTALLDIR/maccatalyst-fat/lib/$FWNAME.a" "-headers" "$INSTALLDIR/maccatalyst/include")

    # Filter out platforms that have been merged into fat binaries to avoid duplicate library definitions
    local FILTERED_PLATFORMS=()
    for p in ${PLATFORMS[@]}; do
        case $p in
            macosx|macosx-arm64|maccatalyst|maccatalyst-arm64)
                # Skip platforms that have been merged into fat binaries
                continue
                ;;
            *)
                FILTERED_PLATFORMS+=("$p")
                ;;
        esac
    done

    echo "🏗️  Building $FWNAME XCFramework containing macosx-fat maccatalyst-fat" ${FILTERED_PLATFORMS[@]}

    for p in ${FILTERED_PLATFORMS[@]}; do
        FRAMEWORKS_ARGS+=("-library" "$INSTALLDIR/$p/lib/$FWNAME.a" "-headers" "$INSTALLDIR/$p/include")
    done

    cd $REPO_ROOT
    echo "📦 Creating XCFramework at Sources/$XCFRAMEWORKNAME.xcframework..."
    mkdir -p Sources
    xcodebuild -create-xcframework ${FRAMEWORKS_ARGS[@]} -output Sources/$XCFRAMEWORKNAME.xcframework
    echo "✅ XCFramework creation completed"
}

### Copy module.modulemap to libgit2.xcframework/*/Headers
### so that we can use libgit2 C API in Swift
function copy_modulemap() {
    echo "📋 Copying module map to XCFramework..."
    local FWDIRS=$(find Sources/Clibgit2.xcframework -mindepth 1 -maxdepth 1 -type d)
    for d in ${FWDIRS[@]}; do
        echo "📋 Copying module map to: $d"
        cp $REPO_ROOT/Scripts/Clibgit2_modulemap $d/Headers/module.modulemap
    done
    echo "✅ Module map copying completed"
}

### Build libgit2 and Clibgit2 frameworks for all available platforms

echo "🏗️  Starting build process for platforms: ${AVAILABLE_PLATFORMS[@]}"

for p in ${AVAILABLE_PLATFORMS[@]}; do
    echo ""
    echo "🚀 Building libraries for platform: $p"
    echo "========================================"

    build_libpcre $p
    build_openssl $p
    build_libssh2 $p
    build_libgit2 $p

    # Put all of the generated *.a files into a single *.a file that will be in our framework
    # Note: Order matters for static linking! Libraries that use symbols must come BEFORE libraries that provide them.
    # libgit2 depends on: libssh2, OpenSSL, PCRE, zlib
    # libssh2 depends on: OpenSSL, zlib
    echo "🔗 Combining static libraries for $p..."
    cd $REPO_ROOT
    libtool -v -static -o libgit2_all.a \
        temp/install/$p/lib/libgit2.a \
        temp/install/$p/lib/libpcre.a \
        temp/install-libssh2/$p/lib/libssh2.a \
        temp/install-openssl/$p/lib/libssl.a \
        temp/install-openssl/$p/lib/libcrypto.a
    cp libgit2_all.a temp/install/$p/lib
    rm libgit2_all.a
    echo "✅ Library combination completed for $p"
done

echo ""
echo "🎯 Creating final XCFramework..."
build_xcframework libgit2_all temp/install Clibgit2
cd $REPO_ROOT
copy_modulemap

echo ""
echo "🎉 Build process completed successfully!"
echo "📁 XCFramework available at: Sources/Clibgit2.xcframework"
echo "📁 Temp files are in: $TEMP_DIR (can be deleted after verification)"
echo "📁 Downloaded source packages are cached in: $DOWNLOADS_DIR"