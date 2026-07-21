import Foundation
import LumiKernel
import SwiftUI

// MARK: - Default Chat Section Provider

/// 默认聊天分区服务实现
///
/// 负责管理所有插件的聊天分区项、工具栏、标题项的注册、排序和查询。
@MainActor
public final class ChatSectionProvider: ChatSectionProviding {
    public private(set) var allChatSectionItems: [ChatSectionItem] = []
    public private(set) var allChatSectionToolbarItems: [ChatSectionToolbarItem] = []
    public private(set) var allChatSectionToolbarBarItems: [ChatSectionToolbarBarItem] = []
    public private(set) var allChatSectionHeaderItems: [ChatSectionHeaderItem] = []
    public private(set) var allChatSectionActionBarItems: [ChatSectionActionBarItem] = []

    private var chatSectionItems: [String: ChatSectionItem] = [:]
    private var chatSectionItemOrder: [String] = []
    private var chatSectionToolbarItems: [String: ChatSectionToolbarItem] = [:]
    private var chatSectionToolbarItemOrder: [String] = []
    private var chatSectionToolbarBars: [String: ChatSectionToolbarBarItem] = [:]
    private var chatSectionToolbarBarOrder: [String] = []
    private var chatSectionHeaders: [String: ChatSectionHeaderItem] = [:]
    private var chatSectionHeaderOrder: [String] = []
    private var chatSectionActionBars: [String: ChatSectionActionBarItem] = [:]
    private var chatSectionActionBarOrder: [String] = []

    public init() {}

    public func chatSectionItems(placement: ChatSectionPlacement) -> [ChatSectionItem] {
        allChatSectionItems.filter { $0.placement == placement }
    }

    public func chatSectionToolbarItems(placement: ChatSectionToolbarPlacement) -> [ChatSectionToolbarItem] {
        allChatSectionToolbarItems.filter { $0.placement == placement }
    }

    public func registerChatSectionItem(_ item: ChatSectionItem) {
        if chatSectionItems[item.id] == nil {
            chatSectionItemOrder.append(item.id)
        }
        chatSectionItems[item.id] = item
        updateSortedChatSectionItems()
    }

    public func unregisterChatSectionItem(id: String) {
        chatSectionItems.removeValue(forKey: id)
        chatSectionItemOrder.removeAll { $0 == id }
        updateSortedChatSectionItems()
    }

    public func registerChatSectionToolbarItem(_ item: ChatSectionToolbarItem) {
        if chatSectionToolbarItems[item.id] == nil {
            chatSectionToolbarItemOrder.append(item.id)
        }
        chatSectionToolbarItems[item.id] = item
        updateSortedChatSectionToolbarItems()
    }

    public func unregisterChatSectionToolbarItem(id: String) {
        chatSectionToolbarItems.removeValue(forKey: id)
        chatSectionToolbarItemOrder.removeAll { $0 == id }
        updateSortedChatSectionToolbarItems()
    }

    public func registerChatSectionToolbarBarItem(_ item: ChatSectionToolbarBarItem) {
        if chatSectionToolbarBars[item.id] == nil {
            chatSectionToolbarBarOrder.append(item.id)
        }
        chatSectionToolbarBars[item.id] = item
        updateSortedChatSectionToolbarBars()
    }

    public func unregisterChatSectionToolbarBarItem(id: String) {
        chatSectionToolbarBars.removeValue(forKey: id)
        chatSectionToolbarBarOrder.removeAll { $0 == id }
        updateSortedChatSectionToolbarBars()
    }

    public func registerChatSectionHeaderItem(_ item: ChatSectionHeaderItem) {
        if chatSectionHeaders[item.id] == nil {
            chatSectionHeaderOrder.append(item.id)
        }
        chatSectionHeaders[item.id] = item
        updateSortedChatSectionHeaders()
    }

    public func unregisterChatSectionHeaderItem(id: String) {
        chatSectionHeaders.removeValue(forKey: id)
        chatSectionHeaderOrder.removeAll { $0 == id }
        updateSortedChatSectionHeaders()
    }

    public func registerChatSectionActionBarItem(_ item: ChatSectionActionBarItem) {
        if chatSectionActionBars[item.id] == nil {
            chatSectionActionBarOrder.append(item.id)
        }
        chatSectionActionBars[item.id] = item
        updateSortedChatSectionActionBars()
    }

    public func unregisterChatSectionActionBarItem(id: String) {
        chatSectionActionBars.removeValue(forKey: id)
        chatSectionActionBarOrder.removeAll { $0 == id }
        updateSortedChatSectionActionBars()
    }

    private func updateSortedChatSectionItems() {
        allChatSectionItems = chatSectionItemOrder.compactMap { chatSectionItems[$0] }
            .sorted { $0.order < $1.order }
    }

    private func updateSortedChatSectionToolbarItems() {
        allChatSectionToolbarItems = chatSectionToolbarItemOrder.compactMap { chatSectionToolbarItems[$0] }
            .sorted { $0.order < $1.order }
    }

    private func updateSortedChatSectionToolbarBars() {
        allChatSectionToolbarBarItems = chatSectionToolbarBarOrder.compactMap { chatSectionToolbarBars[$0] }
            .sorted { $0.order < $1.order }
    }

    private func updateSortedChatSectionHeaders() {
        allChatSectionHeaderItems = chatSectionHeaderOrder.compactMap { chatSectionHeaders[$0] }
            .sorted { $0.order < $1.order }
    }

    private func updateSortedChatSectionActionBars() {
        allChatSectionActionBarItems = chatSectionActionBarOrder.compactMap { chatSectionActionBars[$0] }
            .sorted { $0.order < $1.order }
    }
}
