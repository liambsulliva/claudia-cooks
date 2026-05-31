//
//  FrameworkBuildScreenLayout.swift
//  claudia-cooks
//

import SwiftUI

enum FrameworkBuildScreenLayout {
    static let fileSystemBarHeight: CGFloat = 160
    /// How far the front paper dips into the file-system bar (keep small).
    static let paperOverlapIntoBar: CGFloat = 20
    static let paperStackTopInset: CGFloat = 12
    /// Space between the window top and the builder panel / paper stack.
    static let editorContentTopInset: CGFloat = 24
    static let builderPanelContentPadding: CGFloat = 24
    static let builderPanelContentBottomPadding: CGFloat = 48
    static let maxPaperHeightFraction: CGFloat = 0.82
    static let centerStageBreakpoint: CGFloat = 1200
    static let centerStageMaxWidth: CGFloat = 1200
    static let centerStageHorizontalInset: CGFloat = 24
    static let centerStageTopInset: CGFloat = 24
    static let builderPaperSpacing: CGFloat = 32
    static let defaultBuilderPanelWidth: CGFloat = 640
    static let maxBuilderPanelWidth: CGFloat = 800
    static let minBuilderPanelWidth: CGFloat = 500
    static let defaultPreviewPanelWidth: CGFloat = 520
    static let paperStackTrailingMargin: CGFloat = 24
    static let paperAspectRatio: CGFloat = 0.77
    static let paperStackInternalTrailingPadding: CGFloat = 42
    static let maxPaperStackDepth: Int = 7
    static let paperStackDepthOffset: CGFloat = 18
    static let splitDividerHitWidth: CGFloat = 6
    static let minPreviewPanelWidth: CGFloat = 300

    /// Leading builder width that gives the paper preview enough room at the current window size.
    static func strategicLeadingWidth(
        totalWidth: CGFloat,
        availablePaperHeight: CGFloat,
        maxPaperHeight: CGFloat,
        sheetCount: Int,
        minLeadingWidth: CGFloat = minBuilderPanelWidth,
        maxLeadingWidth: CGFloat = maxBuilderPanelWidth,
        minTrailingWidth: CGFloat = minPreviewPanelWidth
    ) -> CGFloat {
        let reservedVerticalSpace = paperStackTopInset + paperOverlapIntoBar + 8
        let previewHeight = max(availablePaperHeight - reservedVerticalSpace, 1)
        let naturalPaperHeight = min(max(maxPaperHeight, 180), previewHeight)
        let naturalPaperWidth = naturalPaperHeight * paperAspectRatio
        let stackOverhang = CGFloat(min(max(sheetCount - 1, 0), maxPaperStackDepth)) * paperStackDepthOffset
        let idealTrailingWidth = naturalPaperWidth
            + stackOverhang
            + paperStackInternalTrailingPadding
            + paperStackTrailingMargin

        let dividerReserve = splitDividerHitWidth + builderPaperSpacing
        let maxTrailing = max(totalWidth - minLeadingWidth - dividerReserve, minTrailingWidth)
        let trailingWidth = min(max(idealTrailingWidth, minTrailingWidth), maxTrailing)

        var leadingWidth = totalWidth - trailingWidth - dividerReserve
        leadingWidth = min(max(leadingWidth, minLeadingWidth), maxLeadingWidth)

        return leadingWidth
    }
}
