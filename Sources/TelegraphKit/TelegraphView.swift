//
//  SwiftUIView.swift
//  
//
//  Created by Oleg on 9/27/23.
//

import SwiftUI

public struct TelegraphView: UIViewControllerRepresentable {
    public typealias Appearance = TelegraphViewController.Appearance
    
    public let url: TelegraphURL
    public let appearance: Appearance
    
    internal init(telegraphURL: TelegraphURL, appearance: Appearance) {
        self.url = telegraphURL
        self.appearance = appearance
    }
    
    public init(url: URL, appearance: Appearance = .defaultAppearance) {
        self.init(telegraphURL: .fullURL(url), appearance: appearance)
    }
    
    public init(postID: String, appearance: Appearance = .defaultAppearance) {
        self.init(telegraphURL: .postID(postID), appearance: appearance)
    }
    
    public typealias UIViewControllerType = TelegraphViewController
    
    public func makeUIViewController(context: Context) -> TelegraphViewController {
        TelegraphViewController(telegraphURL: url, appearance: appearance, script: { TelegraphViewController.AppearanceScript(appearance: $0.appearance, traits: $0.traitCollection) })
    }
    
    public func updateUIViewController(_ uiViewController: TelegraphViewController, context: Context) {
        // no-act
    }
}

@available(iOS 15.0, *)
fileprivate struct DismissableTelegraphView: SwiftUI.View {
    let telegraphView: TelegraphView
    let doneButtonTitle: String
    @Environment(\.dismiss) var dismiss
    
    var body: some SwiftUI.View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                contentView
            }
        } else {
            NavigationView {
                contentView
            }
        }
    }
    
    var contentView: some SwiftUI.View {
        telegraphView
            .toolbar {
                Button(doneButtonTitle) {
                    dismiss()
                }
                .font(.body.bold())
            }
            .edgesIgnoringSafeArea(.all)
    }
}

extension TelegraphView {
    @available(iOS 15.0, *)
    public func dismissable(doneButtonTitle: String = "Done") -> some SwiftUI.View {
        DismissableTelegraphView(telegraphView: self, doneButtonTitle: doneButtonTitle)
    }
    
    @available(iOS 15.0, *)
    @available(*, deprecated, renamed: "dismissable(doneButtonTitle:)")
    public func dismissable(_ doneButtonTitle: String) -> some SwiftUI.View {
        self.dismissable(doneButtonTitle: doneButtonTitle)
    }
}
