//
//  EmojiPickerView.swift
//  EmojiPicker
//
//  Created by Edward Sanchez on 10/22/25.
//

import SwiftUI

struct EmojiPickerView: View {
    @State private var viewModel = EmojiPickerViewModel()
    @State private var scrollPosition: ScrollPosition = .init(idType: EmojiCategory.self)

    let onEmojiSelected: (Emoji) -> Void

    private let rows = [GridItem(.adaptive(minimum: 44), spacing: 8)]

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
            setInitialScrollPosition()
        }
        .onChange(of: viewModel.frequentlyUsedEmojis.count > 1) { _, hasFrequentlyUsed in
            updateScrollPositionForFrequentlyUsed(isAvailable: hasFrequentlyUsed)
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
        Picker("Categories", selection: $scrollPosition.stablePickerValue) {
            ForEach(displayCategories) { category in
                Image(systemName: category.iconName)
                    .tag(category as EmojiCategory?)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private func setInitialScrollPosition() {
        updateScrollPositionForFrequentlyUsed(
            isAvailable: viewModel.frequentlyUsedEmojis.count > 1,
            force: true
        )
    }

    private func updateScrollPositionForFrequentlyUsed(isAvailable: Bool, force: Bool = false) {
        guard let firstCategory = displayCategories.first else { return }

        let currentCategory = scrollPosition.stablePickerValue

        if isAvailable {
            if force || currentCategory != .some(.frequentlyUsed) {
                scrollPosition.stablePickerValue = .frequentlyUsed
            }
        } else {
            let needsFallback = force || currentCategory == .some(.frequentlyUsed) || currentCategory == nil
            if needsFallback {
                scrollPosition.stablePickerValue = firstCategory
            }
        }
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

private extension ScrollPosition {
    var stablePickerValue: EmojiCategory? {
        get { viewID(type: EmojiCategory.self) }
        set { scrollTo(id: newValue, anchor: .leading) }
    }
}

//private extension ScrollPosition {
//    var stablePickerValue: HorizontalScrolling.Group? {
//        get { viewID(type: HorizontalScrolling.Group.self) }
//        set {
//            scrollTo(id: newValue, anchor: .leading)
//        }
//    }
//}
