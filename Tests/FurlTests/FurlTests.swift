import XCTest
@testable import Furl

final class FileSystemTests: XCTestCase {

#if !os(Linux)
	func testBasicFirst() throws {
		let rootObject = try Folder.userLibraryFolder().subfolder("Caches")
		XCTAssertTrue(rootObject.isFolder)

		XCTAssertEqual("Caches", rootObject.name)
		XCTAssertEqual("", rootObject.`extension`)

		let folders = try rootObject.allSubfolders()
		XCTAssertGreaterThan(folders.count, 0)
		/// All the folders recursively
		let rfolders = try rootObject.allSubfolders(shallow: false)
		XCTAssertGreaterThan(rfolders.count, 0)
		XCTAssertGreaterThan(rfolders.count, folders.count)

		XCTAssertTrue(try rootObject.subfolder("com.apple.HomeKit").isFolder)
		XCTAssertFalse(try rootObject.subfolder("com.apple.HomeKit2").exists)
	}
#endif

#if !os(Linux)
	func testExtensionHidden() throws {
		let temp = try Folder.Temporary(create: true)
		defer { try? temp.delete() }

		var dummy = try temp.file("myfile.txt")

		try "hello".write(to: dummy.locationURL, atomically: true, encoding: .utf8)

		XCTAssertEqual(5, dummy.fileSize)

		Swift.print(dummy)

		dummy.isExtensionHidden = true
		XCTAssertTrue(dummy.isExtensionHidden)
		dummy.isExtensionHidden = false
		XCTAssertFalse(dummy.isExtensionHidden)

		let ti = try dummy.typeIdentifier()
		XCTAssertEqual(ti, "public.plain-text")

		try dummy.delete()

		// Dummy file should have been deleted
		XCTAssertFalse(dummy.exists)
	}

	func testLockedImmutable() throws {
		let temp = try Folder.Temporary(create: true)
		defer { try? temp.delete() }

		var dummy = try temp.file("myfile2.blah")
		try "hello".write(to: dummy.locationURL, atomically: true, encoding: .utf8)

		XCTAssertFalse(dummy.isLocked)
		dummy.isLocked = true
		XCTAssertTrue(dummy.isLocked)
		dummy.isLocked = false
		XCTAssertFalse(dummy.isLocked)
	}
#endif

	func testTildeExpansion() throws {
		#if !os(Linux)
		let loc = Folder(path: "~/Library")
		XCTAssertTrue(loc.isFolder)
		XCTAssertEqual("Library", loc.basename)
		XCTAssertFalse(try loc.isEmpty())
		#else
		let loc = Folder(path: "~/")
		XCTAssertEqual("/root/", loc.path)
		#endif
	}

	func testTemporaryFile() throws {
		let root = try Folder.Temporary(create: true)
		defer { try? root.delete() }
		let t1 = try root.createUniqueFile()
		XCTAssertFalse(t1.exists)
		let t2 = try root.createUniqueFile(create: true)
		XCTAssertTrue(t2.exists)
		XCTAssertEqual(t1.parent, t2.parent)
	}

#if os(macOS)
	func testBasicQuery() throws {
		let waitExpectation = expectation(description: "Waiting...")
		let q = LocationQuery()
		q.searchScopes = [try Folder.userLibraryFolder()]
		q.predicate = NSPredicate(format: "%K ENDSWITH '.txt'", NSMetadataItemFSNameKey)
		var results: [NSMetadataItem] = []
		q.start { items in
			results = items
			waitExpectation.fulfill()
		}
		wait(for: [waitExpectation], timeout: 10)
		XCTAssertGreaterThan(results.count, 0)
		XCTAssertEqual(results[0].value.fileURL?.pathExtension, "txt")
		XCTAssertEqual(results[0].value.contentType, "public.plain-text")
		XCTAssertEqual(results[0].value.kind, "Plain Text Document")
	}
#endif

#if os(macOS)
	func testTrashPut() throws {
		let temp = try Folder.Temporary()
		let dummy = try temp.file("myfile.blah")
		try "hello".write(to: dummy.locationURL, atomically: true, encoding: .utf8)
		XCTAssertTrue(dummy.exists)

		let created = try temp.subfolder(["one", "two", "three"])
		try created.actualize()
		XCTAssertTrue(created.exists)

		// Try to trash the file
		let newLoc = try created.moveToTrash()
		XCTAssertFalse(created.exists)
		XCTAssertTrue(newLoc.exists)
		Swift.print(newLoc)
	}
#endif

	func testActualizeFolder() throws {
		// Create a temporary folder
		let temp = try Folder.Temporary(create: true)

		// This creates the fileURL for temporary/noodles/, but does not create it on disk
		let subfolder = try temp.subfolder("noodles")
		XCTAssertFalse(subfolder.exists)

		// Actualize the folder (ie. create it if it doesn't already exist)
		try subfolder.actualize()
		XCTAssertTrue(subfolder.exists)

#if os(macOS)
		// Move the created subfolder to the trash
		let tr = try subfolder.moveToTrash()
		XCTAssertTrue(tr.isFolder)
		XCTAssertFalse(subfolder.exists)
#endif
	}

	func testFolderExistsCount() throws {

#if os(macOS)
		do {
			let desktopFolder = Folder(path: "~/Desktop")
			XCTAssertTrue(desktopFolder.exists)

			let desktop = try Folder.userDesktopFolder()
			XCTAssertTrue(desktop.exists)

			let s = try desktop.allSubfolders()
			let a = try desktop.allFiles()
			XCTAssertGreaterThan(a.count, s.count)
		}
#endif

		#if !os(Linux)
		do {
			let library = try Folder.userLibraryFolder()
			let folders = try library.allSubfolders()
			XCTAssert(folders.count > 0)
		}
		#endif

		#if !os(tvOS) && !os(Linux)
		do {
			let library = try Folder.userLibraryFolder().subfolder("Caches")
			let files = try library.allFiles()
			XCTAssert(files.count > 0)
		}
		#endif
	}

	func testMoveFile() throws {
		let root1 = try Folder.Temporary(create: true)
		let file = try root1.createUniqueFile()
		try "This is a test".write(to: file.locationURL, atomically: true, encoding: .utf8)

		XCTAssertTrue(file.isFile)

		let root2 = try Folder.Temporary(create: true)

		let newLoc = try file.move(into: root2)
		XCTAssertFalse(file.exists)   // Old file should no longer exist
		XCTAssertTrue(newLoc.isFile)  // New file should exist

		let str = try String(contentsOf: newLoc.locationURL, encoding: .utf8)
		XCTAssertEqual("This is a test", str)
	}

	func testCopyFile() throws {
		let root1 = try Folder.Temporary(create: true)
		let file = try root1.createUniqueFile()
		try "This is a test".write(to: file.locationURL, atomically: true, encoding: .utf8)

		XCTAssertTrue(file.isFile)

		let root2 = try Folder.Temporary(create: true)

		let newLoc = try file.copy(into: root2)
		XCTAssertTrue(file.exists)    // Old file should still exist
		XCTAssertTrue(newLoc.isFile)  // New file should exist

		let str = try String(contentsOf: newLoc.locationURL, encoding: .utf8)
		XCTAssertEqual("This is a test", str)
	}

	func testMoveFolder() throws {

		let root1 = try Folder.Temporary(create: true)

		let subfolder = try root1.createUniqueSubfolder(prefix: "orig", create: true)
		let file = try subfolder.createUniqueFile(prefix: "origfile")
		try "This is a test".write(to: file.locationURL, atomically: true, encoding: .utf8)

		XCTAssertTrue(subfolder.isFolder)
		XCTAssertTrue(file.isFile)

		let root2 = try Folder.Temporary(create: true)

		let newSubfolderLoc = try subfolder.move(into: root2)
		XCTAssertFalse(subfolder.exists)         // Old folder should no longer exists
		XCTAssertTrue(newSubfolderLoc.isFolder)  // New file should exist
		XCTAssertEqual(newSubfolderLoc.basename, subfolder.basename) // Name should match

		XCTAssertTrue(try newSubfolderLoc.containsFile(named: file.basename))
		let movedSubfile = try newSubfolderLoc.file(file.basename)
		let str = try String(contentsOf: movedSubfile.locationURL, encoding: .utf8)
		XCTAssertEqual("This is a test", str)
	}

	func testCopyFolder() throws {

		let root1 = try Folder.Temporary(create: true)

		let subfolder = try root1.createUniqueSubfolder(prefix: "orig", create: true)
		let file = try subfolder.createUniqueFile(prefix: "origfile")
		try "This is a test".write(to: file.locationURL, atomically: true, encoding: .utf8)

		XCTAssertTrue(subfolder.isFolder)
		XCTAssertTrue(file.isFile)

		XCTAssertEqual(14, file.fileSize)

		let root2 = try Folder.Temporary(create: true)

		let newSubfolderLoc = try subfolder.copy(into: root2)
		XCTAssertTrue(subfolder.exists)          // Orig folder should still exist
		XCTAssertTrue(file.exists)               // Orig file should still exist
		XCTAssertFalse(file.isAlias)
		XCTAssertFalse(file.isSymlink)

		XCTAssertTrue(newSubfolderLoc.isFolder)  // New file should also exist

		let subfile = try newSubfolderLoc.file(file.basename)
		XCTAssertTrue(subfile.isFile)

		XCTAssertTrue(try newSubfolderLoc.containsFile(named: file.basename))
		let copiedSubfile = try newSubfolderLoc.file(file.basename)
		let str = try String(contentsOf: copiedSubfile.locationURL, encoding: .utf8)
		XCTAssertEqual("This is a test", str)
	}

#if !os(Linux)
	func testAliasCreation() throws {
		//let root1 = try Folder.Temporary(create: true)
		let root1 = try Folder.Temporary(identifier: "testAliasCreation")

		let base1 = try root1.createUniqueSubfolder(prefix: "origfolder").actualize()
		let file = try base1.createUniqueFile(prefix: "origfile")
		try "This is a test".write(to: file.locationURL, atomically: true, encoding: .utf8)

		let base2 = try root1.createUniqueSubfolder(prefix: "origfolder").actualize()
		let destFile = try base2.createUniqueFile(prefix: "aliasfile")
		let createdAlias = try file.createAlias(destination: destFile)

		// Create alias file
		XCTAssertTrue(createdAlias.exists)
		XCTAssertTrue(createdAlias.isAlias)
		XCTAssertTrue(createdAlias.isFile)
		XCTAssertFalse(createdAlias.isSymlink)

		// See if we can resolve back to the original file
		let resolved = try createdAlias.resolvingAlias().resolvingSymLinks()
		XCTAssertTrue(resolved.exists)
		XCTAssertTrue(resolved.isFile)
		XCTAssertEqual(resolved as? File, file)

		// Create alias folder
		let createdAliasFolder = try base1.createAlias(destination: base2.subfolder("aliasfolder"))
		XCTAssertTrue(createdAliasFolder.exists)
		XCTAssertTrue(createdAliasFolder.isAlias)
		XCTAssertFalse(createdAliasFolder.isSymlink)

		// Note that the alias does not appear to us as a folder. It is a file
		XCTAssertTrue(createdAliasFolder.isFile)

		// See if we can resolve back to the original folder
		let resolvedFolder = try createdAliasFolder.resolvingAlias().resolvingSymLinks()
		XCTAssertTrue(resolvedFolder.exists)
		XCTAssertEqual(resolvedFolder as? Folder, base1)
	}
#endif

	func testRecursiveSubfolderCreation() throws {
		let root1 = try Folder.Temporary(identifier: "testAddString")

		let child = try root1.subfolder(["sub1", "sub2"])
		try child.actualize()

		// Make sure the folder exists
		XCTAssertTrue(child.isFolder)
	}

	func testRename() throws {
		let root1 = try Folder.Temporary(identifier: "testRename")

		let base1 = try root1.createUniqueSubfolder(prefix: "origfolder").actualize()
		let file = try base1.file("origfile.txt", createIfNotExist: true)
		try "This is a test".write(to: file.locationURL, atomically: true, encoding: .utf8)

		let renamedFolder = try base1.rename(to: "renamedFolder")
		XCTAssertTrue(renamedFolder.isFolder)
		let repositionedFile = try renamedFolder.file(file.basename)
		XCTAssertTrue(repositionedFile.isFile)

		let renamedFile = try repositionedFile.rename(to: "renamedFolder.txt")
		XCTAssertTrue(renamedFile.isFile)
	}

	#if !os(Linux)
	func testEnumerateFolder() throws {
		let rootObject = try Folder.userLibraryFolder().subfolder("Caches")

		var results: [Location] = []
		try rootObject.enumerateContent { location in
			results.append(location)
			return results.count < 10
		}
		XCTAssertLessThanOrEqual(results.count, 10)
	}
	#endif

	func testSymlinks() throws {
		let root1 = try Folder.Temporary(identifier: "testSymlinks")

		let baseFolder = try root1.subfolder("myFolder", createIfNotExist: true)
		XCTAssertTrue(baseFolder.exists)
		XCTAssertFalse(baseFolder.isSymlink)
		XCTAssertTrue(baseFolder.isFolder)

		let baseFile = try root1.file("myFile.txt", createIfNotExist: true)
		XCTAssertTrue(baseFile.exists)
		XCTAssertFalse(baseFile.isSymlink)
		XCTAssertTrue(baseFile.isFile)

		let subfolder = try root1.subfolder("sub", createIfNotExist: true)

		let linkedFolder = try baseFolder.createSymLink(at: subfolder.subfolder("linkedFolder"))
		XCTAssertTrue(linkedFolder.exists)
		XCTAssertTrue(linkedFolder.isSymlink)
		XCTAssertTrue(linkedFolder.isFolder)

		let resolvedFolder = try linkedFolder.resolvingSymLinks()
		XCTAssertEqual(resolvedFolder.path, baseFolder.path)

		let linkedFile = try baseFile.createSymLink(at: subfolder.file("linkedFile"))
		XCTAssertTrue(linkedFile.exists)
		XCTAssertTrue(linkedFile.isSymlink)
		XCTAssertTrue(linkedFile.isFile)

		let resolvedFile = try linkedFile.resolvingSymLinks()
		XCTAssertEqual(resolvedFile.path, baseFile.path)
	}
}
