//
//  EmojiPickerView.swift
//  EmojiPicker
//
//  Created by Edward Sanchez on 10/22/25.
//

import SwiftUI

struct EmojiPickerView: View {
    @State private var viewModel = EmojiPickerViewModel()
    @State private var scrollPosition = ScrollPosition(idType: EmojiCategory.self)
    @State private var selectedCategory: EmojiCategory? = .frequentlyUsed
    @State private var lastProgrammaticTarget: EmojiCategory?

    let onEmojiSelected: (Emoji) -> Void

    private let rows = [GridItem(.adaptive(minimum: 44), spacing: 8)]

    private var currentScrollCategory: EmojiCategory? {
        scrollPosition.viewID(type: EmojiCategory.self)
    }

    private var displayCategories: [EmojiCategory] {
        if viewModel.frequentlyUsedEmojis.count > 1 {
            return EmojiCategory.allCases
        } else {
            return EmojiCategory.allCases.filter { $0 != .frequentlyUsed }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.top, 5)

            if viewModel.isSearching {
                searchResultsView
            } else {
                categoryScrollView

                categoryBarView
            }
        }
        .onAppear {
            viewModel.refreshFrequentlyUsedEmojis()
            configureInitialSelection()
        }
        .onChange(of: viewModel.frequentlyUsedEmojis.count > 1) { _, _ in
            syncSelection()
        }
        .onChange(of: selectedCategory) { _, newValue in
            scrollPosition.scrollToCategory(newValue, lastRequest: &lastProgrammaticTarget)
        }
        .onChange(of: currentScrollCategory) { _, current in
            guard let current else { return }
            if current != selectedCategory {
                selectedCategory = current
            }
            if current == lastProgrammaticTarget {
                lastProgrammaticTarget = nil
            }
        }
    }

    private var searchResultsView: some View {
        Group {
            if viewModel.filteredEmojis.isEmpty {
                emptySearchState
            } else {
                ScrollView(.horizontal) {
                    LazyHGrid(rows: rows, alignment: .top, spacing: 0) {
                        ForEach(viewModel.filteredEmojis) { emoji in
                            EmojiCellView(emoji: emoji) {
                                handleEmojiSelection(emoji, in: emoji.category)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private var categoryScrollView: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 0) {
                ForEach(displayCategories) { category in
                    categorySection(for: category)
                        .id(category)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition($scrollPosition, anchor: .leading)
    }

    private func categorySection(for category: EmojiCategory) -> some View {
        let emojis = viewModel.emojis(for: category)

        return LazyHGrid(rows: rows, alignment: .top, spacing: 0) {
            ForEach(emojis) { emoji in
                EmojiCellView(emoji: emoji) {
                    handleEmojiSelection(emoji, in: category)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // Category bar
    private var categoryBarView: some View {
        Picker("Categories", selection: $selectedCategory) {
            ForEach(displayCategories) { category in
                Image(systemName: category.iconName)
                    .tag(category as EmojiCategory?)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private func handleEmojiSelection(_ emoji: Emoji, in category: EmojiCategory) {
        viewModel.trackEmojiUsage(emoji, sourceCategory: category)
        onEmojiSelected(emoji)
    }
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search emoji", text: $viewModel.searchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            Capsule(style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
    
    private var emptySearchState: some View {
        VStack(spacing: 8) {
            Text("No results")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    EmojiPickerView { emoji in
        print("Selected: \(emoji.character)")
    }
    .frame(height: 400)
}

private extension EmojiPickerView {
    func configureInitialSelection() {
        syncSelection(force: true)
    }

    func syncSelection(force: Bool = false) {
        let categories = displayCategories

        guard let firstCategory = categories.first else {
            selectedCategory = nil
            lastProgrammaticTarget = nil
            return
        }

        let hasFrequentlyUsed = viewModel.frequentlyUsedEmojis.count > 1
        let preferred = hasFrequentlyUsed ? EmojiCategory.frequentlyUsed : firstCategory
        let shouldAdoptFrequentlyUsed = hasFrequentlyUsed && selectedCategory != .some(.frequentlyUsed)

        let needsUpdate =
            force ||
            selectedCategory == nil ||
            shouldAdoptFrequentlyUsed ||
            (selectedCategory == .some(.frequentlyUsed) && !hasFrequentlyUsed) ||
            (selectedCategory.map { !categories.contains($0) } ?? true)

        if needsUpdate {
            selectedCategory = preferred
            scrollPosition.scrollToCategory(preferred, lastRequest: &lastProgrammaticTarget)
        }
    }
}

@MainActor
extension ScrollPosition {
    /// Scrolls to the provided emoji category if it differs from the current view ID.
    /// The `lastRequest` flag prevents re-entrant writes while SwiftUI delivers intermediate updates.
    mutating func scrollToCategory(
        _ target: EmojiCategory?,
        lastRequest: inout EmojiCategory?
    ) {
        guard let target else { return }
        if target == viewID(type: EmojiCategory.self) { return }
        if target == lastRequest { return }

        lastRequest = target
        scrollTo(id: target, anchor: .leading)
    }
}
