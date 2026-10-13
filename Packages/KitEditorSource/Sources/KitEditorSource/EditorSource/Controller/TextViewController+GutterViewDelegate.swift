//
//  TextViewController+GutterViewDelegate.swift
//  EditorSource
//
//  Created by Khan Winter on 4/17/25.
//

import Foundation

extension TextViewController: GutterViewDelegate {
    public func gutterViewWidthDidUpdate() {
        updateTextInsets()
    }
}
