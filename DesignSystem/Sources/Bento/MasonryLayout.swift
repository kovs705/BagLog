//
//  MasonryLayout.swift
//  BagLog-DesignSystem
//
//  Created by Eugene Kovs on 24.02.2025.
//  https://github.com/kovs705
//

import SwiftUI

public struct MasonryLayout: Layout {
    private let columns: Int
    private let spacing: CGFloat

    public init(columns: Int, spacing: CGFloat = 10) {
        self.columns = columns
        self.spacing = spacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let proposedWidth = proposal.width ?? idealWidth(for: subviews)
        let columnWidth = columnWidth(for: proposedWidth)

        var columnHeights = emptyColumnHeights
        for subview in subviews {
            let size = subview.sizeThatFits(.init(width: columnWidth, height: nil))
            let columnIndex = shortestColumnIndex(in: columnHeights)
            columnHeights[columnIndex] += size.height + spacing
        }

        let contentHeight = max((columnHeights.max() ?? 0) - spacing, 0)
        return CGSize(width: proposedWidth, height: contentHeight)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let columnWidth = columnWidth(for: bounds.width)
        var columnHeights = emptyColumnHeights

        for subview in subviews {
            let size = subview.sizeThatFits(.init(width: columnWidth, height: nil))
            let columnIndex = shortestColumnIndex(in: columnHeights)
            let x = bounds.minX + CGFloat(columnIndex) * (columnWidth + spacing)
            let y = bounds.minY + columnHeights[columnIndex]
            subview.place(at: CGPoint(x: x, y: y), proposal: .init(width: columnWidth, height: size.height))
            columnHeights[columnIndex] += size.height + spacing
        }
    }

    private func idealWidth(for subviews: Subviews) -> CGFloat {
        let widestSubview = subviews
            .map { $0.sizeThatFits(.unspecified).width }
            .max() ?? 0

        return widestSubview * CGFloat(resolvedColumnCount) + totalSpacing
    }

    private var resolvedColumnCount: Int {
        max(columns, 1)
    }

    private var totalSpacing: CGFloat {
        CGFloat(resolvedColumnCount - 1) * spacing
    }

    private var emptyColumnHeights: [CGFloat] {
        Array(repeating: 0, count: resolvedColumnCount)
    }

    private func columnWidth(for availableWidth: CGFloat) -> CGFloat {
        max(availableWidth - totalSpacing, 0) / CGFloat(resolvedColumnCount)
    }

    private func shortestColumnIndex(in columnHeights: [CGFloat]) -> Int {
        columnHeights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
    }
}
