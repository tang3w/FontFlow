//
//  FontListViewController.swift
//  FontFlow
//
//  Created on 2026/3/21.
//

import Cocoa
import CoreData

// MARK: - Delegate

protocol FontListSelectionDelegate: AnyObject {
    func fontListDidSelectFont(_ fontList: FontListViewController, font: FontRecord?)
}

// MARK: - Outline Data Model

/// A family group in the font list outline.
class FontFamilyNode {
    let familyName: String
    let fonts: [FontRecord]

    init(familyName: String, fonts: [FontRecord]) {
        self.familyName = familyName
        self.fonts = fonts
    }
}

// MARK: - FontListViewController

class FontListViewController: NSViewController {

    weak var delegate: FontListSelectionDelegate?
    var managedObjectContext: NSManagedObjectContext!

    private var outlineView: NSOutlineView!
    private var familyNodes: [FontFamilyNode] = []

    private static let familyCellIdentifier = NSUserInterfaceItemIdentifier("FamilyCell")
    private static let fontCellIdentifier = NSUserInterfaceItemIdentifier("FontCell")

    // MARK: - Lifecycle

    override func loadView() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.style = .plain
        outlineView.rowHeight = 44
        outlineView.indentationPerLevel = 20
        outlineView.dataSource = self
        outlineView.delegate = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("FontColumn"))
        column.isEditable = false
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column

        scrollView.documentView = outlineView
        view = scrollView
    }

    // MARK: - Public

    /// Updates the fetch predicate, re-fetches font records, groups by family, and reloads.
    func updatePredicate(_ predicate: NSPredicate?) {
        let request = FontRecord.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = [
            NSSortDescriptor(key: "familyName", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:))),
            NSSortDescriptor(key: "styleName", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:))),
        ]
        let records = (try? managedObjectContext.fetch(request)) ?? []
        familyNodes = buildFamilyNodes(from: records)
        outlineView.reloadData()

        // Expand all families by default
        for node in familyNodes {
            outlineView.expandItem(node)
        }

        delegate?.fontListDidSelectFont(self, font: nil)
    }

    // MARK: - Grouping

    private func buildFamilyNodes(from records: [FontRecord]) -> [FontFamilyNode] {
        var grouped: [(String, [FontRecord])] = []
        var currentFamily: String?
        var currentRecords: [FontRecord] = []

        for record in records {
            let family = record.familyName ?? "Unknown"
            if family == currentFamily {
                currentRecords.append(record)
            } else {
                if let name = currentFamily {
                    grouped.append((name, currentRecords))
                }
                currentFamily = family
                currentRecords = [record]
            }
        }
        if let name = currentFamily {
            grouped.append((name, currentRecords))
        }

        return grouped.map { FontFamilyNode(familyName: $0.0, fonts: $0.1) }
    }
}

// MARK: - NSOutlineViewDataSource

extension FontListViewController: NSOutlineViewDataSource {

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil { return familyNodes.count }
        if let familyNode = item as? FontFamilyNode {
            // Single-font families are displayed as leaf rows — no children to expand.
            return familyNode.fonts.count > 1 ? familyNode.fonts.count : 0
        }
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil { return familyNodes[index] }
        if let familyNode = item as? FontFamilyNode {
            return familyNode.fonts[index]
        }
        fatalError("Unexpected outline item")
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let familyNode = item as? FontFamilyNode {
            return familyNode.fonts.count > 1
        }
        return false
    }
}

// MARK: - NSOutlineViewDelegate

extension FontListViewController: NSOutlineViewDelegate {

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if let familyNode = item as? FontFamilyNode {
            return makeFamilyCell(familyNode: familyNode)
        }
        if let record = item as? FontRecord {
            return makeFontCell(record: record, isChild: true)
        }
        return nil
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        // Allow selecting family rows only for single-font families (they act as direct font rows).
        if let familyNode = item as? FontFamilyNode {
            return familyNode.fonts.count == 1
        }
        return item is FontRecord
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        let row = outlineView.selectedRow
        guard row >= 0 else {
            delegate?.fontListDidSelectFont(self, font: nil)
            return
        }

        let item = outlineView.item(atRow: row)
        if let record = item as? FontRecord {
            delegate?.fontListDidSelectFont(self, font: record)
        } else if let familyNode = item as? FontFamilyNode, familyNode.fonts.count == 1 {
            delegate?.fontListDidSelectFont(self, font: familyNode.fonts.first)
        } else {
            delegate?.fontListDidSelectFont(self, font: nil)
        }
    }

    // MARK: - Cell Factories

    /// Cell for a family row. For single-font families, shows the font name in its own typeface.
    /// For multi-font families, shows the family name with a font count badge.
    private func makeFamilyCell(familyNode: FontFamilyNode) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = Self.familyCellIdentifier

        if familyNode.fonts.count == 1 {
            // Single font — display like a flat font row.
            let record = familyNode.fonts[0]
            let displayName = record.displayName ?? record.postScriptName ?? "Unknown"
            let textField = NSTextField(labelWithString: displayName)
            textField.lineBreakMode = .byTruncatingTail
            textField.translatesAutoresizingMaskIntoConstraints = false

            if let psName = record.postScriptName,
               let font = NSFont(name: psName, size: 15) {
                textField.font = font
            } else {
                textField.font = .systemFont(ofSize: 15)
            }

            cell.addSubview(textField)
            cell.textField = textField

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                textField.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -8),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        } else {
            // Multi-font family — show family name and count.
            let textField = NSTextField(labelWithString: familyNode.familyName)
            textField.font = .systemFont(ofSize: 14, weight: .medium)
            textField.lineBreakMode = .byTruncatingTail
            textField.translatesAutoresizingMaskIntoConstraints = false

            let countLabel = NSTextField(labelWithString: "\(familyNode.fonts.count)")
            countLabel.font = .systemFont(ofSize: 11)
            countLabel.textColor = .secondaryLabelColor
            countLabel.alignment = .center
            countLabel.translatesAutoresizingMaskIntoConstraints = false

            cell.addSubview(textField)
            cell.addSubview(countLabel)
            cell.textField = textField

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                textField.trailingAnchor.constraint(lessThanOrEqualTo: countLabel.leadingAnchor, constant: -8),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),

                countLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -12),
                countLabel.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                countLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 20),
            ])
        }

        return cell
    }

    /// Cell for an individual font (child of a family group).
    private func makeFontCell(record: FontRecord, isChild: Bool) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = Self.fontCellIdentifier

        let styleName = record.styleName ?? record.displayName ?? record.postScriptName ?? "Unknown"
        let textField = NSTextField(labelWithString: styleName)
        textField.lineBreakMode = .byTruncatingTail
        textField.translatesAutoresizingMaskIntoConstraints = false

        if let psName = record.postScriptName,
           let font = NSFont(name: psName, size: 14) {
            textField.font = font
        } else {
            textField.font = .systemFont(ofSize: 14)
        }

        cell.addSubview(textField)
        cell.textField = textField

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            textField.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -8),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])

        return cell
    }
}
