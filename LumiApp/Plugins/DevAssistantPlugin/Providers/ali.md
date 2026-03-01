Coding Plan中的模型支持 Anthropic API 兼容接口，可以通过 Claude Code 调用。

## **安装 Claude Code**

## macOS/Linux

1.  安装或更新 [Node.js](https://nodejs.org/en/download/)（v18.0 或更高版本）。
    
2.  在终端中执行下列命令，安装 Claude Code。
    
    ```
    npm install -g @anthropic-ai/claude-code
    ```
    
3.  运行以下命令验证安装。若有版本号输出，则表示安装成功。
    
    ```
    claude --version
    ```
    

## Windows

在 Windows 上使用 Claude Code，需要安装 WSL 或 [Git for Windows](https://git-scm.com/install/windows)，然后在 WSL 或 Git Bash 中执行以下命令。

```
npm install -g @anthropic-ai/claude-code
```

> 详情可以参考Claude Code官方文档的[Windows安装教程](https://docs.anthropic.com/en/docs/claude-code/setup#windows-setup)。

## 配置 Coding Plan 接入信息

在 Claude Code 中接入百炼 Coding Plan，需要配置以下信息：

1.  `ANTHROPIC_BASE_URL`：设置为 `https://coding.dashscope.aliyuncs.com/apps/anthropic`。
    
2.  `ANTHROPIC_AUTH_TOKEN`：设置为Coding Plan专属 [API Key](https://bailian.console.aliyun.com/cn-beijing/?tab=model#/efm/coding_plan)。
    
3.  `ANTHROPIC_MODEL`：设置为 Coding Plan [支持的模型](https://help.aliyun.com/zh/model-studio/coding-plan)。
    

## macOS/Linux

1.  创建并打开配置文件`~/.claude/settings.json`。
    
    > `~` 代表用户主目录。如果 `.claude` 目录不存在，需要先行创建。可在终端执行 `mkdir -p ~/.claude` 来创建。
    
    ```
    nano ~/.claude/settings.json
    ```
    
2.  编辑配置文件。将 YOUR\_API\_KEY 替换为 Coding Plan 专属 [API Key](https://bailian.console.aliyun.com/cn-beijing/?tab=model#/efm/coding_plan)。
    
    ```
    {    
        "env": {
            "ANTHROPIC_AUTH_TOKEN": "YOUR_API_KEY",
            "ANTHROPIC_BASE_URL": "https://coding.dashscope.aliyuncs.com/apps/anthropic",
            "ANTHROPIC_MODEL": "qwen3.5-plus"
        }
    }
    ```
    
    保存配置文件，重新打开一个终端即可生效。
    
3.  编辑或新增 `~/.claude.json` 文件，将`hasCompletedOnboarding` 字段的值设置为 `true`并保存文件。
    
    ```
    {
      "hasCompletedOnboarding": true
    }
    ```
    
    > `hasCompletedOnboarding` 作为顶层字段，请勿嵌套于其他字段。
    
    该步骤可避免启动Claude Code时报错：`Unable to connect to Anthropic services`。
    

## Windows

1.  创建并打开配置文件`C:\Users\您的用户名\.claude\settings.json`。
    
    ## CMD
    
    1.  创建目录
        
        ```
        if not exist "%USERPROFILE%\.claude" mkdir "%USERPROFILE%\.claude"
        ```
        
    2.  创建并打开文件
        
        ```
        notepad "%USERPROFILE%\.claude\settings.json"
        ```
        
    
    ## PowerShell
    
    1.  创建目录
        
        ```
        mkdir -Force $HOME\.claude
        ```
        
    2.  创建并打开文件
        
        ```
        notepad $HOME\.claude\settings.json
        ```
        
    
2.  编辑配置文件。将 YOUR\_API\_KEY 替换为 Coding Plan 专属 [API Key](https://bailian.console.aliyun.com/cn-beijing/?tab=model#/efm/coding_plan)。
    
    ```
    {    
        "env": {
            "ANTHROPIC_AUTH_TOKEN": "YOUR_API_KEY",
            "ANTHROPIC_BASE_URL": "https://coding.dashscope.aliyuncs.com/apps/anthropic",
            "ANTHROPIC_MODEL": "qwen3.5-plus"
        }
    }
    ```
    
    保存配置文件，重新打开一个终端即可生效。
    
3.  编辑或新增 `C:\Users\您的用户名\.claude.json` 文件，将`hasCompletedOnboarding` 字段的值设置为 `true`，并保存文件。
    
    ```
    {
      "hasCompletedOnboarding": true
    }
    ```
    

## **开始使用**

1.  打开终端，并进入项目所在的目录。运行以下命令启动程序 Claude Code：
    
    ```
    cd path/to/your_project
    claude
    ```
    
2.  启动后，需要授权 Claude Code 执行文件。
    
    ![image](https://help-static-aliyun-doc.aliyuncs.com/assets/img/zh-CN/0924991771/p1040228.png)
    
3.  输入`/status`确认模型、Base URL、API Key 是否配置正确。
    
    ![image](https://help-static-aliyun-doc.aliyuncs.com/assets/img/zh-CN/0428202771/p1054776.png)
    
4.  在 Claude Code 中对话。
    
    ![image](https://help-static-aliyun-doc.aliyuncs.com/assets/img/zh-CN/8292228671/p1040230.png)
    

## 切换模型

1.  **启动 Claude Code 时切换**：在终端执行`claude --model <模型名称>`指定模型并启动 Claude Code，例如`claude --model qwen3-coder-next`。
    
2.  **会话期间**：在对话框输入`/model <模型名称>`命令切换模型，例如`/model qwen3-coder-next`。
    

## 能力扩展

Claude Code 支持通过 MCP 和 Skills 扩展自身能力，例如调用联网搜索获取实时信息、使用图片理解 Skill 分析图像内容等。详情请参考[最佳实践](https://help.aliyun.com/zh/model-studio/coding-plan-best-practices/)。

## 常见命令

| **命令** | **说明** | **示例** |
| --- | --- | --- |
| /init | 在项目根目录生成 CLAUDE.md 文件，用于定义项目级指令和上下文。 | /init |
| /status | 查看当前模型、API Key、Base URL 等配置状态。 | /status |
| /model <模型名称> | 切换模型。 | /model qwen3-coder-next |
| /clear | 清除对话历史，开始全新对话。 | /clear |
| /plan | 进入规划模式，仅分析和讨论方案，不修改代码。 | /plan |
| /compact | 压缩对话历史，释放上下文窗口空间。 | /compact |
| /config | 打开配置菜单，可设置语言、主题等。 | /config |

更多命令与用法详情，请参考 [Claude Code 官方文档](https://code.claude.com/docs/en/overview)。

## **使用 Claude Code IDE 插件**

Claude Code IDE 插件支持在 VSCode、VSCode 系列 IDE（如 Cursor、Trae 等）、JetBrains 系列 IDE（如 IntelliJ IDEA、PyCharm 等）中使用。

## VS Code

1.  请先[配置 Coding Plan 接入信息](#15a5a014e5uy8)，Windows还需要安装 WSL 或 [Git for Windows](https://git-scm.com/install/windows)。
    
2.  打开VS Code，在扩展市场中搜索 `Claude Code for VS Code` 并安装。
    
    ![image](https://help-static-aliyun-doc.aliyuncs.com/assets/img/zh-CN/9898540771/p1053283.png)
    
3.  安装完成后，重启 VSCode。单击右上角图标进入 Claude Code。
    
    ![截屏2026-02-06 17](https://help-static-aliyun-doc.aliyuncs.com/assets/img/zh-CN/9898540771/p1053286.png)
    
4.  切换模型：在对话框中输入`/`，选择 General config 进入设置页面，在Selected Model中选择[支持的模型](https://help.aliyun.com/zh/model-studio/coding-plan-overview)，新建一个新窗口开始对话。
    
    ![截屏2026-02-06 17](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=)
    

## JetBrains

1.  请先[安装 Claude Code](#c5bddcb57es8r)，并[配置 Coding Plan 接入信息](#15a5a014e5uy8)。
    
2.  打开JetBrains（如 IntelliJ IDEA、PyCharm 等），在扩展市场中搜索 `Claude Code` 并安装。
    
    ![2026-02-25_16-27-56](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=)
    
3.  安装后重启IDE，点击右上角图标即可使用，可通过`/model <模型名称>`命令切换模型。
    
    ![2026-02-25_16-40-33](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=)
    

## **了解更多**

如需进一步了解 Claude Code 的 MCP、Skills、自定义命令、Hooks 等高级功能，请参考 [Claude Code 官方文档](https://code.claude.com/docs/en/overview)。

## 错误码

请参考[常见报错及解决方案](https://help.aliyun.com/zh/model-studio/coding-plan-faq#a9248c44029g6)。

## 常见问题

请参考[常见问题](https://help.aliyun.com/zh/model-studio/coding-plan-faq)。
