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

#if os(macOS)

import CoreServices
import Foundation

/// A basic Spotlight (NSMetadataQuery) wrapper
public class LocationQuery {
	/// The query
	public let query = NSMetadataQuery()

	/// The query predicate
	///
	/// [Syntax](https://developer.apple.com/library/archive/documentation/Carbon/Conceptual/SpotlightQuery/Concepts/QueryFormat.html#//apple_ref/doc/uid/TP40001849-CJBEJBHH)
	///
	/// [Attributes](https://developer.apple.com/library/archive/documentation/CoreServices/Reference/MetadataAttributesRef/MetadataAttrRef.html#//apple_ref/doc/uid/TP40001689)
	public var predicate: NSPredicate? {
		@inlinable get { self.query.predicate }
		@inlinable set { self.query.predicate = newValue }
	}

	/// The search scopes
	///
	/// These can be `Folder`s, folder URLs or [search scope strings](https://developer.apple.com/documentation/foundation/nsmetadataquery/1412155-searchscopes)
	public var searchScopes: [Any] {
		@inlinable get { self.query.searchScopes }
		@inlinable set {
			self.query.searchScopes = newValue.map {
				if let folder = $0 as? Folder { return folder.locationURL as Any }
				return $0
			}
		}
	}

	/// Create
	public init() {}

	deinit {
		self.stop()
	}

	private var callback: (([NSMetadataItem]) -> Void)?
	private var kvoBucket: [NSObjectProtocol] = []
}

// MARK: - Start/stop

public extension LocationQuery {
	/// Start a query on an operation queue
	/// - Parameters:
	///   - queue: The queue to perform the query on
	///   - resultsBlock: A callback block to receive the query results
	func start(
		queue: OperationQueue = .main,
		_ resultsBlock: @escaping ([NSMetadataItem]) -> Void
	) {
		self.stop()

		self.callback = resultsBlock
		self.kvoBucket.append(
			NotificationCenter.default.addObserver(
				forName: NSNotification.Name.NSMetadataQueryDidUpdate,
				object: self.query,
				queue: queue
			) { [weak self] notification in
				self?.didUpdate()
			}
		)
		self.kvoBucket.append(
			NotificationCenter.default.addObserver(
				forName: NSNotification.Name.NSMetadataQueryDidFinishGathering,
				object: self.query,
				queue: queue
			) { [weak self] notification in
				self?.initialGatherComplete()
			}
		)

		self.query.start()
	}

	/// Stop a running query.
	///
	/// The results callback is _not_ called
	func stop() {
		self.kvoBucket.forEach { NotificationCenter.default.removeObserver($0) }
		self.kvoBucket.removeAll()
		if self.query.isStarted {
			self.query.stop()
		}
	}
}

// MARK: - Metadata extensions

extension NSMetadataItem {
	/// A convenience for accessing metadata item values
	public struct Value {
		public let owner: NSMetadataItem
		@inlinable public init(owner: NSMetadataItem) { self.owner = owner }
		@inlinable public subscript(attribute: String) -> Any? { owner.value(forAttribute: attribute) }
	}

	/// A convenience for accessing metadata item values
	public var value: Value { Value(owner: self) }
}

public extension NSMetadataItem.Value {
	/// File system name
	@inlinable var baseName: String? { self[NSMetadataItemFSNameKey] as? String }
	/// URL
	@inlinable var url: URL? { self[NSMetadataItemURLKey] as? URL }
	/// Path
	@inlinable var path: String? { self[NSMetadataItemPathKey] as? String }
	/// File URL (simple url conversion from path)
	@inlinable var fileURL: URL? { if let p = self.path { return URL(fileURLWithPath: p) }; return nil }
	/// Display name
	@inlinable var displayName: String? { self[NSMetadataItemDisplayNameKey] as? String }
	/// File size
	@inlinable var fileSize: UInt64? { self[NSMetadataItemFSSizeKey] as? UInt64 }
	/// The content type (eg. "public.plain-text")
	@inlinable var contentType: String? { self[NSMetadataItemContentTypeKey] as? String }

#if os(macOS)
	/// Kind (eg. "Plain text document")
	@inlinable var kind: String? { self[NSMetadataItemKindKey] as? String }
#endif
}

// MARK: - Private

extension LocationQuery {
	private func didUpdate() {}
	private func initialGatherComplete() {
		self.stop()
		let results: [NSMetadataItem] = (0 ..< self.query.resultCount).compactMap { index in
			self.query.result(at: index) as? NSMetadataItem
		}
		self.callback?(results)
	}
}

#endif
