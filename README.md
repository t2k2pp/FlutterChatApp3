# 🤖 Flutter AI Chat App

マルチプロバイダー対応のモダンなAIチャットアプリケーション。Llama.cpp、Claude、OpenAI、Geminiに対応し、高度なカスタマイズ機能を備えています。

## ✨ 主な機能

### 🔄 マルチプロバイダー対応
複数のLLMプロバイダーを切り替えて使用可能。

| プロバイダー | 対応API |
|-------------|---------|
| **Llama.cpp** | ローカルLLM (OpenAI互換API) |
| **Claude** | Anthropic API |
| **OpenAI** | GPT-4 / GPT-3.5 |
| **Gemini** | Google AI |

### 📁 プロジェクト機能 (Gems風)
カスタムAIペルソナを作成。プロジェクトごとにシステムプロンプトを設定し、特化型AIを簡単に切り替え。

- テンプレートから素早く作成
- プロジェクト別の会話管理
- 「一般」に戻すことも可能

### 🛠️ スキル機能 (Claude Skills準拠)
再利用可能なワークフロー/タスクテンプレート。

- **複数ファイル構成**: SKILL.md + 参照資料 + 例示
- **動的トリガー**: キーワード/正規表現で自動検出
- **ビルトインスキル**: コードレビュー、ドキュメント作成、翻訳、要約、デバッグ支援

### 🔍 Web検索機能
SearXNG連携によるWeb検索統合。

- **通常検索**: ボタン一つで検索結果をコンテキストに追加
- **DeepSearch**: 複数クエリでの深層調査

### 🎨 Artifact/Canvas機能
AIが生成したHTML/CSS/JSをリアルタイムプレビュー。

- **Web**: iframeでライブプレビュー
- **Android/iOS**: WebViewでプレビュー
- コード/プレビュー切替
- 展開/縮小表示

### 🧠 Watson (サブAI)
メインAIの応答を分析するセカンドオピニオン機能。

- ハルシネーション警告
- 改善提案
- 割り込みレベル調整可能

### 💭 Thinking Mode
AIの思考過程を表示。展開/縮小可能な思考ブロック。

### 📋 その他の機能
- **クリップボードコピー**: メッセージをワンタップでコピー
- **会話エクスポート**: Markdown形式で出力
- **ストリーミング応答**: リアルタイムで応答を表示
- **ダークテーマ**: モダンなグラデーションデザイン

---

## 🚀 セットアップ

### 必要条件
- Flutter SDK 3.x
- Dart 3.x
- Android Studio / VS Code

### インストール

```bash
# リポジトリをクローン
git clone https://github.com/t2k2pp/FlutterChatApp3.git
cd FlutterChatApp3

# 依存関係をインストール
flutter pub get

# 実行
flutter run -d chrome --web-port=8080  # Web
flutter run -d <device>                 # Android/iOS
```

### 設定

アプリ起動後、ドロワーから以下を設定：

1. **LLMプロバイダー** (☁️アイコン)
   - プロバイダーを追加/編集
   - APIキーを入力

2. **システム設定** (⚙️アイコン)
   - API URL (ローカルLlama.cpp用)
   - グローバルシステムプロンプト

3. **SearXNG** (検索機能用)
   - `http://your-searxng-server:8081/`

---

## 📱 対応プラットフォーム

| プラットフォーム | 状態 |
|-----------------|------|
| Web | ✅ 完全対応 |
| Android | ✅ 完全対応 |
| iOS | ✅ 対応 (要テスト) |
| Windows | 🔧 部分対応 |
| macOS | 🔧 部分対応 |
| Linux | 🔧 部分対応 |

---

## 🏗️ アーキテクチャ

```
lib/
├── main.dart           # エントリーポイント
├── models/             # データモデル
│   ├── message.dart
│   ├── conversation.dart
│   ├── project.dart
│   ├── skill.dart
│   └── artifact.dart
├── providers/          # 状態管理 (Provider)
│   ├── chat_provider.dart
│   ├── project_provider.dart
│   ├── skill_provider.dart
│   ├── search_provider.dart
│   └── llm_provider_manager.dart
├── services/           # API通信・ビジネスロジック
│   ├── llm_service.dart
│   ├── llm_provider.dart
│   ├── providers/      # LLMプロバイダー実装
│   ├── searxng_service.dart
│   └── deep_search_service.dart
├── screens/            # 画面
├── widgets/            # UIコンポーネント
└── theme/              # テーマ設定
```

---

## 📄 ライセンス

MIT License

---

## 🤝 貢献

Issue・Pull Request歓迎です！
