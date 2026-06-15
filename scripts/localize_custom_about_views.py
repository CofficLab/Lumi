#!/usr/bin/env python3
"""Merge AboutView string translations into plugin Localizable.xcstrings."""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# English key -> (zh-Hans, zh-Hant, zh-HK, zh-TW)
TRANSLATIONS: dict[str, tuple[str, str, str, str]] = {
    "Requirements": ("系统要求", "系統需求", "系統需求", "系統需求"),
    "macOS 14.0 or later": ("macOS 14.0 或更高版本", "macOS 14.0 或更高版本", "macOS 14.0 或更高版本", "macOS 14.0 或更高版本"),
    "External displays with DDC/CI support": ("支持 DDC/CI 的外接显示器", "支援 DDC/CI 的外接顯示器", "支援 DDC/CI 的外接顯示器", "支援 DDC/CI 的外接顯示器"),
    "USB-C or DisplayPort connection (recommended)": ("USB-C 或 DisplayPort 连接（推荐）", "USB-C 或 DisplayPort 連接（建議）", "USB-C 或 DisplayPort 連接（建議）", "USB-C 或 DisplayPort 連接（建議）"),
    "Idle-Time Scanning": ("空闲时扫描", "閒置時掃描", "閒置時掃描", "閒置時掃描"),
    "Automatically scans for project issues when the system is idle": ("在系统空闲时自动扫描项目问题", "在系統閒置時自動掃描專案問題", "在系統閒置時自動掃描專案問題", "在系統閒置時自動掃描專案問題"),
    "AI-Powered Hints": ("AI 智能提示", "AI 智能提示", "AI 智能提示", "AI 智能提示"),
    "Provides contextual hints to the LLM about known issues": ("向 LLM 提供已知问题的上下文提示", "向 LLM 提供已知問題的上下文提示", "向 LLM 提供已知問題的上下文提示", "向 LLM 提供已知問題的上下文提示"),
    "Issue Tracking": ("问题跟踪", "問題追蹤", "問題追蹤", "問題追蹤"),
    "Maintains a list of detected issues for reference": ("维护已检测问题列表供参考", "維護已偵測問題列表供參考", "維護已偵測問題列表供參考", "維護已偵測問題列表供參考"),
    "Background Processing": ("后台处理", "背景處理", "背景處理", "背景處理"),
    "Runs scans in the background without disrupting your workflow": ("在后台运行扫描，不干扰你的工作流", "在背景執行掃描，不干擾你的工作流程", "在背景執行掃描，不干擾你的工作流程", "在背景執行掃描，不干擾你的工作流程"),
    "Monitors system idle time to trigger scans": ("监控系统空闲时间以触发扫描", "監控系統閒置時間以觸發掃描", "監控系統閒置時間以觸發掃描", "監控系統閒置時間以觸發掃描"),
    "Analyzes project files for common issues": ("分析项目文件中的常见问题", "分析專案檔案中的常見問題", "分析專案檔案中的常見問題", "分析專案檔案中的常見問題"),
    "Stores detected issues in a local database": ("将检测到的问题存储在本地数据库", "將偵測到的問題儲存在本機資料庫", "將偵測到的問題儲存在本機資料庫", "將偵測到的問題儲存在本機資料庫"),
    "Provides hints to LLM during chat sessions": ("在聊天会话期间向 LLM 提供提示", "在聊天工作階段期間向 LLM 提供提示", "在聊天工作階段期間向 LLM 提供提示", "在聊天工作階段期間向 LLM 提供提示"),
    "Enable during development for proactive issue detection": ("开发期间启用以主动检测问题", "開發期間啟用以主動偵測問題", "開發期間啟用以主動偵測問題", "開發期間啟用以主動偵測問題"),
    "Review detected issues regularly": ("定期查看检测到的问题", "定期查看偵測到的問題", "定期查看偵測到的問題", "定期查看偵測到的問題"),
    "Configure scan sensitivity in plugin settings": ("在插件设置中配置扫描灵敏度", "在插件設定中設定掃描靈敏度", "在外掛設定中設定掃描靈敏度", "在外掛設定中設定掃描靈敏度"),
    "Image Management": ("镜像管理", "映像管理", "映像管理", "映像管理"),
    "Browse, inspect, and manage local Docker images": ("浏览、检查和管理本地 Docker 镜像", "瀏覽、檢查和管理本機 Docker 映像", "瀏覽、檢查和管理本機 Docker 映像", "瀏覽、檢查和管理本機 Docker 映像"),
    "Layer Inspection": ("层检查", "層檢查", "層檢查", "層檢查"),
    "View detailed image layers and their sizes": ("查看镜像层详情及大小", "查看映像層詳情及大小", "查看映像層詳情及大小", "查看映像層詳情及大小"),
    "Tag Management": ("标签管理", "標籤管理", "標籤管理", "標籤管理"),
    "Manage image tags and versions": ("管理镜像标签和版本", "管理映像標籤和版本", "管理映像標籤和版本", "管理映像標籤和版本"),
    "Image Cleanup": ("镜像清理", "映像清理", "映像清理", "映像清理"),
    "Remove unused images to free up disk space": ("删除未使用的镜像以释放磁盘空间", "刪除未使用的映像以釋放磁碟空間", "刪除未使用的映像以釋放磁碟空間", "刪除未使用的映像以釋放磁碟空間"),
    "Connects to local Docker daemon via socket": ("通过 socket 连接本地 Docker 守护进程", "透過 socket 連接本機 Docker 守護程式", "透過 socket 連接本機 Docker 守護程式", "透過 socket 連接本機 Docker 守護程式"),
    "Fetches image list and metadata": ("获取镜像列表和元数据", "取得映像列表和中繼資料", "取得映像列表和中繼資料", "取得映像列表和中繼資料"),
    "Displays image layers and sizes": ("显示镜像层和大小", "顯示映像層和大小", "顯示映像層和大小", "顯示映像層和大小"),
    "Provides management actions": ("提供管理操作", "提供管理操作", "提供管理操作", "提供管理操作"),
    "Ensure Docker Desktop is running before use": ("使用前请确保 Docker Desktop 正在运行", "使用前請確保 Docker Desktop 正在執行", "使用前請確保 Docker Desktop 正在執行", "使用前請確保 Docker Desktop 正在執行"),
    "Regular cleanup helps reclaim disk space": ("定期清理有助于回收磁盘空间", "定期清理有助於回收磁碟空間", "定期清理有助於回收磁碟空間", "定期清理有助於回收磁碟空間"),
    "Click an image to view layer details": ("点击镜像查看层详情", "點擊映像查看層詳情", "點擊映像查看層詳情", "點擊映像查看層詳情"),
    "Hosts File Management": ("Hosts 文件管理", "Hosts 檔案管理", "Hosts 檔案管理", "Hosts 檔案管理"),
    "Edit and manage the system hosts file with a user-friendly interface": ("通过友好界面编辑和管理系统 hosts 文件", "透過友善介面編輯和管理系統 hosts 檔案", "透過友善介面編輯和管理系統 hosts 檔案", "透過友善介面編輯和管理系統 hosts 檔案"),
    "Profile Support": ("配置文件支持", "設定檔支援", "設定檔支援", "設定檔支援"),
    "Create and switch between different hosts profiles": ("创建并切换不同的 hosts 配置文件", "建立並切換不同的 hosts 設定檔", "建立並切換不同的 hosts 設定檔", "建立並切換不同的 hosts 設定檔"),
    "Quick Toggle": ("快速开关", "快速開關", "快速開關", "快速開關"),
    "Enable or disable hosts entries without deleting them": ("无需删除即可启用或禁用 hosts 条目", "無需刪除即可啟用或停用 hosts 條目", "無需刪除即可啟用或停用 hosts 條目", "無需刪除即可啟用或停用 hosts 條目"),
    "Syntax Highlighting": ("语法高亮", "語法醒目提示", "語法醒目提示", "語法醒目提示"),
    "Syntax highlighting and validation for hosts entries": ("为 hosts 条目提供语法高亮和校验", "為 hosts 條目提供語法醒目提示和驗證", "為 hosts 條目提供語法醒目提示和驗證", "為 hosts 條目提供語法醒目提示和驗證"),
    "Reads the system hosts file with proper permissions": ("以适当权限读取系统 hosts 文件", "以適當權限讀取系統 hosts 檔案", "以適當權限讀取系統 hosts 檔案", "以適當權限讀取系統 hosts 檔案"),
    "Parses and displays entries in an organized list": ("解析并以有序列表显示条目", "解析並以有序列表顯示條目", "解析並以有序列表顯示條目", "解析並以有序列表顯示條目"),
    "Allows adding, editing, and removing entries": ("支持添加、编辑和删除条目", "支援新增、編輯和刪除條目", "支援新增、編輯和刪除條目", "支援新增、編輯和刪除條目"),
    "Writes changes back to the hosts file": ("将更改写回 hosts 文件", "將變更寫回 hosts 檔案", "將變更寫回 hosts 檔案", "將變更寫回 hosts 檔案"),
    "Backup your hosts file before making changes": ("修改前请备份 hosts 文件", "修改前請備份 hosts 檔案", "修改前請備份 hosts 檔案", "修改前請備份 hosts 檔案"),
    "Use profiles to switch between different configurations": ("使用配置文件在不同配置间切换", "使用設定檔在不同配置間切換", "使用設定檔在不同配置間切換", "使用設定檔在不同配置間切換"),
    "Comments start with # and are ignored": ("以 # 开头的行是注释，会被忽略", "以 # 開頭的行是註解，會被忽略", "以 # 開頭的行是註解，會被忽略", "以 # 開頭的行是註解，會被忽略"),
    "Registry Management": ("注册表管理", "註冊表管理", "註冊表管理", "註冊表管理"),
    "Manage and configure Lumi registries for package management": ("管理和配置 Lumi 注册表以进行包管理", "管理和設定 Lumi 註冊表以進行套件管理", "管理和設定 Lumi 註冊表以進行套件管理", "管理和設定 Lumi 註冊表以進行套件管理"),
    "Mirror Configuration": ("镜像配置", "鏡像設定", "鏡像設定", "鏡像設定"),
    "Configure registry mirrors for better performance": ("配置注册表镜像以提升性能", "設定註冊表鏡像以提升效能", "設定註冊表鏡像以提升效能", "設定註冊表鏡像以提升效能"),
    "Performance Optimization": ("性能优化", "效能最佳化", "效能最佳化", "效能最佳化"),
    "Optimize package download speeds with regional mirrors": ("通过区域镜像优化包下载速度", "透過區域鏡像最佳化套件下載速度", "透過區域鏡像最佳化套件下載速度", "透過區域鏡像最佳化套件下載速度"),
    "Secure Connections": ("安全连接", "安全連線", "安全連線", "安全連線"),
    "Ensure secure connections to package registries": ("确保与包注册表的安全连接", "確保與套件註冊表的安全連線", "確保與套件註冊表的安全連線", "確保與套件註冊表的安全連線"),
    "Connects to package registries for dependency resolution": ("连接包注册表以解析依赖", "連接套件註冊表以解析相依性", "連接套件註冊表以解析相依性", "連接套件註冊表以解析相依性"),
    "Configures mirrors based on your region and preferences": ("根据你的地区和偏好配置镜像", "根據你的地區和偏好設定鏡像", "根據你的地區和偏好設定鏡像", "根據你的地區和偏好設定鏡像"),
    "Caches package metadata for faster access": ("缓存包元数据以加快访问", "快取套件中繼資料以加快存取", "快取套件中繼資料以加快存取", "快取套件中繼資料以加快存取"),
    "Provides a unified interface for registry management": ("提供统一的注册表管理界面", "提供統一的註冊表管理介面", "提供統一的註冊表管理介面", "提供統一的註冊表管理介面"),
    "Use regional mirrors for faster downloads": ("使用区域镜像加快下载", "使用區域鏡像加快下載", "使用區域鏡像加快下載", "使用區域鏡像加快下載"),
    "Regularly update registry cache for latest packages": ("定期更新注册表缓存以获取最新包", "定期更新註冊表快取以取得最新套件", "定期更新註冊表快取以取得最新套件", "定期更新註冊表快取以取得最新套件"),
    "Configure authentication for private registries": ("为私有注册表配置身份验证", "為私有註冊表設定驗證", "為私有註冊表設定驗證", "為私有註冊表設定驗證"),
    "Brightness Control": ("亮度控制", "亮度控制", "亮度控制", "亮度控制"),
    "Adjust brightness for external displays via DDC/CI protocol": ("通过 DDC/CI 协议调节外接显示器亮度", "透過 DDC/CI 協定調節外接顯示器亮度", "透過 DDC/CI 協定調節外接顯示器亮度", "透過 DDC/CI 協定調節外接顯示器亮度"),
    "Volume Control": ("音量控制", "音量控制", "音量控制", "音量控制"),
    "Control audio volume directly from your menu bar": ("直接从菜单栏控制音量", "直接從選單列控制音量", "直接從選單列控制音量", "直接從選單列控制音量"),
    "Contrast Adjustment": ("对比度调节", "對比度調節", "對比度調節", "對比度調節"),
    "Fine-tune display contrast for optimal viewing": ("微调显示对比度以获得最佳观看效果", "微調顯示對比度以獲得最佳觀看效果", "微調顯示對比度以獲得最佳觀看效果", "微調顯示對比度以獲得最佳觀看效果"),
    "Multi-Display Support": ("多显示器支持", "多顯示器支援", "多顯示器支援", "多顯示器支援"),
    "Manage multiple displays with individual controls": ("独立控制多个显示器", "獨立控制多個顯示器", "獨立控制多個顯示器", "獨立控制多個顯示器"),
    "Detects connected displays with DDC/CI support": ("检测支持 DDC/CI 的已连接显示器", "偵測支援 DDC/CI 的已連接顯示器", "偵測支援 DDC/CI 的已連接顯示器", "偵測支援 DDC/CI 的已連接顯示器"),
    "Provides brightness, volume, and contrast sliders": ("提供亮度、音量和对比度滑块", "提供亮度、音量和對比度滑桿", "提供亮度、音量和對比度滑桿", "提供亮度、音量和對比度滑桿"),
    "Updates display settings in real-time": ("实时更新显示设置", "即時更新顯示設定", "即時更新顯示設定", "即時更新顯示設定"),
    "Stores preferences for each display": ("为每个显示器保存偏好设置", "為每個顯示器儲存偏好設定", "為每個顯示器儲存偏好設定", "為每個顯示器儲存偏好設定"),
    "Application Listing": ("应用列表", "應用程式列表", "應用程式列表", "應用程式列表"),
    "Browse all installed macOS applications with detailed information": ("浏览所有已安装的 macOS 应用及详细信息", "瀏覽所有已安裝的 macOS 應用程式及詳細資訊", "瀏覽所有已安裝的 macOS 應用程式及詳細資訊", "瀏覽所有已安裝的 macOS 應用程式及詳細資訊"),
    "App Details": ("应用详情", "應用程式詳情", "應用程式詳情", "應用程式詳情"),
    "View app size, version, and related files for each application": ("查看每个应用的大小、版本和相关文件", "查看每個應用程式的大小、版本和相關檔案", "查看每個應用程式的大小、版本和相關檔案", "查看每個應用程式的大小、版本和相關檔案"),
    "Cache Management": ("缓存管理", "快取管理", "快取管理", "快取管理"),
    "Scan and clean application cache to free up disk space": ("扫描并清理应用缓存以释放磁盘空间", "掃描並清理應用程式快取以釋放磁碟空間", "掃描並清理應用程式快取以釋放磁碟空間", "掃描並清理應用程式快取以釋放磁碟空間"),
    "Application Scanning": ("应用扫描", "應用程式掃描", "應用程式掃描", "應用程式掃描"),
    "Automatically scan the system for installed applications": ("自动扫描系统中已安装的应用", "自動掃描系統中已安裝的應用程式", "自動掃描系統中已安裝的應用程式", "自動掃描系統中已安裝的應用程式"),
    "Scans system Applications folder and other locations": ("扫描系统 Applications 文件夹及其他位置", "掃描系統 Applications 資料夾及其他位置", "掃描系統 Applications 資料夾及其他位置", "掃描系統 Applications 資料夾及其他位置"),
    "Builds a comprehensive list of installed apps": ("构建已安装应用的完整列表", "建立已安裝應用程式的完整列表", "建立已安裝應用程式的完整列表", "建立已安裝應用程式的完整列表"),
    "Calculates app size and related cache files": ("计算应用大小和相关缓存文件", "計算應用程式大小和相關快取檔案", "計算應用程式大小和相關快取檔案", "計算應用程式大小和相關快取檔案"),
    "Provides options to clean app cache": ("提供清理应用缓存的选项", "提供清理應用程式快取的選項", "提供清理應用程式快取的選項", "提供清理應用程式快取的選項"),
    "Click on an app to view detailed information": ("点击应用查看详细信息", "點擊應用程式查看詳細資訊", "點擊應用程式查看詳細資訊", "點擊應用程式查看詳細資訊"),
    "Use the cache manager to free up disk space": ("使用缓存管理器释放磁盘空间", "使用快取管理器釋放磁碟空間", "使用快取管理器釋放磁碟空間", "使用快取管理器釋放磁碟空間"),
    "Rescan to refresh the application list": ("重新扫描以刷新应用列表", "重新掃描以刷新應用程式列表", "重新掃描以刷新應用程式列表", "重新掃描以刷新應用程式列表"),
    "Network Permission Management": ("网络权限管理", "網路權限管理", "網路權限管理", "網路權限管理"),
    "Control which applications can access the network": ("控制哪些应用可以访问网络", "控制哪些應用程式可以存取網路", "控制哪些應用程式可以存取網路", "控制哪些應用程式可以存取網路"),
    "App-Level Control": ("应用级控制", "應用程式級控制", "應用程式級控制", "應用程式級控制"),
    "Set network permissions for individual applications": ("为单个应用设置网络权限", "為個別應用程式設定網路權限", "為個別應用程式設定網路權限", "為個別應用程式設定網路權限"),
    "Traffic Monitoring": ("流量监控", "流量監控", "流量監控", "流量監控"),
    "Monitor network traffic and connection attempts": ("监控网络流量和连接尝试", "監控網路流量和連線嘗試", "監控網路流量和連線嘗試", "監控網路流量和連線嘗試"),
    "Rule Profiles": ("规则配置", "規則設定檔", "規則設定檔", "規則設定檔"),
    "Create and switch between different firewall rule profiles": ("创建并切换不同的防火墙规则配置", "建立並切換不同的防火牆規則設定檔", "建立並切換不同的防火牆規則設定檔", "建立並切換不同的防火牆規則設定檔"),
    "Monitors network connection requests from applications": ("监控来自应用的网络连接请求", "監控來自應用程式的網路連線請求", "監控來自應用程式的網路連線請求", "監控來自應用程式的網路連線請求"),
    "Applies rules based on your configuration": ("根据你的配置应用规则", "根據你的設定套用規則", "根據你的設定套用規則", "根據你的設定套用規則"),
    "Blocks or allows traffic according to permissions": ("根据权限阻止或允许流量", "根據權限封鎖或允許流量", "根據權限封鎖或允許流量", "根據權限封鎖或允許流量"),
    "Logs network activity for review": ("记录网络活动以供查看", "記錄網路活動以供查看", "記錄網路活動以供查看", "記錄網路活動以供查看"),
    "Start with a permissive profile and tighten rules gradually": ("从宽松配置开始，逐步收紧规则", "從寬鬆設定檔開始，逐步收緊規則", "從寬鬆設定檔開始，逐步收緊規則", "從寬鬆設定檔開始，逐步收緊規則"),
    "Review logs to identify unnecessary network access": ("查看日志以识别不必要的网络访问", "查看日誌以識別不必要的網路存取", "查看日誌以識別不必要的網路存取", "查看日誌以識別不必要的網路存取"),
    "Use profiles for different network environments": ("为不同网络环境使用不同配置", "為不同網路環境使用不同設定檔", "為不同網路環境使用不同設定檔", "為不同網路環境使用不同設定檔"),
    "Clipboard History": ("剪贴板历史", "剪貼簿歷史", "剪貼簿歷史", "剪貼簿歷史"),
    "Keep track of your clipboard history and access previous copies": ("跟踪剪贴板历史并访问之前的复制内容", "追蹤剪貼簿歷史並存取之前的複製內容", "追蹤剪貼簿歷史並存取之前的複製內容", "追蹤剪貼簿歷史並存取之前的複製內容"),
    "Snippet Management": ("片段管理", "片段管理", "片段管理", "片段管理"),
    "Save frequently used text snippets for quick access": ("保存常用文本片段以便快速访问", "儲存常用文字片段以便快速存取", "儲存常用文字片段以便快速存取", "儲存常用文字片段以便快速存取"),
    "Quick Search": ("快速搜索", "快速搜尋", "快速搜尋", "快速搜尋"),
    "Search through clipboard history to find what you need": ("搜索剪贴板历史以找到所需内容", "搜尋剪貼簿歷史以找到所需內容", "搜尋剪貼簿歷史以找到所需內容", "搜尋剪貼簿歷史以找到所需內容"),
    "Auto Cleanup": ("自动清理", "自動清理", "自動清理", "自動清理"),
    "Automatically clean old clipboard items to save memory": ("自动清理旧剪贴板项以节省内存", "自動清理舊剪貼簿項目以節省記憶體", "自動清理舊剪貼簿項目以節省記憶體", "自動清理舊剪貼簿項目以節省記憶體"),
    "Monitors clipboard changes automatically": ("自动监控剪贴板变化", "自動監控剪貼簿變化", "自動監控剪貼簿變化", "自動監控剪貼簿變化"),
    "Stores history in local database": ("将历史记录存储在本地数据库", "將歷史記錄儲存在本機資料庫", "將歷史記錄儲存在本機資料庫", "將歷史記錄儲存在本機資料庫"),
    "Provides search and filter capabilities": ("提供搜索和筛选功能", "提供搜尋和篩選功能", "提供搜尋和篩選功能", "提供搜尋和篩選功能"),
    "Supports text, images, and rich content": ("支持文本、图片和富文本内容", "支援文字、圖片和豐富內容", "支援文字、圖片和豐富內容", "支援文字、圖片和豐富內容"),
    "Use keyboard shortcuts for quick access": ("使用键盘快捷键快速访问", "使用鍵盤快捷鍵快速存取", "使用鍵盤快捷鍵快速存取", "使用鍵盤快捷鍵快速存取"),
    "Pin important items to keep them accessible": ("固定重要项目以保持可访问", "釘選重要項目以保持可存取", "釘選重要項目以保持可存取", "釘選重要項目以保持可存取"),
    "Configure auto-cleanup to manage storage": ("配置自动清理以管理存储", "設定自動清理以管理儲存空間", "設定自動清理以管理儲存空間", "設定自動清理以管理儲存空間"),
    "App Management": ("应用管理", "應用程式管理", "應用程式管理", "應用程式管理"),
    "Manage your App Store Connect apps, metadata, and screenshots": ("管理 App Store Connect 应用、元数据和截图", "管理 App Store Connect 應用程式、中繼資料和截圖", "管理 App Store Connect 應用程式、中繼資料和截圖", "管理 App Store Connect 應用程式、中繼資料和截圖"),
    "Screenshot Management": ("截图管理", "截圖管理", "截圖管理", "截圖管理"),
    "Upload, preview, and organize app screenshots": ("上传、预览和整理应用截图", "上傳、預覽和整理應用程式截圖", "上傳、預覽和整理應用程式截圖", "上傳、預覽和整理應用程式截圖"),
    "Metadata Editing": ("元数据编辑", "中繼資料編輯", "中繼資料編輯", "中繼資料編輯"),
    "Edit app information, descriptions, and keywords": ("编辑应用信息、描述和关键词", "編輯應用程式資訊、描述和關鍵字", "編輯應用程式資訊、描述和關鍵字", "編輯應用程式資訊、描述和關鍵字"),
    "Version Management": ("版本管理", "版本管理", "版本管理", "版本管理"),
    "Create and manage app versions for submission": ("创建和管理用于提交的应用版本", "建立和管理用於提交的應用程式版本", "建立和管理用於提交的應用程式版本", "建立和管理用於提交的應用程式版本"),
    "Connect to App Store Connect API": ("连接 App Store Connect API", "連接 App Store Connect API", "連接 App Store Connect API", "連接 App Store Connect API"),
    "Fetch app information and metadata": ("获取应用信息和元数据", "取得應用程式資訊和中繼資料", "取得應用程式資訊和中繼資料", "取得應用程式資訊和中繼資料"),
    "Allow editing and screenshot upload": ("允许编辑和上传截图", "允許編輯和上傳截圖", "允許編輯和上傳截圖", "允許編輯和上傳截圖"),
    "Submit changes to App Store Connect": ("将更改提交到 App Store Connect", "將變更提交到 App Store Connect", "將變更提交到 App Store Connect", "將變更提交到 App Store Connect"),
    "Configure API key in plugin settings": ("在插件设置中配置 API 密钥", "在插件設定中設定 API 金鑰", "在外掛設定中設定 API 金鑰", "在外掛設定中設定 API 金鑰"),
    "Select an app from the toolbar to manage": ("从工具栏选择应用进行管理", "從工具列選擇應用程式進行管理", "從工具列選擇應用程式進行管理", "從工具列選擇應用程式進行管理"),
    "Changes are submitted directly to App Store Connect": ("更改直接提交到 App Store Connect", "變更直接提交到 App Store Connect", "變更直接提交到 App Store Connect", "變更直接提交到 App Store Connect"),
    "Automated Code Review": ("自动代码审查", "自動程式碼審查", "自動程式碼審查", "自動程式碼審查"),
    "Analyze Git changes and identify potential issues automatically": ("自动分析 Git 变更并识别潜在问题", "自動分析 Git 變更並識別潛在問題", "自動分析 Git 變更並識別潛在問題", "自動分析 Git 變更並識別潛在問題"),
    "Issue Detection": ("问题检测", "問題偵測", "問題偵測", "問題偵測"),
    "Detect bugs, security vulnerabilities, and code smells": ("检测 bug、安全漏洞和代码异味", "偵測 bug、安全漏洞和程式碼異味", "偵測 bug、安全漏洞和程式碼異味", "偵測 bug、安全漏洞和程式碼異味"),
    "Detailed Reports": ("详细报告", "詳細報告", "詳細報告", "詳細報告"),
    "Generate comprehensive review reports with actionable feedback": ("生成包含可操作建议的全面审查报告", "產生包含可行建議的全面審查報告", "產生包含可行建議的全面審查報告", "產生包含可行建議的全面審查報告"),
    "AI-Powered Analysis": ("AI 智能分析", "AI 智能分析", "AI 智能分析", "AI 智能分析"),
    "Leverage AI to provide intelligent code suggestions": ("利用 AI 提供智能代码建议", "利用 AI 提供智能程式碼建議", "利用 AI 提供智能程式碼建議", "利用 AI 提供智能程式碼建議"),
    "Analyzes Git diff for the current branch": ("分析当前分支的 Git diff", "分析目前分支的 Git diff", "分析目前分支的 Git diff", "分析目前分支的 Git diff"),
    "Uses AI to understand code context and intent": ("使用 AI 理解代码上下文和意图", "使用 AI 理解程式碼上下文和意圖", "使用 AI 理解程式碼上下文和意圖", "使用 AI 理解程式碼上下文和意圖"),
    "Identifies potential issues and improvements": ("识别潜在问题和改进点", "識別潛在問題和改進點", "識別潛在問題和改進點", "識別潛在問題和改進點"),
    "Generates a structured review report": ("生成结构化审查报告", "產生結構化審查報告", "產生結構化審查報告", "產生結構化審查報告"),
    "Review changes before committing for best results": ("提交前审查更改以获得最佳效果", "提交前審查變更以獲得最佳效果", "提交前審查變更以獲得最佳效果", "提交前審查變更以獲得最佳效果"),
    "Configure review rules in plugin settings": ("在插件设置中配置审查规则", "在插件設定中設定審查規則", "在外掛設定中設定審查規則", "在外掛設定中設定審查規則"),
    "Use with Git integration for seamless workflow": ("配合 Git 集成实现无缝工作流", "配合 Git 整合實現無縫工作流程", "配合 Git 整合實現無縫工作流程", "配合 Git 整合實現無縫工作流程"),
    "Multi-Database Support": ("多数据库支持", "多資料庫支援", "多資料庫支援", "多資料庫支援"),
    "Connect to SQLite, MySQL, PostgreSQL, and Redis databases": ("连接 SQLite、MySQL、PostgreSQL 和 Redis 数据库", "連接 SQLite、MySQL、PostgreSQL 和 Redis 資料庫", "連接 SQLite、MySQL、PostgreSQL 和 Redis 資料庫", "連接 SQLite、MySQL、PostgreSQL 和 Redis 資料庫"),
    "Data Browser": ("数据浏览器", "資料瀏覽器", "資料瀏覽器", "資料瀏覽器"),
    "Browse and inspect database tables and records": ("浏览和检查数据库表及记录", "瀏覽和檢查資料庫表及記錄", "瀏覽和檢查資料庫表及記錄", "瀏覽和檢查資料庫表及記錄"),
    "Query Editor": ("查询编辑器", "查詢編輯器", "查詢編輯器", "查詢編輯器"),
    "Write and execute SQL queries with syntax highlighting": ("编写并执行带语法高亮的 SQL 查询", "編寫並執行帶語法醒目提示的 SQL 查詢", "編寫並執行帶語法醒目提示的 SQL 查詢", "編寫並執行帶語法醒目提示的 SQL 查詢"),
    "Schema Inspector": ("结构检查器", "結構檢查器", "結構檢查器", "結構檢查器"),
    "View database schema, indexes, and relationships": ("查看数据库结构、索引和关系", "查看資料庫結構、索引和關聯", "查看資料庫結構、索引和關聯", "查看資料庫結構、索引和關聯"),
    "Configure database connections in settings": ("在设置中配置数据库连接", "在設定中設定資料庫連線", "在設定中設定資料庫連線", "在設定中設定資料庫連線"),
    "Browse available databases and tables": ("浏览可用数据库和表", "瀏覽可用資料庫和表", "瀏覽可用資料庫和表", "瀏覽可用資料庫和表"),
    "Execute queries and view results": ("执行查询并查看结果", "執行查詢並查看結果", "執行查詢並查看結果", "執行查詢並查看結果"),
    "Export data in various formats": ("以多种格式导出数据", "以多種格式匯出資料", "以多種格式匯出資料", "以多種格式匯出資料"),
    "Use read-only mode for production databases": ("对生产数据库使用只读模式", "對生產資料庫使用唯讀模式", "對生產資料庫使用唯讀模式", "對生產資料庫使用唯讀模式"),
    "Save frequently used queries as snippets": ("将常用查询保存为片段", "將常用查詢儲存為片段", "將常用查詢儲存為片段", "將常用查詢儲存為片段"),
    "Enable connection pooling for better performance": ("启用连接池以提升性能", "啟用連線池以提升效能", "啟用連線池以提升效能", "啟用連線池以提升效能"),
}


def make_entry(en: str, hans: str, hant: str, hk: str, tw: str) -> dict:
    return {
        "localizations": {
            "en": {"stringUnit": {"state": "translated", "value": en}},
            "zh-Hans": {"stringUnit": {"state": "translated", "value": hans}},
            "zh-Hant": {"stringUnit": {"state": "translated", "value": hant}},
            "zh-HK": {"stringUnit": {"state": "translated", "value": hk}},
            "zh-TW": {"stringUnit": {"state": "translated", "value": tw}},
        }
    }


def main() -> None:
    missing: set[str] = set()
    updated: list[str] = []
    for about_path in ROOT.glob("Plugins/*/Sources/**/*AboutView.swift"):
        plugin_dir = about_path.parents[2]
        xc_path = plugin_dir / "Sources" / "Localizable.xcstrings"
        if not xc_path.exists():
            continue
        keys = set(re.findall(r'(?<!core)L\("([^"]+)"\)', about_path.read_text()))
        data = json.loads(xc_path.read_text())
        strings = data.setdefault("strings", {})
        changed = False
        for key in keys:
            if key not in TRANSLATIONS:
                missing.add(key)
                continue
            hans, hant, hk, tw = TRANSLATIONS[key]
            strings[key] = make_entry(key, hans, hant, hk, tw)
            changed = True
        if changed:
            xc_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
            updated.append(plugin_dir.name)
    print(f"Updated {len(updated)} plugin xcstrings")
    if missing:
        raise SystemExit(f"Missing translations: {sorted(missing)}")


if __name__ == "__main__":
    main()
