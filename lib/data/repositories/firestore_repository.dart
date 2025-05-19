// lib/data/repositories/firestore_repository.dart
import 'dart:async';
import 'dart:nativewrappers/_internal/vm/lib/math_patch.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../core/logging/logger_service.dart';
import '../models/chat/chat_conversation.dart';
import '../models/chat/chat_message.dart';

/// تنفيذ نمط Repository لعزل منطق التعامل مع Firestore وتوفير طبقة تخزين مؤقت
class FirestoreRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final LoggerService _logger;
  final String _currentAgentCode;

  // تخزين مؤقت للمحادثات
  final Map<String, ChatConversation> _conversationsCache = {};

  // تخزين مؤقت للرسائل مع مفتاح مركب من معرف المحادثة
  final Map<String, List<ChatMessage>> _messagesCache = {};

  // تخزين مؤقت لمعلومات المستخدمين
  final Map<String, ChatParticipantInfo> _participantInfoCache = {};

  // تخزين مؤقت لنتائج التحقق من رموز العملاء
  final Map<String, bool> _agentCodeValidationCache = {};

  // مؤقتات لإعادة تحميل البيانات
  final Map<String, Timer> _cacheExpiryTimers = {};

  // مدة صلاحية التخزين المؤقت
  static const Duration _cacheDuration = Duration(minutes: 15);
  static const Duration _participantInfoCacheDuration = Duration(hours: 1);

  // حد أقصى لعدد الرسائل في الصفحة الواحدة
  static const int _defaultPageSize = 20;

  // تدفقات البيانات المباشرة
  final Map<String, StreamController<List<ChatConversation>>>
  _conversationStreamControllers = {};
  final Map<String, StreamController<List<ChatMessage>>>
  _messageStreamControllers = {};

  FirestoreRepository(
    this._firestore,
    this._storage,
    this._logger,
    this._currentAgentCode,
  ) {
    if (_currentAgentCode.isEmpty) {
      _logger.error(
        "FirestoreRepository:Constructor",
        "CRITICAL: Repository initialized with an empty agent code!",
      );
    }
    _logger.info(
      "FirestoreRepository:Constructor",
      "Repository initialized for agent: $_currentAgentCode",
    );
  }

  /// الحصول على تدفق المحادثات مع التخزين المؤقت
  Stream<List<ChatConversation>> getConversationsStream() {
    final String cacheKey = 'conversations_$_currentAgentCode';

    // إنشاء وحدة تحكم بالتدفق إذا لم تكن موجودة
    _conversationStreamControllers[cacheKey] ??=
        StreamController<List<ChatConversation>>.broadcast(
          onListen: () {
            _logger.debug(
              "FirestoreRepository:getConversationsStream",
              "First listener attached, starting Firestore stream",
            );
            _startConversationsFirestoreStream(cacheKey);
          },
          onCancel: () {
            _logger.debug(
              "FirestoreRepository:getConversationsStream",
              "Last listener detached, considering cleanup",
            );
            // تنظيف بعد تأخير للسماح بإعادة الاستماع السريعة
            Future.delayed(const Duration(minutes: 5), () {
              if (_conversationStreamControllers[cacheKey]?.hasListener ==
                  false) {
                _logger.debug(
                  "FirestoreRepository:getConversationsStream",
                  "No listeners after delay, cleaning up",
                );
                _conversationStreamControllers[cacheKey]?.close();
                _conversationStreamControllers.remove(cacheKey);
              }
            });
          },
        );

    // إرسال البيانات المخزنة مؤقتًا فورًا إذا كانت متوفرة
    if (_conversationsCache.isNotEmpty) {
      final cachedConversations =
          _conversationsCache.values.toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _conversationStreamControllers[cacheKey]?.add(cachedConversations);
    }

    return _conversationStreamControllers[cacheKey]!.stream;
  }

  /// بدء تدفق Firestore للمحادثات
  void _startConversationsFirestoreStream(String cacheKey) {
    _firestore
        .collection("conversations")
        .where("participants", arrayContains: _currentAgentCode)
        .where("deletedForUsers.$_currentAgentCode", isNotEqualTo: true)
        .orderBy("updatedAt", descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            _logger.debug(
              "FirestoreRepository:_startConversationsFirestoreStream",
              "Received ${snapshot.docs.length} conversations from Firestore",
            );

            // تحديث التخزين المؤقت
            for (final doc in snapshot.docs) {
              final conversation = ChatConversation.fromFirestore(
                doc as DocumentSnapshot<Map<String, dynamic>>,
                _currentAgentCode,
              );
              _conversationsCache[conversation.id] = conversation;
            }

            // إرسال البيانات المحدثة للمستمعين
            final conversations =
                _conversationsCache.values.toList()
                  ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

            _conversationStreamControllers[cacheKey]?.add(conversations);

            // تعيين مؤقت لانتهاء صلاحية التخزين المؤقت
            _resetCacheExpiryTimer(cacheKey, _cacheDuration);
          },
          onError: (error, stackTrace) {
            _logger.error(
              "FirestoreRepository:_startConversationsFirestoreStream",
              "Error in Firestore stream",
              error,
              stackTrace,
            );
            _conversationStreamControllers[cacheKey]?.addError(
              error,
              stackTrace,
            );
          },
        );
  }

  /// الحصول على تدفق الرسائل مع التخزين المؤقت والتحميل الكسول
  Stream<List<ChatMessage>> getMessagesStream(
    String conversationId, {
    int pageSize = _defaultPageSize,
  }) {
    if (conversationId.isEmpty) {
      _logger.warn(
        "FirestoreRepository:getMessagesStream",
        "Empty conversation ID provided",
      );
      return Stream.value([]);
    }

    final String cacheKey = 'messages_${conversationId}_$_currentAgentCode';

    // إنشاء وحدة تحكم بالتدفق إذا لم تكن موجودة
    _messageStreamControllers[cacheKey] ??= StreamController<
      List<ChatMessage>
    >.broadcast(
      onListen: () {
        _logger.debug(
          "FirestoreRepository:getMessagesStream",
          "First listener attached for conversation $conversationId, starting Firestore stream",
        );
        _startMessagesFirestoreStream(conversationId, cacheKey, pageSize);
      },
      onCancel: () {
        _logger.debug(
          "FirestoreRepository:getMessagesStream",
          "Last listener detached for conversation $conversationId, considering cleanup",
        );
        // تنظيف بعد تأخير للسماح بإعادة الاستماع السريعة
        Future.delayed(const Duration(minutes: 5), () {
          if (_messageStreamControllers[cacheKey]?.hasListener == false) {
            _logger.debug(
              "FirestoreRepository:getMessagesStream",
              "No listeners after delay for conversation $conversationId, cleaning up",
            );
            _messageStreamControllers[cacheKey]?.close();
            _messageStreamControllers.remove(cacheKey);
          }
        });
      },
    );

    // إرسال البيانات المخزنة مؤقتًا فورًا إذا كانت متوفرة
    if (_messagesCache.containsKey(conversationId)) {
      _messageStreamControllers[cacheKey]?.add(
        List.unmodifiable(_messagesCache[conversationId]!),
      );
    }

    return _messageStreamControllers[cacheKey]!.stream;
  }

  /// بدء تدفق Firestore للرسائل مع التحميل الكسول
  void _startMessagesFirestoreStream(
    String conversationId,
    String cacheKey,
    int pageSize,
  ) {
    // استخدام التحميل الكسول (Lazy Loading) مع Pagination
    _firestore
        .collection("conversations")
        .doc(conversationId)
        .collection("messages")
        .orderBy(
          "timestamp",
          descending: true,
        ) // ترتيب تنازلي للحصول على أحدث الرسائل أولاً
        .limit(pageSize)
        .snapshots()
        .listen(
          (snapshot) {
            _logger.debug(
              "FirestoreRepository:_startMessagesFirestoreStream",
              "Received ${snapshot.docs.length} messages from Firestore for conversation $conversationId",
            );

            // تحويل المستندات إلى رسائل
            final messages =
                snapshot.docs
                    .map(
                      (doc) => ChatMessage.fromFirestore(
                        doc as DocumentSnapshot<Map<String, dynamic>>,
                        _currentAgentCode,
                      ),
                    )
                    .toList();

            // ترتيب الرسائل تصاعديًا حسب الوقت (الأقدم أولاً)
            messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

            // تحديث التخزين المؤقت
            _messagesCache[conversationId] = messages;

            // إرسال البيانات المحدثة للمستمعين
            _messageStreamControllers[cacheKey]?.add(
              List.unmodifiable(messages),
            );

            // تعيين مؤقت لانتهاء صلاحية التخزين المؤقت
            _resetCacheExpiryTimer('messages_$conversationId', _cacheDuration);
          },
          onError: (error, stackTrace) {
            _logger.error(
              "FirestoreRepository:_startMessagesFirestoreStream",
              "Error in Firestore stream for conversation $conversationId",
              error,
              stackTrace,
            );
            _messageStreamControllers[cacheKey]?.addError(error, stackTrace);
          },
        );
  }

  /// تحميل المزيد من الرسائل (صفحة إضافية)
  Future<List<ChatMessage>> loadMoreMessages(
    String conversationId,
    DateTime beforeTimestamp, {
    int pageSize = _defaultPageSize,
  }) async {
    if (conversationId.isEmpty) {
      _logger.warn(
        "FirestoreRepository:loadMoreMessages",
        "Empty conversation ID provided",
      );
      return [];
    }

    try {
      final snapshot =
          await _firestore
              .collection("conversations")
              .doc(conversationId)
              .collection("messages")
              .orderBy("timestamp", descending: true)
              .where("timestamp", isLessThan: beforeTimestamp)
              .limit(pageSize)
              .get();

      _logger.debug(
        "FirestoreRepository:loadMoreMessages",
        "Loaded ${snapshot.docs.length} more messages for conversation $conversationId",
      );

      // تحويل المستندات إلى رسائل
      final newMessages =
          snapshot.docs
              .map(
                (doc) => ChatMessage.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                  _currentAgentCode,
                ),
              )
              .toList();

      // ترتيب الرسائل تصاعديًا حسب الوقت (الأقدم أولاً)
      newMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // دمج الرسائل الجديدة مع الرسائل المخزنة مؤقتًا
      if (_messagesCache.containsKey(conversationId)) {
        final allMessages = [
          ..._messagesCache[conversationId]!,
          ...newMessages,
        ];
        // إزالة التكرارات (إذا وجدت)
        final uniqueMessages = <String, ChatMessage>{};
        for (final message in allMessages) {
          uniqueMessages[message.id] = message;
        }

        // ترتيب الرسائل تصاعديًا حسب الوقت
        final sortedMessages =
            uniqueMessages.values.toList()
              ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

        // تحديث التخزين المؤقت
        _messagesCache[conversationId] = sortedMessages;

        // إرسال البيانات المحدثة للمستمعين
        final cacheKey = 'messages_${conversationId}_$_currentAgentCode';
        _messageStreamControllers[cacheKey]?.add(
          List.unmodifiable(sortedMessages),
        );
      } else {
        // إذا لم تكن هناك رسائل مخزنة مؤقتًا، فقم بتخزين الرسائل الجديدة
        _messagesCache[conversationId] = newMessages;
      }

      return newMessages;
    } catch (e, s) {
      _logger.error(
        "FirestoreRepository:loadMoreMessages",
        "Error loading more messages for conversation $conversationId",
        e,
        s,
      );
      return [];
    }
  }

  /// الحصول على معلومات المستخدم مع التخزين المؤقت
  Future<ChatParticipantInfo?> getAgentInfo(String agentCode) async {
    if (agentCode.isEmpty) {
      _logger.warn(
        "FirestoreRepository:getAgentInfo",
        "Empty agent code provided",
      );
      return null;
    }

    // التحقق من التخزين المؤقت أولاً
    if (_participantInfoCache.containsKey(agentCode)) {
      _logger.debug(
        "FirestoreRepository:getAgentInfo",
        "Returning cached participant info for agent $agentCode",
      );
      return _participantInfoCache[agentCode];
    }

    try {
      final doc =
          await _firestore.collection("agent_identities").doc(agentCode).get();

      if (doc.exists) {
        final data = doc.data()!;
        final participantInfo = ChatParticipantInfo(
          agentCode: agentCode,
          displayName: data["displayName"] as String? ?? agentCode,
        );

        // تخزين في الذاكرة المؤقتة
        _participantInfoCache[agentCode] = participantInfo;

        // تعيين مؤقت لانتهاء صلاحية التخزين المؤقت
        _resetCacheExpiryTimer(
          'participant_$agentCode',
          _participantInfoCacheDuration,
        );

        return participantInfo;
      }

      _logger.warn(
        "FirestoreRepository:getAgentInfo",
        "Agent info not found for $agentCode in 'agent_identities'",
      );
      return null;
    } catch (e, s) {
      _logger.error(
        "FirestoreRepository:getAgentInfo",
        "Error fetching agent info for $agentCode",
        e,
        s,
      );
      return null;
    }
  }

  /// التحقق من صحة رمز العميل مع التخزين المؤقت
  Future<bool> validateAgentCode(String agentCode) async {
    if (agentCode.isEmpty) {
      _logger.warn(
        "FirestoreRepository:validateAgentCode",
        "Empty agent code provided",
      );
      return false;
    }

    // التحقق من التخزين المؤقت أولاً
    if (_agentCodeValidationCache.containsKey(agentCode)) {
      _logger.debug(
        "FirestoreRepository:validateAgentCode",
        "Returning cached validation result for agent $agentCode",
      );
      return _agentCodeValidationCache[agentCode]!;
    }

    try {
      final doc =
          await _firestore.collection("agent_identities").doc(agentCode).get();

      final isValid = doc.exists;

      // تخزين في الذاكرة المؤقتة
      _agentCodeValidationCache[agentCode] = isValid;

      // تعيين مؤقت لانتهاء صلاحية التخزين المؤقت
      _resetCacheExpiryTimer(
        'validation_$agentCode',
        _participantInfoCacheDuration,
      );

      return isValid;
    } catch (e, s) {
      _logger.error(
        "FirestoreRepository:validateAgentCode",
        "Error validating agent code $agentCode",
        e,
        s,
      );
      return false;
    }
  }

  /// إنشاء أو الحصول على محادثة مع المشاركين
  Future<String?> createOrGetConversation(
    List<String> participantAgentCodes,
    Map<String, ChatParticipantInfo> participantInfoMap, {
    String? groupTitle,
  }) async {
    _logger.info(
      "FirestoreRepository:createOrGetConversation",
      "Attempting with participants: $participantAgentCodes. Current user: $_currentAgentCode",
    );

    final allParticipantsSorted = List<String>.from(participantAgentCodes);
    if (!allParticipantsSorted.contains(_currentAgentCode)) {
      allParticipantsSorted.add(_currentAgentCode);
    }
    allParticipantsSorted.sort();

    // تجميع معلومات المشاركين
    final Map<String, ChatParticipantInfo> finalParticipantInfoMap =
        Map<String, ChatParticipantInfo>.from(participantInfoMap);

    // إضافة معلومات المستخدم الحالي إذا لم تكن موجودة
    if (!finalParticipantInfoMap.containsKey(_currentAgentCode)) {
      final currentUserInfo = await getAgentInfo(_currentAgentCode);
      if (currentUserInfo != null) {
        finalParticipantInfoMap[_currentAgentCode] = currentUserInfo;
      } else {
        finalParticipantInfoMap[_currentAgentCode] = ChatParticipantInfo(
          agentCode: _currentAgentCode,
          displayName:
              "أنا (${_currentAgentCode.substring(0, min(3, _currentAgentCode.length))}..)",
        );
      }
    }

    // جمع معلومات المشاركين الآخرين
    for (final code in allParticipantsSorted) {
      if (!finalParticipantInfoMap.containsKey(code)) {
        final info = await getAgentInfo(code);
        if (info != null) {
          finalParticipantInfoMap[code] = info;
        } else {
          _logger.error(
            "FirestoreRepository:createOrGetConversation",
            "Could not fetch participant info for $code",
          );
          return null;
        }
      }
    }

    // التحقق من وجود محادثة ثنائية
    if (allParticipantsSorted.length == 2) {
      try {
        final existingConversation =
            await _firestore
                .collection("conversations")
                .where("participants", isEqualTo: allParticipantsSorted)
                .limit(1)
                .get();

        if (existingConversation.docs.isNotEmpty) {
          final doc = existingConversation.docs.first;
          final docId = doc.id;
          final data = doc.data() as Map<String, dynamic>?;
          final deletedForUsers =
              data?["deletedForUsers"] as Map<String, dynamic>?;

          // إذا كانت المحادثة محذوفة للمستخدم الحالي، قم بإلغاء الحذف
          if (deletedForUsers != null &&
              deletedForUsers[_currentAgentCode] == true) {
            await _firestore.collection("conversations").doc(docId).update({
              "deletedForUsers.$_currentAgentCode": FieldValue.delete(),
              "updatedAt": FieldValue.serverTimestamp(),
            });
          }

          _logger.info(
            "FirestoreRepository:createOrGetConversation",
            "Found/Reactivated existing 2-party conversation: $docId",
          );
          return docId;
        }
      } catch (e, s) {
        _logger.error(
          "FirestoreRepository:createOrGetConversation",
          "Error checking for existing conversation",
          e,
          s,
        );
      }
    }

    // إنشاء محادثة جديدة
    final now = DateTime.now();
    final newConversation = ChatConversation(
      id: "",
      participants: allParticipantsSorted,
      participantInfo: finalParticipantInfoMap,
      conversationTitle:
          groupTitle ??
          (allParticipantsSorted.length > 2
              ? "مجموعة جديدة (${allParticipantsSorted.length})"
              : "محادثة"),
      lastMessageText: "تم إنشاء المحادثة.",
      lastMessageTimestamp: now,
      lastMessageSenderAgentCode: _currentAgentCode,
      createdAt: now,
      updatedAt: now,
      deletedForUsers: {},
    );

    try {
      final docRef = await _firestore
          .collection("conversations")
          .add(newConversation.toFirestore());

      _logger.info(
        "FirestoreRepository:createOrGetConversation",
        "Successfully created new conversation with ID: ${docRef.id}",
      );

      // تحديث التخزين المؤقت
      final createdConversation = newConversation.copyWith(id: docRef.id);
      _conversationsCache[docRef.id] = createdConversation;

      // إرسال البيانات المحدثة للمستمعين
      final cacheKey = 'conversations_$_currentAgentCode';
      if (_conversationStreamControllers.containsKey(cacheKey)) {
        final conversations =
            _conversationsCache.values.toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        _conversationStreamControllers[cacheKey]?.add(conversations);
      }

      return docRef.id;
    } catch (e, s) {
      _logger.error(
        "FirestoreRepository:createOrGetConversation",
        "Failed to create new conversation in Firestore",
        e,
        s,
      );
      return null;
    }
  }

  /// إرسال رسالة إلى محادثة
  Future<bool> sendMessage(String conversationId, ChatMessage message) async {
    _logger.info(
      "FirestoreRepository:sendMessage",
      "Sending message to conversation $conversationId by agent $_currentAgentCode",
    );

    if (conversationId.isEmpty || message.senderId != _currentAgentCode) {
      _logger.error(
        "FirestoreRepository:sendMessage",
        "Invalid params: convId empty or senderId mismatch",
      );
      return false;
    }

    try {
      final messageData = message.toFirestore();
      messageData["timestamp"] = FieldValue.serverTimestamp();

      final messageDocRef = await _firestore
          .collection("conversations")
          .doc(conversationId)
          .collection("messages")
          .add(messageData);

      // تحديث بيانات المحادثة
      Map<String, dynamic> updateData = {
        "lastMessageText": message.text ?? (message.fileName ?? "مرفق"),
        "lastMessageTimestamp": FieldValue.serverTimestamp(),
        "lastMessageSenderAgentCode": message.senderId,
        "updatedAt": FieldValue.serverTimestamp(),
        "deletedForUsers": {},
      };

      await _firestore
          .collection("conversations")
          .doc(conversationId)
          .update(updateData);

      // تحديث التخزين المؤقت للرسائل
      if (_messagesCache.containsKey(conversationId)) {
        final updatedMessage = message.copyWith(id: messageDocRef.id);
        _messagesCache[conversationId]!.add(updatedMessage);

        // إرسال البيانات المحدثة للمستمعين
        final cacheKey = 'messages_${conversationId}_$_currentAgentCode';
        if (_messageStreamControllers.containsKey(cacheKey)) {
          _messageStreamControllers[cacheKey]?.add(
            List.unmodifiable(_messagesCache[conversationId]!),
          );
        }
      }

      return true;
    } catch (e, s) {
      _logger.error(
        "FirestoreRepository:sendMessage",
        "Failed to send message to conversation $conversationId",
        e,
        s,
      );
      return false;
    }
  }

  /// تحميل ملف إلى Firebase Storage
  Future<String?> uploadFile(
    List<int> fileBytes,
    String fileName,
    String conversationId,
  ) async {
    _logger.info(
      "FirestoreRepository:uploadFile",
      "Uploading file $fileName to conversation $conversationId",
    );

    if (fileBytes.isEmpty || fileName.isEmpty || conversationId.isEmpty) {
      _logger.error("FirestoreRepository:uploadFile", "Invalid params");
      return null;
    }

    try {
      final String filePath =
          "chat_attachments/$conversationId/${DateTime.now().millisecondsSinceEpoch}_$fileName";
      final ref = _storage.ref().child(filePath);

      final uploadTask = ref.putData(Uint8List.fromList(fileBytes));
      final snapshot = await uploadTask;

      final downloadUrl = await snapshot.ref.getDownloadURL();
      _logger.info(
        "FirestoreRepository:uploadFile",
        "File uploaded successfully. URL: $downloadUrl",
      );

      return downloadUrl;
    } catch (e, s) {
      _logger.error(
        "FirestoreRepository:uploadFile",
        "Error uploading file",
        e,
        s,
      );
      return null;
    }
  }

  /// إعادة تعيين مؤقت انتهاء صلاحية التخزين المؤقت
  void _resetCacheExpiryTimer(String cacheKey, Duration duration) {
    _cacheExpiryTimers[cacheKey]?.cancel();
    _cacheExpiryTimers[cacheKey] = Timer(duration, () {
      _logger.debug(
        "FirestoreRepository:_resetCacheExpiryTimer",
        "Cache expired for key $cacheKey",
      );

      if (cacheKey.startsWith('conversations_')) {
        // لا نقوم بمسح التخزين المؤقت للمحادثات، فقط نعيد تحميلها
        // لأن التدفق المباشر سيقوم بتحديثها
      } else if (cacheKey.startsWith('messages_')) {
        final conversationId = cacheKey.split('_')[1];
        _messagesCache.remove(conversationId);
      } else if (cacheKey.startsWith('participant_')) {
        final agentCode = cacheKey.substring('participant_'.length);
        _participantInfoCache.remove(agentCode);
      } else if (cacheKey.startsWith('validation_')) {
        final agentCode = cacheKey.substring('validation_'.length);
        _agentCodeValidationCache.remove(agentCode);
      }

      _cacheExpiryTimers.remove(cacheKey);
    });
  }

  /// تنظيف الموارد عند التخلص من الكائن
  void dispose() {
    // إلغاء جميع المؤقتات
    for (final timer in _cacheExpiryTimers.values) {
      timer.cancel();
    }
    _cacheExpiryTimers.clear();

    // إغلاق جميع وحدات التحكم بالتدفق
    for (final controller in _conversationStreamControllers.values) {
      controller.close();
    }
    _conversationStreamControllers.clear();

    for (final controller in _messageStreamControllers.values) {
      controller.close();
    }
    _messageStreamControllers.clear();

    // مسح التخزين المؤقت
    _conversationsCache.clear();
    _messagesCache.clear();
    _participantInfoCache.clear();
    _agentCodeValidationCache.clear();
  }
}
