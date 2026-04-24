import Foundation

/// Code Server CSS 注入配置
///
/// 定义需要注入到 code-server 页面的 CSS 规则，用于隐藏特定 UI 元素。
enum CodeServerCSS {
    /// 获取完整的 CSS 注入脚本（纯 CSS，不注入 JS，确保不会导致编辑器崩溃）
    static var injectionScript: String {
        """
        (function() {
            const style = document.createElement('style');
            style.id = 'lumi-code-server-custom-styles';
            style.textContent = `
                /* 隐藏左侧活动栏 (图标列) */
                .part.activitybar { display: none !important; }
                
                /* 隐藏左侧侧边栏 (文件树/资源管理器) */
                .part.sidebar { display: none !important; }
                
                /* 隐藏底部面板 (终端/输出等) */
                .part.panel { display: none !important; }
                
                /* 隐藏顶部标题栏 */
                .part.titlebar { display: none !important; }
            `;
            document.head.appendChild(style);
        })();
        """
    }
}
