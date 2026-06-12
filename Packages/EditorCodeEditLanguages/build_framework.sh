#!/usr/bin/env sh

# This script builds the CodeLanguagesContainer.xcframework
#
# Just call it from the root of the project
# $ ./build_framework.sh
#
# To suppress xcodebuild logs (e.g. in CI):
# $ ./build_framework.sh --quiet
#
# Created by: Lukas Pistrol on 29.10.2022

# convenience function to print a status message in green
status () {
    local GREEN='\033[0;32m'
    local NC='\033[0m' # No Color
    echo "${GREEN}◆ $1${NC}"
}

QUIET_FLAG=""
BUILD_OUTPUT=/dev/stdout

for arg in "$@"; do
    case "$arg" in
        --quiet)
            QUIET_FLAG="-quiet"
            BUILD_OUTPUT=/dev/null
            ;;
        --debug)
            # Legacy flag; verbose output is now the default.
            ;;
    esac
done

# Set pipefail to make sure that the script fails if any of the commands fail
set -euo pipefail

# build the framework project `CodeLanguages-Container`
status "Clean Building CodeLanguages-Container.xcodeproj..."
if [ -z "$QUIET_FLAG" ]; then
    status "First run usually takes 10–20 minutes. Pass --quiet to hide xcodebuild logs."
fi
xcodebuild \
    -project CodeLanguages-Container/CodeLanguages-Container.xcodeproj \
    -scheme CodeLanguages-Container \
    -destination "platform=macOS" \
    -derivedDataPath DerivedData \
    -configuration Release \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    $QUIET_FLAG clean build &> $BUILD_OUTPUT
status "Build complete!"

# set path variables
PRODUCTS_PATH="$PWD/DerivedData/Build/Products/Release"
FRAMEWORK_PATH="$PRODUCTS_PATH/CodeLanguages_Container.framework"
OUTPUT_PATH="CodeLanguagesContainer.xcframework"

# remove previous generated files
rm -rf "$OUTPUT_PATH"
rm -f "$OUTPUT_PATH".zip
status "Removed previous generated files!"

# build the binary framework
status "Creating CodeLanguagesContainer.xcframework..."
xcodebuild \
    -create-xcframework \
    -framework "$FRAMEWORK_PATH" \
    -output "$OUTPUT_PATH" &> $BUILD_OUTPUT

# zip the xcframework
status "Zipping CodeLanguagesContainer.xcframework..."
zip -r -q -y "$OUTPUT_PATH".zip "$OUTPUT_PATH"

status "CodeLanguagesContainer.xcframework and CodeLanguagesContainer.xcframework.zip created!"

# copy language queries to package resources
# set path variables
CHECKOUTS_PATH="$PWD/DerivedData/SourcePackages/checkouts"
RESOURCES_PATH="$PWD/Sources/Resources"

# remove previous copied files
status "Copying language queries to package resources..."
rm -rf "$RESOURCES_PATH"

# find and copy language queries
LIST=$( echo $CHECKOUTS_PATH/tree-* )

OLD_PWD="$PWD"

for lang in $LIST ; do
    # determine how many targets a given package has
    cd $lang
    
    # get package info as JSON
    manifest=$(swift package dump-package)

    # use jq to get the target path
    targets=$(echo $manifest | jq -r '.targets[] | select(.type != "test") | .path')
    
    # use jq to count number of targets
    count=$(echo $manifest | jq '[.targets[] | select(.type != "test")] | length')
    
    # Determine if target paths are all '.'
    same=1
    for target in $targets; do
        if [[ $target != "." ]]; then
            same=0
            break
        fi
    done

    # loop through targets
    for target in $targets; do
        name=${lang##*/}
        
        # if there is only one target, use name
        # otherwise use target
        if [[ $count -eq 1 || ($count -ne 1 && $same -eq 1) ]]; then
            mkdir -p $RESOURCES_PATH/$name
        else
            mkdir -p $RESOURCES_PATH/$target
        fi
            
        highlights=$( find $lang/$target -type f -name "*.scm" )
        for highlight in $highlights ; do
            highlight_name=${highlight##*/}
            
            # if there is only one target, use name
            # otherwise use target
            if [[ $count -eq 1 || ($count -ne 1 && $same -eq 1) ]]; then
                cp $highlight $RESOURCES_PATH/$name/$highlight_name
            else
                cp $highlight $RESOURCES_PATH/$target/$highlight_name
            fi
        done
        
        # If target paths are all '.', break out of loop
        if [[ $same -eq 1 || ($count -ne 1 && $same -eq 1) ]]; then
            break
        fi
    done
done
status "Language queries copied to package resources!"

# cleanup derived derived data

cd $OLD_PWD

if [ -d "$PWD/DerivedData" ]; then
    status "Cleaning up DerivedData..."
    rm -rf "$PWD/DerivedData"
fi

status "Done!"
