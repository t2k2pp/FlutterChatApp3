import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/skill.dart';

class SkillProvider extends ChangeNotifier {
  List<Skill> _skills = [];
  List<Skill> _activeSkills = [];  // 現在有効なスキル
  bool _isLoading = false;
  String? _error;
  bool _autoDetectEnabled = true;

  // Getters
  List<Skill> get skills => _skills;
  List<Skill> get activeSkills => _activeSkills;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get autoDetectEnabled => _autoDetectEnabled;

  SkillProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();

    await _loadSkills();
    await _loadSettings();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _autoDetectEnabled = prefs.getBool('skills_autoDetect') ?? true;
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('skills_autoDetect', _autoDetectEnabled);
  }

  Future<void> _loadSkills() async {
    final prefs = await SharedPreferences.getInstance();
    final skillsJson = prefs.getString('skills_v2');
    
    if (skillsJson != null) {
      try {
        final skillsList = jsonDecode(skillsJson) as List;
        _skills = skillsList
            .map((s) => Skill.fromJson(s as Map<String, dynamic>))
            .toList();
      } catch (e) {
        _error = 'スキルの読み込みに失敗しました: $e';
        _skills = [];
      }
    }
    
    // ビルトインスキルを追加（重複チェック）
    _ensureBuiltInSkills();
  }

  Future<void> _saveSkills() async {
    final prefs = await SharedPreferences.getInstance();
    final skillsJson = jsonEncode(_skills.map((s) => s.toJson()).toList());
    await prefs.setString('skills_v2', skillsJson);
  }

  void _ensureBuiltInSkills() {
    final builtInIds = BuiltInSkills.all.map((s) => s.id).toSet();
    final existingBuiltInIds = _skills
        .where((s) => s.isBuiltIn)
        .map((s) => s.id)
        .toSet();
    
    // 不足しているビルトインスキルを追加
    for (final builtIn in BuiltInSkills.all) {
      if (!existingBuiltInIds.contains(builtIn.id)) {
        _skills.add(builtIn);
      }
    }
  }

  /// 自動検出を切替
  Future<void> setAutoDetect(bool enabled) async {
    _autoDetectEnabled = enabled;
    await _saveSettings();
    notifyListeners();
  }

  /// メッセージから関連スキルを自動検出
  List<Skill> detectSkills(String message) {
    if (!_autoDetectEnabled) return [];
    
    return _skills
        .where((skill) => skill.trigger.matches(message))
        .toList();
  }

  /// スキルを有効化
  void activateSkill(Skill skill) {
    if (!_activeSkills.any((s) => s.id == skill.id)) {
      _activeSkills.add(skill);
      notifyListeners();
    }
  }

  /// スキルを無効化
  void deactivateSkill(String skillId) {
    _activeSkills.removeWhere((s) => s.id == skillId);
    notifyListeners();
  }

  /// 全スキルを無効化
  void deactivateAllSkills() {
    _activeSkills.clear();
    notifyListeners();
  }

  /// 有効なスキルのコンテキストを生成
  String getActiveSkillsContext() {
    if (_activeSkills.isEmpty) return '';
    
    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.writeln('# 有効なスキル');
    buffer.writeln();
    
    for (final skill in _activeSkills) {
      buffer.writeln(skill.toContext());
      buffer.writeln('---');
    }
    
    return buffer.toString();
  }

  /// スキルを追加
  Future<void> addSkill(Skill skill) async {
    _skills.add(skill);
    await _saveSkills();
    notifyListeners();
  }

  /// スキルを更新
  Future<void> updateSkill(Skill skill) async {
    final index = _skills.indexWhere((s) => s.id == skill.id);
    if (index != -1) {
      _skills[index] = skill;
      
      // 有効なスキルも更新
      final activeIndex = _activeSkills.indexWhere((s) => s.id == skill.id);
      if (activeIndex != -1) {
        _activeSkills[activeIndex] = skill;
      }
      
      await _saveSkills();
      notifyListeners();
    }
  }

  /// スキルを削除
  Future<void> deleteSkill(String skillId) async {
    final skill = _skills.firstWhere((s) => s.id == skillId);
    if (skill.isBuiltIn) return;  // ビルトインは削除不可
    
    _skills.removeWhere((s) => s.id == skillId);
    _activeSkills.removeWhere((s) => s.id == skillId);
    await _saveSkills();
    notifyListeners();
  }

  /// ビルトインスキルを復元
  Future<void> restoreBuiltInSkills() async {
    _skills.removeWhere((s) => s.isBuiltIn);
    _skills.addAll(BuiltInSkills.all);
    await _saveSkills();
    notifyListeners();
  }

  /// 新規カスタムスキルを作成
  Skill createNewSkill() {
    return Skill(
      name: '新規スキル',
      description: 'スキルの説明',
      files: [
        const SkillFile(
          name: 'SKILL.md',
          type: SkillFileType.instruction,
          content: '# スキル名\n\nここにスキルの指示を記述します。',
        ),
      ],
    );
  }

  /// スキルにファイルを追加
  Skill addFileToSkill(Skill skill, SkillFile file) {
    final updatedFiles = [...skill.files, file];
    return skill.copyWith(files: updatedFiles);
  }

  /// スキルからファイルを削除
  Skill removeFileFromSkill(Skill skill, String fileName) {
    final updatedFiles = skill.files
        .where((f) => f.name != fileName)
        .toList();
    return skill.copyWith(files: updatedFiles);
  }

  /// エラーをクリア
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
