import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/conversation.dart';
import '../models/project.dart';

class StorageService {
  static const String _conversationsKey = 'conversations';
  static const String _projectsKey = 'projects';
  static const String _settingsKey = 'settings';

  // ===== 会話関連 =====
  
  Future<List<Conversation>> loadConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_conversationsKey);
    
    if (data == null) return [];
    
    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList
          .map((json) => Conversation.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveConversations(List<Conversation> conversations) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(conversations.map((c) => c.toJson()).toList());
    await prefs.setString(_conversationsKey, data);
  }

  // ===== プロジェクト関連 =====

  Future<List<Project>> loadProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_projectsKey);
    
    if (data == null) return [];
    
    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList
          .map((json) => Project.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveProjects(List<Project> projects) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(projects.map((p) => p.toJson()).toList());
    await prefs.setString(_projectsKey, data);
  }

  // ===== 設定関連 =====

  Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_settingsKey);
    
    if (data == null) {
      return {
        'apiUrl': 'http://192.168.1.24:11437/v1',
        'model': 'default',
        'systemPrompt': '',
        'currentProjectId': null,
      };
    }
    
    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (e) {
      return {
        'apiUrl': 'http://192.168.1.24:11437/v1',
        'model': 'default',
        'systemPrompt': '',
        'currentProjectId': null,
      };
    }
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings));
  }
}
