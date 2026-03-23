//
//  FontLoader.swift
//  FontFlow
//
//  Created on 2026/3/23.
//

import Cocoa
import CoreText

enum FontLoader {

    static func font(for record: FontRecord, size: CGFloat) -> NSFont? {
        if let descriptor = fontDescriptor(for: record) {
            return CTFontCreateWithFontDescriptor(descriptor, size, nil) as NSFont
        }

        if let postScriptName = record.postScriptName {
            return NSFont(name: postScriptName, size: size)
        }

        return nil
    }

    static func fontDescriptor(for record: FontRecord) -> CTFontDescriptor? {
        guard let descriptors = fontDescriptors(for: record), !descriptors.isEmpty else {
            return nil
        }

        guard let postScriptName = record.postScriptName, !postScriptName.isEmpty else {
            return descriptors.first
        }

        return descriptors.first(where: { descriptor in
            descriptorPostScriptName(for: descriptor) == postScriptName
        }) ?? descriptors.first
    }

    static func resolvedFileURL(for record: FontRecord) -> URL? {
        if let bookmarkData = record.bookmarkData {
            var isStale = false

            do {
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: [.withSecurityScope, .withoutUI],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                if isStale {
                    NSLog("FontLoader: Resolved stale bookmark for %@", record.postScriptName ?? "Unknown")
                }

                return url
            } catch {
                NSLog("FontLoader: Failed to resolve bookmark for %@ - %@", record.postScriptName ?? "Unknown", String(describing: error))
            }
        }

        guard let filePath = record.filePath, !filePath.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: filePath)
    }

    private static func fontDescriptors(for record: FontRecord) -> [CTFontDescriptor]? {
        guard let fileURL = resolvedFileURL(for: record) else {
            return nil
        }

        let didAccessSecurityScope = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScope {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        return CTFontManagerCreateFontDescriptorsFromURL(fileURL as CFURL) as? [CTFontDescriptor]
    }

    private static func descriptorPostScriptName(for descriptor: CTFontDescriptor) -> String? {
        CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String
    }
}
