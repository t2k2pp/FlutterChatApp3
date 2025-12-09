import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/skill.dart';

class SkillProvider extends ChangeNotifier {
  static const String _skillsKey = 'skills';
  
  List<Skill> _skills = [];
  bool _isLoading = false;

  List<Skill> get skills => _skills;
  bool get isLoading => _isLoading;

  SkillProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();
    
    await _loadSkills();
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadSkills() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_skillsKey);
    
    if (data == null) {
      // 初回はプリセットスキルを追加
      _skills = List.from(SkillTemplates.templates);
      await _saveSkills();
      return;
    }
    
    try {
      final List<dynamic> jsonList = jsonDecode(data);
      _skills = jsonList
          .map((json) => Skill.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _skills = List.from(SkillTemplates.templates);
    }
  }

  Future<void> _saveSkills() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_skills.map((s) => s.toJson()).toList());
    await prefs.setString(_skillsKey, data);
  }

  /// スキルを作成
  Future<Skill> createSkill({
    required String name,
    String description = '',
    required String promptTemplate,
    String? icon,
    String color = '#6366F1',
    List<SkillVariable> variables = const [],
  }) async {
    final skill = Skill(
      name: name,
      description: description,
      promptTemplate: promptTemplate,
      icon: icon,
      color: color,
      variables: variables,
    );
    
    _skills.insert(0, skill);
    await _saveSkills();
    notifyListeners();
    
    return skill;
  }

  /// テンプレートからスキルを作成
  Future<Skill> createFromTemplate(Skill template) async {
    final skill = Skill(
      name: template.name,
      description: template.description,
      promptTemplate: template.promptTemplate,
      icon: template.icon,
      color: template.color,
      variables: template.variables,
    );
    
    _skills.insert(0, skill);
    await _saveSkills();
    notifyListeners();
    
    return skill;
  }

  /// スキルを更新
  Future<void> updateSkill(Skill skill) async {
    final index = _skills.indexWhere((s) => s.id == skill.id);
    if (index != -1) {
      _skills[index] = skill.copyWith(updatedAt: DateTime.now());
      await _saveSkills();
      notifyListeners();
    }
  }

  /// スキルを削除
  Future<void> deleteSkill(String id) async {
    _skills.removeWhere((s) => s.id == id);
    await _saveSkills();
    notifyListeners();
  }

  /// スキルを実行してプロンプトを生成
  String executeSkill(Skill skill, Map<String, String> variableValues) {
    return skill.generatePrompt(variableValues);
  }

  /// スキルをIDで取得
  Skill? getSkillById(String id) {
    try {
      return _skills.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  /// プリセットをリセット
  Future<void> resetToDefaults() async {
    _skills = List.from(SkillTemplates.templates);
    await _saveSkills();
    notifyListeners();
  }
}
