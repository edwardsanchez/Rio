//
//  CustomForm.swift
//  Rio
//
//  Created by Cursor on 10/30/25.
//

import SwiftUI
#if canImport(UIKit)
    import UIKit
#endif

/// A container that replicates SwiftUI's grouped `Form` appearance without embedding
/// its content inside a `ScrollView`.
///
/// `CustomForm` is designed for screens that need form styling but must manage their
/// own scrolling behavior. The layout mirrors the spacing, backgrounds, and row
/// separators from the grouped form style on iOS while remaining open to arbitrary
/// content before or after sections.
struct SimpleForm<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CustomFormConstants.sectionSpacing) {
            content
        }
        .padding(.vertical, CustomFormConstants.verticalPadding)
        .padding(.horizontal, CustomFormConstants.horizontalPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
//        .background(Color.customFormListBackground)
        .labeledContentStyle(CustomFormLabeledContentStyle())
    }
}

/// A section that mimics the grouped form styling used in SwiftUI's `Form`.
struct CustomSection<Content: View>: View {
    private let content: Content
    private let header: AnyView?
    private let footer: AnyView?

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
        header = nil
        footer = nil
    }

    init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder header: () -> some View
    ) {
        self.content = content()
        let headerView = header()
        self.header = headerView.isEmptyView ? nil : AnyView(headerView)
        footer = nil
    }

    init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder header: () -> some View,
        @ViewBuilder footer: () -> some View
    ) {
        self.content = content()
        let headerView = header()
        let footerView = footer()
        self.header = headerView.isEmptyView ? nil : AnyView(headerView)
        self.footer = footerView.isEmptyView ? nil : AnyView(footerView)
    }

    init(
        _ title: some StringProtocol,
        @ViewBuilder content: () -> Content
    ) {
        self.init(content: content) {
            Text(title)
        }
    }

    init(
        _ titleKey: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) {
        self.init(content: content) {
            Text(titleKey)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CustomFormConstants.headerToContentSpacing) {
            if let header {
                header
                    .customFormSectionHeaderStyle()
            }

            CustomSectionContainer(content: content)

            if let footer {
                footer
                    .customFormSectionFooterStyle()
            }
        }
        .padding(.horizontal, CustomFormConstants.sectionHorizontalPadding)
    }
}

// MARK: - Section Container

private struct CustomSectionContainer<Content: View>: View {
    let content: Content

    var body: some View {
        _VariadicView.Tree(CustomFormRowRoot()) {
            content
        }
    }
}

private struct CustomFormRowRoot: _VariadicView_UnaryViewRoot {
    func body(children: _VariadicView.Children) -> some View {
        VStack(spacing: 0) {
            let rowCount = children.count
            ForEach(Array(children.enumerated()), id: \.offset) { pair in
                pair.element
                    .customFormRow()

                if pair.offset < rowCount - 1 {
                    CustomFormDivider()
                }
            }
        }
        .background(Color.customFormRowBackground)
        .clipShape(RoundedRectangle(
            cornerRadius: CustomFormConstants.cornerRadius,
            style: .continuous
        ))
        .overlay(
            RoundedRectangle(
                cornerRadius: CustomFormConstants.cornerRadius,
                style: .continuous
            )
            .stroke(Color.customFormRowOutline, lineWidth: CustomFormConstants.borderWidth)
        )
    }
}

// MARK: - Styles & Helpers

private enum CustomFormConstants {
    static let verticalPadding: CGFloat = 20
    static let horizontalPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 24
    static let sectionHorizontalPadding: CGFloat = 0
    static let headerToContentSpacing: CGFloat = 8
    static let rowHorizontalPadding: CGFloat = 16
    static let rowVerticalPadding: CGFloat = 12
    static let labelValueSpacing: CGFloat = 12
    static let cornerRadius: CGFloat = 12
    static let borderWidth: CGFloat = 1
    static let dividerInset: CGFloat = rowHorizontalPadding
}

private struct CustomFormDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.customFormSeparator)
            .frame(height: CustomFormConstants.borderWidth)
            .padding(.leading, CustomFormConstants.dividerInset)
    }
}

private struct CustomFormLabeledContentStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: CustomFormConstants.labelValueSpacing) {
            configuration.label
                .font(.body)
                .foregroundStyle(.primary)

            Spacer(minLength: CustomFormConstants.labelValueSpacing)

            configuration.content
                .font(.body)
                .multilineTextAlignment(.trailing)
        }
    }
}

private extension View {
    func customFormRow() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, CustomFormConstants.rowVerticalPadding)
            .padding(.horizontal, CustomFormConstants.rowHorizontalPadding)
            .background(Color.customFormRowBackground)
    }

    func customFormSectionHeaderStyle() -> some View {
        font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .padding(.horizontal, CustomFormConstants.sectionHorizontalPadding)
    }

    func customFormSectionFooterStyle() -> some View {
        font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, CustomFormConstants.sectionHorizontalPadding)
            .padding(.top, CustomFormConstants.headerToContentSpacing)
    }
}

private extension Color {
    static let customFormListBackground = Color(.systemGroupedBackground)
    static let customFormRowBackground = Color(.secondarySystemGroupedBackground)
    static let customFormRowOutline = Color(.separator).opacity(0.18)
    static let customFormSeparator = Color(.separator).opacity(0.25)
}

private extension View {
    var isEmptyView: Bool {
        if Self.self == EmptyView.self {
            return true
        }
        return false
    }
}
