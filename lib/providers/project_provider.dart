import 'package:flutter/foundation.dart';
import '../models/project.dart';
import '../services/storage_service.dart';

class ProjectProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  
  List<Project> _projects = [];
  Project? _currentProject;
  bool _isLoading = false;

  // Getters
  List<Project> get projects => _projects;
  Project? get currentProject => _currentProject;
  bool get isLoading => _isLoading;

  /// 現在のプロジェクトのシステムプロンプトを取得
  String get currentSystemPrompt => _currentProject?.systemPrompt ?? '';

  ProjectProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();
    
    await loadProjects();
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadProjects() async {
    _projects = await _storage.loadProjects();
    notifyListeners();
  }

  Future<void> _saveProjects() async {
    await _storage.saveProjects(_projects);
  }

  /// プロジェクトを作成
  Future<Project> createProject({
    required String name,
    String description = '',
    String systemPrompt = '',
    String? icon,
    String color = '#6366F1',
  }) async {
    final project = Project(
      name: name,
      description: description,
      systemPrompt: systemPrompt,
      icon: icon,
      color: color,
    );
    
    _projects.insert(0, project);
    await _saveProjects();
    notifyListeners();
    
    return project;
  }

  /// テンプレートからプロジェクトを作成
  Future<Project> createFromTemplate(Project template) async {
    final project = Project(
      name: template.name,
      description: template.description,
      systemPrompt: template.systemPrompt,
      icon: template.icon,
      color: template.color,
    );
    
    _projects.insert(0, project);
    await _saveProjects();
    notifyListeners();
    
    return project;
  }

  /// プロジェクトを更新
  Future<void> updateProject(Project project) async {
    final index = _projects.indexWhere((p) => p.id == project.id);
    if (index != -1) {
      _projects[index] = project.copyWith(updatedAt: DateTime.now());
      await _saveProjects();
      
      // 現在選択中のプロジェクトなら更新
      if (_currentProject?.id == project.id) {
        _currentProject = _projects[index];
      }
      
      notifyListeners();
    }
  }

  /// プロジェクトを削除
  Future<void> deleteProject(String id) async {
    _projects.removeWhere((p) => p.id == id);
    
    if (_currentProject?.id == id) {
      _currentProject = null;
    }
    
    await _saveProjects();
    notifyListeners();
  }

  /// プロジェクトを選択
  void selectProject(String? projectId) {
    if (projectId == null) {
      _currentProject = null;
    } else {
      _currentProject = _projects.firstWhere(
        (p) => p.id == projectId,
        orElse: () => Project.defaultProject,
      );
    }
    notifyListeners();
  }

  /// プロジェクトをIDで取得
  Project? getProjectById(String? id) {
    if (id == null) return null;
    try {
      return _projects.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }
}
