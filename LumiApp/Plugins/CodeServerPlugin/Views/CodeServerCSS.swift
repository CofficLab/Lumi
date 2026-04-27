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
                .part.activitybar.left,
                .part.activitybar.right {
                    width: 0 !important;
                    min-width: 0 !important;
                    border: 0 !important;
                }
                
                /* 隐藏左侧侧边栏 (文件树/资源管理器) */
                .part.sidebar { display: none !important; }

                /* 隐藏右侧辅助侧边栏 */
                .part.auxiliarybar { display: none !important; }
                
                /* 隐藏底部面板 (终端/输出等) */
                .part.panel { display: none !important; }
                
                /* 隐藏顶部标题栏 */
                .part.titlebar { display: none !important; }

                /* 隐藏底部状态栏 */
                .part.statusbar { display: none !important; }

                /* 隐藏横幅与通知区域，避免打断编辑 */
                .monaco-workbench .notifications-toasts,
                .monaco-workbench .notification-center,
                .monaco-workbench .global-notification-center,
                .monaco-workbench .editor-banner {
                    display: none !important;
                }

                /* 隐藏编辑器分组标题栏（无标签时顶部空白条） */
                .monaco-workbench .part.editor > .content .editor-group-container > .title {
                    display: none !important;
                    height: 0 !important;
                    min-height: 0 !important;
                    border: 0 !important;
                }
                .monaco-workbench .editor-group-container > .title,
                .monaco-workbench .tabs-and-actions-container {
                    display: none !important;
                    height: 0 !important;
                    min-height: 0 !important;
                    border: 0 !important;
                    padding: 0 !important;
                    margin: 0 !important;
                }

                /* 关闭 Centered Layout 产生的左右留白容器 */
                .monaco-workbench .centered-layout-margin {
                    width: 0 !important;
                    min-width: 0 !important;
                    max-width: 0 !important;
                    flex-basis: 0 !important;
                    border: 0 !important;
                    overflow: hidden !important;
                }
            `;
            document.head.appendChild(style);
        })();
        """
    }
}
