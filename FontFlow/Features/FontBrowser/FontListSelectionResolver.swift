//
//  FontListSelectionResolver.swift
//  FontFlow
//
//  Created on 2026/4/24.
//

import Cocoa

// MARK: - FontListSelectionResolver

/// Translates raw `NSOutlineView` selection proposals into the row set that
/// should actually be applied, accounting for the two-tier (section row /
/// typeface row) structure of the font list.
///
/// The bulk of the complexity here exists to disambiguate user intents that
/// AppKit reports identically: a drag that shrinks back toward its anchor
/// looks like a Cmd+click hole-punch by set diff alone, repeated identical
/// proposals during a drag look like new gestures, and so on. Each public
/// branch in `resolve(proposed:isDragGesture:)` and the comments inside
/// `derivedTypefaceIDs(...)` document a specific case observed during
/// development.
final class FontListSelectionResolver {

    /// Caches the most recent `(proposed, resolved)` pair returned from
    /// `resolve(proposed:isDragGesture:)`.
    ///
    /// AppKit re-emits the same `proposed` IndexSet during a drag (mouse move,
    /// autoscroll tick, internal validation) regardless of what the delegate
    /// previously returned. Without this cache, the second callback compares
    /// the raw drag rectangle against our augmented `selectedRowIndexes` and
    /// the section-row heuristic incorrectly drops it. Returning the cached
    /// answer keeps repeated identical proposals idempotent.
    private var lastProposalCache: (proposed: IndexSet, resolved: IndexSet)?

    private weak var outlineView: NSOutlineView?
    private var snapshot: FontBrowserSnapshot

    init(outlineView: NSOutlineView, snapshot: FontBrowserSnapshot = .empty) {
        self.outlineView = outlineView
        self.snapshot = snapshot
    }

    // MARK: - Public API

    /// Replace the data snapshot used for row/item lookups. Implicitly
    /// invalidates the cache because row indices may have shifted.
    func updateSnapshot(_ snapshot: FontBrowserSnapshot) {
        self.snapshot = snapshot
        lastProposalCache = nil
    }

    /// Discard the cached proposal. Call before applying selection
    /// programmatically, since programmatic selection bypasses the proposal
    /// callback and would otherwise leave the cache out of sync.
    func resetCache() {
        lastProposalCache = nil
    }

    /// Computes the set of outline-view rows that should be selected for a
    /// given typeface selection: every selected typeface row, plus the section
    /// row of every family that resolves to `.full`.
    func rowIndexes(forTypefaces typefaceIDs: Set<FontTypefaceID>) -> IndexSet {
        guard let outlineView else { return IndexSet() }
        var rows = IndexSet()

        for typefaceID in typefaceIDs {
            guard let item = snapshot.typefaceByID[typefaceID] else { continue }
            let row = outlineView.row(forItem: item)
            if row >= 0 {
                rows.insert(row)
            }
        }

        for section in snapshot.families {
            let state = FontFamilySelectionState.resolve(
                typefaceIDs: section.typefaces.map { $0.id },
                selected: typefaceIDs
            )
            guard state == .full else { continue }
            let row = outlineView.row(forItem: section)
            if row >= 0 {
                rows.insert(row)
            }
        }

        return rows
    }

    /// Normalize the user's proposed selection so the outline view never
    /// settles on an inconsistent state — e.g. selecting all of a family's
    /// typefaces should also light up the section row, and selecting a section
    /// row should pull in all of its typefaces.
    ///
    /// `isDragGesture` should be `true` when the triggering input event is a
    /// `.leftMouseDragged` (i.e. the user is mid-drag-select); the caller is
    /// responsible for that determination because it is a callsite concern.
    func resolve(proposed: IndexSet, isDragGesture: Bool) -> IndexSet {
        guard let outlineView else { return proposed }

        // Idempotency guard: AppKit may re-issue the same `proposed` IndexSet
        // multiple times for a single user gesture (e.g. while the cursor sits
        // on a row mid-drag). Returning the cached answer for an identical
        // proposal keeps the gesture stable and avoids re-running the
        // section-row heuristic against contaminated state.
        if let cache = lastProposalCache, cache.proposed == proposed {
            return cache.resolved
        }

        // Diff against the *previous resolved selection* — i.e. what we last
        // returned and AppKit actually applied. We can't use AppKit's prior
        // raw `proposed` IndexSet because it omits the section-row
        // expansions we add ourselves; that would make a section row appear
        // "newly arriving" on a subsequent click and incorrectly skip the
        // hole-punch path. We can't use `selectedRowIndexes` either, as it
        // can lag mid-gesture. The cached `resolved` is the source of truth.
        // The original drag-contamination concern (proposal shrinks during
        // a drag would look like a member deselect) is handled separately
        // by `isDragGesture` below. On the very first callback there is no
        // cache yet, so fall back to `selectedRowIndexes`, which is correct
        // at that moment.
        let previous = lastProposalCache?.resolved ?? outlineView.selectedRowIndexes
        let derivedTypefaceIDs = derivedTypefaceIDs(
            fromProposed: proposed,
            previous: previous,
            isDragGesture: isDragGesture,
            outlineView: outlineView
        )
        let resolved = rowIndexes(forTypefaces: derivedTypefaceIDs)
        lastProposalCache = (proposed, resolved)
        return resolved
    }

    // MARK: - Internals

    /// Translates the proposed outline-view rows into the underlying typeface
    /// ID set.
    ///
    /// Selected typeface rows always contribute their own id. A selected
    /// section row expands to the whole family *unless* the user just punched
    /// a hole in it with a click — i.e. some typeface of that family was
    /// present in the previous resolved selection but is now missing from the
    /// current proposal, AND the triggering event is not a drag. That
    /// signature is what distinguishes:
    ///
    /// - Cmd+click an individual typeface inside a fully-selected family
    ///   (`isDragGesture == false`): exactly one family member drops out of
    ///   `proposed` → don't expand, so the family row deselects and the hole
    ///   is preserved.
    /// - Drag extension or *shrinkage* across the family's typefaces
    ///   (`isDragGesture == true`): rows may be added OR removed as the drag
    ///   rectangle grows and shrinks, but a drag never means "punch a hole".
    ///   Keep the section sticky and expand so the family row stays lit for
    ///   the duration of the drag.
    ///
    /// `previous` must be the prior *resolved* selection (what we last
    /// returned), not AppKit's prior raw `proposed`: the raw proposal omits
    /// our section-row augmentations and would make the diff lie when a
    /// subsequent click follows a section-row click.
    private func derivedTypefaceIDs(
        fromProposed proposed: IndexSet,
        previous: IndexSet,
        isDragGesture: Bool,
        outlineView: NSOutlineView
    ) -> Set<FontTypefaceID> {
        var ids: Set<FontTypefaceID> = []

        for row in proposed {
            switch outlineView.item(atRow: row) {
            case let typeface as FontTypefaceItem:
                ids.insert(typeface.id)

            case let section as FontFamilySection:
                // Hole-punch is a very narrow case: the section row was
                // already "owning" the family in the previous proposal, and
                // a click (not a drag) removed one of its typefaces. All
                // three conditions must hold:
                //
                //   1. The section row was in `previous` — without that,
                //      there was no prior full-family state to punch a hole
                //      in. Newly-arriving section rows (arrow navigation,
                //      plain click on the section, drag onto the section)
                //      always expand.
                //   2. Not all family typefaces are still in `proposed` —
                //      something dropped. When the section was owning the
                //      family, every typeface was effectively selected even
                //      if their individual rows weren't in the prior
                //      `proposed` IndexSet, so the absence of any typeface
                //      row from `proposed` now is the hole signal.
                //   3. The gesture is not a drag — drag rectangles shrink
                //      naturally as the user moves back toward the anchor;
                //      that's not a deselect.
                let sectionRow = outlineView.row(forItem: section)
                let sectionWasOwning = sectionRow >= 0 && previous.contains(sectionRow)
                let someTypefaceMissing = section.typefaces.contains { typeface in
                    let typefaceRow = outlineView.row(forItem: typeface)
                    return typefaceRow >= 0 && !proposed.contains(typefaceRow)
                }
                let familyMemberDeselected = sectionWasOwning
                    && !isDragGesture
                    && someTypefaceMissing
                if !familyMemberDeselected {
                    for typeface in section.typefaces {
                        ids.insert(typeface.id)
                    }
                }

            default:
                continue
            }
        }

        return ids
    }
}
