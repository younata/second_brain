import WebKit

class FakeNavigationAction: WKNavigationAction {
    private let _navigationType: WKNavigationType
    override var navigationType: WKNavigationType { return self._navigationType }

    private let _request: URLRequest
    override var request: URLRequest { return self._request }

    init(navigationType: WKNavigationType, request: URLRequest) {
        self._navigationType = navigationType
        self._request = request
        super.init()
    }
}
