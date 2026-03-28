//
//  FontListViewController.swift
//  FontFlow
//
//  Created on 2026/3/21.
//

import Cocoa
import CoreData

// MARK: - FontListViewController

class FontListViewController: NSViewController, FontBrowserChildViewControlling {

    var onSelectionChanged: (([FontRecord]) -> Void)?
    var onSectionToggled: ((String) -> Void)?

    // MARK: - FontBrowserChildViewControlling

    func reloadData(
        familyNodes: [FontFamilyNode],
        fontsByObjectID: [NSManagedObjectID: FontRecord],
        collapsedSections: Set<String>,
        animatingDifferences: Bool,
        reloadingSections: Set<String>
    ) {
        // TODO
    }
}
