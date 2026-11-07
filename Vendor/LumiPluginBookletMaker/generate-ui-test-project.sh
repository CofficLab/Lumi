#!/bin/bash
set -e

echo "🔧 Generating Xcode project for UI tests..."

# Check if XcodeGen is installed
if ! command -v xcodegen &> /dev/null; then
    echo "❌ XcodeGen not found. Please install it first:"
    echo "   brew install xcodegen"
    exit 1
fi

# Generate the project
xcodegen generate

echo "✅ Project generated successfully!"
echo ""
echo "Next steps:"
echo "  1. Open BookletMakerUITests.xcodeproj"
echo "  2. Select the 'BookletMakerUITests' scheme"
echo "  3. Run the tests (⌘U)"
echo ""
echo "Note: The first build may take a while as it downloads dependencies."
