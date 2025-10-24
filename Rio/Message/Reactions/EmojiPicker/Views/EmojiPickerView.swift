//
//  EmojiPickerView.swift
//  EmojiPicker
//
//  Created by Edward Sanchez on 10/22/25.
//

import SwiftUI

struct EmojiPickerView: View {
    @State private var viewModel = EmojiPickerViewModel()
    @State private var selectedCategory: EmojiCategory? = .frequentlyUsed

    let onEmojiSelected: (Emoji) -> Void

    private let rows = [GridItem(.adaptive(minimum: 44), spacing: 8)]
    private let categories = EmojiCategory.allCases

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Reactions")
                .navigationBarTitleDisplayMode(.automatic)
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            if viewModel.isSearching {
                searchResultsView
            } else {
                categoryScrollView
                Divider()
                categoryBarView
            }
        }
        .searchable(
            text: $viewModel.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search emoji"
        )
        .onAppear {
            viewModel.refreshFrequentlyUsedEmojis()
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
                ForEach(categories) { category in
                    categorySection(for: category)
                        .id(category)
                    //Commented out to prevent feedback loop
//                            .onScrollTargetVisibilityChange(idType: EmojiCategory.self, threshold: 0.5) { visibleIDs in
//                                if let firstVisible = visibleIDs.first {
//                                    selectedCategory = firstVisible
//                                }
//                            }
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $selectedCategory, anchor: .leading)
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
        HStack(spacing: 0) {
            ForEach(categories) { category in
                Button {
                    withAnimation(.smooth) {
                        selectedCategory = category
                    }
                } label: {
                    Image(systemName: category.iconName)
                        .font(.system(size: 22))
//                        .foregroundStyle(selectedCategory == category ? .blue : .secondary)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, 8)
    }

    private func handleEmojiSelection(_ emoji: Emoji, in category: EmojiCategory) {
        viewModel.trackEmojiUsage(emoji, sourceCategory: category)
        onEmojiSelected(emoji)
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
