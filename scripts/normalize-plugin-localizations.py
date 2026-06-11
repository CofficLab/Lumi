#!/usr/bin/env python3
"""Normalize plugin Localizable.xcstrings for en, zh-Hans, zh-HK, zh-Hant, zh-TW."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

LOCALES = ("en", "zh-Hans", "zh-HK", "zh-Hant", "zh-TW")

# Simplified -> Traditional (shared)
S_TO_T = {
    "应用": "應用", "确定": "確定", "结束": "結束", "进程": "進程",
    "剪贴板": "剪貼板", "数据库": "資料庫", "开发": "開發",
    "设备": "設備", "磁盘": "磁碟", "管理": "管理", "网络": "網路",
    "监控": "監控", "文件": "檔案", "扫描": "掃描", "搜索": "搜尋",
    "设置": "設定", "显示": "顯示", "终端": "終端", "文本": "文字",
    "右键": "右鍵", "运行": "執行", "保存": "儲存", "系统": "系統",
    "总计": "總計", "更新": "更新", "上传": "上傳", "标签": "標籤",
    "信息": "資訊", "视图": "視圖", "选择": "選擇", "这个": "這個",
    "错误": "錯誤", "历史": "歷史", "主页": "主頁", "下载": "下載",
    "导入": "導入", "导出": "匯出", "配置": "設定", "脚本": "腳本",
    "帮助": "說明", "问题": "問題", "路径": "路徑", "状态": "狀態",
    "类型": "類型", "选项": "選項", "全部": "全部", "当前": "目前",
    "删除": "刪除", "项目": "專案", "端口": "連接埠", "时间": "時間",
    "自动": "自動", "手动": "手動", "启用": "啟用", "禁用": "停用",
    "扩展": "擴充", "功能": "功能", "检查": "檢查", "清理": "清理",
    "安装": "安裝", "卸载": "解除安裝", "重启": "重新啟動",
    "刷新": "重新整理", "复制": "複製", "拷贝": "拷貝", "默认": "預設",
    "自定义": "自訂", "内容": "內容", "查找": "尋找", "替换": "替換",
    "排序": "排序", "过滤": "過濾", "分组": "群組", "标记": "標記",
    "预览": "預覽", "操作": "操作", "动作": "動作", "添加": "新增",
    "模板": "範本", "子菜单": "子選單", "权限": "權限", "检测": "偵測",
    "选中": "選取", "取消": "取消", "支持": "支援", "监听": "監聽",
    "发现": "發現", "正在": "正在", "失败": "失敗", "管理器": "管理員",
    "主机": "主機", "条目": "項目", "常规": "一般", "后台": "後台",
    "软件": "軟體", "程序": "程式", "内存": "記憶體", "屏幕": "螢幕",
    "显示器": "顯示器", "内置": "內建", "外接": "外接", "亮度": "亮度",
    "对比度": "對比度", "音量": "音量", "连接": "連接", "请": "請",
    "与": "與", "为": "為", "通过": "透過", "时": "時", "小时": "小時",
    "分钟": "分鐘", "秒": "秒", "无": "無", "个": "個", "后": "後",
    "发": "發", "开": "開", "关": "關", "门": "門", "页": "頁",
    "图": "圖", "单": "單", "双": "雙", "击": "擊", "击": "擊",
    "载": "載", "录": "錄", "汇": "匯", "总": "總", "线": "線",
    "网": "網", "电": "電", "脑": "腦", "码": "碼", "语": "語",
    "译": "譯", "话": "話", "说": "說", "读": "讀", "写": "寫",
    "编": "編", "辑": "輯", "输": "輸", "入": "入", "出": "出",
}

# HK-specific overrides applied after generic traditional conversion
HK_OVERRIDES = {
    "連線": "連接", "內建": "內置", "軟體": "軟件", "程式": "程序",
    "資料庫": "數據庫", "螢幕": "屏幕", "滑鼠": "鼠標", "影片": "視頻",
    "資訊": "信息", "匯出": "導出", "設定": "設置", "檔案": "文件",
    "重新整理": "刷新", "連接埠": "端口", "磁碟": "磁盤",
}

# TW-specific overrides (after generic traditional)
TW_OVERRIDES = {
    "連接": "連線", "鼠標": "滑鼠", "視頻": "影片", "信息": "資訊",
    "導出": "匯出", "設置": "設定", "文件": "檔案", "刷新": "重新整理",
    "端口": "連接埠", "磁盘": "磁碟", "程序": "程式", "软件": "軟體",
    "内存": "記憶體", "屏幕": "螢幕", "默认": "預設", "视频": "影片",
}


def has_cjk(text: str) -> bool:
    return bool(re.search(r"[\u4e00-\u9fff]", text))


def looks_english_key(key: str) -> bool:
    if not key or key.startswith("%"):
        return False
    return not has_cjk(key)


def unit_value(loc: dict | None) -> str | None:
    if not loc:
        return None
    if "stringUnit" in loc:
        return loc["stringUnit"].get("value")
    if "string" in loc:
        return loc["string"]
    return None


def make_unit(value: str, state: str = "translated") -> dict:
    return {"stringUnit": {"state": state, "value": value}}


def s_to_traditional(text: str) -> str:
    result = text
    for simple, trad in sorted(S_TO_T.items(), key=lambda item: len(item[0]), reverse=True):
        result = result.replace(simple, trad)
    return result


def apply_overrides(text: str, overrides: dict[str, str]) -> str:
    result = text
    for src, dst in sorted(overrides.items(), key=lambda item: len(item[0]), reverse=True):
        result = result.replace(src, dst)
    return result


def resolve_english(key: str, locs: dict) -> str:
    en = unit_value(locs.get("en"))
    if en:
        return en
    if looks_english_key(key):
        return key
    hans = unit_value(locs.get("zh-Hans"))
    if hans and not has_cjk(hans):
        return hans
    return key


def resolve_zh_hans(key: str, locs: dict, english: str) -> str:
    hans = unit_value(locs.get("zh-Hans"))
    if hans:
        return hans
    if has_cjk(key):
        return key
    if has_cjk(english):
        return english
    return english


def resolve_zh_hant(hans: str, locs: dict) -> str:
    hant = unit_value(locs.get("zh-Hant"))
    if hant:
        return hant
    hk = unit_value(locs.get("zh-HK"))
    if hk:
        return hk
    tw = unit_value(locs.get("zh-TW"))
    if tw:
        return tw
    if has_cjk(hans):
        return s_to_traditional(hans)
    return hans


def resolve_zh_hk(hans: str, hant: str, locs: dict) -> str:
    hk = unit_value(locs.get("zh-HK"))
    if hk:
        return hk
    base = hant if has_cjk(hant) else s_to_traditional(hans)
    return apply_overrides(base, HK_OVERRIDES)


def resolve_zh_tw(hans: str, hant: str, locs: dict) -> str:
    tw = unit_value(locs.get("zh-TW"))
    if tw:
        return tw
    base = hant if has_cjk(hant) else s_to_traditional(hans)
    return apply_overrides(base, TW_OVERRIDES)


def normalize_entry(key: str, entry: dict | None) -> dict:
    if not entry:
        entry = {}
    locs = dict(entry.get("localizations") or {})

    english = resolve_english(key, locs)
    zh_hans = resolve_zh_hans(key, locs, english)
    zh_hant = resolve_zh_hant(zh_hans, locs)
    zh_hk = resolve_zh_hk(zh_hans, zh_hant, locs)
    zh_tw = resolve_zh_tw(zh_hans, zh_hant, locs)

    en_state = "translated" if looks_english_key(key) or unit_value(locs.get("en")) else "new"

    entry["localizations"] = {
        "en": make_unit(english, en_state),
        "zh-Hans": make_unit(zh_hans),
        "zh-HK": make_unit(zh_hk),
        "zh-Hant": make_unit(zh_hant),
        "zh-TW": make_unit(zh_tw),
    }
    entry.pop("extractionState", None)
    return entry


def normalize_file(path: Path) -> int:
    data = json.loads(path.read_text(encoding="utf-8"))
    data["sourceLanguage"] = "en"
    strings = data.get("strings") or {}
    updated = 0
    for key, entry in list(strings.items()):
        normalized = normalize_entry(key, entry)
        if normalized != entry:
            updated += 1
        strings[key] = normalized
    data["strings"] = strings
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return updated


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("Plugins")
    files = sorted(root.rglob("Localizable.xcstrings"))
    total = 0
    for file_path in files:
        if ".build" in file_path.parts:
            continue
        count = normalize_file(file_path)
        total += count
        print(f"{file_path}: normalized {count} entries")
    print(f"Done. {len(files)} files, {total} entries touched.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
