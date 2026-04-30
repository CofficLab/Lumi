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
}
#endif
