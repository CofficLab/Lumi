# LibGit2Swift

A type-safe Swift wrapper around [libgit2](https://libgit2.org/), providing a native Swift interface for Git operations without relying on shell commands.

## Requirements

- macOS 14.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

## Installation

### Swift Package Manager

Add LibGit2Swift as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/nookery/LibGit2Swift.git", from: "1.0.0")
]
```

Or add it via Xcode:

1. File → Add Package Dependencies
2. Enter the repository URL: `https://github.com/nookery/LibGit2Swift.git`
3. Select the version rule

## Building

### Dependency Versions

- **libgit2**: v1.9.2
- **OpenSSL**: 3.4.3
- **libssh2**: 1.11.1

### Initial Build Steps

For the first use or when updating dependency versions, you need to manually build `Clibgit2.xcframework`:

```bash
cd Scripts
./build-libgit2-framework.sh
```

#### Build Process Description

The script will automatically perform the following operations:

1. Download dependency source code:
   - OpenSSL 3.4.3
   - libssh2 1.11.1
   - libgit2 v1.9.2

2. Compile static libraries for the following platforms:
   - iOS (arm64)
   - iOS Simulator (x86_64)
   - macOS (arm64)
   - macOS (x86_64)
   - Mac Catalyst (arm64 + x86_64)

3. Create `Sources/Clibgit2.xcframework` and copy module map

#### Build-time System Requirements

- macOS 14.0+
- Xcode 15.0+
- CMake (usually installed with Xcode)
- wget (for downloading source code)

If wget is not installed:

```bash
brew install wget
```

### After Building

After successful build, the `Sources/Clibgit2.xcframework` file will be generated.

You can then use Swift Package Manager normally:

```bash
# In LibGit2Swift directory
swift build
```

Or in other projects:

```bash
cd /path/to/your/project
swift build
```

### Daily Development

Once `Clibgit2.xcframework` is built and committed to the repository, subsequent development doesn't require rebuilding unless:

1. Need to update dependency versions (modify version numbers in `Scripts/build-libgit2-framework.sh`)
2. Add new platform support
3. Regenerate xcframework

### Version Updates

If you need to update dependency versions:

1. Edit `Scripts/build-libgit2-framework.sh`
2. Modify the following version numbers:
   - `openssl-X.X.X`
   - `libssh2-X.X.X`
   - `vX.X.X` (libgit2)
3. Re-run the build script

## Usage

### Initialize a Repository

```swift
import LibGit2Swift

// Create a new repository
let repository = try LibGit2.createRepository(at: "/path/to/project")

// Open an existing repository
let repository = try LibGit2.Repository(at: "/path/to/existing/repo")
```

### Get Repository Status

```swift
let repository = try LibGit2.Repository(at: "/path/to/repo")

// Get HEAD
let head = try repository.getHead()
print("Current branch: \(head.branchName)")

// Check if there are uncommitted changes
let hasChanges = try repository.hasUncommittedChanges()
```

### Branch Operations

```swift
let repository = try LibGit2.Repository(at: "/path/to/repo")

// List branches
let branches = try repository.getBranches()

// Create a new branch
try repository.createBranch(name: "feature-branch")

// Delete a branch
try repository.deleteBranch(name: "old-branch")

// Rename a branch
try repository.renameBranch(oldName: "old-name", newName: "new-name")
```

### Commit Operations

```swift
let repository = try LibGit2.Repository(at: "/path/to/repo")

// Get commit history
let commits = try repository.getCommits(maxCount: 10)

// Create a commit
try repository.commit(message: "Add new feature", authorName: "John Doe", authorEmail: "john@example.com")

// Add file and commit in one operation
try repository.addAndCommit(path: "file.swift", message: "Add file.swift", authorName: "John Doe", authorEmail: "john@example.com")
```

### Working with Files

```swift
let repository = try LibGit2.Repository(at: "/path/to/repo")

// Stage a file
try repository.add(path: "file.swift")

// Stage all changes
try repository.addAll()

// Get file status
let status = try repository.getStatus()
```

### Remote Operations

```swift
let repository = try LibGit2.Repository(at: "/path/to/repo")

// List remotes
let remotes = try repository.getRemotes()

// Add a remote
try repository.addRemote(name: "origin", url: "https://github.com/user/repo.git")

// Get remote URL
if let url = try repository.getRemoteURL(name: "origin") {
    print("Remote URL: \(url)")
}
```

### Diff Operations

```swift
let repository = try LibGit2.Repository(at: "/path/to/repo")

// Get working tree vs index diff
let diff = try repository.getDiffWorkingTreeVsIndex()

// Get index vs HEAD diff
let diff = try repository.getDiffIndexVsHEAD()

// Get diff between commits
let diff = try repository.getDiffCommit(commitOid: "abc123", parentCommitOid: "def456")
```

## Error Handling

LibGit2Swift provides comprehensive error handling with meaningful error messages:

```swift
do {
    let repository = try LibGit2.Repository(at: "/path/to/repo")
    // Perform operations...
} catch LibGit2.Error.repositoryNotFound(let path) {
    print("Repository not found at: \(path)")
} catch LibGit2.Error.invalidReference(let message) {
    print("Invalid reference: \(message)")
} catch {
    print("Error: \(error.localizedDescription)")
}
```

## License

This project is available under the MIT license. See the LICENSE file for more info.
