//
//  MasonryLayout.swift
//  BagLog-DesignSystem
//
//  Created by Eugene Kovs on 24.02.2025.
//  https://github.com/kovs705
//

import SwiftUI

public struct MasonryLayout: Layout {
    var columns: Int
    var spacing: CGFloat

    public init(columns: Int, spacing: CGFloat = 10) {
        self.columns = columns
        self.spacing = spacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let resolvedColumns = max(columns, 1)
        let proposedWidth = proposal.width ?? idealWidth(for: subviews)
        let totalSpacing = CGFloat(resolvedColumns - 1) * spacing
        let availableWidth = max(proposedWidth - totalSpacing, 0)
        let columnWidth = availableWidth / CGFloat(resolvedColumns)

        var columnHeights = Array(repeating: CGFloat(0), count: resolvedColumns)
        for subview in subviews {
            let size = subview.sizeThatFits(.init(width: columnWidth, height: nil))
            if let minIndex = columnHeights.enumerated().min(by: { $0.element < $1.element })?.offset {
                columnHeights[minIndex] += size.height + spacing
            }
        }
        let maxHeight = columnHeights.max() ?? 0
        return CGSize(width: proposedWidth, height: maxHeight)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let resolvedColumns = max(columns, 1)
        let totalSpacing = CGFloat(resolvedColumns - 1) * spacing
        let columnWidth = max(bounds.width - totalSpacing, 0) / CGFloat(resolvedColumns)
        var columnHeights = Array(repeating: CGFloat(0), count: resolvedColumns)

        for subview in subviews {
            let size = subview.sizeThatFits(.init(width: columnWidth, height: nil))
            if let minIndex = columnHeights.enumerated().min(by: { $0.element < $1.element })?.offset {
                let x = bounds.minX + CGFloat(minIndex) * (columnWidth + spacing)
                let y = bounds.minY + columnHeights[minIndex]
                subview.place(at: CGPoint(x: x, y: y), proposal: .init(width: columnWidth, height: size.height))
                columnHeights[minIndex] += size.height + spacing
            }
        }
    }

    private func idealWidth(for subviews: Subviews) -> CGFloat {
        let resolvedColumns = max(columns, 1)
        let widestSubview = subviews
            .map { $0.sizeThatFits(.unspecified).width }
            .max() ?? 0
        let totalSpacing = CGFloat(resolvedColumns - 1) * spacing

        return widestSubview * CGFloat(resolvedColumns) + totalSpacing
    }
}
