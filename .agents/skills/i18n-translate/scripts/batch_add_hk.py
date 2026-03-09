#!/usr/bin/env python3
"""批量添加缺失的 zh-HK 翻译"""
import json
import sys
from pathlib import Path

# 简繁映射（常见词汇）
SIMPLIFIED_TO_TRADITIONAL = {
    "应用": "應用", "确定": "確定", "结束": "結束", "进程": "進程",
    "剪贴板": "剪貼板", "数据库": "資料庫", "开发": "開發",
    "设备": "設備", "磁盘": "磁盤", "管理": "管理", "网络": "網絡",
    "监控": "監控", "文件": "檔案", "新建": "新建", "扫描": "掃描",
    "搜索": "搜尋", "设置": "設定", "显示": "顯示", "终端": "終端",
    "文本": "文本", "右键": "右鍵", "运行": "執行", "保存": "儲存",
    "系统": "系統", "总计": "總計", "更新": "更新", "上传": "上傳",
    "标签": "標籤", "信息": "資訊", "视图": "視圖", "选择": "選擇",
    "这个": "這個", "错误": "錯誤", "历史": "歷史", "主页": "主頁",
    "下载": "下載", "导入": "導入", "导出": "導出", "配置": "配置",
    "脚本": "腳本", "帮助": "幫助", "问题": "問題", "位置": "位置",
    "路径": "路徑", "大小": "大小", "状态": "狀態", "类型": "類型",
    "选项": "選項", "全部": "全部", "当前": "目前", "版本": "版本",
    "删除": "刪除", "项目": "項目", "连接": "連線", "端口": "端口",
    "时间": "時間", "自动": "自動", "手动": "手動", "启用": "啟用",
    "禁用": "停用", "扩展": "擴充", "功能": "功能", "检查": "檢查",
    "清理": "清理", "安装": "安裝", "卸载": "卸載", "重启": "重新啟動",
    "刷新": "重新整理", "复制": "拷貝", "拷贝": "拷貝", "默认": "默認",
    "自定义": "自訂", "内容": "內容", "查找": "尋找", "替换": "替換",
    "排序": "排序", "过滤": "過濾", "分组": "群組", "标记": "標記",
    "预览": "預覽", "操作": "操作", "动作": "動作", "行为": "行為",
    "添加": "新增", "新增": "新增", "模板": "範本", "新文件": "新建檔案",
    "子菜单": "子選單", "扩展": "擴充", "权限": "權限", "检测": "檢測",
    "选中的": "選中的", "已选中": "已選中", "选中": "選取", "取消": "取消",
    "支持": "支援", "操作": "操作", "监听": "監聽", "发现": "發現",
    "正在": "正在", "进程": "進程", "失败": "失敗", "刷新": "重新整理",
    "管理器": "管理員", "管理": "管理", "主机": "主機", "映射": "映射",
    "条目": "條目", "常规": "一般", "操作": "操作", "后台": "後台",
}

def simplified_to_traditional(text):
    """简繁转换"""
    result = text
    for simple, trad in SIMPLIFIED_TO_TRADITIONAL.items():
        result = result.replace(simple, trad)
    return result

def add_missing_translations(file_path):
    """为文件添加缺失的 zh-HK 翻译"""
    path = Path(file_path)
    if not path.exists():
        print(f"❌ 文件不存在: {file_path}")
        return

    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    strings = data.get("strings", {})
    added_count = 0

    for key, value in strings.items():
        if not value:
            continue

        localizations = value.get("localizations", {})
        hans = localizations.get("zh-Hans")

        # 如果有简体但没有繁体
        if hans and "zh-HK" not in localizations:
            hans_value = hans.get("stringUnit", {}).get("value", "")
            if hans_value:
                # 自动转换简繁
                hk_value = simplified_to_traditional(hans_value)

                # 添加繁体翻译
                if "localizations" not in value:
                    value["localizations"] = {}
                value["localizations"]["zh-HK"] = {
                    "stringUnit": {
                        "state": "translated",
                        "value": hk_value
                    }
                }
                added_count += 1
                print(f"✅ 添加: {key[:50]}")

    # 保存文件
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"\n✅ 完成！共添加 {added_count} 个繁体中文翻译")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("用法: python3 batch_add_hk.py <文件路径>.xcstrings")
        sys.exit(1)

    file_path = sys.argv[1]
    add_missing_translations(file_path)
