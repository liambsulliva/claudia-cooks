//
//  AppWindowMetrics.swift
//  claudia-cooks
//

import CoreGraphics

enum AppWindowMode: Equatable {
    case frameworkPicker
    case builder
}

enum AppWindowMetrics {
    static let pickerSize = CGSize(width: 900, height: 680)
    static let builderMinimumSize = CGSize(width: 900, height: 600)
}
