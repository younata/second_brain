import UIKit

protocol HTMLWrapper {
    func wrap(html: String) -> String
}

final class BundleHTMLWrapper: HTMLWrapper {
    func wrap(html: String) -> String {
        return """
<html>
<head>
<style type="text/css">\(self.general)</style>
<!--<style type="text/css">\(self.fontAwesome)</style>-->
<meta name="viewport" content="initial-scale=1.0,maximum-scale=10.0"/>
</head>
<body class="ayu">
<div id="page-wrapper" class="page-wrapper">
<div class="page">
<div id="content" class="content">
<main>
\(html)
</main>
</div>
</div>
</div>
</body>
</html>
"""
    }

    private lazy var general: String = {
        return self.css(filename: "general")
    }()

    private lazy var fontAwesome: String = {
        return self.css(filename: "font-awesome")
    }()

    private lazy var ayu: String = {
        return self.css(filename: "ayu")
    }()

    private func css(filename: String) -> String {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "css") else {
            return ""
        }
        return (try? String(contentsOf: url)) ?? ""
    }
}
