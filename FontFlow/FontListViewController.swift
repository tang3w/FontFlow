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

// MARK: - FontListViewController

class FontListViewController: NSViewController {

    weak var delegate: FontListSelectionDelegate?
    var managedObjectContext: NSManagedObjectContext!

    private var tableView: NSTableView!
    private var fontRecords: [FontRecord] = []

    private static let cellIdentifier = NSUserInterfaceItemIdentifier("FontCell")

    // MARK: - Lifecycle

    override func loadView() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        tableView = NSTableView()
        tableView.headerView = nil
        tableView.style = .plain
        tableView.rowHeight = 44
        tableView.dataSource = self
        tableView.delegate = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("FontColumn"))
        column.isEditable = false
        tableView.addTableColumn(column)

        scrollView.documentView = tableView
        view = scrollView
    }

    // MARK: - Public

    /// Updates the fetch predicate, re-fetches font records, and reloads the table.
    func updatePredicate(_ predicate: NSPredicate?) {
        let request = FontRecord.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = [NSSortDescriptor(key: "displayName", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]
        fontRecords = (try? managedObjectContext.fetch(request)) ?? []
        tableView.reloadData()
        delegate?.fontListDidSelectFont(self, font: nil)
    }
}

// MARK: - NSTableViewDataSource

extension FontListViewController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        fontRecords.count
    }
}

// MARK: - NSTableViewDelegate

extension FontListViewController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let record = fontRecords[row]

        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: Self.cellIdentifier, owner: nil) as? NSTableCellView {
            cell = reused
        } else {
            cell = makeFontCell()
        }

        let displayName = record.displayName ?? record.postScriptName ?? "Unknown"
        cell.textField?.stringValue = displayName

        // Render the font name in its own typeface if the font is available.
        if let psName = record.postScriptName,
           let font = NSFont(name: psName, size: 15) {
            cell.textField?.font = font
        } else {
            cell.textField?.font = .systemFont(ofSize: 15)
        }

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        let font: FontRecord? = row >= 0 ? fontRecords[row] : nil
        delegate?.fontListDidSelectFont(self, font: font)
    }

    // MARK: - Cell Factory

    private func makeFontCell() -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = Self.cellIdentifier

        let textField = NSTextField(labelWithString: "")
        textField.lineBreakMode = .byTruncatingTail
        textField.translatesAutoresizingMaskIntoConstraints = false

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
