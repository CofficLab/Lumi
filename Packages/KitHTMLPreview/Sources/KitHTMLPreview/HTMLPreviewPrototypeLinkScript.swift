import Foundation

/// 原型屏幕跳转桥接脚本（issue #323）。
///
/// 原型屏幕以 `data-prototype-link="<screen-id>"` 声明跳转热点（与
/// `PrototypeHotspot.parse(fromHTML:)`、Linter 的约定一致），本脚本在捕获
/// 阶段拦截点击并回传目标屏 ID；屏幕切换由宿主侧完成。内容 JavaScript 被禁用
/// 时原生注入的脚本仍可运行，与元素右键桥接一致。
enum HTMLPreviewPrototypeLinkScript {
    static let messageHandlerName = "lumiPrototypeLink"
    static let source = makeSource(navigationGeneration: 0)

    static func makeSource(navigationGeneration: Int) -> String {
        #"""
        (function () {
            if (window.__lumiPrototypeLinkBridge && window.__lumiPrototypeLinkBridge.dispose) {
                window.__lumiPrototypeLinkBridge.dispose();
            }

            var navigationGeneration = \#(navigationGeneration);

            function onCaptureClick(event) {
                var target = event.target;
                if (!target || !(target instanceof Element)) { return; }
                var hotspot = target.closest('[data-prototype-link]');
                if (!hotspot) { return; }
                var link = String(hotspot.getAttribute('data-prototype-link') || '').trim();
                if (!link) { return; }
                event.preventDefault();
                try {
                    window.webkit.messageHandlers.lumiPrototypeLink.postMessage({
                        schemaVersion: 1,
                        action: 'prototypeLink',
                        navigationGeneration: navigationGeneration,
                        target: link.slice(0, 256)
                    });
                } catch (_) { /* 通道不可用时静默忽略 */ }
            }

            document.addEventListener('click', onCaptureClick, true);

            var api = {
                dispose: function () {
                    document.removeEventListener('click', onCaptureClick, true);
                    if (window.__lumiPrototypeLinkBridge === api) {
                        delete window.__lumiPrototypeLinkBridge;
                    }
                }
            };
            window.__lumiPrototypeLinkBridge = api;
        })();
        """#
    }
}
