# Furl - basic file URL operations

![tag](https://img.shields.io/github/v/tag/dagronf/Furl)
![Swift](https://img.shields.io/badge/Swift-5.4-orange.svg)
[![License MIT](https://img.shields.io/badge/license-MIT-magenta.svg)](https://github.com/dagronf/Furl/blob/master/LICENSE) 
![SPM](https://img.shields.io/badge/spm-compatible-maroon.svg)
![Build](https://img.shields.io/github/actions/workflow/status/dagronf/SwiftSubtitles/swift.yml)

![macOS](https://img.shields.io/badge/macOS-10.13+-darkblue)
![iOS](https://img.shields.io/badge/iOS-13+-crimson)
![tvOS](https://img.shields.io/badge/tvOS-13+-forestgreen)
![watchOS](https://img.shields.io/badge/watchOS-6+-indigo)
![macCatalyst](https://img.shields.io/badge/macCatalyst-2+-orangered)
![Linux](https://img.shields.io/badge/Linux-compatible-peru)

## Why?

I found myself re-writing common file/folder access/info routines. While the Cocoa apis are very capable, sometimes getting basic information is quite tedious.

This is a micro-framework of basic file/folder and Spotlight query operations.

## Basic example

```swift
// Create a temporary folder to work in
let tempFolder = Folder.Temporary(create: true)

// Generate a new file within the folder, but don't create it
let workingFile = try tempFolder.file("output.txt")

// Write some text into the file
try "hello".write(to: workingFile.fileURL, atomically: true, encoding: .utf8)

// Check that we are a file
assert(workingFile.isFile)

// Grab the file's UTI
let uti = try workingFile.typeIdentifier()  // should be "public.plain-text"

// Lock the file
workingFile.isLocked = true

// Generate a child folder (note, this by default does not create it)
let childFolder = try tempFolder.subFolder("child")

// Make the folder on disk. Note this creates the folder if it doesn't already exist
try childFolder.actualize()

// And finally remove our temporary folder
try tempFolder.delete()
```

# API

## Location

A `Location` is the common sub-unit of a `File` and a `Folder`.  It contains routines that are 
common to both files and folders.

You never explicitly create a `Location`, rather you will work with `File` and `Folder`. 

### Attributes

| API                 | Description                                        |
|:--------------------|:---------------------------------------------------|
| `basename`          | The location's name *including* the extension      |
| `name`              | The location's name *without* the extension        |
| `displayName`       | The location's display name                        |
| `extension`         | The location's extension                           |
| `parent`            | The location's containing folder                   |
| `state`             | The location's state (`folder`, `file`, `unknown`) |
| `exists`            | Does the location exist on disk?                   |
| `doesNotExist`      | Does the location not yet exist on disk?           |
| `isFolder`          | Is this an existing folder?                        |
| `isFile`            | Is this an existing file?                          |
| `isAlias`           | Is this an alias file?                             |
| `isSymlink`         | Is this a symbolic link?                           |
| `creationDate`      | The location's creation date                       |
| `modificationDate`  | The location's modification date                   |
| `isExtensionHidden` | Is the location's extension hidden? (read/write)   |
| `isLocked`          | Is the location locked? (read/write)               |
| `attributes`        | The location's attributes                          |

### Basic permissions

| API            | Description                    |
|:---------------|:-------------------------------|
| `isReadable`   | The location can be read       |
| `isWritable`   | The location can be written to |
| `isExecutable` | The location can be executed   |
| `isDeletable`  | The location is deletable      |

### Universal Type Identifier

| API                | Description                                     |
|:-------------------|:------------------------------------------------|
| `contentType()`    | The UTI for the location (if it exists)         |
| `typeIdentifier()` | The type identifier for the location            |
| `conformsTo()`     | Does this location conform to the specified UTI |

### Operations

| API                | Description                            | Notes      |
|:-------------------|:---------------------------------------|:-----------|
| `move()`           | Move the file/folder to a new location |            |
| `copy()`           | Copy the file/folder to a new location |            |
| `rename()`         | Rename the file/folder                 |            |
| `delete()`         | Remove the file/folder from disk       |            |
| `moveToTrash()`    | Move the file/folder to the trash      | macOS only |
| `revealInFinder()` | Reveal the file/folder in the Finder   | macOS only |

### Symlinks and Aliases

| API                   | Description                                | Notes      |
|:----------------------|:-------------------------------------------|:-----------|
| `resolvingSymLinks()` | Resolve any symlinks within the location   |            |
| `createSymLink()`     | Create a symlink                           |            |
| `resolvingAlias()`    | Resolves the destination of the alias file | macOS only |
| `createAlias()`       | Create a file/folder alias                 | macOS only |

## File

A `File` object represents a file. The file may or may exist yet.

```swift
let file = File(fileURL: <some url>)
guard file.exists else { .... }
let fileSize = file.fileSize
let modificationDate = file.modificationDate
let uti = try file.contentType()

try file.moveToTrash()
```

### General

| API            | Description                                        |
|:---------------|:---------------------------------------------------|
| `fileSize`     | The file's size in bytes                           |
| `standardized` | Returns a File with a [standardised file path](https://developer.apple.com/documentation/foundation/nsurl/1414302-standardizingpath) |
| `actualize()`  | If the file doesn't exist, create the file on disk |

### Temporary files

| API                | Description              |
|--------------------|--------------------------|
| `File.Temporary()` | Returns a temporary file |


## Folder

A `Folder` object represents a folder.  The representation may or may not yet exist on disk

### Temporary folders

| API                            | Description                                                                    |
|--------------------------------|--------------------------------------------------------------------------------|
| `Folder.Temporary()`           | Returns a temporary folder                                                     |
| `createUniqueFile()`           | Create a unique file within this folder                                        |
| `createUniqueSubfolder()`      | Create a unique subfolder within this folder                                   |
| `createUniqueDatedSubfolder()` | Create a unique subfolder within this folder of the form `<identifier>/<date>` |




### Locating files

| API                | Description                                                  |
|:-------------------|:-------------------------------------------------------------|
| `contains()`       | Does this folder contain a location with the specified name  |
| `containsFolder()` | Does this folder contain a subfolder with the specified name |
| `containsFile()`   | Does this folder contain a file with the specified name      |


### Generating files/folders

| API                 | Description                                      |
|:--------------------|:-------------------------------------------------|
| `subfolder()`       | A subfolder in this folder with a specified name |
| `file()`            | A file in this folder with a specified name      |
| `writeDataToFile()` | Write data to a file in this folder              |

### Folder Content

| API                  | Description                                     | Notes                |
|:---------------------|:------------------------------------------------|:---------------------|
| `isEmpty()`          | Is this folder empty?                           |                      |
| `enumerateContent()` | Enumerate the contents of this folder           | Optionally recursive |
| `allContent()`       | Returns all the locations in this folder        | Optionally recursive |
| `allSubfolders()`    | Returns just the subfolders of this folder      | Optionally recursive |
| `allFiles()`         | Returns just the files contained in this folder | Optionally recursive |

### Common folder locations

| API                            | Description                         | Notes      |
|:-------------------------------|:------------------------------------|:-----------|
| `Folder.current()`             | The process' current working folder |            |
| `Folder.userHomeFolder()`      | User's home folder                  |            |
| `Folder.userDocumentsFolder()` | User's documents folder             |            |
| `Folder.userDesktopFolder()`   | User's desktop folder               |            |
| `Folder.userCachesFolder()`    | User's caches folder                |            |
| `Folder.userDownloadsFolder()` | User's downloads folder             |            |
| `Folder.userLibraryFolder()`   | User's library folder               |            |
| `Folder.userTemporaryFolder()` | User's temporary folder             |            |
| `Folder.userTrashFolder()`     | User's trash folder                 | macOS only |

## Location Query (macOS only)

`LocationQuery` is a basic wrapper around Spotlight search with a callback syntax

```swift
let q = LocationQuery()
q.searchScopes = [try Folder.userLibraryFolder()]
q.predicate = NSPredicate(format: "%K ENDSWITH '.txt'", NSMetadataItemFSNameKey)
q.start { foundItems in 
	// `foundItems` is an array of found metadata items
}
```

| API            | Description                                                            |
|:---------------|:-----------------------------------------------------------------------|
| `searchScopes` | The search scopes for the query (`URL`, `String` or `Folder`)          |
| `predicate`    | The query predicate ([Syntax](https://developer.apple.com/library/archive/documentation/Carbon/Conceptual/SpotlightQuery/Concepts/QueryFormat.html#//apple_ref/doc/uid/TP40001849-CJBEJBHH)) |
| `start()`      | Start the query, providing a completion handler to receive the results |
| `stop()`       | Stop a running query                                                   |

## License

```
MIT License

Copyright (c) 2023 Darren Ford

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
