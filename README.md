# おでかけチェッカーウィジェット

おでかけチェッカーウィジェット は、持ち物チェックを **アプリ本体** と **ウィジェット** の両方から管理できる iOS アプリです。

## 主な機能

- 項目の追加 / 編集 / 削除 / 並び替え
- アプリ本体から各項目の ON/OFF 切り替え
- ウィジェットから各項目の ON/OFF 切り替え（インタラクティブ）
- ロック画面ウィジェット（タップでアプリ起動）
- 自動リセット（毎日 / 曜日 / 第 n 曜日）

## ウィジェット構成

ホーム画面ウィジェットは以下の 2 種類です（既存仕様を維持）。

1. **通常レイアウト**（Small / Medium / Large）
2. **2列レイアウト**（Medium / Large）

加えて、ロック画面向けウィジェット（Inline / Circular / Rectangular）を提供します。ロック画面ウィジェットはタップでアプリを開けます。

### サイズ対応（重要）

- **ロック画面ウィジェット**: `accessoryInline` / `accessoryCircular` / `accessoryRectangular`
- **ホーム画面ウィジェット**: `systemSmall` / `systemMedium` / `systemLarge`

`OutingCheckerLockScreenWidget` に `systemMedium` を要求すると、以下のようなエラーで表示に失敗します。

- `Request widget family (systemMedium) is not supported by this widget kind (OutingCheckerLockScreenWidget)`
- `Failed to open "com.apple.springboard"`（上記サイズ不一致に起因する副次エラー）

### 項目配置順

すべてのグリッド系ウィジェットは、**1 列目を上から埋めてから 2 列目へ進む**（列優先）順で配置されます。

## データと安全性

- データは端末内の `UserDefaults`（App Group）に保存されます。
- 外部サーバーへの送信処理は実装していません。
- 取得する個人情報はありません（入力したチェック項目名のみ、端末内保持）。
- 詳細は `PRIVACY_POLICY.md` を参照してください。

## 開発メモ

- 共有ロジックは `Shared/` 配下に配置
- ウィジェット実装は `OutingCheckerWidget/` 配下

## ビルドエラー対処（entitlements が開けない）

Xcode で次のようなエラーが出る場合があります。

- `The file ".../OutingCheckerWidget/OutingCheckerWidgetExtension.entitlements" could not be opened.`

このエラーは、多くの場合 `CODE_SIGN_ENTITLEMENTS` の参照先が壊れている（古い参照 ID / 間違った場所の参照）ときに発生します。  
**最短の直し方は「一度参照を消して、正しい entitlements を再追加する」ことです。**

1. **いまの壊れた参照を消す（重要）**
   - 左ペインで `OutingCheckerWidgetExtension.entitlements` を右クリック → **Delete**  
   - ダイアログは **Remove Reference** を選択（Move to Trash ではない）
2. **正しいファイルを再追加する**
   - `File > Add Files to "OutingChecker"...`
   - 実ファイル `OutingCheckerWidget/OutingCheckerWidgetExtension.entitlements` を選択
   - Target は **WidgetExtension ターゲットのみ**にチェック
3. **Build Settings を固定する**
   - WidgetExtension ターゲット > `Build Settings` > `Code Signing Entitlements`
   - 値を `OutingCheckerWidget/OutingCheckerWidgetExtension.entitlements` にする（Debug/Release 両方）
4. **重複ファイルを避ける**
   - ルートの `OutingCheckerWidgetExtension.entitlements` を使わない方針なら削除して 1 つに統一
5. **クリーンして再ビルド**
   - `Product > Clean Build Folder`
   - Xcode 再起動 → Build

### それでも直らない場合（最終確認）

- `TARGETS > WidgetExtension > Build Phases > Copy Bundle Resources` に entitlements が入っていたら削除（通常不要）
- `DerivedData` を削除して再ビルド
- `.xcodeproj` の競合解消後に壊れたケースがあるため、直前のブランチ差分で `project.pbxproj` を確認

### ターミナルでの事前確認（任意）

リポジトリ直下で次を実行すると、期待パスに entitlements があるか確認できます。

```bash
./scripts/check_entitlements_path.sh
```
