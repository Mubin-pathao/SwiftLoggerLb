//
//  File.swift
//  
//
//  Created by Pathao Ltd on 31/12/24.
//

import Darwin

@preconcurrency protocol _SwiftLogSendable: Sendable {}

extension Logger {
    /// A `MetadataProvider` is used to automatically inject runtime-generated metadata
    /// to all logs emitted by a logger.
    ///
    /// ### Example
    /// A metadata provider may be used to automatically inject metadata such as
    /// trace IDs:
    ///
    /// ```swift
    /// import Tracing // https://github.com/apple/swift-distributed-tracing
    ///
    /// let metadataProvider = MetadataProvider {
    ///     guard let traceID = Baggage.current?.traceID else { return nil }
    ///     return ["traceID": "\(traceID)"]
    /// }
    /// let logger = Logger(label: "example", metadataProvider: metadataProvider)
    /// var baggage = Baggage.topLevel
    /// baggage.traceID = 42
    /// Baggage.withValue(baggage) {
    ///     logger.info("hello") // automatically includes ["traceID": "42"] metadata
    /// }
    /// ```
    ///
    /// We recommend referring to [swift-distributed-tracing](https://github.com/apple/swift-distributed-tracing)
    /// for metadata providers which make use of its tracing and metadata propagation infrastructure. It is however
    /// possible to make use of metadata providers independently of tracing and instruments provided by that library,
    /// if necessary.
    public struct MetadataProvider: _SwiftLogSendable {
        /// Provide ``Logger.Metadata`` from current context.
        @usableFromInline
        internal let _provideMetadata: @Sendable () -> Metadata

        /// Create a new `MetadataProvider`.
        ///
        /// - Parameter provideMetadata: A closure extracting metadata from the current execution context.
        public init(_ provideMetadata: @escaping @Sendable () -> Metadata) {
            self._provideMetadata = provideMetadata
        }

        /// Invoke the metadata provider and return the generated contextual ``Logger/Metadata``.
        public func get() -> Metadata {
            self._provideMetadata()
        }
    }
}

extension Logger.MetadataProvider {
    /// A pseudo-`MetadataProvider` that can be used to merge metadata from multiple other `MetadataProvider`s.
    ///
    /// ### Merging conflicting keys
    ///
    /// `MetadataProvider`s are invoked left to right in the order specified in the `providers` argument.
    /// In case multiple providers try to add a value for the same key, the last provider "wins" and its value is being used.
    ///
    /// - Parameter providers: An array of `MetadataProvider`s to delegate to. The array must not be empty.
    /// - Returns: A pseudo-`MetadataProvider` merging metadata from the given `MetadataProvider`s.
    public static func multiplex(_ providers: [Logger.MetadataProvider]) -> Logger.MetadataProvider? {
        assert(!providers.isEmpty, "providers MUST NOT be empty")
        return Logger.MetadataProvider {
            providers.reduce(into: [:]) { metadata, provider in
                let providedMetadata = provider.get()
                guard !providedMetadata.isEmpty else {
                    return
                }
                metadata.merge(providedMetadata, uniquingKeysWith: { _, rhs in rhs })
            }
        }
    }
}
