#if canImport(XCTest)
import Foundation

enum XcodeProjectFixtureFactory {
    static func synchronizedRootPBXProj() -> String {
        """
        /* Begin PBXNativeTarget section */
                A1B2C3D4 /* Lumi */ = {
                    isa = PBXNativeTarget;
                    fileSystemSynchronizedGroups = (
                        F00DBABE /* LumiApp */,
                    );
                    name = Lumi;
                };
                B1C2D3E4 /* LumiTests */ = {
                    isa = PBXNativeTarget;
                    fileSystemSynchronizedGroups = (
                        F00DBABE /* LumiApp */,
                    );
                    name = LumiTests;
                };
        /* End PBXNativeTarget section */

        /* Begin PBXFileSystemSynchronizedRootGroup section */
                F00DBABE /* LumiApp */ = {
                    isa = PBXFileSystemSynchronizedRootGroup;
                    exceptions = (
                        EXC00001 /* Exceptions for Lumi */,
                        EXC00002 /* Exceptions for LumiTests */,
                    );
                    path = LumiApp;
                    sourceTree = "<group>";
                };
        /* End PBXFileSystemSynchronizedRootGroup section */

        /* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section */
                EXC00001 /* Exceptions for Lumi */ = {
                    isa = PBXFileSystemSynchronizedBuildFileExceptionSet;
                    membershipExceptions = (
                        "Plugins/AgentEditorPlugin/Experimental.swift",
                        "Generated/Ignored.swift",
                    );
                    target = A1B2C3D4 /* Lumi */;
                };
                EXC00002 /* Exceptions for LumiTests */ = {
                    isa = PBXFileSystemSynchronizedBuildFileExceptionSet;
                    membershipExceptions = (
                        "Tests/Disabled.swift",
                    );
                    target = B1C2D3E4 /* LumiTests */;
                };
        /* End PBXFileSystemSynchronizedBuildFileExceptionSet section */
        """
    }

    static func traditionalBuildPhasePBXProj() -> String {
        """
        /* Begin PBXProject section */
                PROJ0001 /* Project object */ = {
                    isa = PBXProject;
                    mainGroup = GRP_ROOT /* Root */;
                };
        /* End PBXProject section */

        /* Begin PBXNativeTarget section */
                TARGET001 /* Lumi */ = {
                    isa = PBXNativeTarget;
                    buildPhases = (
                        PHASE001 /* Sources */,
                        PHASE002 /* Headers */,
                    );
                    name = Lumi;
                };
                TARGET002 /* LumiTests */ = {
                    isa = PBXNativeTarget;
                    buildPhases = (
                        PHASE003 /* Sources */,
                    );
                    name = LumiTests;
                };
        /* End PBXNativeTarget section */

        /* Begin PBXGroup section */
                GRP_ROOT /* Root */ = {
                    isa = PBXGroup;
                    children = (
                        GRP_APP /* LumiApp */,
                        GRP_TESTS /* Tests */,
                    );
                    sourceTree = "<group>";
                };
                GRP_APP /* LumiApp */ = {
                    isa = PBXGroup;
                    children = (
                        FILE001 /* AppDelegate.swift */,
                        FILE002 /* Config.h */,
                    );
                    path = LumiApp;
                    sourceTree = "<group>";
                };
                GRP_TESTS /* Tests */ = {
                    isa = PBXGroup;
                    children = (
                        FILE003 /* AppTests.swift */,
                    );
                    path = Tests;
                    sourceTree = "<group>";
                };
        /* End PBXGroup section */

        /* Begin PBXFileReference section */
                FILE001 /* AppDelegate.swift */ = {
                    isa = PBXFileReference;
                    path = AppDelegate.swift;
                    sourceTree = "<group>";
                };
                FILE002 /* Config.h */ = {
                    isa = PBXFileReference;
                    path = Config.h;
                    sourceTree = "<group>";
                };
                FILE003 /* AppTests.swift */ = {
                    isa = PBXFileReference;
                    path = AppTests.swift;
                    sourceTree = "<group>";
                };
        /* End PBXFileReference section */

        /* Begin PBXBuildFile section */
                BUILD001 /* AppDelegate.swift in Sources */ = {
                    isa = PBXBuildFile;
                    fileRef = FILE001 /* AppDelegate.swift */;
                };
                BUILD002 /* Config.h in Headers */ = {
                    isa = PBXBuildFile;
                    fileRef = FILE002 /* Config.h */;
                };
                BUILD003 /* AppTests.swift in Sources */ = {
                    isa = PBXBuildFile;
                    fileRef = FILE003 /* AppTests.swift */;
                };
        /* End PBXBuildFile section */

        /* Begin PBXSourcesBuildPhase section */
                PHASE001 /* Sources */ = {
                    isa = PBXSourcesBuildPhase;
                    files = (
                        BUILD001 /* AppDelegate.swift in Sources */,
                    );
                };
                PHASE003 /* Sources */ = {
                    isa = PBXSourcesBuildPhase;
                    files = (
                        BUILD003 /* AppTests.swift in Sources */,
                    );
                };
        /* End PBXSourcesBuildPhase section */

        /* Begin PBXHeadersBuildPhase section */
                PHASE002 /* Headers */ = {
                    isa = PBXHeadersBuildPhase;
                    files = (
                        BUILD002 /* Config.h in Headers */,
                    );
                };
        /* End PBXHeadersBuildPhase section */
        """
    }

    static func mixedMembershipPBXProj() -> String {
        """
        /* Begin PBXProject section */
                PROJ0001 /* Project object */ = {
                    isa = PBXProject;
                    mainGroup = GRP_ROOT /* Root */;
                };
        /* End PBXProject section */

        /* Begin PBXNativeTarget section */
                TARGET001 /* Lumi */ = {
                    isa = PBXNativeTarget;
                    buildPhases = (
                        PHASE001 /* Sources */,
                    );
                    fileSystemSynchronizedGroups = (
                        F00DBABE /* LumiApp */,
                    );
                    name = Lumi;
                };
        /* End PBXNativeTarget section */

        /* Begin PBXFileSystemSynchronizedRootGroup section */
                F00DBABE /* LumiApp */ = {
                    isa = PBXFileSystemSynchronizedRootGroup;
                    exceptions = (
                        EXC00001 /* Exceptions for Lumi */,
                    );
                    path = LumiApp;
                    sourceTree = "<group>";
                };
        /* End PBXFileSystemSynchronizedRootGroup section */

        /* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section */
                EXC00001 /* Exceptions for Lumi */ = {
                    isa = PBXFileSystemSynchronizedBuildFileExceptionSet;
                    membershipExceptions = (
                        "Generated/Ignored.swift",
                    );
                    target = TARGET001 /* Lumi */;
                };
        /* End PBXFileSystemSynchronizedBuildFileExceptionSet section */

        /* Begin PBXGroup section */
                GRP_ROOT /* Root */ = {
                    isa = PBXGroup;
                    children = (
                        GRP_SUPPORT /* Support */,
                    );
                    sourceTree = "<group>";
                };
                GRP_SUPPORT /* Support */ = {
                    isa = PBXGroup;
                    children = (
                        FILE001 /* Config.xcconfig */,
                    );
                    path = Support;
                    sourceTree = "<group>";
                };
        /* End PBXGroup section */

        /* Begin PBXFileReference section */
                FILE001 /* Config.xcconfig */ = {
                    isa = PBXFileReference;
                    path = Config.xcconfig;
                    sourceTree = "<group>";
                };
        /* End PBXFileReference section */

        /* Begin PBXBuildFile section */
                BUILD001 /* Config.xcconfig in Sources */ = {
                    isa = PBXBuildFile;
                    fileRef = FILE001 /* Config.xcconfig */;
                };
        /* End PBXBuildFile section */

        /* Begin PBXSourcesBuildPhase section */
                PHASE001 /* Sources */ = {
                    isa = PBXSourcesBuildPhase;
                    files = (
                        BUILD001 /* Config.xcconfig in Sources */,
                    );
                };
        /* End PBXSourcesBuildPhase section */
        """
    }
}
#endif
