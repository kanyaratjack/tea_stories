import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalDb {
  LocalDb._();

  static final LocalDb instance = LocalDb._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'tea_store_pos.db');
    _database = await openDatabase(
      path,
      version: 22,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _database!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        name_th TEXT,
        name_zh TEXT,
        name_en TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE option_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        group_key TEXT NOT NULL,
        name TEXT NOT NULL,
        name_th TEXT,
        name_zh TEXT,
        name_en TEXT,
        price REAL NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        name_th TEXT,
        name_zh TEXT,
        name_en TEXT,
        description TEXT,
        image_url TEXT,
        show_size INTEGER NOT NULL DEFAULT 1,
        show_sugar INTEGER NOT NULL DEFAULT 1,
        show_ice INTEGER NOT NULL DEFAULT 1,
        show_toppings INTEGER NOT NULL DEFAULT 1,
        category TEXT NOT NULL,
        price REAL NOT NULL,
        delivery_price REAL,
        promo_type TEXT NOT NULL DEFAULT 'none',
        promo_value REAL NOT NULL DEFAULT 0,
        promo_active INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_no TEXT NOT NULL UNIQUE,
        pickup_no TEXT NOT NULL,
        subtotal REAL NOT NULL,
        discount REAL NOT NULL,
        total REAL NOT NULL,
        payment_method TEXT NOT NULL,
        order_type TEXT NOT NULL DEFAULT 'inStore',
        order_channel TEXT NOT NULL DEFAULT '',
        platform_order_id TEXT NOT NULL DEFAULT '',
        promo_amount REAL NOT NULL DEFAULT 0,
        promo_breakdown_json TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_orders_created_at ON orders(created_at)',
    );
    await db.execute('CREATE INDEX idx_orders_status ON orders(status)');
    await db.execute('CREATE INDEX idx_orders_type ON orders(order_type)');
    await db.execute(
      'CREATE INDEX idx_orders_channel ON orders(order_channel)',
    );
    await db.execute(
      'CREATE INDEX idx_orders_promo_amount ON orders(promo_amount)',
    );

    await db.execute('''
      CREATE TABLE promotion_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        priority INTEGER NOT NULL DEFAULT 100,
        is_active INTEGER NOT NULL DEFAULT 1,
        apply_in_store INTEGER NOT NULL DEFAULT 1,
        apply_delivery INTEGER NOT NULL DEFAULT 0,
        start_at TEXT,
        end_at TEXT,
        condition_json TEXT NOT NULL,
        benefit_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_promotion_rules_active ON promotion_rules(is_active, priority)',
    );

    await db.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        product_name_th TEXT,
        product_name_zh TEXT,
        product_name_en TEXT,
        category TEXT NOT NULL,
        base_price REAL NOT NULL,
        unit_price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        size TEXT NOT NULL,
        sugar TEXT NOT NULL,
        ice TEXT NOT NULL,
        toppings TEXT NOT NULL DEFAULT '',
        topping_total REAL NOT NULL DEFAULT 0,
        note TEXT NOT NULL,
        line_total REAL NOT NULL,
        FOREIGN KEY(order_id) REFERENCES orders(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_order_items_order_id ON order_items(order_id)',
    );

    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        method TEXT NOT NULL,
        amount REAL NOT NULL,
        received_amount REAL,
        change_amount REAL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(order_id) REFERENCES orders(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE suspended_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ticket_no TEXT NOT NULL UNIQUE,
        label TEXT,
        payload_json TEXT NOT NULL,
        total REAL NOT NULL,
        item_count INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE refunds (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_no TEXT NOT NULL,
        amount REAL NOT NULL,
        refund_type TEXT NOT NULL DEFAULT 'full',
        reason TEXT NOT NULL,
        operator_name TEXT NOT NULL DEFAULT 'cashier',
        manager_pin_tail TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_refunds_order_no ON refunds(order_no)');

    await db.execute('''
      CREATE TABLE refund_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        refund_id INTEGER NOT NULL,
        order_item_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        amount REAL NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(refund_id) REFERENCES refunds(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_refund_items_order_item_id ON refund_items(order_item_id)',
    );
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_type TEXT NOT NULL,
        task_key TEXT NOT NULL UNIQUE,
        payload_json TEXT NOT NULL,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        next_retry_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_sync_queue_next_retry ON sync_queue(next_retry_at)',
    );
    await _seedInitialCatalogAndSpecOptions(db);
  }

  Future<void> _seedInitialCatalogAndSpecOptions(Database db) async {
    final now = DateTime.now().toIso8601String();
    const categories = <String>['奶茶', '果茶', '冰淇淋', '沙冰'];
    for (final name in categories) {
      await db.insert('categories', {
        'name': name,
        'name_zh': name,
        'is_active': 1,
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.update(
        'categories',
        {'is_active': 1},
        where: 'name = ?',
        whereArgs: [name],
      );
    }

    const options = <(String, String, int)>[
      ('size', '大杯', 1),
      ('size', '小杯', 2),
      ('sugar', '三分', 1),
      ('sugar', '五分', 2),
      ('sugar', '七分', 3),
      ('sugar', '全糖', 4),
      ('ice', '正常冰', 1),
      ('ice', '少冰', 2),
      ('ice', '不加冰块', 3),
      ('toppings', '黑糖珍珠', 1),
      ('toppings', '脆啵啵', 2),
    ];
    for (final option in options) {
      final groupKey = option.$1;
      final name = option.$2;
      final sortOrder = option.$3;
      final rows = await db.query(
        'option_items',
        columns: ['id'],
        where: 'group_key = ? AND name = ?',
        whereArgs: [groupKey, name],
        limit: 1,
      );
      if (rows.isEmpty) {
        await db.insert('option_items', {
          'group_key': groupKey,
          'name': name,
          'name_zh': name,
          'price': 0,
          'sort_order': sortOrder,
          'is_active': 1,
          'created_at': now,
        });
      } else {
        await db.update(
          'option_items',
          {'is_active': 1, 'sort_order': sortOrder},
          where: 'id = ?',
          whereArgs: [rows.first['id']],
        );
      }
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE order_items ADD COLUMN toppings TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        'ALTER TABLE order_items ADD COLUMN topping_total REAL NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS suspended_orders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ticket_no TEXT NOT NULL UNIQUE,
          label TEXT,
          payload_json TEXT NOT NULL,
          total REAL NOT NULL,
          item_count INTEGER NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS refunds (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          order_no TEXT NOT NULL,
          amount REAL NOT NULL,
          reason TEXT NOT NULL,
          manager_pin_tail TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute(
        "ALTER TABLE refunds ADD COLUMN refund_type TEXT NOT NULL DEFAULT 'full'",
      );
      await db.execute(
        "ALTER TABLE refunds ADD COLUMN operator_name TEXT NOT NULL DEFAULT 'cashier'",
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS refund_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          refund_id INTEGER NOT NULL,
          order_item_id INTEGER NOT NULL,
          quantity INTEGER NOT NULL,
          amount REAL NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY(refund_id) REFERENCES refunds(id)
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL
        )
      ''');
      final existing = await db.query('categories', limit: 1);
      if (existing.isEmpty) {
        final rows = await db.rawQuery(
          'SELECT DISTINCT category FROM products ORDER BY category ASC',
        );
        final now = DateTime.now().toIso8601String();
        for (final row in rows) {
          final name = (row['category'] as String?)?.trim() ?? '';
          if (name.isEmpty) continue;
          await db.insert('categories', {
            'name': name,
            'is_active': 1,
            'created_at': now,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE products ADD COLUMN name_th TEXT');
      await db.execute('ALTER TABLE products ADD COLUMN name_zh TEXT');
      await db.execute('ALTER TABLE products ADD COLUMN name_en TEXT');
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE products ADD COLUMN description TEXT');
      await db.execute('ALTER TABLE products ADD COLUMN image_url TEXT');
    }
    if (oldVersion < 8) {
      await db.execute(
        'ALTER TABLE products ADD COLUMN show_size INTEGER NOT NULL DEFAULT 1',
      );
      await db.execute(
        'ALTER TABLE products ADD COLUMN show_sugar INTEGER NOT NULL DEFAULT 1',
      );
      await db.execute(
        'ALTER TABLE products ADD COLUMN show_ice INTEGER NOT NULL DEFAULT 1',
      );
      await db.execute(
        'ALTER TABLE products ADD COLUMN show_toppings INTEGER NOT NULL DEFAULT 1',
      );
    }
    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS option_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          group_key TEXT NOT NULL,
          name TEXT NOT NULL,
          price REAL NOT NULL DEFAULT 0,
          sort_order INTEGER NOT NULL DEFAULT 0,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 10) {
      await db.execute(
        "ALTER TABLE orders ADD COLUMN pickup_no TEXT NOT NULL DEFAULT ''",
      );
      final rows = await db.query(
        'orders',
        columns: ['id', 'created_at'],
        orderBy: 'id ASC',
      );
      final daySeq = <String, int>{};
      for (final row in rows) {
        final id = row['id'] as int;
        final created = row['created_at'] as String;
        final dt = DateTime.tryParse(created) ?? DateTime.now();
        final key =
            '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        final seq = daySeq.update(key, (v) => v + 1, ifAbsent: () => 1);
        final pickupNo = 'A${seq.toString().padLeft(3, '0')}';
        await db.update(
          'orders',
          {'pickup_no': pickupNo},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
    if (oldVersion < 11) {
      await db.execute(
        "ALTER TABLE orders ADD COLUMN order_type TEXT NOT NULL DEFAULT 'inStore'",
      );
      await db.update(
        'orders',
        {'order_type': 'inStore'},
        where: 'order_type IS NULL OR TRIM(order_type) = ?',
        whereArgs: [''],
      );
    }
    if (oldVersion < 12) {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_type ON orders(order_type)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_refunds_order_no ON refunds(order_no)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_refund_items_order_item_id ON refund_items(order_item_id)',
      );
    }
    if (oldVersion < 13) {
      await db.execute(
        "ALTER TABLE orders ADD COLUMN order_channel TEXT NOT NULL DEFAULT ''",
      );
      await db.update('orders', {
        'order_channel': '',
      }, where: 'order_channel IS NULL');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_channel ON orders(order_channel)',
      );
    }
    if (oldVersion < 14) {
      await db.execute(
        "ALTER TABLE products ADD COLUMN promo_type TEXT NOT NULL DEFAULT 'none'",
      );
      await db.execute(
        'ALTER TABLE products ADD COLUMN promo_value REAL NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE products ADD COLUMN promo_active INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 15) {
      await db.execute('ALTER TABLE products ADD COLUMN delivery_price REAL');
    }
    if (oldVersion < 16) {
      await db.execute(
        'ALTER TABLE orders ADD COLUMN promo_amount REAL NOT NULL DEFAULT 0',
      );
      await db.execute(
        "ALTER TABLE orders ADD COLUMN promo_breakdown_json TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_promo_amount ON orders(promo_amount)',
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS promotion_rules (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          priority INTEGER NOT NULL DEFAULT 100,
          is_active INTEGER NOT NULL DEFAULT 1,
          apply_in_store INTEGER NOT NULL DEFAULT 1,
          apply_delivery INTEGER NOT NULL DEFAULT 0,
          start_at TEXT,
          end_at TEXT,
          condition_json TEXT NOT NULL,
          benefit_json TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_promotion_rules_active ON promotion_rules(is_active, priority)',
      );
    }
    if (oldVersion < 17) {
      await db.execute('ALTER TABLE option_items ADD COLUMN name_th TEXT');
      await db.execute('ALTER TABLE option_items ADD COLUMN name_zh TEXT');
      await db.execute('ALTER TABLE option_items ADD COLUMN name_en TEXT');
    }
    if (oldVersion < 18) {
      await db.execute('ALTER TABLE categories ADD COLUMN name_th TEXT');
      await db.execute('ALTER TABLE categories ADD COLUMN name_zh TEXT');
      await db.execute('ALTER TABLE categories ADD COLUMN name_en TEXT');
    }
    if (oldVersion < 19) {
      await db.execute(
        "ALTER TABLE orders ADD COLUMN platform_order_id TEXT NOT NULL DEFAULT ''",
      );
      await db.update('orders', {
        'platform_order_id': '',
      }, where: 'platform_order_id IS NULL');
    }
    if (oldVersion < 20) {
      await _seedInitialCatalogAndSpecOptions(db);
    }
    if (oldVersion < 21) {
      await db.execute(
        'ALTER TABLE order_items ADD COLUMN product_name_th TEXT',
      );
      await db.execute(
        'ALTER TABLE order_items ADD COLUMN product_name_zh TEXT',
      );
      await db.execute(
        'ALTER TABLE order_items ADD COLUMN product_name_en TEXT',
      );
    }
    if (oldVersion < 22) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          task_type TEXT NOT NULL,
          task_key TEXT NOT NULL UNIQUE,
          payload_json TEXT NOT NULL,
          attempt_count INTEGER NOT NULL DEFAULT 0,
          last_error TEXT,
          next_retry_at TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sync_queue_next_retry ON sync_queue(next_retry_at)',
      );
    }
  }
}
