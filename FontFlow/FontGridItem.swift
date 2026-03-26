//
//  FontGridItem.swift
//  FontFlow
//
//  Created on 2026/3/21.
//

import Cocoa

class FontGridItem: NSCollectionViewItem {

    static let identifier = NSUserInterfaceItemIdentifier("FontGridItem")

    private var rootContentView: FontGridContentView? {
        viewIfLoaded as? FontGridContentView
    }

    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
    }

    override func loadView() {
        let root = FontGridContentView()
        view = root
        updateSelectionHighlight()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isSelected: Bool {
        didSet {
            updateSelectionHighlight()
        }
    }

    func configure(with record: FontRecord) {
        let availableWidth = view.bounds.width > 0 ? view.bounds.width : nil
        rootContentView?.configure(
            with: content(for: record),
            availableWidth: availableWidth
        )
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        rootContentView?.prepareForReuse()
        updateSelectionHighlight()
    }

    private func updateSelectionHighlight() {
        rootContentView?.setSelected(isSelected)
    }

    private func content(for record: FontRecord) -> FontGridContentView.Content {
        FontGridContentView.Content(
            displayName: record.styleName ?? record.displayName ?? record.postScriptName ?? "Unknown",
            previewText: "Aa",
            previewFont: FontLoader.font(for: record, size: 48) ?? .systemFont(ofSize: 48)
        )
    }
}
