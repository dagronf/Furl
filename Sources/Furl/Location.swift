//
//  Copyright © 2023 Darren Ford. All rights reserved.
//
//  MIT license
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
//  documentation files (the "Software"), to deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or substantial
//  portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
//  WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
//  OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
//  OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import Foundation

#if canImport(CoreServices)
import CoreServices
#endif

#if os(macOS)
import AppKit
#endif

#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

/// Errors thrown by the library
public enum FurlError: Error {
	/// A file exists at the specified location
	case fileExistsAtURL(URL)
	/// A folder exists at the specified location
	case folderExistsAtURL(URL)
	/// The destination file already exists
	case destinationExistsAtURL(URL)
	/// The file or folder does not exist on disk
	case fileOrFolderDoesntExist(URL)
	/// Could not create a file at the given location
	case couldntCreateFile(URL)
	/// Couldn't generate a unique name in the folder
	case couldNotGenerateUniqueLocationInFolder(URL)
	/// Copy/move destination doesn't exist
	case destinationFolderDoesntExist(URL)
	/// Could not move the specified file/folder to its new destination
	case couldntMoveFileOrFolder(URL)
	/// A catch all
	case unknownError(String)
	/// Couldn't locate the specified user search path
	case couldntLocateSearchPath
}

// MARK: - Location

/// A file-system location. Does not imply the existence of the location
///
/// A location represents a file or a folder.
public protocol Location {
	/// Create a new location object with the specified fileURL
	static func Create(locationURL: URL) throws -> Self

	/// The location url
	var locationURL: URL { get }

	/// The location path
	var path: String { get }

	/// Make the item exist on disk
	/// - Parameters:
	///   - attributes: The attributes for the create file item
	///   - create: If true, creates the item on disk.
	/// - Returns: The file item
	func actualize(attributes: [FileAttributeKey: Any]?, create: Bool) throws -> Self
}

/// The state of the location object
public enum LocationState {
	/// Is a folder
	case folder
	/// Is a file
	case file
	/// Doesn't exist, therefore we don't know
	case unknown

	/// Determine the state of a url
	/// - Parameter url: The URL to check
	/// - Returns: The state for the URL
	internal static func urlState(_ url: URL) -> LocationState {
		assert(url.isFileURL)
		var isDir: ObjCBool = false
		let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
		guard exists else { return .unknown }
		return isDir.boolValue ? .folder : .file
	}
}

// MARK: Location attributes

public extension Location {
	/// The name of the file/folder
	@inlinable var basename: String { self.locationURL.lastPathComponent }
	/// The name without the extension
	@inlinable var name: String { self.locationURL.deletingPathExtension().lastPathComponent }
	/// Returns the display name (user-friendly name).
	///
	/// The result of this call is only usable display - it cannot be used in other file-system type calls.
	@inlinable var displayName: String { FileManager.default.displayName(atPath: self.path) }
	/// The location's path extension
	@inlinable var `extension`: String { self.locationURL.pathExtension }
	/// The location's state
	var state: LocationState { LocationState.urlState(self.locationURL) }
	/// Does the location exist in the filesystem?
	@inlinable var exists: Bool { return self.state != .unknown }
	/// Does the location not exist?
	@inlinable var doesNotExist: Bool { !self.exists }
	/// Is this location a folder?
	@inlinable var isFolder: Bool { self.state == .folder }
	/// Is this location a file?
	@inlinable var isFile: Bool { self.state == .file }
	/// Is this location an alias file?
	@inlinable var isAlias: Bool {
		(try? locationURL.resourceValues(forKeys: [.isAliasFileKey]).isAliasFile) ?? false
	}

	/// Is this location a symbolic link?
	@inlinable var isSymlink: Bool {
		(try? self.locationURL.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) ?? false
	}

	/// The parent folder
	@inlinable var parent: Folder { Folder(folderURL: self.locationURL.deletingLastPathComponent()) }
}

public extension Location {
	/// Test whether a path is readable
	///
	/// - Returns: `true` if the current process has read privileges for the file at path;
	///   otherwise `false` if the process does not have read privileges or the existence of the
	///   file could not be determined.
	var isReadable: Bool { FileManager.default.isReadableFile(atPath: self.path) }

	/// Test whether a path is writeable
	///
	/// - Returns: `true` if the current process has write privileges for the file at path;
	///   otherwise `false` if the process does not have write privileges or the existence of the
	///   file could not be determined.
	var isWritable: Bool { FileManager.default.isWritableFile(atPath: self.path) }

	/// Test whether a path is executable
	///
	/// - Returns: `true` if the current process has execute privileges for the file at path;
	///   otherwise `false` if the process does not have execute privileges or the existence of the
	///   file could not be determined.
	var isExecutable: Bool { FileManager.default.isExecutableFile(atPath: self.path) }

	/// Test whether a path is deletable
	///
	/// - Returns: `true` if the current process has delete privileges for the file at path;
	///   otherwise `false` if the process does not have delete privileges or the existence of the
	///   file could not be determined.
	var isDeletable: Bool { FileManager.default.isDeletableFile(atPath: self.path) }
}

public extension Location {
	/// File creation date
	///
	/// [Documentation](https://developer.apple.com/documentation/foundation/fileattributekey/1418187-creationdate)
	///
	/// This API has the potential of being misused to access device signals to try to identify the device or user,
	/// also known as fingerprinting. Regardless of whether a user gives your app permission to track, fingerprinting
	/// is not allowed. When you use this API in your app or third-party SDK (an SDK not provided by Apple), declare
	/// your usage and the reason for using the API in your app or third-party SDK’s PrivacyInfo.xcprivacy file.
	///
	/// For more information, including the list of valid reasons for using the API,
	/// see Describing use of required reason API.
	var creationDate: Date? { self.attributes[FileAttributeKey.creationDate] as? Date }

	/// File modification date
	///
	/// [Documentation](https://developer.apple.com/documentation/foundation/fileattributekey/1410058-modificationdate)
	///
	/// This API has the potential of being misused to access device signals to try to identify the device or user,
	/// also known as fingerprinting. Regardless of whether a user gives your app permission to track, fingerprinting
	/// is not allowed. When you use this API in your app or third-party SDK (an SDK not provided by Apple), declare
	/// your usage and the reason for using the API in your app or third-party SDK’s PrivacyInfo.xcprivacy file.
	///
	/// For more information, including the list of valid reasons for using the API,
	/// see Describing use of required reason API.
	var modificationDate: Date? { self.attributes[FileAttributeKey.modificationDate] as? Date }
}

#if !os(Linux)
public extension Location {
	/// Is the location's extension hidden
	///
	/// [Documentation](https://developer.apple.com/documentation/foundation/fileattributekey/1409258-extensionhidden)
	@inlinable var isExtensionHidden: Bool {
		get { self.attributes[FileAttributeKey.extensionHidden] as? Bool ?? false }
		set { try? self.setAttribute(newValue, forKey: .extensionHidden) }
	}

	/// Is the location locked? (the 'Locked' status in the get info panel)
	@inlinable var isLocked: Bool {
		get { self.attributes[FileAttributeKey.immutable] as? Bool ?? false }
		set { try? self.setAttribute(newValue, forKey: .immutable) }
	}
}
#endif

public extension Location {
	/// Returns the attributes of the item at a given path
	@inlinable var attributes: [FileAttributeKey: Any] {
		(try? FileManager.default.attributesOfItem(atPath: self.path)) ?? [:]
	}

	/// Sets the attributes of a location
	@inlinable func setAttributes(_ values: [FileAttributeKey: Any]) throws {
		try FileManager.default.setAttributes(values, ofItemAtPath: self.path)
	}

	/// Sets an attribute of a location
	@inlinable func setAttribute(_ value: Any, forKey key: FileAttributeKey) throws {
		try self.setAttributes([key: value])
	}
}

public extension Location {
	/// Returns a collection of resource values identified by the given resource keys
	@inlinable func resourceValues(forKeys keys: Set<URLResourceKey>) throws -> URLResourceValues {
		try self.locationURL.resourceValues(forKeys: keys)
	}

	/// Localized or extension-hidden name as displayed to users
	@inlinable func localizedName() throws -> String? {
		try self.resourceValues(forKeys: [.localizedNameKey]).localizedName
	}
}

// MARK: Trash/delete

public extension Location {
	/// Remove the file/folder from disk immediately.
	///
	/// If this item is a folder, the entire content of the folder is deleted along with the folder itself
	@inlinable func delete() throws {
		try FileManager.default.removeItem(at: self.locationURL)
	}

	#if os(macOS)
	/// Move the file to the trash. Throws an error if the file/folder doesn't exist on disk
	/// - Returns: The location within the trash folder
	@discardableResult func moveToTrash() throws -> Self {
		guard self.exists else { throw FurlError.fileOrFolderDoesntExist(self.locationURL) }

		var resultURL: NSURL?
		try FileManager.default.trashItem(at: self.locationURL, resultingItemURL: &resultURL)

		// If we are a folder, the result is a Folder. If we are a file, the result is a File
		guard let url = resultURL as? URL else { throw FurlError.unknownError("trashItem URL was nil?") }
		return try Self.Create(locationURL: url)
	}

	/// Reveal this location in a new Finder window
	/// - Returns: True if the location was successfully presented in a new Finder window
	@discardableResult @inlinable func revealInFinder() -> Bool {
		NSWorkspace.shared.selectFile(self.path, inFileViewerRootedAtPath: self.parent.path)
	}
	#endif
}

#if !os(Linux)

// MARK: Universal Type Identifier support

// MARK: Legacy

public extension Location {
	/// The resource’s uniform type identifier (UTI) as a string
	@inlinable func typeIdentifier() throws -> String? {
		try self.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier
	}

	/// Does this location conform to the provided type identifier (eg. "public.image")
	@inlinable func conformsTo(_ typeIdentifier: String) throws -> Bool {
		guard let tf = try self.typeIdentifier() else { return false }
		return UTTypeConformsTo(tf as CFString, typeIdentifier as CFString)
	}
}

// MARK: Modern

@available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
public extension Location {
	/// Returns the UTType for the file
	@inlinable func contentType() throws -> UTType? {
		return try self.locationURL.resourceValues(forKeys: [.contentTypeKey]).contentType
	}

	/// Does this file/folder conform to the specified UTType
	@inlinable func conformsTo(_ utType: UTType) throws -> Bool {
		try self.contentType()?.conforms(to: utType) ?? false
	}
}

#endif

// MARK: Alias/Shortcuts

public extension Location {
	/// Resolve any symbolic links in the location and return the result
	@inlinable func resolvingSymLinks() throws -> Self {
		try Self.Create(locationURL: self.locationURL.resolvingSymlinksInPath())
	}

	/// Create a symbolic link for this location
	/// - Parameter destination: The location where the symlink should be created
	/// - Returns: A location file representing the created symlink
	@inlinable func createSymLink(at destination: Location) throws -> Location {
		try self.createSymLink(at: destination.locationURL)
	}

	/// Create a symbolic link for this location
	/// - Parameter destinationURL: The location URL for the created symbolic link
	/// - Returns: A location
	func createSymLink(at destinationURL: URL) throws -> Self {
		// The source must exist
		guard self.exists else { throw FurlError.fileOrFolderDoesntExist(self.locationURL) }
		// The destination mustn't exist
		guard LocationState.urlState(destinationURL) == .unknown else {
			throw FurlError.destinationExistsAtURL(destinationURL)
		}

		// Create the symlink
		try FileManager.default.createSymbolicLink(at: destinationURL, withDestinationURL: self.locationURL)

		return try Self.Create(locationURL: destinationURL)
	}
}

#if !os(Linux)
public extension Location {
	/// Returns the resolution of an alias
	///
	/// If the location isn't an alias, returns the original location
	func resolvingAlias() throws -> Location {
		guard self.isAlias else { return self }

		var options: URL.BookmarkResolutionOptions = [.withoutMounting, .withoutUI]
		#if os(macOS)
		options.insert(.withSecurityScope)
		#endif

		let resolved = try URL(resolvingAliasFileAt: self.locationURL, options: options)

		switch LocationState.urlState(resolved) {
		case .file: return File(fileURL: resolved)
		case .folder: return Folder(folderURL: resolved)
		default: throw FurlError.fileOrFolderDoesntExist(resolved)
		}
	}

	/// Create an alias file for this location
	/// - Parameters:
	///   - destination: The location to create the alias file
	///   - keys: resource keys to include in the alias file definition
	///   - options: alias options, such as security options etc
	/// - Returns: The created alias file
	func createAlias(
		destination: Location,
		includingResourceValuesForKeys keys: Set<URLResourceKey>? = nil,
		options: URL.BookmarkCreationOptions = []
	) throws -> Location {
		// The source must exist
		guard self.exists else { throw FurlError.fileOrFolderDoesntExist(self.locationURL) }
		// The destination mustn't exist
		guard destination.exists == false else { throw FurlError.destinationExistsAtURL(destination.locationURL) }

		// This creates a hard link
		// try FileManager.default.linkItem(at: self.fileURL, to: destination.fileURL)

		// Mark that the data needs to be bookmark data
		var options = options
		options.insert(.suitableForBookmarkFile)

		// Create the bookmark data
		let bookmarkData = try self.locationURL.bookmarkData(
			options: options,
			includingResourceValuesForKeys: keys,
			relativeTo: nil
		)

		// Write the bookmark data to the destination alias file
		try URL.writeBookmarkData(bookmarkData, to: destination.locationURL)

		assert(destination.isAlias)

		return destination
	}
}
#endif

// MARK: Move, copy, rename

public extension Location {
	/// Move this location into a destination folder
	/// - Parameter destinationFolder: The destination for the move
	/// - Returns: A folder representing the new location within the destination folder
	func move(into destinationFolder: Folder) throws -> Self {
		guard self.exists else { throw FurlError.fileOrFolderDoesntExist(self.locationURL) }
		guard destinationFolder.isFolder else {
			throw FurlError.destinationFolderDoesntExist(destinationFolder.folderURL)
		}

		// Make the destination URL
		let destination = destinationFolder.folderURL.appendingPathComponent(self.basename, isDirectory: self.isFolder)

		// Check that the destination doesn't exist.
		guard LocationState.urlState(destination) == .unknown else {
			throw FurlError.fileExistsAtURL(destination)
		}

		// Attempt the move
		try FileManager.default.moveItem(at: self.locationURL, to: destination)

		// We're returning the same type as us
		return try Self.Create(locationURL: destination)
	}

	/// Copy this location into a destination folder
	/// - Parameter destinationFolder: The destination folder for the copy
	/// - Returns: A folder representing the new location within the destination folder
	func copy(into destinationFolder: Folder) throws -> Self {
		guard self.exists else { throw FurlError.fileOrFolderDoesntExist(self.locationURL) }
		guard destinationFolder.isFolder else {
			throw FurlError.destinationFolderDoesntExist(destinationFolder.folderURL)
		}

		// Make the destination URL using the file name of the copy
		let destination = destinationFolder.folderURL.appendingPathComponent(self.basename, isDirectory: self.isFolder)

		// Check that the destination doesn't already exist.
		guard LocationState.urlState(destination) == .unknown else {
			throw FurlError.fileExistsAtURL(destination)
		}

		// Attempt the copy. This copies recursively in the case of folder copy
		try FileManager.default.copyItem(at: self.locationURL, to: destination)

		// We're returning the same type as us
		return try Self.Create(locationURL: destination)
	}

	/// Rename this file/folder
	/// - Parameter newName: The new name for the location
	/// - Returns: A new location
	func rename(to newName: String) throws -> Self {
		// Work out the name for the renamed file
		let newURL = self.parent.folderURL.appendingPathComponent(newName)
		// Check that it doesn't exist before the rename
		guard LocationState.urlState(newURL) == .unknown else { throw FurlError.destinationExistsAtURL(newURL) }

		// Attempt the move
		try FileManager.default.moveItem(at: self.locationURL, to: newURL)

		// We're return the renamed location
		return try Self.Create(locationURL: newURL)
	}
}

// MARK: - File

/// A file
public struct File: Location, CustomDebugStringConvertible, Equatable {
	/// The location url
	public let locationURL: URL
	/// The file url
	@inlinable public var fileURL: URL { self.locationURL }
	/// The file path
	public let path: String
	/// The file's description
	public var debugDescription: String { "File(\(self.path))" }

	/// Create a File with the specified fileURL
	///
	/// Throws an error if fileURL exists and is not an existing file
	public static func Create(locationURL: URL) throws -> Self {
		if LocationState.urlState(locationURL) == .folder { throw FurlError.folderExistsAtURL(locationURL) }
		return Self(fileURL: locationURL)
	}

	/// Create using a file URL
	public init(fileURL: URL) {
		assert(fileURL.isFileURL)
		self.locationURL = fileURL
		self.path = self.locationURL.path
	}

	/// Create using a file path. Expands tilde ~ at the start of the path as required (eg. ~/Desktop/noodle.txt -> /Users/Womble/Desktop/noodle.txt)
	public init(path: String) {
		self.path = __expandingTildeInPath(path)
		self.locationURL = URL(fileURLWithPath: self.path, isDirectory: false)
	}

	/// Equality
	@inlinable public static func == (lhs: File, rhs: File) -> Bool { lhs.path == rhs.path }

	/// Return a [normalized representation](https://developer.apple.com/documentation/foundation/nsurl/1414302-standardizingpath)
	/// of this file URL
	@inlinable public var standardized: Self { File(fileURL: self.locationURL.standardizedFileURL) }

	/// Make the file exist on disk if it doesn't yet exist
	/// - Parameters:
	///   - attributes: The attributes of the file
	///   - create: If true, creates the file if it doesn't exist
	/// - Returns: A file object
	///
	/// Notes:
	/// * If the parent folder doesn't exist, attempts to actualize the parent folder first
	/// * A basic wrapper for [createFile](https://developer.apple.com/documentation/foundation/filemanager/1410695-createfile)
	@discardableResult
	public func actualize(attributes: [FileAttributeKey: Any]? = nil, create: Bool = true) throws -> Self {
		switch self.state {
		case .folder:
			// Folder exists at location
			throw FurlError.folderExistsAtURL(self.locationURL)
		case .file:
			// File already exists - just ignore
			break
		case .unknown:
			// Nothing exists at the location.
			if create {
				// Make sure the parent folder exists first
				try self.parent.actualize(create: create)

				// Create an empty file.
				guard FileManager.default.createFile(atPath: self.path, contents: nil, attributes: attributes) else {
					throw FurlError.couldntCreateFile(self.locationURL)
				}
			}
		}
		return self
	}

	/// The size of the file in bytes. If the file doesn't yet exist (or an error occurs) returns UInt64.max
	///
	/// [Documentation](https://developer.apple.com/documentation/foundation/fileattributekey/1416548-size)
	public var fileSize: UInt64 { self.attributes[FileAttributeKey.size] as? UInt64 ?? .max }
}

public extension File {
	/// Geerate a temporary file with a specified name
	/// - Parameters:
	///   - name: The temporary file's name
	///   - create: If true creates an empty file on disk
	/// - Returns: File
	@inlinable static func Temporary(
		named name: String,
		create: Bool = false
	) throws -> File {
		try Folder.Temporary().file(name, createIfNotExist: create)
	}

	/// Create a temporary file of the form `<prefix>_<random>[.fileExtension]`
	/// - Parameters:
	///   - prefix: The filename's prefix (eg. tmp)
	///   - fileExtension: The file's extension
	///   - create: If true creates an empty file on disk
	/// - Returns: File
	@inlinable static func Temporary(
		prefix: String = "tmp",
		fileExtension: String = "",
		create: Bool = false
	) throws -> File {
		try Folder.Temporary().createUniqueFile(prefix: prefix, fileExtension: fileExtension, create: create)
	}
}

// MARK: - Folder

/// A folder
public struct Folder: Location, CustomDebugStringConvertible, Equatable {
	/// The folder location URL
	public let locationURL: URL
	/// The folder's URL
	@inlinable public var folderURL: URL { self.locationURL }
	/// The folder's path
	public let path: String
	/// Debug string
	public var debugDescription: String { "Folder(\(self.path))" }

	/// Create a Folder with the specified fileURL
	///
	/// Throws an error if fileURL exists and is not an existing folder
	public static func Create(locationURL: URL) throws -> Self {
		if LocationState.urlState(locationURL) == .file { throw FurlError.fileExistsAtURL(locationURL) }
		return Self(folderURL: locationURL)
	}

	/// Create a folder location using a folder URL
	public init(folderURL: URL) {
		assert(folderURL.isFileURL)
		self.path = folderURL.path
		self.locationURL = folderURL
	}

	/// Create a folder location using a folder path string (eg `"/tmp/myfolder"`.
	/// - Parameter path: The folder's path
	///
	///  Expands tilde ~ at the start of the path as required (eg. ~/Desktop -> /Users/Womble/Desktop)
	public init(path: String) {
		self.path = __expandingTildeInPath(path)
		self.locationURL = URL(fileURLWithPath: self.path, isDirectory: true)
	}

	/// Equality
	///
	/// Equality is determined using the folder's path
	@inlinable public static func == (lhs: Folder, rhs: Folder) -> Bool { lhs.path == rhs.path }

	/// Return a [normalized representation](https://developer.apple.com/documentation/foundation/nsurl/1414302-standardizingpath)
	/// of this folder URL
	@inlinable public var standardized: Self { Folder(folderURL: self.folderURL.standardizedFileURL) }

	/// Make the folder exist on disk if it doesn't yet exist
	/// - Parameters:
	///   - attributes: The folder's attributes
	///   - create: Create the folder if it doesn't yet exist
	/// - Returns: A folder representation

	/// Make the folder exist on disk if it doesn't yet exist
	/// - Parameters:
	///   - attributes: The attributes of the folder
	///   - create: If true, creates the folder if it doesn't exist
	/// - Returns: A folder object
	///
	/// Notes:
	/// * If the parent folder doesn't exist, attempts to actualize the parent folder first
	/// * A basic wrapper for [createDirectory](https://developer.apple.com/documentation/foundation/filemanager/1407884-createdirectory)
	@discardableResult
	public func actualize(attributes: [FileAttributeKey: Any]? = nil, create: Bool = true) throws -> Self {
		switch self.state {
		case .folder:
			// Already exists
			break
		case .file:
			throw FurlError.fileExistsAtURL(self.locationURL)
		case .unknown:
			if create {
				try FileManager.default.createDirectory(
					at: self.locationURL,
					withIntermediateDirectories: true,
					attributes: attributes
				)
			}
		}
		return self
	}
}

// MARK: Temporary files/folders

public extension Folder {
	// Note:  DateFormatter is thread safe
	// See https://developer.apple.com/documentation/foundation/dateformatter#1680059
	private static let iso8601Formatter: DateFormatter = {
		let dateFormatter = DateFormatter()
		dateFormatter.locale = Locale(identifier: "en_US_POSIX") // set locale to reliable US_POSIX ISO8601
		// dateFormatter.dateFormat = "yyyy-MM-dd'T'HHmmssZ"
		dateFormatter.dateFormat = "yyyy-MM-dd'T'HHmmss-AAAAAAZ"
		return dateFormatter
	}()

	/// Returns a new temporary folder
	/// - Parameter create: If true, creates the folder on disk
	/// - Returns: A folder
	static func Temporary(create: Bool = false) throws -> Folder {
		let temp = try FileManager.default.url(
			for: .itemReplacementDirectory,
			in: .userDomainMask,
			appropriateFor: URL(fileURLWithPath: NSTemporaryDirectory()),
			create: create
		)
		return Folder(folderURL: temp)
	}

	/// Create a named folder within the temporary folder.
	///
	/// Creates a subfolder of the form `<temporary folder>/<identifier>/<date>/`
	static func Temporary(identifier: String) throws -> Folder {
		let url = FileManager.default
			.temporaryDirectory
			.appendingPathComponent(identifier)
			.appendingPathComponent(Self.iso8601Formatter.string(from: Date()))
		return try Folder(folderURL: url).actualize(create: true)
	}

	/// Create a temporary file in this folder
	/// - Parameters:
	///   - prefix: A prefix to prepend to the unique file name. Defaults to "tmp"
	///   - fileExtension: The extension for the file
	///   - create: If true, create the file on disk
	/// - Returns: A file
	func createUniqueFile(prefix: String = "tmp", fileExtension: String = "", create: Bool = false) throws -> File {
		// Make sure the parent folder exists
		try self.actualize()

		// Make a unique name in the folder, and create if if necessary
		let uniqueURL = try __uniqueNameInFolder(self.folderURL, prefix: prefix, fileExtension: fileExtension)
		return try File(fileURL: uniqueURL).actualize(create: create)
	}

	/// Create a temporary folder in this folder of the form `<prefix>_<tempstring>[.fileExtension]`
	/// - Parameters:
	///   - prefix: A prefix to prepend to the unique file name. Defaults to "tmp"
	///   - folderExtension: The extension for the folder
	///   - create: If true, create the folder on disk
	/// - Returns: A folder
	func createUniqueSubfolder(
		prefix: String = "tmp",
		folderExtension: String = "",
		create: Bool = false
	) throws -> Folder {
		// Make sure the parent folder exists
		try self.actualize()

		// Make a unique name in the folder
		let uniqueURL = try __uniqueNameInFolder(self.locationURL, prefix: prefix, fileExtension: folderExtension)

		// Create it if necessary, and return
		return try Folder(folderURL: uniqueURL).actualize(create: create)
	}

	/// Create a subfolder of the form `<identifier>/<isodatestring>/`
	/// - Parameter identifier: A top-level identifier
	/// - Returns: A folder
	func createUniqueDatedSubfolder(identifier: String) throws -> Folder {
		let url = self.folderURL
			.appendingPathComponent(identifier)
			.appendingPathComponent(Self.iso8601Formatter.string(from: Date()))
		return try Folder(folderURL: url).actualize(create: true)
	}
}

// MARK: Finding folders/files within this folder

public extension Folder {
	/// Does this folder contain this file or folder?
	/// - Parameter:
	///   - name: The name (including any extension) of the file/folder
	/// - Returns: True if the named file/folder exists
	@inlinable func contains(named name: String) throws -> Bool {
		precondition(self.isFolder)
		return try self.file(name).state != .unknown
	}

	/// Does this folder contain a named folder?
	/// - Parameter:
	///   - name: The name (including any extension) of the folder
	/// - Returns: True if the named folder exists within this folder
	@inlinable func containsFolder(named name: String) throws -> Bool {
		precondition(self.isFolder)
		return try self.file(name).state == .folder
	}

	/// Does this folder contain a named file?
	/// - Parameter:
	///   - name: The name (including any extension) of the file
	/// - Returns: True if the named file exists within the folder
	@inlinable func containsFile(named name: String) throws -> Bool {
		precondition(self.isFolder)
		return try self.file(name).state == .file
	}
}

// MARK: Folder children

public extension Folder {
	/// Returns a subfolder within this folder
	/// - Parameters:
	///   - name: The name of the subfolder
	///   - create: If true, creates the folder if it doesn't yet exist.
	/// - Returns: A folder
	func subfolder(_ name: String, createIfNotExist create: Bool = false) throws -> Folder {
		precondition(name.count > 0)

		// If we are actually a file, throw an error
		guard self.isFile == false else { throw FurlError.fileExistsAtURL(self.folderURL) }

		let child = self.folderURL.appendingPathComponent(name, isDirectory: true)
		return try Folder(folderURL: child).actualize(create: create)
	}

	/// Generate a multiple-level subfolder
	/// - Parameters:
	///   - components: An array of strings of each of the subfolder names
	///   - create: Create the resulting folder on disk, including all intermediate folders
	/// - Returns: A folder
	///
	/// `root.subfolder("lvl1", "item2")` returns `root + "<current folder>/lvl1/item2"`
	func subfolder(_ components: [String], createIfNotExist create: Bool = false) throws -> Folder {
		precondition(components.count > 0)

		// If we are actually a file, throw an error
		guard self.isFile == false else { throw FurlError.fileExistsAtURL(self.folderURL) }

		// Build the result folder
		var result = self.folderURL
		components.forEach { component in
			result = result.appendingPathComponent(component, isDirectory: true)
		}
		return try Folder(folderURL: result).actualize(create: create)
	}

	/// Return a named file in the current folder. The file may or may not exist at this point
	/// - Parameters:
	///   - name: The name of the file
	///   - create: If true, creates the file on disk if it doesn't already exist
	/// - Returns: A file
	func file(_ name: String, createIfNotExist create: Bool = false) throws -> File {
		precondition(name.count > 0)

		// If we are actually a folder, throw an error
		// Note that if the file status is unknown we are still fine, as we may be representing a file
		// that hasn't been created yet
		guard self.isFile == false else { throw FurlError.fileExistsAtURL(self.folderURL) }

		let child = self.folderURL.appendingPathComponent(name)
		return try File(fileURL: child).actualize(create: create)
	}

	/// Returns a location within this folder. Throws if there is not file/folder with this name
	/// - Parameter name: The name of the child location
	/// - Returns: An location
	func item(named name: String) throws -> Location {
		precondition(name.count > 0)

		// If we are actually a file, throw an error
		guard self.isFile == false else { throw FurlError.fileExistsAtURL(self.folderURL) }

		let child = self.folderURL.appendingPathComponent(name)
		switch LocationState.urlState(child) {
		case .file: return File(fileURL: child)
		case .folder: return Folder(folderURL: child)
		case .unknown: throw FurlError.fileOrFolderDoesntExist(child)
		}
	}

	/// Writes data to a file in the current folder, creating the folder if it doesn't already exist
	/// - Parameters:
	///   - name: The name of the file to write to
	///   - data: The data to write
	/// - Returns: The written file
	///
	/// Overwrites existing data if the file exists
	func writeDataToFile(named name: String, _ data: Data) throws -> File {
		// Make sure we (the parent folder for the file) exists on disk
		try self.actualize()

		// Create the file, and write to disk
		let file = try self.file(name)
		try data.write(to: file.locationURL)
		return file
	}
}

// MARK: Folder content

public extension Folder {
	/// Is the folder empty?
	///
	/// Throws an error if the url is not a folder or doesn't exist
	@inlinable func isEmpty() throws -> Bool {
		try FileManager.default.contentsOfDirectory(atPath: self.path).isEmpty
	}

	/// Enumerate the contents of the folder
	/// - Parameters:
	///   - shallow: If true, does not recurse into subfolders
	///   - includeHiddenFiles: Include hidden files
	///   - recurseIntoPackages: Recurse into packages
	///   - notifyBlock: The callback block for each enumerated item. Returning false will stop the enumeration
	/// - Returns: File objects
	///
	/// Notes:
	/// * Does not follow symlinks or file aliases
	func enumerateContent(
		shallow: Bool = true,
		includeHiddenFiles: Bool = false,
		recurseIntoPackages: Bool = false,
		_ notifyBlock: (Location) -> Bool
	) throws {
		var fmo = FileManager.DirectoryEnumerationOptions()
		if shallow { fmo.insert(.skipsSubdirectoryDescendants) }
		if !includeHiddenFiles { fmo.insert(.skipsHiddenFiles) }
		if !recurseIntoPackages { fmo.insert(.skipsPackageDescendants) }

		guard let enumerator = FileManager.default.enumerator(
			at: locationURL,
			includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isAliasFileKey, .isSymbolicLinkKey],
			options: fmo
		)
		else {
			throw FurlError.unknownError("Couldn't create enumerator?")
		}

		while let fileURL = enumerator.nextObject() as? URL {
			guard let rvs = try? fileURL.resourceValues(
				forKeys: [.isDirectoryKey, .isRegularFileKey, .isAliasFileKey, .isSymbolicLinkKey]
			)
			else {
				continue
			}

			let currentLocation: Location? = {
				if rvs.isDirectory ?? false { return Folder(folderURL: fileURL) }
				if rvs.isRegularFile ?? false { return File(fileURL: fileURL) }
				return nil
			}()

			if let current = currentLocation, notifyBlock(current) == false {
				return
			}
		}
	}

	/// Return the contents of the folder
	/// - Parameters:
	///   - shallow: If true, does not recurse into subfolders
	///   - includeHiddenFiles: Include hidden files
	///   - recurseIntoPackages: Recurse into packages
	///   - fileType: An optional file type filter (eg. folders only, files only)
	///   - filter: An optional filter block
	/// - Returns: File objects
	///
	/// Notes:
	/// * Does not follow symlinks or file aliases
	private func allContents(
		shallow: Bool = true,
		includeHiddenFiles: Bool = false,
		recurseIntoPackages: Bool = false,
		fileType: LocationState? = nil,
		filter: ((URL) -> Bool)? = nil
	) throws -> [Location] {
		var fmo = FileManager.DirectoryEnumerationOptions()
		if shallow { fmo.insert(.skipsSubdirectoryDescendants) }
		if !includeHiddenFiles { fmo.insert(.skipsHiddenFiles) }
		if !recurseIntoPackages { fmo.insert(.skipsPackageDescendants) }

		var result: [Location] = []
		if let enumerator = FileManager.default.enumerator(
			at: locationURL,
			includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isAliasFileKey, .isSymbolicLinkKey],
			options: fmo
		) {
			for case let fileURL as URL in enumerator {
				// If the filter was specified, check with it first
				if let filterFunc = filter, filterFunc(fileURL) == false {
					// Filter says no
					continue
				}

				guard let rvs = try? fileURL.resourceValues(
					forKeys: [.isDirectoryKey, .isRegularFileKey, .isAliasFileKey, .isSymbolicLinkKey]
				)
				else {
					continue
				}

				let isDir: Bool = rvs.isDirectory ?? false
				let isFile: Bool = rvs.isRegularFile ?? false

				if isDir, fileType == nil || fileType == .folder {
					result.append(Folder(folderURL: fileURL))
				}
				else if isFile, fileType == nil || fileType == .file {
					result.append(File(fileURL: fileURL))
				}
			}
		}
		return result
	}

	/// Return the contents of the folder
	/// - Parameters:
	///   - shallow: If true, does not recurse into subfolders
	///   - includeHiddenFiles: Include hidden files
	///   - recurseIntoPackages: Recurse into packages
	///   - filter: An optional filter block
	/// - Returns: File objects
	///
	/// Notes:
	/// * Does not follow symlinks or file aliases
	func allContent(
		shallow: Bool = true,
		includeHiddenFiles: Bool = false,
		recurseIntoPackages: Bool = false,
		filter: ((URL) -> Bool)? = nil
	) throws -> [Location] {
		let results = try self.allContents(
			shallow: shallow,
			includeHiddenFiles: includeHiddenFiles,
			recurseIntoPackages: recurseIntoPackages,
			filter: filter
		)
		return results
	}

	/// Return the subfolders of the folder
	/// - Parameters:
	///   - shallow: If true, does not recurse into subfolders
	///   - includeHiddenFiles: Include hidden folders
	///   - recurseIntoPackages: Recurse into packages
	///   - filter: An optional filter block
	/// - Returns: Folders
	///
	/// Notes:
	/// * Does not follow symlinks or file aliases
	func allSubfolders(
		shallow: Bool = true,
		includeHiddenFiles: Bool = false,
		recurseIntoPackages: Bool = false,
		filter: ((URL) -> Bool)? = nil
	) throws -> [Folder] {
		let results = try self.allContents(
			shallow: shallow,
			includeHiddenFiles: includeHiddenFiles,
			recurseIntoPackages: recurseIntoPackages,
			fileType: .folder,
			filter: filter
		)
		return results.compactMap { $0 as? Folder }
	}

	/// Return the files of the folder
	/// - Parameters:
	///   - shallow: If true, does not recurse into subfolders
	///   - includeHiddenFiles: Include hidden folders
	///   - recurseIntoPackages: Recurse into packages
	///   - includeSymlinks: If false, ignores symlinked files and folders
	///   - filter: An optional filter block
	/// - Returns: Files
	///
	/// Notes:
	/// * Does not follow symlinks or file aliases
	func allFiles(
		shallow: Bool = true,
		includeHiddenFiles: Bool = false,
		recurseIntoPackages: Bool = false,
		filter: ((URL) -> Bool)? = nil
	) throws -> [File] {
		let results = try self.allContents(
			shallow: shallow,
			includeHiddenFiles: includeHiddenFiles,
			recurseIntoPackages: recurseIntoPackages,
			fileType: .file,
			filter: filter
		)
		return results.compactMap { $0 as? File }
	}
}

// MARK: - Common user folders

public extension Folder {
	/// The user's home folder (`/User/<name>/`)
	@inlinable static func userHomeFolder() -> Folder { Folder(path: NSHomeDirectory()) }
	/// The current working directory of the process
	@inlinable static func current() throws -> Folder { Folder(path: FileManager.default.currentDirectoryPath) }
	/// The user's temporary folder
	@inlinable static func userTemporaryFolder() -> Folder { Folder(folderURL: FileManager.default.temporaryDirectory) }
}

#if !os(Linux)
public extension Folder {
	/// The user's documents folder
	@inlinable static func userDocumentsFolder() throws -> Folder { try Self.userSearchPath(for: .documentDirectory) }
	/// The user's desktop folder
	@inlinable static func userDesktopFolder() throws -> Folder { try Self.userSearchPath(for: .desktopDirectory) }
	/// The user's caches folder
	@inlinable static func userCachesFolder() throws -> Folder { try Self.userSearchPath(for: .cachesDirectory) }
	/// The user's downloads folder
	@inlinable static func userDownloadsFolder() throws -> Folder { try Self.userSearchPath(for: .downloadsDirectory) }
	/// The user's library folder
	@inlinable static func userLibraryFolder() throws -> Folder { try Self.userSearchPath(for: .libraryDirectory) }
}
#endif

#if os(macOS)
public extension Folder {
	/// The user's trash folder
	static func userTrashFolder() throws -> Folder { try Self.userSearchPath(for: .trashDirectory) }
}
#endif

public extension Folder {
	/// Returns the user search paths for the specified search path
	static func userSearchPaths(for search: FileManager.SearchPathDirectory) -> [Folder] {
		FileManager.default.urls(for: search, in: .userDomainMask)
			.map { Folder(folderURL: $0) }
	}

	/// Returns the first user search path for the specified search path
	static func userSearchPath(for search: FileManager.SearchPathDirectory) throws -> Folder {
		guard let folder = Self.userSearchPaths(for: search).first else {
			throw FurlError.couldntLocateSearchPath
		}
		return folder
	}
}

// MARK: - Utility functions

// Expand a tilde in the specified file path
private func __expandingTildeInPath(_ path: String) -> String {
	let path = path.trimmingCharacters(in: .whitespaces)
	if path.hasPrefix("~") {
		// let homePath = ProcessInfo.processInfo.environment["HOME"]!
		return Folder.userHomeFolder().path + path.dropFirst()
	}
	return path
}

// Create a unique name in a folder

private let __fsAllowedChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890[]-_+=#"

// Generate a file/folder name that is unique within the specified folder
private func __uniqueNameInFolder(
	_ folderURL: URL,
	prefix: String = "tmp",
	fileExtension: String = ""
) throws -> URL {
	// Folder must exist before calling this function
	guard LocationState.urlState(folderURL) == .folder else {
		throw FurlError.fileOrFolderDoesntExist(folderURL)
	}

	var count = 1000
	while count > 0 {
		let tempStr = (0 ..< 8).reduce("") { partialResult, _ in
			let o = Int.random(in: 0 ..< __fsAllowedChars.count)
			let c = __fsAllowedChars[__fsAllowedChars.index(__fsAllowedChars.startIndex, offsetBy: o)]
			return partialResult + String(c)
		}

		let filename = prefix + "_" + tempStr + (fileExtension.count > 0 ? "." : "") + fileExtension
		let fso = folderURL.appendingPathComponent(filename)
		if FileManager.default.fileExists(atPath: fso.path) == false {
			return fso
		}
		count -= 1
	}
	throw FurlError.couldNotGenerateUniqueLocationInFolder(folderURL)
}
