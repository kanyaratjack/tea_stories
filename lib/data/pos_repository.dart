import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/cart_item.dart';
import '../models/checkout_result.dart';
import '../models/order_detail.dart';
import '../models/paid_order.dart';
import '../models/product_category.dart';
import '../models/product.dart';
import '../models/promotion_rule.dart';
import '../models/refundable_order_item.dart';
import '../models/sales_stats.dart';
import '../models/spec_option.dart';
import '../models/suspended_order.dart';
import 'local_db.dart';

class PosRepository {
  Database? _db;

  Future<void> init() async {
    if (kIsWeb) {
      throw UnsupportedError(
        '当前运行在 Web（Chrome），sqflite 不支持 Web。请改用 iOS/macOS 运行。',
      );
    }
    _db = await LocalDb.instance.database;
  }

  Database get db {
    final database = _db;
    if (database == null) {
      throw StateError('Database is not initialized.');
    }
    return database;
  }

  Future<void> seedProductsIfEmpty() async {
    await _seedSpecOptionsIfEmpty();
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM products');
    final count = (result.first['c'] as int?) ?? 0;
    if (count > 0) return;

    final now = DateTime.now().toIso8601String();
    final seeds = [
      ('经典珍珠奶茶', '奶茶', 16.0),
      ('芋泥波波奶茶', '奶茶', 20.0),
      ('四季春茶', '纯茶', 14.0),
      ('茉莉绿茶', '纯茶', 14.0),
      ('芝士莓莓', '果茶', 22.0),
      ('满杯橙橙', '果茶', 19.0),
      ('百香双响炮', '果茶', 21.0),
      ('黑糖波波鲜奶', '鲜奶', 24.0),
      ('椰果', '加料', 2.0),
      ('珍珠', '加料', 2.0),
      ('布丁', '加料', 3.0),
      ('仙草', '加料', 3.0),
    ];

    final batch = db.batch();
    final categorySet = <String>{};
    for (final seed in seeds) {
      categorySet.add(seed.$2);
      batch.insert('products', {
        'name': seed.$1,
        'category': seed.$2,
        'price': seed.$3,
        'is_active': 1,
        'created_at': now,
      });
    }
    final nowForCategories = DateTime.now().toIso8601String();
    for (final category in categorySet) {
      batch.insert('categories', {
        'name': category,
        'is_active': 1,
        'created_at': nowForCategories,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Product>> fetchProducts() async {
    final rows = await db.query(
      'products',
      where: 'is_active = 1',
      orderBy: 'category ASC, id ASC',
    );
    return rows.map(Product.fromMap).toList(growable: false);
  }

  Future<List<SpecOption>> fetchSpecOptions({
    String? groupKey,
    bool includeInactive = false,
  }) async {
    final whereParts = <String>[];
    final whereArgs = <Object?>[];
    if (groupKey != null && groupKey.trim().isNotEmpty) {
      whereParts.add('group_key = ?');
      whereArgs.add(groupKey.trim());
    }
    if (!includeInactive) {
      whereParts.add('is_active = 1');
    }
    final rows = await db.query(
      'option_items',
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'group_key ASC, sort_order ASC, id ASC',
    );
    return rows.map(SpecOption.fromMap).toList(growable: false);
  }

  Future<void> createSpecOption({
    required String groupKey,
    required String name,
    String? nameTh,
    String? nameZh,
    String? nameEn,
    double price = 0,
  }) async {
    final group = groupKey.trim();
    final label = name.trim();
    if (!SpecGroupKey.values.contains(group)) {
      throw StateError('Invalid spec group.');
    }
    if (label.isEmpty) {
      throw StateError('Spec option name is required.');
    }
    final duplicated = await db.query(
      'option_items',
      columns: ['id'],
      where: 'group_key = ? AND LOWER(TRIM(name)) = LOWER(TRIM(?))',
      whereArgs: [group, label],
      limit: 1,
    );
    if (duplicated.isNotEmpty) {
      throw StateError('Duplicate spec option name in this group.');
    }
    final sortRows = await db.rawQuery(
      'SELECT COALESCE(MAX(sort_order), -1) AS max_order FROM option_items WHERE group_key = ?',
      [group],
    );
    final maxOrder = (sortRows.first['max_order'] as num?)?.toInt() ?? -1;
    final now = DateTime.now().toIso8601String();
    await db.insert('option_items', {
      'group_key': group,
      'name': label,
      'name_th': _normalizeNullable(nameTh),
      'name_zh': _normalizeNullable(nameZh),
      'name_en': _normalizeNullable(nameEn),
      'price': price,
      'sort_order': maxOrder + 1,
      'is_active': 1,
      'created_at': now,
    });
  }

  Future<void> updateSpecOption({
    required int id,
    required String name,
    String? nameTh,
    String? nameZh,
    String? nameEn,
    double price = 0,
  }) async {
    final label = name.trim();
    if (label.isEmpty) {
      throw StateError('Spec option name is required.');
    }
    final rows = await db.query(
      'option_items',
      columns: ['id', 'group_key'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Spec option not found.');
    }
    final groupKey = rows.first['group_key'] as String;
    final duplicated = await db.query(
      'option_items',
      columns: ['id'],
      where: 'group_key = ? AND LOWER(TRIM(name)) = LOWER(TRIM(?)) AND id != ?',
      whereArgs: [groupKey, label, id],
      limit: 1,
    );
    if (duplicated.isNotEmpty) {
      throw StateError('Duplicate spec option name in this group.');
    }
    await db.update(
      'option_items',
      {
        'name': label,
        'name_th': _normalizeNullable(nameTh),
        'name_zh': _normalizeNullable(nameZh),
        'name_en': _normalizeNullable(nameEn),
        'price': price,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setSpecOptionActive(int id, bool isActive) async {
    await db.update(
      'option_items',
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteSpecOption(int id) async {
    await db.transaction((txn) async {
      final rows = await txn.query(
        'option_items',
        columns: ['id', 'group_key', 'name', 'name_th', 'name_zh', 'name_en'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Spec option not found.');
      }
      final row = rows.first;
      final groupKey = (row['group_key'] as String?)?.trim() ?? '';
      final labels = <String>{
        (row['name'] as String?)?.trim() ?? '',
        (row['name_th'] as String?)?.trim() ?? '',
        (row['name_zh'] as String?)?.trim() ?? '',
        (row['name_en'] as String?)?.trim() ?? '',
      }..removeWhere((e) => e.isEmpty);

      for (final label in labels) {
        int refs = 0;
        if (groupKey == SpecGroupKey.size) {
          final result = await txn.rawQuery(
            'SELECT COUNT(*) AS c FROM order_items WHERE TRIM(size) = ?',
            [label],
          );
          refs = (result.first['c'] as num?)?.toInt() ?? 0;
        } else if (groupKey == SpecGroupKey.sugar) {
          final result = await txn.rawQuery(
            'SELECT COUNT(*) AS c FROM order_items WHERE TRIM(sugar) = ?',
            [label],
          );
          refs = (result.first['c'] as num?)?.toInt() ?? 0;
        } else if (groupKey == SpecGroupKey.ice) {
          final result = await txn.rawQuery(
            'SELECT COUNT(*) AS c FROM order_items WHERE TRIM(ice) = ?',
            [label],
          );
          refs = (result.first['c'] as num?)?.toInt() ?? 0;
        } else if (groupKey == SpecGroupKey.toppings) {
          final result = await txn.rawQuery(
            'SELECT COUNT(*) AS c FROM order_items WHERE toppings LIKE ?',
            ['%$label%'],
          );
          refs = (result.first['c'] as num?)?.toInt() ?? 0;
        }
        if (refs > 0) {
          throw StateError('This spec option is used in historical orders.');
        }

        final suspended = await txn.rawQuery(
          'SELECT COUNT(*) AS c FROM suspended_orders WHERE payload_json LIKE ?',
          ['%$label%'],
        );
        final suspendedRefs = (suspended.first['c'] as num?)?.toInt() ?? 0;
        if (suspendedRefs > 0) {
          throw StateError('This spec option is used by suspended orders.');
        }
      }

      await txn.delete('option_items', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<Product>> fetchAllProducts() async {
    final rows = await db.query('products', orderBy: 'category ASC, id ASC');
    return rows.map(Product.fromMap).toList(growable: false);
  }

  Future<void> createProduct({
    required String name,
    required String category,
    required double price,
    double? deliveryPrice,
    String promoType = 'none',
    double promoValue = 0,
    bool promoActive = false,
    String? nameTh,
    String? nameZh,
    String? nameEn,
    String? description,
    String? imageUrl,
    bool showSize = true,
    bool showSugar = true,
    bool showIce = true,
    bool showToppings = true,
  }) async {
    await _ensureCategoryExists(category.trim());
    final now = DateTime.now().toIso8601String();
    await db.insert('products', {
      'name': name.trim(),
      'name_th': _normalizeNullable(nameTh),
      'name_zh': _normalizeNullable(nameZh),
      'name_en': _normalizeNullable(nameEn),
      'description': _normalizeNullable(description),
      'image_url': _normalizeNullable(imageUrl),
      'show_size': showSize ? 1 : 0,
      'show_sugar': showSugar ? 1 : 0,
      'show_ice': showIce ? 1 : 0,
      'show_toppings': showToppings ? 1 : 0,
      'category': category.trim(),
      'price': price,
      'delivery_price': deliveryPrice,
      'promo_type': promoType,
      'promo_value': promoValue,
      'promo_active': promoActive ? 1 : 0,
      'is_active': 1,
      'created_at': now,
    });
  }

  Future<void> updateProduct({
    required int id,
    required String name,
    required String category,
    required double price,
    double? deliveryPrice,
    String promoType = 'none',
    double promoValue = 0,
    bool promoActive = false,
    String? nameTh,
    String? nameZh,
    String? nameEn,
    String? description,
    String? imageUrl,
    bool showSize = true,
    bool showSugar = true,
    bool showIce = true,
    bool showToppings = true,
  }) async {
    await _ensureCategoryExists(category.trim());
    await db.update(
      'products',
      {
        'name': name.trim(),
        'name_th': _normalizeNullable(nameTh),
        'name_zh': _normalizeNullable(nameZh),
        'name_en': _normalizeNullable(nameEn),
        'description': _normalizeNullable(description),
        'image_url': _normalizeNullable(imageUrl),
        'show_size': showSize ? 1 : 0,
        'show_sugar': showSugar ? 1 : 0,
        'show_ice': showIce ? 1 : 0,
        'show_toppings': showToppings ? 1 : 0,
        'category': category.trim(),
        'price': price,
        'delivery_price': deliveryPrice,
        'promo_type': promoType,
        'promo_value': promoValue,
        'promo_active': promoActive ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setProductActive(int id, bool isActive) async {
    await db.update(
      'products',
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteProduct(int id) async {
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ProductCategory>> fetchCategories({
    bool includeInactive = false,
  }) async {
    final where = includeInactive ? '' : 'WHERE c.is_active = 1';
    final rows = await db.rawQuery('''
      SELECT
        c.id,
        c.name,
        c.name_th,
        c.name_zh,
        c.name_en,
        c.is_active,
        COUNT(p.id) AS product_count
      FROM categories c
      LEFT JOIN products p ON p.category = c.name
      $where
      GROUP BY c.id, c.name, c.name_th, c.name_zh, c.name_en, c.is_active
      ORDER BY c.name ASC
      ''');
    return rows
        .map(
          (row) => ProductCategory.fromMap({
            'id': row['id'] as int,
            'name': row['name'] as String,
            'name_th': row['name_th'] as String?,
            'name_zh': row['name_zh'] as String?,
            'name_en': row['name_en'] as String?,
            'is_active': row['is_active'] as int,
            'product_count': (row['product_count'] as num).toInt(),
          }),
        )
        .toList(growable: false);
  }

  Future<void> createCategory(
    String name, {
    String? nameTh,
    String? nameZh,
    String? nameEn,
  }) async {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw StateError('Category name is required.');
    }
    final now = DateTime.now().toIso8601String();
    await db.insert('categories', {
      'name': normalized,
      'name_th': _normalizeNullable(nameTh),
      'name_zh': _normalizeNullable(nameZh),
      'name_en': _normalizeNullable(nameEn),
      'is_active': 1,
      'created_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<void> renameCategory({
    required int id,
    required String newName,
    String? nameTh,
    String? nameZh,
    String? nameEn,
  }) async {
    final normalized = newName.trim();
    if (normalized.isEmpty) {
      throw StateError('Category name is required.');
    }
    await db.transaction((txn) async {
      final rows = await txn.query(
        'categories',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Category not found.');
      }
      final oldName = rows.first['name'] as String;
      await txn.update(
        'categories',
        {
          'name': normalized,
          'name_th': _normalizeNullable(nameTh),
          'name_zh': _normalizeNullable(nameZh),
          'name_en': _normalizeNullable(nameEn),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.update(
        'products',
        {'category': normalized},
        where: 'category = ?',
        whereArgs: [oldName],
      );
    });
  }

  Future<void> setCategoryActive(int id, bool isActive) async {
    await db.update(
      'categories',
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteCategory(int id) async {
    await db.transaction((txn) async {
      final rows = await txn.query(
        'categories',
        columns: ['id', 'name'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Category not found.');
      }
      final categoryName = (rows.first['name'] as String?)?.trim() ?? '';
      if (categoryName.isEmpty) {
        throw StateError('Category not found.');
      }
      final refs = await txn.rawQuery(
        'SELECT COUNT(*) AS c FROM products WHERE TRIM(category) = ?',
        [categoryName],
      );
      final productCount = (refs.first['c'] as num?)?.toInt() ?? 0;
      if (productCount > 0) {
        throw StateError('This category still has products.');
      }
      await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<CheckoutResult> createOrder({
    required List<CartItem> items,
    required double subtotal,
    required double discount,
    required double total,
    required double promoAmount,
    required String promoBreakdownJson,
    required String paymentMethod,
    required String orderType,
    required String orderChannel,
    required String platformOrderId,
    double? receivedAmount,
    double? changeAmount,
  }) async {
    if (items.isEmpty) {
      throw StateError('Cannot create order with empty items.');
    }
    await _ensurePlatformOrderIdColumn();

    final now = DateTime.now();
    final orderNo = _buildOrderNo(
      now,
      orderType: orderType,
      orderChannel: orderChannel,
    );

    await db.transaction((txn) async {
      final dayStart = DateTime(now.year, now.month, now.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      final seqRows = await txn.rawQuery(
        '''
        SELECT COUNT(*) AS c
        FROM orders
        WHERE created_at >= ? AND created_at < ?
        ''',
        [dayStart.toIso8601String(), dayEnd.toIso8601String()],
      );
      final seq = ((seqRows.first['c'] as num?)?.toInt() ?? 0) + 1;
      final pickupNo = _buildPickupNo(seq);
      final orderId = await txn.insert('orders', {
        'order_no': orderNo,
        'pickup_no': pickupNo,
        'subtotal': subtotal,
        'discount': discount,
        'total': total,
        'promo_amount': promoAmount,
        'promo_breakdown_json': promoBreakdownJson,
        'payment_method': paymentMethod,
        'order_type': orderType,
        'order_channel': orderChannel,
        'platform_order_id': platformOrderId,
        'status': 'paid',
        'created_at': now.toIso8601String(),
      });

      final itemBatch = txn.batch();
      for (final item in items) {
        itemBatch.insert('order_items', {
          'order_id': orderId,
          'product_id': item.product.id,
          'product_name': item.product.name,
          'product_name_th': item.product.nameTh,
          'product_name_zh': item.product.nameZh,
          'product_name_en': item.product.nameEn,
          'category': item.product.category,
          'base_price': item.product.effectivePrice,
          'unit_price': item.unitPrice,
          'quantity': item.quantity,
          'size': item.sizeName,
          'sugar': item.sugarName,
          'ice': item.iceName,
          'toppings': item.toppings.map((e) => e.name).join(','),
          'topping_total': item.toppingTotal,
          'note': item.note,
          'line_total': item.subtotal,
        });
      }
      await itemBatch.commit(noResult: true);

      await txn.insert('payments', {
        'order_id': orderId,
        'method': paymentMethod,
        'amount': total,
        'received_amount': receivedAmount,
        'change_amount': changeAmount,
        'created_at': now.toIso8601String(),
      });
    });

    final row = await db.query(
      'orders',
      columns: [
        'order_no',
        'pickup_no',
        'order_type',
        'order_channel',
        'platform_order_id',
      ],
      where: 'order_no = ?',
      whereArgs: [orderNo],
      limit: 1,
    );
    final pickupNo = row.isNotEmpty ? (row.first['pickup_no'] as String) : '';
    final orderTypeCode = row.isNotEmpty
        ? ((row.first['order_type'] as String?) ?? 'inStore')
        : 'inStore';
    final orderChannelCode = row.isNotEmpty
        ? ((row.first['order_channel'] as String?) ?? '')
        : '';
    final platformOrderIdCode = row.isNotEmpty
        ? ((row.first['platform_order_id'] as String?) ?? '')
        : '';
    return CheckoutResult(
      orderNo: orderNo,
      pickupNo: pickupNo,
      orderType: orderTypeCode,
      orderChannel: orderChannelCode,
      platformOrderId: platformOrderIdCode,
    );
  }

  Future<void> _ensurePlatformOrderIdColumn() async {
    final rows = await db.rawQuery("PRAGMA table_info('orders')");
    final hasColumn = rows.any(
      (row) => (row['name'] as String?) == 'platform_order_id',
    );
    if (hasColumn) return;
    await db.execute(
      "ALTER TABLE orders ADD COLUMN platform_order_id TEXT NOT NULL DEFAULT ''",
    );
    await db.update('orders', {
      'platform_order_id': '',
    }, where: 'platform_order_id IS NULL');
  }

  Future<List<PromotionRule>> fetchPromotionRules({
    bool includeInactive = true,
  }) async {
    final rows = await db.query(
      'promotion_rules',
      where: includeInactive ? null : 'is_active = 1',
      orderBy: 'priority ASC, id DESC',
    );
    return rows.map(PromotionRule.fromMap).toList(growable: false);
  }

  Future<void> createPromotionRule({
    required String name,
    required PromotionType type,
    required int priority,
    required bool isActive,
    required bool applyInStore,
    required bool applyDelivery,
    required Map<String, dynamic> condition,
    required Map<String, dynamic> benefit,
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    final now = DateTime.now().toIso8601String();
    await db.insert('promotion_rules', {
      'name': name.trim(),
      'type': type.code,
      'priority': priority,
      'is_active': isActive ? 1 : 0,
      'apply_in_store': applyInStore ? 1 : 0,
      'apply_delivery': applyDelivery ? 1 : 0,
      'start_at': startAt?.toIso8601String(),
      'end_at': endAt?.toIso8601String(),
      'condition_json': jsonEncode(condition),
      'benefit_json': jsonEncode(benefit),
      'created_at': now,
    });
  }

  Future<void> updatePromotionRule({
    required int id,
    required String name,
    required PromotionType type,
    required int priority,
    required bool isActive,
    required bool applyInStore,
    required bool applyDelivery,
    required Map<String, dynamic> condition,
    required Map<String, dynamic> benefit,
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    await db.update(
      'promotion_rules',
      {
        'name': name.trim(),
        'type': type.code,
        'priority': priority,
        'is_active': isActive ? 1 : 0,
        'apply_in_store': applyInStore ? 1 : 0,
        'apply_delivery': applyDelivery ? 1 : 0,
        'start_at': startAt?.toIso8601String(),
        'end_at': endAt?.toIso8601String(),
        'condition_json': jsonEncode(condition),
        'benefit_json': jsonEncode(benefit),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setPromotionRuleActive(int id, bool isActive) async {
    await db.update(
      'promotion_rules',
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deletePromotionRule(int id) async {
    await db.delete('promotion_rules', where: 'id = ?', whereArgs: [id]);
  }

  Future<String> suspendCart({
    required List<CartItem> items,
    required double total,
    String? label,
  }) async {
    await _ensureOpsTables();
    if (items.isEmpty) {
      throw StateError('Cannot suspend empty cart.');
    }
    final now = DateTime.now();
    final ticketNo = _buildSuspendNo(now);
    final payload = jsonEncode({
      'items': items
          .map(
            (item) => {
              'product_id': item.product.id,
              'product_name': item.product.name,
              'category': item.product.category,
              'price': item.product.effectivePrice,
              'quantity': item.quantity,
              'size_name': item.sizeName,
              'size_extra': item.sizeExtraPrice,
              'sugar_name': item.sugarName,
              'ice_name': item.iceName,
              'toppings': item.toppings
                  .map((t) => {'id': t.id, 'name': t.name, 'price': t.price})
                  .toList(growable: false),
              'note': item.note,
            },
          )
          .toList(growable: false),
    });

    await db.insert('suspended_orders', {
      'ticket_no': ticketNo,
      'label': (label == null || label.trim().isEmpty) ? null : label.trim(),
      'payload_json': payload,
      'total': total,
      'item_count': items.length,
      'created_at': now.toIso8601String(),
    });

    return ticketNo;
  }

  Future<List<SuspendedOrder>> fetchSuspendedOrders() async {
    await _ensureOpsTables();
    final rows = await db.query('suspended_orders', orderBy: 'id DESC');
    return rows.map(SuspendedOrder.fromMap).toList(growable: false);
  }

  Future<List<CartItem>> restoreSuspendedOrder(int id) async {
    await _ensureOpsTables();
    final rows = await db.query(
      'suspended_orders',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Suspended order not found.');

    final payload =
        jsonDecode(rows.first['payload_json'] as String)
            as Map<String, dynamic>;
    final rawItems = (payload['items'] as List<dynamic>?) ?? [];

    return rawItems
        .map((raw) {
          final item = raw as Map<String, dynamic>;
          final toppingRaw = (item['toppings'] as List<dynamic>? ?? []);
          final toppings = toppingRaw
              .map(
                (t) => ToppingSelection(
                  id: t['id'] as int,
                  name: t['name'] as String,
                  price: (t['price'] as num).toDouble(),
                ),
              )
              .toList(growable: false);

          return CartItem(
            product: Product(
              id: item['product_id'] as int,
              name: item['product_name'] as String,
              category: item['category'] as String,
              price: (item['price'] as num).toDouble(),
            ),
            quantity: item['quantity'] as int,
            sizeName:
                (item['size_name'] as String?) ??
                _legacySizeLabel(item['size'] as String?),
            sizeExtraPrice:
                (item['size_extra'] as num?)?.toDouble() ??
                _legacySizeExtra(item['size'] as String?),
            sugarName:
                (item['sugar_name'] as String?) ??
                _legacySugarLabel(item['sugar'] as String?),
            iceName:
                (item['ice_name'] as String?) ??
                _legacyIceLabel(item['ice'] as String?),
            toppings: toppings,
            note: item['note'] as String? ?? '',
          );
        })
        .toList(growable: false);
  }

  Future<void> deleteSuspendedOrder(int id) async {
    await _ensureOpsTables();
    await db.delete('suspended_orders', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteOrderByNo(String orderNo) async {
    final no = orderNo.trim();
    if (no.isEmpty) return;
    await _ensureOpsTables();
    await db.transaction((txn) async {
      final orderRows = await txn.query(
        'orders',
        columns: ['id'],
        where: 'order_no = ?',
        whereArgs: [no],
        limit: 1,
      );
      if (orderRows.isEmpty) return;
      final orderId = orderRows.first['id'] as int;

      await txn.rawDelete(
        '''
        DELETE FROM refund_items
        WHERE refund_id IN (
          SELECT id FROM refunds WHERE order_no = ?
        )
        ''',
        [no],
      );
      await txn.delete('refunds', where: 'order_no = ?', whereArgs: [no]);
      await txn.delete('payments', where: 'order_id = ?', whereArgs: [orderId]);
      await txn.delete(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [orderId],
      );
      await txn.delete('orders', where: 'id = ?', whereArgs: [orderId]);
    });
  }

  Future<void> clearOrderData() async {
    await _ensureOpsTables();
    await db.transaction((txn) async {
      await txn.delete('refund_items');
      await txn.delete('refunds');
      await txn.delete('payments');
      await txn.delete('order_items');
      await txn.delete('orders');
      await txn.delete('suspended_orders');
      await txn.execute('''
        DELETE FROM sqlite_sequence
        WHERE name IN ('orders', 'order_items', 'payments', 'refunds', 'refund_items', 'suspended_orders')
        ''');
    });
  }

  Future<List<PaidOrder>> fetchRecentPaidOrders({int limit = 20}) async {
    final rows = await db.rawQuery(
      '''
      SELECT
        o.order_no,
        o.pickup_no,
        o.total,
        o.order_type,
        o.order_channel,
        o.platform_order_id,
        o.created_at,
        o.status,
        COALESCE(SUM(r.amount), 0) AS refunded_amount
      FROM orders o
      LEFT JOIN refunds r ON r.order_no = o.order_no
      WHERE o.status IN (?, ?, ?)
      GROUP BY
        o.id,
        o.order_no,
        o.pickup_no,
        o.total,
        o.order_type,
        o.order_channel,
        o.platform_order_id,
        o.created_at,
        o.status
      ORDER BY o.id DESC
      LIMIT ?
      ''',
      ['paid', 'partially_refunded', 'refunded', limit],
    );
    return rows.map(PaidOrder.fromMap).toList(growable: false);
  }

  Future<int> countRecentPaidOrders() async {
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS c
      FROM orders
      WHERE status IN (?, ?, ?)
      ''',
      ['paid', 'partially_refunded', 'refunded'],
    );
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<List<DailyRevenueStat>> fetchDailyRevenueStats({
    required int days,
  }) async {
    final allTime = days <= 0;
    final today = DateTime.now();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: (days <= 0 ? 1 : days) - 1));
    final end = DateTime(
      today.year,
      today.month,
      today.day,
    ).add(const Duration(days: 1));

    final rows = await db.rawQuery(
      '''
      SELECT
        t.day,
        SUM(t.gross_amount) AS gross_amount,
        SUM(t.promo_amount) AS promo_amount,
        SUM(t.refunded_amount) AS refunded_amount,
        SUM(t.net_amount) AS net_amount,
        COUNT(*) AS order_count
      FROM (
        SELECT
          substr(o.created_at, 1, 10) AS day,
          o.total AS gross_amount,
          COALESCE(o.promo_amount, 0) AS promo_amount,
          COALESCE(r.refunded_amount, 0) AS refunded_amount,
          MAX(o.total - COALESCE(r.refunded_amount, 0), 0) AS net_amount
        FROM orders o
        LEFT JOIN (
          SELECT order_no, SUM(amount) AS refunded_amount
          FROM refunds
          GROUP BY order_no
        ) r ON r.order_no = o.order_no
        WHERE o.status IN (?, ?, ?)
          ${allTime ? '' : 'AND o.created_at >= ? AND o.created_at < ?'}
      ) t
      GROUP BY t.day
      ORDER BY t.day DESC
      ''',
      [
        'paid',
        'partially_refunded',
        'refunded',
        if (!allTime) start.toIso8601String(),
        if (!allTime) end.toIso8601String(),
      ],
    );
    return rows.map(DailyRevenueStat.fromMap).toList(growable: false);
  }

  Future<List<ProductSalesStat>> fetchTopProductSalesStats({
    required int days,
    int limit = 10,
  }) async {
    final allTime = days <= 0;
    final today = DateTime.now();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: (days <= 0 ? 1 : days) - 1));
    final end = DateTime(
      today.year,
      today.month,
      today.day,
    ).add(const Duration(days: 1));

    final rows = await db.rawQuery(
      '''
      SELECT
        p.product_name,
        SUM(p.qty) AS gross_qty,
        SUM(p.refunded_qty) AS refunded_qty,
        SUM(MAX(p.qty - p.refunded_qty, 0)) AS net_qty,
        SUM(p.line_total) AS gross_amount,
        SUM((p.unit_price * p.refunded_qty)) AS refunded_amount,
        SUM(MAX(p.line_total - (p.unit_price * p.refunded_qty), 0)) AS net_amount
      FROM (
        SELECT
          oi.id AS order_item_id,
          oi.product_name,
          oi.quantity AS qty,
          oi.line_total,
          CASE
            WHEN oi.quantity > 0 THEN oi.line_total / oi.quantity
            ELSE 0
          END AS unit_price,
          COALESCE(SUM(ri.quantity), 0) AS refunded_qty
        FROM order_items oi
        JOIN orders o ON o.id = oi.order_id
        LEFT JOIN refund_items ri ON ri.order_item_id = oi.id
        WHERE o.status IN (?, ?, ?)
          ${allTime ? '' : 'AND o.created_at >= ? AND o.created_at < ?'}
        GROUP BY oi.id, oi.product_name, oi.quantity, oi.line_total
      ) p
      GROUP BY p.product_name
      ORDER BY net_qty DESC, net_amount DESC
      LIMIT ?
      ''',
      [
        'paid',
        'partially_refunded',
        'refunded',
        if (!allTime) start.toIso8601String(),
        if (!allTime) end.toIso8601String(),
        limit,
      ],
    );
    return rows.map(ProductSalesStat.fromMap).toList(growable: false);
  }

  Future<List<PaymentMethodStat>> fetchPaymentMethodStats({
    required int days,
  }) async {
    final allTime = days <= 0;
    final today = DateTime.now();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: (days <= 0 ? 1 : days) - 1));
    final end = DateTime(
      today.year,
      today.month,
      today.day,
    ).add(const Duration(days: 1));

    final rows = await db.rawQuery(
      '''
      SELECT
        t.payment_method,
        COUNT(*) AS order_count,
        SUM(t.gross_amount) AS gross_amount,
        SUM(t.refunded_amount) AS refunded_amount,
        SUM(t.net_amount) AS net_amount
      FROM (
        SELECT
          o.order_no,
          o.payment_method,
          o.total AS gross_amount,
          COALESCE(r.refunded_amount, 0) AS refunded_amount,
          MAX(o.total - COALESCE(r.refunded_amount, 0), 0) AS net_amount
        FROM orders o
        LEFT JOIN (
          SELECT order_no, SUM(amount) AS refunded_amount
          FROM refunds
          GROUP BY order_no
        ) r ON r.order_no = o.order_no
        WHERE o.status IN (?, ?, ?)
          ${allTime ? '' : 'AND o.created_at >= ? AND o.created_at < ?'}
      ) t
      GROUP BY t.payment_method
      ORDER BY net_amount DESC, order_count DESC
      ''',
      [
        'paid',
        'partially_refunded',
        'refunded',
        if (!allTime) start.toIso8601String(),
        if (!allTime) end.toIso8601String(),
      ],
    );
    return rows.map(PaymentMethodStat.fromMap).toList(growable: false);
  }

  Future<List<OrderTypeStat>> fetchOrderTypeStats({required int days}) async {
    final allTime = days <= 0;
    final today = DateTime.now();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: (days <= 0 ? 1 : days) - 1));
    final end = DateTime(
      today.year,
      today.month,
      today.day,
    ).add(const Duration(days: 1));

    final rows = await db.rawQuery(
      '''
      SELECT
        t.order_type,
        COUNT(*) AS order_count,
        SUM(t.gross_amount) AS gross_amount,
        SUM(t.refunded_amount) AS refunded_amount,
        SUM(t.net_amount) AS net_amount
      FROM (
        SELECT
          o.order_no,
          o.order_type,
          o.total AS gross_amount,
          COALESCE(r.refunded_amount, 0) AS refunded_amount,
          MAX(o.total - COALESCE(r.refunded_amount, 0), 0) AS net_amount
        FROM orders o
        LEFT JOIN (
          SELECT order_no, SUM(amount) AS refunded_amount
          FROM refunds
          GROUP BY order_no
        ) r ON r.order_no = o.order_no
        WHERE o.status IN (?, ?, ?)
          ${allTime ? '' : 'AND o.created_at >= ? AND o.created_at < ?'}
      ) t
      GROUP BY t.order_type
      ORDER BY net_amount DESC, order_count DESC
      ''',
      [
        'paid',
        'partially_refunded',
        'refunded',
        if (!allTime) start.toIso8601String(),
        if (!allTime) end.toIso8601String(),
      ],
    );
    return rows.map(OrderTypeStat.fromMap).toList(growable: false);
  }

  Future<List<DeliveryChannelStat>> fetchDeliveryChannelStats({
    required int days,
  }) async {
    final allTime = days <= 0;
    final today = DateTime.now();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: (days <= 0 ? 1 : days) - 1));
    final end = DateTime(
      today.year,
      today.month,
      today.day,
    ).add(const Duration(days: 1));

    final rows = await db.rawQuery(
      '''
      SELECT
        t.order_channel,
        COUNT(*) AS order_count,
        SUM(t.net_amount) AS net_amount
      FROM (
        SELECT
          o.order_no,
          o.order_channel,
          MAX(o.total - COALESCE(r.refunded_amount, 0), 0) AS net_amount
        FROM orders o
        LEFT JOIN (
          SELECT order_no, SUM(amount) AS refunded_amount
          FROM refunds
          GROUP BY order_no
        ) r ON r.order_no = o.order_no
        WHERE o.order_type = 'delivery'
          AND o.status IN (?, ?, ?)
          AND TRIM(COALESCE(o.order_channel, '')) != ''
          ${allTime ? '' : 'AND o.created_at >= ? AND o.created_at < ?'}
      ) t
      GROUP BY t.order_channel
      ORDER BY net_amount DESC, order_count DESC
      ''',
      [
        'paid',
        'partially_refunded',
        'refunded',
        if (!allTime) start.toIso8601String(),
        if (!allTime) end.toIso8601String(),
      ],
    );
    return rows.map(DeliveryChannelStat.fromMap).toList(growable: false);
  }

  Future<List<HourlyRevenueStat>> fetchTodayHourlyRevenueStats() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final rows = await db.rawQuery(
      '''
      SELECT
        CAST(substr(t.created_at, 12, 2) AS INTEGER) AS hour,
        COUNT(*) AS order_count,
        SUM(t.net_amount) AS net_amount
      FROM (
        SELECT
          o.order_no,
          o.created_at,
          MAX(o.total - COALESCE(r.refunded_amount, 0), 0) AS net_amount
        FROM orders o
        LEFT JOIN (
          SELECT order_no, SUM(amount) AS refunded_amount
          FROM refunds
          GROUP BY order_no
        ) r ON r.order_no = o.order_no
        WHERE o.status IN (?, ?, ?)
          AND o.created_at >= ? AND o.created_at < ?
      ) t
      GROUP BY hour
      ORDER BY hour ASC
      ''',
      [
        'paid',
        'partially_refunded',
        'refunded',
        start.toIso8601String(),
        end.toIso8601String(),
      ],
    );
    return rows.map(HourlyRevenueStat.fromMap).toList(growable: false);
  }

  Future<OrderDetail> fetchOrderDetail(String orderNo) async {
    final orderRows = await db.query(
      'orders',
      where: 'order_no = ?',
      whereArgs: [orderNo],
      limit: 1,
    );
    if (orderRows.isEmpty) {
      throw StateError('Order not found.');
    }
    final order = orderRows.first;
    final orderId = order['id'] as int;

    final paymentRows = await db.query(
      'payments',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'id DESC',
      limit: 1,
    );
    final payment = paymentRows.isEmpty ? null : paymentRows.first;

    final itemRows = await db.rawQuery(
      '''
      SELECT
        oi.id,
        oi.product_name,
        oi.product_name_th,
        oi.product_name_zh,
        oi.product_name_en,
        oi.quantity,
        oi.unit_price,
        oi.line_total,
        oi.size,
        oi.sugar,
        oi.ice,
        oi.toppings,
        oi.note,
        COALESCE(SUM(ri.quantity), 0) AS refunded_qty
      FROM order_items oi
      LEFT JOIN refund_items ri ON ri.order_item_id = oi.id
      WHERE oi.order_id = ?
      GROUP BY
        oi.id,
        oi.product_name,
        oi.product_name_th,
        oi.product_name_zh,
        oi.product_name_en,
        oi.quantity,
        oi.unit_price,
        oi.line_total,
        oi.size,
        oi.sugar,
        oi.ice,
        oi.toppings,
        oi.note
      ORDER BY oi.id ASC
      ''',
      [orderId],
    );

    final items = itemRows
        .map(
          (row) => OrderDetailItem(
            productName: row['product_name'] as String,
            productNameTh: row['product_name_th'] as String?,
            productNameZh: row['product_name_zh'] as String?,
            productNameEn: row['product_name_en'] as String?,
            quantity: row['quantity'] as int,
            refundedQuantity: (row['refunded_qty'] as num?)?.toInt() ?? 0,
            unitPrice: (row['unit_price'] as num).toDouble(),
            lineTotal: (row['line_total'] as num).toDouble(),
            size: row['size'] as String,
            sugar: row['sugar'] as String,
            ice: row['ice'] as String,
            toppings: (row['toppings'] as String?) ?? '',
            note: (row['note'] as String?) ?? '',
          ),
        )
        .toList(growable: false);

    final refundRows = await db.query(
      'refunds',
      where: 'order_no = ?',
      whereArgs: [orderNo],
      orderBy: 'id DESC',
    );
    final refundRecords = refundRows
        .map(
          (row) => RefundRecord(
            amount: (row['amount'] as num).toDouble(),
            refundType: (row['refund_type'] as String?) ?? 'partial',
            reason: (row['reason'] as String?) ?? '',
            operatorName: (row['operator_name'] as String?) ?? 'cashier',
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList(growable: false);

    return OrderDetail(
      orderNo: order['order_no'] as String,
      pickupNo: (order['pickup_no'] as String?) ?? '',
      orderType: (order['order_type'] as String?) ?? 'inStore',
      orderChannel: (order['order_channel'] as String?) ?? '',
      platformOrderId: (order['platform_order_id'] as String?) ?? '',
      subtotal: (order['subtotal'] as num).toDouble(),
      promoAmount: (order['promo_amount'] as num?)?.toDouble() ?? 0,
      discount: (order['discount'] as num).toDouble(),
      total: (order['total'] as num).toDouble(),
      status: order['status'] as String,
      createdAt: DateTime.parse(order['created_at'] as String),
      paymentMethod: (payment?['method'] as String?) ?? '',
      cashReceived: (payment?['received_amount'] as num?)?.toDouble(),
      changeAmount: (payment?['change_amount'] as num?)?.toDouble(),
      items: items,
      refundRecords: refundRecords,
    );
  }

  Future<List<RefundableOrderItem>> fetchRefundableOrderItems(
    String orderNo,
  ) async {
    await _ensureOpsTables();
    final rows = await db.rawQuery(
      '''
      SELECT
        oi.id AS order_item_id,
        oi.product_name,
        oi.quantity,
        oi.unit_price,
        COALESCE(SUM(ri.quantity), 0) AS refunded_qty
      FROM order_items oi
      JOIN orders o ON o.id = oi.order_id
      LEFT JOIN refund_items ri ON ri.order_item_id = oi.id
      WHERE o.order_no = ?
      GROUP BY oi.id, oi.product_name, oi.quantity, oi.unit_price
      ORDER BY oi.id ASC
      ''',
      [orderNo],
    );
    return rows
        .map(
          (row) => RefundableOrderItem.fromMap({
            'order_item_id': row['order_item_id'] as int,
            'product_name': row['product_name'] as String,
            'quantity': row['quantity'] as int,
            'unit_price': (row['unit_price'] as num).toDouble(),
            'refunded_qty': (row['refunded_qty'] as num).toInt(),
          }),
        )
        .toList(growable: false);
  }

  Future<double> refundOrderItems({
    required String orderNo,
    required String reason,
    required String managerPin,
    required String operatorName,
    required Map<int, int> refundQtyByOrderItem,
  }) async {
    await _ensureOpsTables();
    if (refundQtyByOrderItem.isEmpty) {
      throw StateError('No refund items selected.');
    }

    return db.transaction((txn) async {
      final orderRows = await txn.query(
        'orders',
        where: 'order_no = ? AND status IN (?, ?)',
        whereArgs: [orderNo, 'paid', 'partially_refunded'],
        limit: 1,
      );
      if (orderRows.isEmpty) {
        throw StateError('Order not found or not refundable.');
      }

      final refundableRows = await txn.rawQuery(
        '''
        SELECT
          oi.id AS order_item_id,
          oi.quantity,
          oi.unit_price,
          COALESCE(SUM(ri.quantity), 0) AS refunded_qty
        FROM order_items oi
        JOIN orders o ON o.id = oi.order_id
        LEFT JOIN refund_items ri ON ri.order_item_id = oi.id
        WHERE o.order_no = ?
        GROUP BY oi.id, oi.quantity, oi.unit_price
        ''',
        [orderNo],
      );

      final refundableMap = <int, Map<String, num>>{};
      for (final row in refundableRows) {
        refundableMap[row['order_item_id'] as int] = {
          'quantity': row['quantity'] as num,
          'refunded_qty': row['refunded_qty'] as num,
          'unit_price': row['unit_price'] as num,
        };
      }

      double refundAmount = 0;
      for (final entry in refundQtyByOrderItem.entries) {
        final source = refundableMap[entry.key];
        if (source == null) throw StateError('Refund item not found.');
        final qty = entry.value;
        final remaining =
            (source['quantity']!.toInt() - source['refunded_qty']!.toInt());
        if (qty <= 0 || qty > remaining) {
          throw StateError('Refund quantity invalid for item ${entry.key}.');
        }
        refundAmount += source['unit_price']!.toDouble() * qty;
      }

      if (refundAmount <= 0) {
        throw StateError('Refund amount must be greater than 0.');
      }

      final pinTail = managerPin.length >= 2
          ? managerPin.substring(managerPin.length - 2)
          : managerPin;
      final now = DateTime.now().toIso8601String();
      final refundId = await txn.insert('refunds', {
        'order_no': orderNo,
        'amount': refundAmount,
        'refund_type': 'partial',
        'reason': reason,
        'operator_name': operatorName,
        'manager_pin_tail': pinTail,
        'created_at': now,
      });

      for (final entry in refundQtyByOrderItem.entries) {
        final unit = refundableMap[entry.key]!['unit_price']!.toDouble();
        await txn.insert('refund_items', {
          'refund_id': refundId,
          'order_item_id': entry.key,
          'quantity': entry.value,
          'amount': unit * entry.value,
          'created_at': now,
        });
      }

      final qtyRows = await txn.rawQuery(
        '''
        SELECT
          COALESCE(SUM(oi.quantity), 0) AS total_qty,
          COALESCE(SUM(ri.quantity), 0) AS refunded_qty
        FROM orders o
        JOIN order_items oi ON oi.order_id = o.id
        LEFT JOIN refund_items ri ON ri.order_item_id = oi.id
        WHERE o.order_no = ?
        ''',
        [orderNo],
      );
      final totalQty = (qtyRows.first['total_qty'] as num).toInt();
      final refundedQty = (qtyRows.first['refunded_qty'] as num).toInt();
      final status = refundedQty >= totalQty
          ? 'refunded'
          : 'partially_refunded';

      await txn.update(
        'orders',
        {'status': status},
        where: 'order_no = ?',
        whereArgs: [orderNo],
      );

      await txn.update(
        'refunds',
        {'refund_type': status == 'refunded' ? 'full' : 'partial'},
        where: 'id = ?',
        whereArgs: [refundId],
      );

      return refundAmount;
    });
  }

  Future<double> refundOrder({
    required String orderNo,
    required String reason,
    required String managerPin,
  }) async {
    final items = await fetchRefundableOrderItems(orderNo);
    final allRemaining = <int, int>{
      for (final item in items)
        if (item.remainingQuantity > 0)
          item.orderItemId: item.remainingQuantity,
    };
    if (allRemaining.isEmpty) {
      throw StateError('Order not found or already refunded.');
    }

    return refundOrderItems(
      orderNo: orderNo,
      reason: reason,
      managerPin: managerPin,
      operatorName: 'cashier',
      refundQtyByOrderItem: allRemaining,
    );
  }

  Future<void> _ensureOpsTables() async {
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
        refund_type TEXT NOT NULL DEFAULT 'full',
        reason TEXT NOT NULL,
        operator_name TEXT NOT NULL DEFAULT 'cashier',
        manager_pin_tail TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
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

  Future<void> _seedSpecOptionsIfEmpty() async {
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM option_items');
    final count = (result.first['c'] as num?)?.toInt() ?? 0;
    if (count > 0) return;

    final now = DateTime.now().toIso8601String();
    final seeds = <(String, String, double)>[
      (SpecGroupKey.size, '中杯', 0),
      (SpecGroupKey.size, '大杯', 2),
      (SpecGroupKey.sugar, '全糖', 0),
      (SpecGroupKey.sugar, '正常糖', 0),
      (SpecGroupKey.sugar, '少糖', 0),
      (SpecGroupKey.sugar, '无糖', 0),
      (SpecGroupKey.ice, '正常冰', 0),
      (SpecGroupKey.ice, '少冰', 0),
      (SpecGroupKey.ice, '去冰', 0),
      (SpecGroupKey.ice, '热饮', 0),
      (SpecGroupKey.toppings, '椰果', 2),
      (SpecGroupKey.toppings, '珍珠', 2),
      (SpecGroupKey.toppings, '布丁', 3),
      (SpecGroupKey.toppings, '仙草', 3),
    ];
    final orderCounter = <String, int>{};
    final batch = db.batch();
    for (final seed in seeds) {
      final sort = orderCounter.update(
        seed.$1,
        (v) => v + 1,
        ifAbsent: () => 0,
      );
      batch.insert('option_items', {
        'group_key': seed.$1,
        'name': seed.$2,
        'price': seed.$3,
        'sort_order': sort,
        'is_active': 1,
        'created_at': now,
      });
    }
    await batch.commit(noResult: true);
  }

  double _legacySizeExtra(String? raw) => raw == 'large' ? 2 : 0;

  String _legacySizeLabel(String? raw) {
    switch (raw) {
      case 'medium':
        return '中杯';
      case 'large':
        return '大杯';
      default:
        return raw ?? '';
    }
  }

  String _legacySugarLabel(String? raw) {
    switch (raw) {
      case 'full':
        return '全糖';
      case 'normal':
        return '正常糖';
      case 'less':
        return '少糖';
      case 'zero':
        return '无糖';
      default:
        return raw ?? '';
    }
  }

  String _legacyIceLabel(String? raw) {
    switch (raw) {
      case 'normal':
        return '正常冰';
      case 'less':
        return '少冰';
      case 'noIce':
        return '去冰';
      case 'hot':
        return '热饮';
      default:
        return raw ?? '';
    }
  }

  Future<void> _ensureCategoryExists(String category) async {
    if (category.isEmpty) return;
    final now = DateTime.now().toIso8601String();
    await db.insert('categories', {
      'name': category,
      'is_active': 1,
      'created_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  String? _normalizeNullable(String? value) {
    if (value == null) return null;
    final v = value.trim();
    return v.isEmpty ? null : v;
  }

  String _buildOrderNo(
    DateTime now, {
    required String orderType,
    required String orderChannel,
  }) {
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');
    final prefix = _orderPrefix(
      orderType: orderType,
      orderChannel: orderChannel,
    );
    return '$prefix$y$m$d-$hh$mm$ss$ms';
  }

  String _orderPrefix({
    required String orderType,
    required String orderChannel,
  }) {
    final type = orderType.trim().toLowerCase();
    if (type != 'delivery') {
      return 'I'; // In-store
    }
    final channel = orderChannel.trim().toLowerCase();
    if (channel.contains('grab')) return 'G';
    if (channel.contains('shopee')) return 'S';
    if (channel.contains('foodpanda') || channel.contains('panda')) return 'F';
    if (channel.contains('line')) return 'L';
    return 'D'; // Other delivery channels
  }

  String _buildPickupNo(int sequence) {
    return 'A${sequence.toString().padLeft(3, '0')}';
  }

  String _buildSuspendNo(DateTime now) {
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    return 'H$y$m$d-$hh$mm$ss';
  }
}
