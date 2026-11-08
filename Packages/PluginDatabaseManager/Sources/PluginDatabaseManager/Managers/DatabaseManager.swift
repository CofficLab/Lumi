import Foundation

public enum DatabaseDriverBootstrap {
    private actor State {
        /// 按 manager 实例记录，不能用一个全局布尔值：
        /// 测试会创建独立 manager，全局标记会让后创建的那个拿不到任何内置驱动。
        private var registered: Set<ObjectIdentifier> = []

        func beginRegistration(for manager: DatabaseManagerCore) -> Bool {
            registered.insert(ObjectIdentifier(manager)).inserted
        }
    }

    private static let state = State()

    public static func registerBuiltinsIfNeeded(on manager: DatabaseManagerCore = .shared) async {
        guard await state.beginRegistration(for: manager) else { return }
        await manager.register(driver: SQLiteDriver())
        await manager.register(driver: MySQLDriver())
        await manager.register(driver: PostgreSQLDriver())
        await manager.register(driver: RedisDriver())
    }
}
