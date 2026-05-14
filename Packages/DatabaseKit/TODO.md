# DatabaseKit TODO

## P0 - Core correctness

- [x] Implement real connection pooling with idle connection reuse, max connection enforcement, waiting acquire calls, and shutdown semantics.
- [x] Add focused tests for connection pool reuse, max connection backpressure, dead connection handling, and shutdown behavior.
- [x] Make PostgreSQL parameter binding actually use `params` instead of executing unsafe raw SQL only.
- [x] Make PostgreSQL `execute` return accurate affected row counts.
- [x] Make MySQL `execute` return accurate affected row counts for write statements.

## P1 - Driver reliability

- [x] Add integration tests for MySQL and PostgreSQL behind opt-in environment variables or local Docker services.
- [x] Add Redis integration tests behind opt-in environment variables.
- [x] Replace Redis whitespace tokenization with a command API or shell-like parser that supports quoted values.
- [x] Make Redis response receiving robust for large and segmented RESP payloads.
- [x] Add connection timeout handling for Redis `waitForReady`.

## P2 - API and docs

- [x] Document supported parameter placeholder syntax for each driver.
- [x] Add README examples for registering drivers, opening connections, using pools, transactions, and probing configs.
- [x] Decide whether `DatabaseManager.shared` should register built-in drivers automatically or remain explicit.
- [x] Add package-level notes for thread safety, lifecycle ownership, and production limitations.

## P3 - Follow-up hardening

- [x] Validate SQLite parameter counts before execution and query calls.
- [x] Check SQLite bind return codes and query step completion errors.
- [x] Implement Redis transactions with `MULTI`, `EXEC`, and `DISCARD`.
- [x] Add opt-in Redis transaction integration tests.

## P4 - Lifecycle management

- [x] Add `DatabaseManager.disconnectAll()` for tracked active connections.
- [x] Add pool shutdown APIs for individual and all cached pools.
- [x] Add `DatabaseManager.shutdown()` to close tracked connections and pools together.
- [x] Document manager shutdown and pool sizing APIs.
- [x] Close the previous tracked connection when reconnecting with the same config id.
- [x] Normalize invalid pool sizes to avoid permanently waiting acquire calls.

## P5 - Driver behavior consistency

- [x] Wait for MySQL connection close before shutting down its event loop group.
- [x] Return PostgreSQL column metadata for empty query results without relying on `PostgresNIO` internal APIs.
- [x] Add opt-in PostgreSQL integration coverage for empty result columns.

## P6 - Pool ownership safety

- [x] Make `DatabaseConnection` class-only so pools can track connection identity.
- [x] Prevent duplicate releases from adding the same connection to idle storage twice.
- [x] Close foreign connections released into a pool instead of caching them.
- [x] Add regression tests for duplicate and foreign releases.

## P7 - Result metadata consistency

- [x] Return MySQL column metadata for empty `SELECT` query results without relying on private `MySQLNIO` APIs.
- [x] Add opt-in MySQL integration coverage for empty result columns.

## P8 - RESP parser correctness

- [x] Reject malformed RESP integers instead of coercing them to zero.

## P9 - Swift concurrency cleanup

- [x] Remove unsafe mutable metadata capture from MySQL affected-row handling.

## P10 - RESP protocol strictness

- [x] Reject RESP bulk string lengths below `-1`.
- [x] Reject RESP array lengths below `-1`.

## P11 - Redis parameter consistency

- [x] Apply `params` to Redis `execute`, `query`, and transaction `execute` calls.
- [x] Add tests for Redis command argument composition.
