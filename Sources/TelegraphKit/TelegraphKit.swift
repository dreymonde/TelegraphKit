//
//  TelegraphKit.swift
//  Nice Photon
//
//  Created by Oleg Dreyman on 2/2/21.
//

import UIKit
import WebKit

// special thanks to Daniel Jalkut:
// https://indiestack.com/2018/10/supporting-dark-mode-in-app-web-content/

public enum TelegraphURL {
    public static let _404 = URL(string: "https://telegra.ph/404-02-03-2")!
    
    case fullURL(URL)
    case postID(String)
    
    public var url: URL {
        switch self {
        case .fullURL(let url):
            if url.host?.contains("telegra.ph") == false {
                print("TelegraphViewController's behavior is undetermined when using URLs other than 'telegra.ph'")
            }
            return url
        case .postID(let postID):
            assert(postID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) == postID, "ID is likely wrong")
            return URL(string: "https://telegra.ph/\(postID)") ?? TelegraphURL._404
        }
    }
}

public final class TelegraphViewController: UIViewController {
    
    public struct Appearance {
        public init(fontStyle: TelegraphViewController.Appearance.FontStyle, hideAuthor: Bool, darkModeSupport: Bool = true, disableImageInteraction: Bool = true, disableSelection: Bool = false) {
            self.fontStyle = fontStyle
            self.hideAuthor = hideAuthor
            self.darkModeSupport = darkModeSupport
            self.disableImageInteraction = disableImageInteraction
            self.disableSelection = disableSelection
        }
        
        public static var defaultAppearance: Appearance = .appleSystem
        
        public var fontStyle: FontStyle
        
        /// When `true`, the "Author" block beneath the Title of the article will be hidden
        public var hideAuthor: Bool
        
        /// Defaults to `true`
        public var darkModeSupport = true
        
        /// Telegraph has a weird behavior when tapping on an image will cause the whole article to scroll a little bit. Set this to `true` to disable this behavior. Defaults to `true`
        public var disableImageInteraction = true
        
        /// Set this to `true` to disable the ability to select text. Defaults to `false`
        public var disableSelection = false
        
        public static let telegraph = Appearance(fontStyle: .telegraph, hideAuthor: false)
        public static let appleSystem = Appearance(fontStyle: .appleSystem, hideAuthor: false)
        
        public enum FontStyle { case telegraph, appleSystem }
    }
    
    public var decideNavigationPolicy: (TelegraphViewController, WKNavigationAction) -> WKNavigationActionPolicy? = { _, _ in nil }
    
    public let loadingIndicator = UIActivityIndicatorView(style: .large)
    let failedView = EmptyStateView(contents: .init(elements: [
        .title("Failed to load"),
        .text("Please check your internet connection and try again later.")
    ]))
    
    public let telegraphURL: TelegraphURL
    public let appearance: Appearance
    public let _appearanceScript: (TelegraphViewController) -> AppearanceScript
    public let webView = DynamicAppearanceWebView()
    
    public var url: URL {
        return telegraphURL.url
    }
        
    public convenience init(url: URL, appearance: Appearance = .defaultAppearance) {
        self.init(telegraphURL: .fullURL(url), appearance: appearance, script: { AppearanceScript(appearance: $0.appearance, traits: $0.traitCollection) })
    }
    
    public convenience init(postID: String, appearance: Appearance = .defaultAppearance) {
        self.init(telegraphURL: .postID(postID), appearance: appearance, script: { AppearanceScript(appearance: $0.appearance, traits: $0.traitCollection) })
    }
    
    internal init(telegraphURL: TelegraphURL, appearance: Appearance, script: @escaping (TelegraphViewController) -> AppearanceScript) {
        self.telegraphURL = telegraphURL
        self.appearance = appearance
        self._appearanceScript = script
        super.init(nibName: nil, bundle: nil)
    }
    
    public static func withScript(telegraphURL: TelegraphURL, script: AppearanceScript) -> TelegraphViewController {
        return TelegraphViewController(telegraphURL: telegraphURL, appearance: .defaultAppearance, script: { _ in script })
    }
    
    public static func withScriptBuilder(telegraphURL: TelegraphURL, makeScript: @escaping (TelegraphViewController) -> AppearanceScript) -> TelegraphViewController {
        return TelegraphViewController(telegraphURL: telegraphURL, appearance: .defaultAppearance, script: makeScript)
    }
    
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(webView) {
            $0.anchors.edges.pin()
        }
        
        view.addSubview(loadingIndicator) {
            $0.anchors.center.align()
            $0.alpha = 0
        }
        
        view.addSubview(failedView) {
            $0.anchors.centerY.align(offset: -25)
            $0.anchors.edges.readableContentPin(insets: .init(top: 0, left: 32, bottom: 0, right: 32), axis: .horizontal)
            $0.isHidden = true
        }
        
        view.backgroundColor = .systemBackground
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.alpha = 0
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(didPressDone))
        
        let appearanceModeScriptSource = _appearanceScript(self)
        
        let appearanceModeScript = WKUserScript(source: appearanceModeScriptSource.rawValue, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        self.webView.configuration.userContentController.addUserScript(appearanceModeScript)
        
        self.navigationItem.backButtonTitle = ""
        
        webView.navigationDelegate = self
        let request = URLRequest(url: telegraphURL.url)
        webView.load(request)
        loadingIndicator.startAnimating()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            animated {
                self.loadingIndicator.alpha = 1.0
            }
        }
    }
    
    @objc
    func didPressDone() {
        presentingViewController?.dismiss(animated: true, completion: nil)
    }
}

extension TelegraphViewController: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let delegatedPolicy = decideNavigationPolicy(self, navigationAction) {
            decisionHandler(delegatedPolicy)
            return
        }
        
        if let url = navigationAction.request.url {
            if url.host == self.telegraphURL.url.host {
                if url == self.telegraphURL.url || url.path.contains("embed") {
                    decisionHandler(.allow)
                    return
                } else {
                    let new = TelegraphViewController(telegraphURL: .fullURL(url), appearance: self.appearance, script: self._appearanceScript)
                    self.navigationController?.pushViewController(new, animated: true)
                    decisionHandler(.cancel)
                    return
                }
            } else if navigationAction.navigationType == .linkActivated {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        } else {
            decisionHandler(.allow)
        }
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.loadingIndicator.stopAnimating()
        self.failedView.isHidden = false
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.loadingIndicator.stopAnimating()
        self.failedView.isHidden = false
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.webView.updateContentForEffectiveAppearance()
        self.loadingIndicator.stopAnimating()
        animated {
            self.webView.alpha = 1.0
        }
    }
}

extension TelegraphViewController.AppearanceScript {
    public init(appearance: TelegraphViewController.Appearance, traits: UITraitCollection) {
        var base = Self.base(darkModeSupport: appearance.darkModeSupport, traits: traits)
        if appearance.fontStyle == .appleSystem {
            base.append(.commonAppleStyles)
        }
        if appearance.hideAuthor {
            base.append(.hideAuthorStyle)
        }
        if appearance.disableImageInteraction {
            base.append(.disableImageInteractionStyle)
        }
        if appearance.disableSelection {
            base.append(.disableSelectionStyle)
        }
        self = base
    }
}

extension TelegraphViewController {
    
    // special thanks to Daniel Jalkut:
    // https://indiestack.com/2018/10/supporting-dark-mode-in-app-web-content/
    public struct AppearanceScript: RawRepresentable, Codable, Hashable {
        public var rawValue: String
        
        public init(rawValue: String) { self.rawValue = rawValue }
        
        public static func base(darkModeSupport: Bool, traits: UITraitCollection) -> AppearanceScript {
            let traits = UITraitCollection(traitsFrom: [.init(traitsFrom: [traits]), .init(userInterfaceStyle: .dark)])
            let darkBgHex = UIColor.systemBackground.resolvedColor(with: traits).hexString
            
            return AppearanceScript(rawValue: """
            var _darkModeSupport = \(darkModeSupport);
            var darkModeStylesNodeID = "darkModeStyles";

            function addStyleString(str, nodeID) {
              var node = document.createElement('style');
              node.id = nodeID;
              node.innerHTML = str;

              // Insert to HEAD before all others, so it will serve as a default, all other
              // specificity rules being equal. This allows clients to provide their own
              // high level body {} rules for example, and supersede ours.
              document.head.insertBefore(node, document.head.firstElementChild);
            }

            // For dark mode we impose CSS rules to fine-tune our styles for dark
            function switchToDarkMode() {
              var darkModeStyleElement = document.getElementById(darkModeStylesNodeID);
              if (_darkModeSupport && darkModeStyleElement == null) {
                 var darkModeStyles = "body { color: #d2d2d2; background-color: \(darkBgHex); font-size: 60px } h1 { color: #ffffff } h2 { color: #ffffff } h3 { color: #ffffff } h4 { color: #ffffff } p { color: #ffffff } li { color: #ffffff } aside { color: #ebebf599 ! important } .tl_article a[href] { border-bottom:.1em solid #4490e2 ! important; color: #4490e2 ! important; } blockquote { border-left: 3px solid #fff ! important; color: #fff ! important }";
                 addStyleString(darkModeStyles, darkModeStylesNodeID);
              }
            }

            // For light mode we simply remove the dark mode styles to revert to default colors
            function switchToLightMode() {
              var darkModeStyleElement = document.getElementById(darkModeStylesNodeID);
              if (darkModeStyleElement != null) {
                 darkModeStyleElement.parentElement.removeChild(darkModeStyleElement);
              }
            }
            """)
                .appending(.applyStyle(name: "RemovingBottomBlock", css: "aside.tl_article_buttons { display: none ! important }"))
                .appending(.applyStyle(name: "RemovingTopPadding", css: "div.tl_page { padding: 3px 0 ! important }"))
                .appending(.hideElementStyle(name: "Hide404CreateNewButton", element: "a.button.create_button"))
                .appending(.hideElementStyle(name: "HideReportThisPageFooter", element: "div.tl_page_footer"))
        }
        
        public static func applyStyle(name: String, css: String) -> AppearanceScript {
            assert(!name.contains(" "))
            return AppearanceScript(rawValue: """
            function apply\(name)Styles() {
                 var styles = "\(css)";
                 addStyleString(styles, "__telegraphKit_\(name)");
            }

            if (typeof(apply\(name)Styles) == 'function') { apply\(name)Styles(); }
            """)
        }
        
        public static let commonAppleStyles = AppearanceScript.applyStyle(
            name: "CommonAppleStyles",
            css: "p { font-family: -apple-system ! important } h1 { font-family: -apple-system ! important } h2 { font-family: -apple-system ! important } h3 { font-family: -apple-system ! important } h4 { font-family: -apple-system ! important } aside { font-family: -apple-system ! important } blockquote { font-family: -apple-system ! important } li { font-family: -apple-system ! important } time { font-family: -apple-system ! important } a { font-family: -apple-system ! important } li:before { margin: -1.75px 0 0 -78px ! important } figcaption { font-family: -apple-system ! important }"
        )
        
        public static func hideElementStyle(name: String, element: String) -> AppearanceScript {
            .applyStyle(
                name: name,
                css: "\(element) { display: none ! important }"
            )
        }
        
        public static let hideAuthorStyle = AppearanceScript.hideElementStyle(
            name: "HideAuthor",
            element: "address"
        )
        
        public static let disableImageInteractionStyle = AppearanceScript.applyStyle(
            name: "SmartDisableFigureImgInteraction",
            css: "figure { pointer-events: none ! important; -webkit-user-select: none ! important } iframe { pointer-events: auto ! important }"
        )
        
        public static let disableSelectionStyle = AppearanceScript.applyStyle(
            name: "DisableAllSelection",
            css: "body { -webkit-user-select: none ! important }"
        )
        
        public mutating func append(_ script: AppearanceScript) {
            rawValue.append(script.rawValue)
        }
        
        public func appending(_ script: AppearanceScript) -> AppearanceScript {
            return AppearanceScript(rawValue: rawValue + script.rawValue)
        }
    }
}

// special thanks to Daniel Jalkut:
// https://indiestack.com/2018/10/supporting-dark-mode-in-app-web-content/
public class DynamicAppearanceWebView: WKWebView {
    
    var didInitialize = false
    
    // Override designated initializers to record when we're
    // done initializing, and avoid evaluating JS until we're done.
    public override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        
        didInitialize = true
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        didInitialize = true
    }
    
    public func updateContentForEffectiveAppearance() {
        // Don't try updating anything until we're done loading
        if didInitialize && self.isLoading == false {
            let funcName: String = {
                switch self.traitCollection.userInterfaceStyle {
                case .dark:
                    return "switchToDarkMode"
                case .light:
                    return "switchToLightMode"
                default:
                    return "switchToLightMode"
                }
            }()
            
            switch traitCollection.userInterfaceStyle {
            case .dark:
                self.scrollView.indicatorStyle = .white
            case .light:
                self.scrollView.indicatorStyle = .default
            default:
                self.scrollView.indicatorStyle = .default
            }
            
            // Call the named function only if it is implemented
            let switchScript = "if (typeof(\(funcName)) == 'function') { \(funcName)(); }"
            self.evaluateJavaScript(switchScript)
        }
    }
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        updateContentForEffectiveAppearance()
        super.traitCollectionDidChange(previousTraitCollection)
    }
}

// https://stackoverflow.com/a/47357277
extension UIColor {
    var hexString: String {
        let cgColorInRGB = cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)!
        let colorRef = cgColorInRGB.components
        let r = colorRef?[0] ?? 0
        let g = colorRef?[1] ?? 0
        let b = ((colorRef?.count ?? 0) > 2 ? colorRef?[2] : g) ?? 0
        let a = cgColor.alpha

        var color = String(
            format: "#%02lX%02lX%02lX",
            lroundf(Float(r * 255)),
            lroundf(Float(g * 255)),
            lroundf(Float(b * 255))
        )

        if a < 1 {
            color += String(format: "%02lX", lroundf(Float(a * 255)))
        }

        return color
    }
}

final class EmptyStateView: UIView {
        
    struct Contents {
        enum Element {
            case text(String)
            case title(String)
        }
        
        var elements: [Element]
    }
    
    let stack = UIStackView()
    
    let contents: Contents
    
    init(contents: Contents) {
        self.contents = contents
        super.init(frame: .zero)
        setup()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setup() {
        addSubview(stack)
        with(stack) {
            $0.anchors.edges.pin()
            $0.axis = .vertical
            $0.distribution = .equalSpacing
            $0.spacing = 0
        }
        
        for element in contents.elements {
            switch element {
            case .title(let string):
                let label = with(UILabel()) {
                    $0.text = string + "\n"
                    $0.font = .boldSystemFont(ofSize: 22)
                    $0.numberOfLines = 0
                    $0.textAlignment = .center
                }
                stack.addArrangedSubview(label)
            case .text(let string):
                let label = with(UILabel()) {
                    $0.text = string
                    $0.font = .boldSystemFont(ofSize: 17)
                    $0.numberOfLines = 0
                    $0.textAlignment = .center
                    $0.textColor = .secondaryLabel
                }
                stack.addArrangedSubview(label)
            }
        }
    }
}

func animated(_ block: @escaping () -> (), completion: @escaping () -> () = { }) {
    UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut]) {
        block()
    } completion: { (isCompleted) in
        if isCompleted {
            completion()
        }
    }
}
