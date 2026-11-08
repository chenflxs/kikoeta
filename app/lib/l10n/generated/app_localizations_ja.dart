// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get cacheWritebackSourceMissing =>
      '元のサイトが未設定のキャッシュ歌詞は、ローカルにのみ取り込みました。';

  @override
  String get cacheWritebackLegacyTitle => '旧キャッシュの書き戻し先';

  @override
  String get cacheWritebackLegacyHint =>
      '旧キャッシュには元のサイト情報がありません。書き戻し先を選ぶと作品と音声パスを確認します。一致しない歌詞はローカルにのみ取り込みます。';

  @override
  String get cacheWritebackLocalOnly => 'ローカルにのみ取り込む';

  @override
  String cacheWritebackSummary(String written, String skipped) {
    return 'キャッシュ歌詞の書き戻し：$written 件、未書き戻し：$skipped 件。';
  }

  @override
  String get writebackCheck => '書き戻し権限を確認';

  @override
  String get writebackChecking => '書き戻し権限を確認中…';

  @override
  String get writebackUnknown => '書き戻し権限は未確認です';

  @override
  String get writebackReady => '書き戻しが許可されています';

  @override
  String get writebackDisabled => 'サーバーの書き戻しは無効です';

  @override
  String get writebackUnsupported => 'このサーバーは書き戻しに対応していません';

  @override
  String get writebackLoginRequired => 'このサイトにログインするか、認証情報を更新してください';

  @override
  String get writebackRoleForbidden => 'このアカウントには書き戻し権限がありません';

  @override
  String get writebackKeyRequired => '書き戻しキーを入力してください';

  @override
  String get writebackKeyInvalid => '書き戻しキーが正しくありません';

  @override
  String get writebackUnconfigured => 'サーバーに書き戻しキーが設定されていません';

  @override
  String get writebackSourceUnavailable => '元の音声またはフォルダーが利用できません';

  @override
  String get writebackDirectoryUnwritable => '音声フォルダーに書き込めません';

  @override
  String get writebackConflict => '内容の異なる書き戻し歌詞が既に存在します';

  @override
  String get writebackNetworkError => '書き戻しサービスに接続できません';

  @override
  String get writebackFailed => '書き戻しの認証または保存に失敗しました';

  @override
  String get writebackRetry => '書き戻しを再試行';

  @override
  String get webdavUploadOverwrite => 'ローカルデータでクラウドを上書き';

  @override
  String get webdavDownloadOverwrite => 'クラウドのデータでローカルを上書き';

  @override
  String get webdavMergeData => 'ローカルとクラウドのデータを統合';

  @override
  String get webdavMergeHint =>
      'お気に入り、ブロックリスト、プレイリスト、履歴を統合します。設定が競合する場合はローカルの設定を保持します。';

  @override
  String get dataExport => 'ローカルデータをエクスポート';

  @override
  String get dataImport => 'ローカルデータをインポート';

  @override
  String get dataScope =>
      'お気に入り、プレイリスト、ブロックリスト、履歴、設定が対象です。ダウンロード、歌詞ライブラリ、パスワード、キーは含まれません。';

  @override
  String get dataImportConfirm =>
      'バックアップ対象のローカルデータを置き換えますか？先に復元用コピーを保存します。再生は継続します。';

  @override
  String get dataExportDone => 'データをエクスポートしました';

  @override
  String get dataImportDone => 'データをインポートしました';

  @override
  String get dataOperationFailed => '操作に失敗しました。再試行してください。';

  @override
  String get backupInvalid => 'バックアップが無効、非対応、または破損しています';

  @override
  String get backupTooLarge => 'バックアップが上限の16 MBを超えています';

  @override
  String get webdavTitle => 'WebDAVクラウド同期';

  @override
  String get webdavUrl => 'サーバーURL';

  @override
  String get webdavUsername => 'アカウント';

  @override
  String get webdavPassword => 'アプリパスワード';

  @override
  String get webdavFolder => '同期フォルダー';

  @override
  String get webdavAuto => '1時間ごとに自動同期';

  @override
  String get webdavAutoHint =>
      'アプリの実行中は1時間ごとに、再開時は同期時刻を過ぎていれば確認します。変更分のみアップロードします。';

  @override
  String get webdavTest => '接続テスト';

  @override
  String get webdavTestDone => '接続しました。テストファイルは削除済みです。';

  @override
  String get webdavSyncNow => '今すぐ同期';

  @override
  String get webdavSyncDone => '同期が完了しました';

  @override
  String get webdavNever => '未同期';

  @override
  String get webdavSyncing => '同期中…';

  @override
  String get webdavConflict => 'ローカルとクラウドの両方で変更があります。保持するデータを選んでください。';

  @override
  String get webdavUseLocal => 'ローカルを保持';

  @override
  String get webdavUseCloud => 'クラウドを使用';

  @override
  String get webdavConflictConfirm =>
      '選択したデータでもう一方を置き換えます。クラウドのデータを適用する前に、ローカルの復元用コピーを保存します。';

  @override
  String get webdavInvalidConfig =>
      'HTTPS URL、アカウント、アプリパスワード、単一のフォルダー名を入力してください。';

  @override
  String get webdavAuthError => '認証に失敗しました。アカウントとアプリパスワードを確認してください。';

  @override
  String get webdavTimeout => '接続がタイムアウトしました。しばらくしてから再試行してください。';

  @override
  String get webdavNetworkError => '接続に失敗しました。ネットワークとサーバーURLを確認してください。';

  @override
  String get webdavRateLimited => 'サーバーのアクセス制限に達しました。しばらくしてから再試行してください。';

  @override
  String get webdavRequestFailed => '同期に失敗しました。サーバー設定を確認して再試行してください。';

  @override
  String get webdavNoEtag => 'クラウドのデータを安全に置き換えるための有効なETagがありません。';

  @override
  String get webdavNoBackup => 'クラウドにバックアップがありません';

  @override
  String get webdavCleanupFailed => 'テストファイルの削除に失敗しました。サーバーへの接続を確認してください。';

  @override
  String get webdavBusy => 'データ処理中です。しばらくお待ちください。';

  @override
  String get appName => 'Kikoeta';

  @override
  String get playbackShortcuts => 'キーボードショートカット';

  @override
  String get dictationQueueTitle => '文字起こし・翻訳キュー';

  @override
  String get dictationQueueClear => 'キューをクリア';

  @override
  String get dictationQueueEmpty => 'タスクはありません';

  @override
  String dictationQueueTracks(String count) {
    return '音声ファイル：$count';
  }

  @override
  String dictationQueueActions(String name) {
    return '$nameの操作';
  }

  @override
  String get dictationQueueJump => '先頭へ移動';

  @override
  String get dictationQueuePending => '待機中';

  @override
  String get dictationQueueRunning => '処理中';

  @override
  String get dictationQueueCompleted => '完了';

  @override
  String get dictationQueueFailed => '失敗';

  @override
  String get dictationQueueCancelled => 'キャンセル済み';

  @override
  String get dictationQueueDrag => 'ドラッグして待機中のタスクを並べ替え';

  @override
  String dictationQueueProcessing(String name) {
    return 'キューのバッチを処理中：$name';
  }

  @override
  String get invertSelection => '選択を反転';

  @override
  String get traditionalChinese => '繁體中文';

  @override
  String get home => 'ホーム';

  @override
  String get favorites => 'お気に入り';

  @override
  String get more => 'その他';

  @override
  String get voiceActor => '声優';

  @override
  String get circle => 'サークル';

  @override
  String get tag => 'タグ';

  @override
  String get retry => '再試行';

  @override
  String get advancedFilterPageBuildText => '詳細フィルター';

  @override
  String get advancedFilterPageBuildContentText => 'データはありません';

  @override
  String get advancedFilterPageBuildContentText2 => '一致する項目はありません';

  @override
  String advancedFilterPageBuildSearchFieldHintText(String placeholder) {
    return '$placeholderを検索…';
  }

  @override
  String get add => '追加';

  @override
  String get cancel => 'キャンセル';

  @override
  String get blacklistPageTypeLabelsTypeLabels => 'RJ番号';

  @override
  String get blacklist => 'ブロックリスト';

  @override
  String get blacklistPageResultText => 'ブロックリストに追加';

  @override
  String get blacklistPageResultHintText => 'ブロックするRJ番号 / 名前';

  @override
  String get blacklistPageBuildText => 'ブロックリストは空です\nブロックした作品はホームと検索結果に表示されません';

  @override
  String get local => 'ローカル';

  @override
  String get network => 'ネットワーク';

  @override
  String get password => 'パスワード';

  @override
  String get dictationTranslationPageWorkCardTitle => '作品';

  @override
  String get username => 'ユーザー名';

  @override
  String get dictationTranslationPageWorkCardText => 'タスクをキャンセル';

  @override
  String get dictationTranslationPageInitStateText => '開始できます';

  @override
  String get dictationTranslationPageTestConnectionToast => '接続しました';

  @override
  String get dictationTranslationPageLogCardTitle => 'ログ';

  @override
  String get dictationTranslationPageStartUpdate => 'タスクに失敗しました';

  @override
  String get dictationTranslationPageBuildText => '文字起こし・翻訳';

  @override
  String get dictationTranslationPageConnectionCardTitle => 'サービス接続';

  @override
  String get dictationTranslationPageConnectionCardInputDecoration => 'サービスURL';

  @override
  String get dictationTranslationPageConnectionCardTooltip => 'パスワードを表示';

  @override
  String get dictationTranslationPageConnectionCardTooltip2 => 'パスワードを非表示';

  @override
  String get testConnection => '接続テスト';

  @override
  String get dictationTranslationPageProgressCardTitle => '文字起こしの進捗';

  @override
  String get dictationTranslationPageStartUpdate2 => 'タスクをキューに追加しました';

  @override
  String get dictationTranslationPageStartUpdate3 => 'タスクをキャンセルしました';

  @override
  String get dictationTranslationPageWorkCardTitle2 => '処理する音声';

  @override
  String get dictationTranslationPageWorkCardText2 => 'キャンセル中…';

  @override
  String get dictationTranslationPageStartUpdate4 => '文字起こし・翻訳が完了しました';

  @override
  String get dictationTranslationPageSyncCachedResultsUpdate =>
      'キャッシュの同期が完了しました';

  @override
  String get dictationTranslationPageConnectionCardText => '既定の認証情報を使用';

  @override
  String get dictationTranslationPageWorkCardText3 => '文字起こし・翻訳を開始';

  @override
  String get dictationTranslationPageStartUpdate5 => '歌詞ライブラリに保存中';

  @override
  String get dictationSourceWritebackFailed =>
      '一部の歌詞を音声と同じフォルダーに書き込めなかったため、ローカルの歌詞ライブラリに保存しました。';

  @override
  String get sheetsLyricsWritebackKey => '歌詞の書き戻しキー';

  @override
  String get sheetsLyricsWritebackKeyHint => '半角英数字16文字、大文字と小文字を区別します';

  @override
  String dictationTranslationPageStartAppendLog(String error) {
    return 'エラー：$error';
  }

  @override
  String get dictationTranslationPageConnectionCardInputDecoration2 =>
      'ローカルサービスURL（固定）';

  @override
  String get dictationTranslationPageConnectionCardText2 =>
      'Android端末ではネットワーク接続のみ対応しています';

  @override
  String dictationTranslationPageTestConnectionToast2(String error) {
    return '接続に失敗しました：$error';
  }

  @override
  String dictationTranslationPageCancelToast(String error) {
    return 'キャンセルに失敗しました：$error';
  }

  @override
  String get dictationTranslationPageConnectionCardText3 => 'GitHubからダウンロード';

  @override
  String dictationTranslationPageSyncCachedResultsAppendLog(String error) {
    return 'キャッシュの同期に失敗しました：$error';
  }

  @override
  String dictationTranslationPageStartToast(String error) {
    return '文字起こし・翻訳に失敗しました：$error';
  }

  @override
  String dictationTranslationPageSyncCachedResultsToast(String skipped) {
    return '、重複スキップ：$skipped';
  }

  @override
  String get dictationTranslationPageStartUpdate6 => 'kikoeta-translに接続中';

  @override
  String get dictationTranslationPageStartException =>
      'kikoeta-translのタスクに失敗しました';

  @override
  String get dictationTranslationPageBuildTooltip => 'kikoeta-translのキャッシュを同期';

  @override
  String get dictationTranslationPageConnectionCardText4 =>
      'kikoeta-translをインストールしますか？';

  @override
  String get dictationTranslationPageTestConnectionFormatException =>
      'kikoeta-translサービスの準備ができていません';

  @override
  String get dictationTranslationPageLogCardSelectableText =>
      'kikoeta-translのログを待機中…';

  @override
  String get dictationTranslationPageStartToast2 =>
      '作品詳細ページの「その他」から文字起こし・翻訳を開始してください';

  @override
  String get dictationTranslationPageStartToast3 =>
      '作品詳細ページに戻り、文字起こし・翻訳するメディアファイルを選択してください';

  @override
  String get dictationTranslationPageStartFormatException =>
      'kikoeta-translからタスクIDが返されませんでした';

  @override
  String get dictationTranslationPageOpenKikoetaTranslDownloadToast =>
      'kikoeta-translのプロジェクトページを開けませんでした';

  @override
  String get dictationTranslationPageServiceFormatException =>
      'kikoeta-translのユーザー名にコロンは使用できません';

  @override
  String get dictationTranslationPageCancelAppendLog =>
      'kikoeta-translにキャンセル要求を送信しました';

  @override
  String get dictationTranslationPageServiceFormatException2 =>
      'kikoeta-translのユーザー名とパスワードを入力してください';

  @override
  String get dictationTranslationPageSyncCachedResultsToast2 =>
      '同期できるkikoeta-translのキャッシュ結果はありません';

  @override
  String get dictationTranslationPageStartFormatException2 =>
      'kikoeta-translから有効なLRCファイルが返されませんでした';

  @override
  String dictationTranslationPageProgressCardText(String savedFiles) {
    return ' · 保存済み：$savedFiles';
  }

  @override
  String dictationTranslationPageStartToast4(String missing) {
    return 'ダウンロードURLのない音声ファイル：$missing。作品サーバーにログインして再試行してください';
  }

  @override
  String dictationTranslationPageStartAppendLog2(String jobId, String length) {
    return 'タスク$jobIdを作成しました（音声ファイル$length件）';
  }

  @override
  String get dictationTranslationPageConnectionCardText5 =>
      'kikoeta-translをダウンロードして起動すると、ローカルまたはネットワーク経由で文字起こし・翻訳できます。';

  @override
  String dictationTranslationPageSyncCachedResultsAppendLog2(
    String jobId,
    String name,
    String error,
  ) {
    return '$jobId/$nameの同期に失敗しました：$error';
  }

  @override
  String dictationTranslationPageSyncCachedResultsAppendLog3(
    String saved,
    String skipped,
    String failed,
  ) {
    return 'キャッシュ同期完了：保存$saved件、重複スキップ$skipped件、失敗$failed件';
  }

  @override
  String dictationTranslationPageSyncCachedResultsAppendLog4(String length) {
    return 'kikoeta-translのキャッシュ済みタスク$length件を同期中';
  }

  @override
  String get dictationTranslationPageWorkCardText4 =>
      '作品詳細ページの右上にある「その他」から「文字起こし・翻訳」を選んでタスクを作成します。ファイル未選択の場合は、効果音なし版を優先し、独立した特典トラックを残して自動選択します。先にファイルを手動選択することもできます。';

  @override
  String get dictationAutoSelectionHint =>
      'ファイルを自動選択しました。効果音なし版を優先し、独立した特典トラックを残しています。メディア一覧を確認し、変更する場合は作品ページで手動選択してください。';

  @override
  String dictationTranslationPageStartAppendLog3(String rj, String savedFiles) {
    return '$rjに歌詞ファイル$savedFiles件を保存しました';
  }

  @override
  String dictationTranslationPageWorkCardText5(String rj, String length) {
    return '$rj · 作品詳細ページで選択したメディアファイル：$length件';
  }

  @override
  String dictationTranslationPageStartToast5(String savedFiles, String rj) {
    return '完了：$rjの歌詞ライブラリに歌詞ファイル$savedFiles件を保存しました';
  }

  @override
  String dictationTranslationPageSyncCachedResultsToast3(
    String saved,
    String value,
  ) {
    return '同期完了：歌詞ファイル$saved件を保存$value';
  }

  @override
  String dictationTranslationPageProgressCardText2(
    String finishedFiles,
    String length,
    String value,
  ) {
    return '処理済み $finishedFiles / $length$value';
  }

  @override
  String get selectMultiple => '複数選択';

  @override
  String get selectAll => 'すべて選択';

  @override
  String get downloads => 'ダウンロード';

  @override
  String get downloading => 'ダウンロード中';

  @override
  String get downloadsPageStatusStatus => '待機中';

  @override
  String get downloadsPageStatusStatus2 => '完了';

  @override
  String get downloadsPageStatusStatus3 => '一時停止';

  @override
  String get exitSelection => '選択を終了';

  @override
  String get downloadsPageBuildTooltip => '検索を閉じる';

  @override
  String get downloadsPageStatusStatus4 => 'ダウンロード失敗';

  @override
  String get downloadsPageStatusStatus5 => 'キュー待ち';

  @override
  String get deselectAll => '選択をすべて解除';

  @override
  String get downloadsPageBuildText => 'ファイルをダウンロード';

  @override
  String get downloadsPageBuildText2 => 'ダウンロード済みの音声作品はありません';

  @override
  String get downloadsPageBuildText3 => 'すべてのファイルツリー';

  @override
  String get downloadsPageBuildTooltip2 => '選択した作品を削除';

  @override
  String get downloadsPageBuildText4 => 'ダウンロード済みファイルはありません';

  @override
  String get downloadsPageBuildTooltip3 => 'ダウンロード済みの作品を検索';

  @override
  String get downloadsPageBuildTooltip4 => 'すべて開始 / 一時停止';

  @override
  String get downloadsPageBuildTooltip5 => '選択したダウンロード履歴を削除';

  @override
  String get downloadsPageFileNameFileName => 'ダウンロード中のファイルはありません';

  @override
  String downloadsPageProgressTextText(String percent) {
    return 'ダウンロード中 $percent%';
  }

  @override
  String downloadsPageBuildText5(String value) {
    return 'さらに読み込む（$value）';
  }

  @override
  String downloadsPageBuildText6(String rj, String downloaded, String length) {
    return '$rj  $downloaded/$lengthファイルをダウンロード済み';
  }

  @override
  String downloadsPageStatusStatus6(String round) {
    return 'ダウンロード中 $round%';
  }

  @override
  String get postponed => '保留';

  @override
  String get remove => '削除';

  @override
  String get all => 'すべて';

  @override
  String get wantToListen => '聴きたい';

  @override
  String get listening => '聴いている';

  @override
  String get listened => '聴き終えた';

  @override
  String get replay => 'もう一度聴く';

  @override
  String get favoritesPageReviewFilterButtonTooltip => '進捗で絞り込み';

  @override
  String get favoritesPageLabelLabel => 'お気に入りから削除';

  @override
  String get loading => '読み込み中…';

  @override
  String get favoritesPageReviewSortDropdownTooltip => '並べ替え';

  @override
  String get favoritesPageReviewSortLabelsReviewSortLabels => 'レビュー数';

  @override
  String get favoritesPageBodyText => 'タップして再試行';

  @override
  String get favoritesPageReviewSortLabelsReviewSortLabels2 => '販売数';

  @override
  String get favoritesPageBuildTooltip => 'プレイリストを切り替え';

  @override
  String get favoritesPageReviewSortLabelsReviewSortLabels3 => '発売日';

  @override
  String get favoritesPageReviewSortLabelsReviewSortLabels4 => '自分の評価';

  @override
  String get favoritesPageReviewSortLabelsReviewSortLabels5 => 'マークした日時';

  @override
  String get ageRating => '年齢区分';

  @override
  String get favoritesPageInputText => '作品を追加';

  @override
  String get favoritesPageBodyText2 => 'すべて表示しました';

  @override
  String get favoritesPageLabelLabel2 => 'プレイリストから削除';

  @override
  String get favoritesPagePlaylistHeaderActionsTooltip => '共有リンクをコピー';

  @override
  String favoritesPageAddWorksByRjToast(String e) {
    return '追加に失敗しました：$e';
  }

  @override
  String get shareLinkCopied => '共有リンクをコピーしました';

  @override
  String get favoritesPageRemoveSelectedWorksToast => '作品IDを取得できませんでした';

  @override
  String get favoritesPageBodyText3 => 'お気に入りの作品はありません';

  @override
  String favoritesPageRemoveCurrentLikedPlaylistToast(String e) {
    return 'お気に入りの解除に失敗しました：$e';
  }

  @override
  String get favoritesPagePlaylistHeaderActionsTooltip2 => 'このプレイリストのお気に入りを解除';

  @override
  String get favoritesPageBodyText4 => 'このプレイリストに作品はありません';

  @override
  String get favoritesPagePlaylistHeaderActionsTooltip3 => 'RJ番号で作品を追加';

  @override
  String get favoritesPageAddWorksByRjToast2 => 'RJ番号が見つかりません';

  @override
  String favoritesPageSelectionBarText(String count) {
    return '選択中：$count';
  }

  @override
  String favoritesPageRemoveSelectedWorksToast2(String label, String e) {
    return '$labelに失敗しました：$e';
  }

  @override
  String get favoritesPageBodyText5 => 'SFWモードではお気に入りは表示されません';

  @override
  String get favoritesPageBodyText6 => '読み込みに失敗しました。設定でログイン状態を確認してください';

  @override
  String get favoritesPageOkText => 'このプレイリストをマイプレイリストから削除しますか？';

  @override
  String favoritesPageAddWorksByRjToast3(String length) {
    return '作品を$length件追加しました';
  }

  @override
  String favoritesPageOkText2(String count, String label) {
    return '$count件の作品に「$label」を適用しますか？';
  }

  @override
  String favoritesPageRemoveSelectedWorksToast3(String label, String length) {
    return '$label：$length作品';
  }

  @override
  String get favoritesPageInputHintText =>
      'RJ番号を1つ以上入力\n例：RJ01367541 RJ01417842\n改行、スペース、カンマで区切ってください';

  @override
  String get clear => 'クリア';

  @override
  String get historyPageEntryWorkTitle => '不明な作品';

  @override
  String get playHistory => '再生履歴';

  @override
  String get historyPageBuildText => '再生履歴はありません';

  @override
  String get historyPageBuildText2 => 'SFWモードでは再生履歴は表示されません';

  @override
  String historyPageFmtTimeText(String padLeft, String padLeft2) {
    return '今日 $padLeft:$padLeft2';
  }

  @override
  String historyPageFmtTimeText2(
    String month,
    String day,
    String padLeft,
    String padLeft2,
  ) {
    return '$month/$day $padLeft:$padLeft2';
  }

  @override
  String get homePageServerLabelText => 'カスタム';

  @override
  String get homePageLabelsLabels => '人気';

  @override
  String get homePageLabelsLabels2 => 'おすすめ';

  @override
  String get homePageSortLabelsSortLabels => '総合評価';

  @override
  String get homePageSortLabelsSortLabels2 => '追加日';

  @override
  String get homePageSortLabelsSortLabels3 => '価格';

  @override
  String get homePageEmptyHintText => '作品はありません';

  @override
  String get homePageSearchResultsViewText => '検索中…';

  @override
  String get homePageEmptyHintText2 => '読み込み中…';

  @override
  String get homePageGridText => 'すべての作品を表示しました';

  @override
  String get homePageEmptyHintText3 => '画面をタップして再試行';

  @override
  String get homePageSearchResultsViewText2 => '一致する作品はありません';

  @override
  String get homePageSearchResultsViewText3 => '検索結果をすべて表示しました';

  @override
  String get homePageEmptyHintText4 => '現在のフィルターに一致する作品はありません';

  @override
  String get homePageEmptyHintText5 => '接続できません。ネットワークまたはサーバー設定を確認してください';

  @override
  String get homePageHeaderTooltip => 'SFWモード有効：全年齢向けのみ表示';

  @override
  String get homePageHeaderTooltip2 => 'SFWモードを有効にする（全年齢向けのみ）';

  @override
  String get save => '保存';

  @override
  String get loginPageBuildLoginText => 'ログイン';

  @override
  String get loginPageShowNoAccountText => 'アカウントについて';

  @override
  String get loginPageShowNoAccountText2 => '了解';

  @override
  String get loginPageBuildSiteConfigTooltip => 'ログインに戻る';

  @override
  String get loginPageBuildSiteConfigText => '保存済みサイト';

  @override
  String get loginPageBuildSiteConfigHint => 'サイトのパスワード';

  @override
  String get loginPageShowProxyDialogLabelText => 'プロキシサーバー';

  @override
  String get loginPageBuildLoginText2 => 'アカウントを持っていない';

  @override
  String get loginPageBuildSiteConfigText2 => 'このサイトを使用';

  @override
  String get loginPageBuildSiteConfigText3 => '新しいサイトを追加';

  @override
  String get loginPageBuildSiteConfigText4 => '保存して続行';

  @override
  String get loginPageShowProxyDialogText => 'ネットワークプロキシを設定';

  @override
  String get loginPageBuildLoginText3 => 'カスタムサイトを設定';

  @override
  String get loginPageBuildSiteConfigHint2 => 'サイトのユーザー名';

  @override
  String get loginPageShowProxyDialogToast => 'ネットワークプロキシを有効にしました';

  @override
  String get loginPageShowProxyDialogToast2 => 'ネットワークプロキシを無効にしました';

  @override
  String get loginPageBuildLoginHint => 'oneサイトのアカウント';

  @override
  String get loginPageLoginToast => 'ユーザー名とパスワードを入力してください';

  @override
  String get loginPageLoginToast2 => 'ネットワークまたは認証情報を確認してください';

  @override
  String get loginPageShowProxyDialogText2 => 'HTTPプロキシを使用';

  @override
  String get loginPageBuildLoginText4 => 'oneサイトにログイン';

  @override
  String get loginPageShowProxyDialogHelperText => 'HTTPプロキシのみ対応しています';

  @override
  String get loginPageBuildSiteConfigHint3 => '表示名（例：自宅NAS）';

  @override
  String get loginPageSaveNewSiteToast =>
      '表示名とURLを入力してください。ユーザー名とパスワードは両方空欄でも構いません。';

  @override
  String get loginPageShowProxyDialogHintText => '例：http://proxy-address:port';

  @override
  String get loginPageBuildSiteConfigText5 =>
      'IPとポートに対応（例：http://192.168.1.100:3000）';

  @override
  String loginPageLoginToast3(String value) {
    return 'ログインに失敗しました：$value';
  }

  @override
  String get loginPageShowNoAccountText3 =>
      '本プロジェクトではアカウント登録は提供していません。\n\nユーザー名とパスワードはご自身で取得してください。本プロジェクトでは取得方法の案内は行いません。\n\n本アプリでアカウントを使用してアクセス・再生したコンテンツの権利および責任は、コンテンツ提供者とアカウント所有者に帰属します。本プロジェクトはそのコンテンツに関する責任を負いません。\n\nアカウント情報は端末内にのみ保存され、第三者のサーバーには送信されません。';

  @override
  String get close => '閉じる';

  @override
  String get delete => '削除';

  @override
  String get remote => 'リモート';

  @override
  String get continueAction => '続行';

  @override
  String get online => 'オンライン';

  @override
  String get importAction => 'インポート';

  @override
  String get lyricsLibraryPageBuildNavItem => 'リモートライブラリ';

  @override
  String get lyricsLibrary => '歌詞ライブラリ';

  @override
  String get lyricsLibraryPageBuildNavItem2 => 'ローカルファイル';

  @override
  String get lyricsLibraryPageProceedText => 'インポートを続行';

  @override
  String get lyricsLibraryPageImportText => 'インポートをキャンセル';

  @override
  String get lyricsLibraryPageProgressPhase => 'インポートを準備中';

  @override
  String get lyricsLibraryPageOkText => '完全更新';

  @override
  String get lyricsLibraryPageOkText2 => '歌詞を削除';

  @override
  String get lyricsLibraryPageSectionContentText => 'フォルダーを選択';

  @override
  String get lyricsLibraryPageConfirmedText => 'リモートライブラリを削除';

  @override
  String get lyricsLibraryPageSectionContentText2 => 'リモートライブラリをインポート';

  @override
  String get lyricsLibraryPageBuildText => '歌詞ライブラリをインポート';

  @override
  String get lyricsLibraryPageBuildLabel => '歌詞ライブラリを更新';

  @override
  String get lyricsLibraryPageBuildTooltip => '歌詞ライブラリを検索';

  @override
  String get lyricsLibraryPageBuildText2 => '歌詞をインポート中';

  @override
  String get lyricsLibraryPageImportText2 => '既存ファイルをスキップ';

  @override
  String get lyricsLibraryPageImportText3 => '既存ファイルを上書き';

  @override
  String get lyricsLibraryPageOkText3 => 'リモート作品を削除';

  @override
  String get lyricsLibraryPageProceedText2 => '大量のファイルのインポート';

  @override
  String get lyricsLibraryPageImportText4 => '既存ファイルとの競合';

  @override
  String get lyricsLibraryPageRemoteSourceListTooltip => 'このリモートライブラリのみ更新';

  @override
  String get lyricsLibraryPageOkText4 => '歌詞ライブラリから作品を削除';

  @override
  String get lyricsLibraryPageBuildLabel2 => 'すべてのリモートライブラリを更新';

  @override
  String get lyricsLibraryPageBuildText3 => 'ファイルを準備中…';

  @override
  String get lyricsLibraryPageSelectionDialogTitle => '歌詞フォルダーを選択';

  @override
  String get lyricsLibraryPageSectionContentText3 => '接続して同期中';

  @override
  String get lyricsLibraryPageSearchFieldHintText => '作品IDを検索';

  @override
  String lyricsLibraryPageImportText5(String e) {
    return 'インポートに失敗しました：$e';
  }

  @override
  String get lyricsLibraryPageRemoteSourceListText => 'インポート済みのリモートライブラリはありません';

  @override
  String get lyricsLibraryPageBuildHint => '長押しで完全更新';

  @override
  String get lyricsLibraryPageBuildText4 => '歌詞ファイルを集計中';

  @override
  String get lyricsLibraryPageScanProgressPhase => 'ファイルの競合を確認中';

  @override
  String get lyricsLibraryPageResultDialogTitle => 'ZIPファイルを選択';

  @override
  String get lyricsLibraryPageSectionContentText4 => 'ZIPアーカイブを選択';

  @override
  String get lyricsLibraryPageBuildText5 => '現在、歌詞ファイル数を取得できません';

  @override
  String lyricsLibraryPageRefreshText(String error) {
    return '更新に失敗しました：$error';
  }

  @override
  String get lyricsLibraryPageShowFilesText => '歌詞・字幕ファイルはありません';

  @override
  String get lyricsLibraryPageBuildText6 => 'データはありません。右上の「インポート」をタップしてください';

  @override
  String get lyricsLibraryPageShowFilesText2 => '歌詞ファイルを読み込めませんでした。再試行してください';

  @override
  String lyricsLibraryPageReorderSetState(String error) {
    return '優先順位の変更に失敗しました：$error';
  }

  @override
  String get lyricsLibraryPageSectionContentLabelText => 'HTTP / HTTPS URL';

  @override
  String get lyricsLibraryPageBuildHint2 =>
      'インポート済みのすべてのリモートライブラリから作品インデックスを同期';

  @override
  String get lyricsLibraryPageImportText6 => '選択したフォルダーに歌詞・字幕ファイルがありません';

  @override
  String get lyricsLibraryPageSectionContentText5 =>
      'インポートする歌詞ファイルまたはアーカイブを選んでください。';

  @override
  String get lyricsLibraryPageSectionContentText6 =>
      '歌詞ライブラリを公開している端末のアドレスを入力してください。';

  @override
  String lyricsLibraryPageRefreshOneSetState(String url, String error) {
    return '$urlの更新に失敗しました：$error';
  }

  @override
  String lyricsLibraryPageRemoveRemoteLibrarySetState(
    String url,
    String error,
  ) {
    return '$urlの削除に失敗しました：$error';
  }

  @override
  String lyricsLibraryPageBuildText7(String directoryCount) {
    return 'ディレクトリ数：$directoryCount';
  }

  @override
  String lyricsLibraryPageBuildText8(String length) {
    return '項目数：$length';
  }

  @override
  String get lyricsLibraryPageBuildText9 =>
      'リモート作品はありません。右上の「インポート」からリモートライブラリに接続してください';

  @override
  String lyricsLibraryPageOkText5(String workId) {
    return '$workIdのリモート作品インデックスを削除しますか？';
  }

  @override
  String lyricsLibraryPageOkText6(String workId) {
    return '$workIdの歌詞ファイルをすべて削除しますか？';
  }

  @override
  String get lyricsLibraryPageOkText7 => '歌詞・字幕ファイルのない作品ディレクトリを削除します。続行しますか？';

  @override
  String get lyricsLibraryPageSectionContentText7 =>
      'インポート済みリモートライブラリ（優先順・ドラッグで並べ替え）';

  @override
  String lyricsLibraryPageRemoteSourceListText2(String value) {
    return '優先順位 $value · 長押しで削除';
  }

  @override
  String lyricsLibraryPageConfirmedText2(String url) {
    return 'リモートライブラリ$urlと同期済みの作品インデックスを削除しますか？';
  }

  @override
  String get lyricsLibraryPageSectionContentText8 =>
      'インポート時は作品インデックスのみ同期します。再生時にその作品の歌詞をすべてダウンロードします。';

  @override
  String get lyricsLibraryPageProceedText3 =>
      '大きなアーカイブまたはフォルダーが見つかりました。インポートに時間がかかる場合があります。';

  @override
  String lyricsLibraryPageOkText8(String length) {
    return '選択した$length件の作品ディレクトリを削除しますか？';
  }

  @override
  String lyricsLibraryPageImportText7(String length) {
    return '既存ファイルが$length件あります。処理方法を選んでください。';
  }

  @override
  String lyricsLibraryPageOkText9(String length) {
    return '選択した$length件のリモート作品インデックスを削除しますか？';
  }

  @override
  String lyricsLibraryPageBuildText10(String fileCount, String value) {
    return '歌詞・字幕ファイル：$fileCount · $value';
  }

  @override
  String get morePageBuildRow => 'プレイリスト';

  @override
  String get settings => '設定';

  @override
  String get morePageBuildRow2 => 'ランダム再生';

  @override
  String morePageBuildText(String server) {
    return 'サーバー：$server';
  }

  @override
  String get morePageOpenRandomWorkText => '現在のフィルターに一致する再生可能な作品はありません';

  @override
  String get morePageOpenRandomWorkText2 =>
      'ランダムな作品を読み込めませんでした。しばらくしてから再試行してください';

  @override
  String get playerPageShowLyricSettingsText => 'リセット';

  @override
  String get back => '戻る';

  @override
  String get seekBackward => '巻き戻し';

  @override
  String get seekForward => '早送り';

  @override
  String get playerPageUtilsUtil => 'タイマー';

  @override
  String get equalizer => 'イコライザー';

  @override
  String get playerPageUtilsUtil2 => 'タイマー有効';

  @override
  String get playerPageShowLyricSettingsText2 => '中国語の字体変換';

  @override
  String get autoMatch => '自動照合';

  @override
  String get workDetails => '作品詳細';

  @override
  String get playlist => 'プレイリスト';

  @override
  String get sleepTimer => 'スリープタイマー';

  @override
  String get playerPageWideLyricsPanelText => '歌詞はありません';

  @override
  String get playerPageTopBarText => '再生中';

  @override
  String get desktopLyrics => 'デスクトップ歌詞';

  @override
  String get playerPagePlayModeLabelText => '全曲リピート';

  @override
  String get playerPagePlayModeLabelText2 => '1曲リピート';

  @override
  String get playerPagePlayModeLabelText3 => '順番に再生';

  @override
  String get playerPageShowLyricSettingsText3 => '歌詞設定';

  @override
  String get playerPageShowLyricSettingsText4 => '字幕の時間調整';

  @override
  String get simplifiedToTraditional => '簡体字 → 繁体字';

  @override
  String get traditionalToSimplified => '繁体字 → 簡体字';

  @override
  String get playerPageShowQueueText => 'プレイリストは空です';

  @override
  String get playerPageResDialogTitle => '歌詞ファイルを選択';

  @override
  String get playerPagePickOnlineLyricText => 'オンライン歌詞を選択';

  @override
  String get playerPageBuildText => '再生していません';

  @override
  String get playerPageShowLyricSettingsTitle => 'オフライン歌詞を選択';

  @override
  String get playerPagePickOnlineLyricToast => 'オンライン歌詞は見つかりませんでした';

  @override
  String get playerPageShowLyricSettingsTitle2 => 'ライブラリの歌詞を選択';

  @override
  String get playerPageLoadOnlineLyricToast => 'この歌詞を解析できませんでした';

  @override
  String get playerPageLyricsPanelText => '歌詞を読み込み中…';

  @override
  String get playerAlreadyFirstTrack => '最初のトラックです';

  @override
  String get playerAlreadyLastTrack => '最後のトラックです';

  @override
  String get playerPageNextToast => 'プレイリストの最後に到達しました';

  @override
  String get playerPageOpenCurrentToast => 'ファイルストリームにアクセスするにはログインしてください';

  @override
  String get playerPageShowLyricSettingsSub => 'この作品は歌詞ライブラリにありません';

  @override
  String get playerPageOpenMediaToast => 'メディアを開く処理がタイムアウトしました。再試行してください';

  @override
  String get playerPageLibraryAutoTileText => 'ライブラリの歌詞を自動照合';

  @override
  String get playerPageOpenMediaToast2 => '開けませんでした。再試行中…';

  @override
  String get playerPageFriendlyPlayErrorText => 'メディアストリームのプロキシエラーです。再試行してください';

  @override
  String get playerLoudnessBoostLabel => '音量増幅';

  @override
  String get playerPageVolumeControlTooltip => '音量増幅（最大120）';

  @override
  String get playerPageShowLyricSettingsSub2 => 'ローカルの歌詞・字幕ファイルを選択';

  @override
  String get playerPageInitStateToast => '接続が切れました。再接続中…';

  @override
  String get playerPagePickLibraryLyricToast => 'ライブラリにこの作品の歌詞はありません';

  @override
  String get playerPageOpenMediaToast3 => 'メディアを開く処理がタイムアウトしました。再試行中…';

  @override
  String get playerPageShowLyricSettingsSub3 => '再生中の作品の歌詞ファイルのみ表示';

  @override
  String get playerPageCheckSleepToast => '再生を停止し、システムリソースを解放しました';

  @override
  String get playerPagePickOnlineLyricSub => 'トラック名で自動選択（中国語を優先）';

  @override
  String get playerPageFriendlyPlayErrorText2 => 'サーバーエラーです。しばらくしてから再試行してください';

  @override
  String get playerPageVolumeControlTooltip2 => '音量増幅を有効にする（最大120）';

  @override
  String get playerPageFriendlyPlayErrorText3 =>
      'セッションの有効期限が切れました。再ログインして再試行してください';

  @override
  String get playerPagePickOfflineLyricToast => '読み取り可能なタイムスタンプ付き歌詞がありません';

  @override
  String get playerPageFriendlyPlayErrorText4 =>
      'メディアストリームに接続できません。ネットワークを確認して再試行してください';

  @override
  String get playerPageVolumeControlTooltip3 => '音量増幅Plus（最大200）';

  @override
  String get playerPageToggleDesktopLyricsToast => 'デスクトップ歌詞の表示にはオーバーレイ権限が必要です';

  @override
  String playerPageSeekCircleMessage(String label, String seconds) {
    return '$label $seconds秒';
  }

  @override
  String get playerPageLibraryAutoTileText2 =>
      'ローカルの歌詞を優先し、見つからない場合はオンライン歌詞を使用';

  @override
  String playerPageShowQueueText2(String length) {
    return 'プレイリスト（$length）';
  }

  @override
  String playerPageInitStateToast2(String friendlyPlayError) {
    return '再生に失敗しました：$friendlyPlayError';
  }

  @override
  String playerPageOpenMediaToast4(String friendlyPlayError) {
    return 'メディアストリームを開けませんでした：$friendlyPlayError';
  }

  @override
  String get playlistsPageNameText => '作成';

  @override
  String get playlistsPageBuildText => '名前を変更';

  @override
  String get playlistsPageBuildText2 => '新規プレイリスト';

  @override
  String get playlistsPageNameHintText => 'プレイリスト名';

  @override
  String get playlistsPageBuildText3 => 'プレイリストは空です';

  @override
  String get playlistsPageHeaderTooltip => '作品を削除';

  @override
  String get playlistsPageNameText2 => 'プレイリスト名を変更';

  @override
  String get playlistsPageHeaderMessage => 'ドラッグして作品を並べ替え';

  @override
  String get playlistsPageRowMessage => 'ドラッグしてトラックを並べ替え';

  @override
  String get playlistsPagePlayTrackText => 'プレイリストに再生可能な音声がありません';

  @override
  String get playlistsPageBuildText4 => 'SFWモードではプレイリストは表示されません';

  @override
  String get playlistsPageBuildText5 => 'プレイリストはありません。右下の「新規」をタップしてください';

  @override
  String get playlistsPageBuildText6 => 'SFWモードではプレイリストの内容は表示されません';

  @override
  String playlistsPageBuildText7(String length) {
    return '項目数：$length';
  }

  @override
  String get playlistsPagePlayTrackText2 =>
      'この音声には有効なファイルストリームがありません。作品詳細ページから追加し直してください';

  @override
  String get playlistsPageBuildText8 => 'タイトルをドラッグして作品を、メディアをドラッグしてトラックを並べ替え';

  @override
  String get playlistsPageBuildText9 => 'タイトルを長押しして作品を、メディアを長押ししてトラックを並べ替え';

  @override
  String playlistsPageHeaderText(String length) {
    return '音声ファイル：$length';
  }

  @override
  String get traditionalChineseShort => '繁体字中国語';

  @override
  String get englishLanguage => '英語';

  @override
  String get simplifiedChineseShort => '簡体字中国語';

  @override
  String get settingsPageHealthBadgeStartsWith => '正常';

  @override
  String get settingsPageSectionsMiniBtn => '確認';

  @override
  String get settingsPageSectionsMiniBtn2 => '設定';

  @override
  String get settingsPageLockRowText => 'ロック解除';

  @override
  String get play => '再生';

  @override
  String get lyrics => '歌詞';

  @override
  String get settingsPageSectionsSection => 'トラック';

  @override
  String get settingsPageOnVersionTapText => 'OK';

  @override
  String get settingsPageSectionsSection2 => 'データとネットワーク';

  @override
  String get settingsPageSectionsSection3 => '外観';

  @override
  String get settingsPageSectionsText => 'テーマ';

  @override
  String get settingsPageSectionsText2 => 'ライト';

  @override
  String get settingsPageSectionsText3 => 'ダーク';

  @override
  String get settingsPageSectionsText4 => 'リセット';

  @override
  String get settingsPageSectionsSection4 => 'このアプリについて';

  @override
  String get settingsPageSectionTitleText => 'プライバシー';

  @override
  String get settingsPageSectionsTitle => 'バージョン';

  @override
  String get settingsPageSectionsTitle2 => 'リポジトリ';

  @override
  String get settingsPageLockRowSub => 'ロック解除済み';

  @override
  String get settingsPageSectionsMiniBtn3 => '無効にする';

  @override
  String get settingsPageShortcutConflictText => '次のトラック';

  @override
  String get settingsPageShortcutConflictText2 => '前のトラック';

  @override
  String get settingsPageSectionsLockRow => 'デスクトップ';

  @override
  String get settingsPageSectionsMiniBtn4 => '無効';

  @override
  String get settingsPageShortcutLabelText => '未設定';

  @override
  String get translationEngine => '翻訳エンジン';

  @override
  String get settingsPageSectionsLabel => '文字色';

  @override
  String get settingsPageSectionsLabel2 => '縁取りの色';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get settingsPageAutoCheckSetState => '確認中…';

  @override
  String get settingsPageSectionsTitle3 => '巻き戻し秒数';

  @override
  String get interfaceLanguage => '表示言語';

  @override
  String get settingsPageSectionsTitle4 => '早送り秒数';

  @override
  String get settingsPageAiModelInputLabelText => 'モデル名';

  @override
  String get settingsPageShortcutLabelText2 => '右矢印';

  @override
  String get chineseConversion => '中国語の字体変換';

  @override
  String get settingsPageSectionsText5 => '縁取りの太さ';

  @override
  String get settingsPageSectionsSection5 => 'アカウント';

  @override
  String get settingsPageSectionsText6 => '文字サイズ';

  @override
  String get settingsPageShortcutLabelText3 => '左矢印';

  @override
  String get settingsPageBuildText => 'すべてのデータをリセット';

  @override
  String get settingsPageSectionsSwitchRow => 'スマートナビゲーション';

  @override
  String get settingsPageAutoCheckSetState2 => '接続失敗';

  @override
  String get followSystem => 'システムに従う';

  @override
  String get settingsPageOpenRepoToast => '開けませんでした';

  @override
  String get settingsPageEditAudioTypePreferenceText => '既定値に戻す';

  @override
  String get settingsPageSectionsText7 => '表示倍率';

  @override
  String get settingsPageBuildText2 => 'リセットの確認';

  @override
  String get settingsPageSectionsTitle5 => '更新を確認';

  @override
  String get targetLanguage => '翻訳先言語';

  @override
  String get languageAndTranslation => '言語と翻訳';

  @override
  String get settingsPageSectionsSwitchRow2 => '歌詞ライブラリを公開';

  @override
  String get settingsPageSectionsSwitchRow3 => 'クリップボード検出';

  @override
  String get settingsPageShortcutConflictText3 => '再生 / 一時停止';

  @override
  String get settingsPageSectionsTitle6 => '巻き戻しのショートカット';

  @override
  String get settingsPageSectionsSwitchRow4 => '効果音の優先設定';

  @override
  String get settingsPageSectionsTitle7 => '早送りのショートカット';

  @override
  String get settingsPageOnVersionTapText2 => '開発者モード';

  @override
  String get settingsPageSectionsSub => 'アカウント未設定';

  @override
  String get settingsPageRowSub => '設定を開く';

  @override
  String get settingsPageSectionsTitle8 => '音声形式の優先順位';

  @override
  String get settingsPageSectionsText8 => 'モデル一覧を取得';

  @override
  String get settingsPageProxySettingsTooltip => 'プロキシURLをクリア';

  @override
  String get settingsPageSectionsTitle9 => '前のトラックのショートカット';

  @override
  String get settingsPageSectionsTitle10 => 'バッテリー最適化を無効化';

  @override
  String get settingsPageSectionsSwitchRow5 => 'オーディオフォーカスを無視';

  @override
  String get settingsPageSectionsSwitchRow6 => '更新を自動確認';

  @override
  String get settingsPageMediaCacheLimitRowText => 'メディアキャッシュの上限';

  @override
  String get settingsPageSectionsTitle11 => '次のトラックのショートカット';

  @override
  String get translationTargetLanguage => '翻訳先の言語';

  @override
  String get followInterfaceLanguage => '表示言語に従う';

  @override
  String get followInterfaceLanguageShort => '画面に従う';

  @override
  String get translationTargetSimplifiedChinese => '簡体字中国語';

  @override
  String get translationTargetTraditionalChinese => '繁体字中国語';

  @override
  String get settingsPageSectionsText9 => 'カスタムサイトを追加';

  @override
  String get settingsPageSectionsTitle12 => 'アプリをリセット';

  @override
  String get settingsPageProxySettingsSwitchRow => 'HTTPプロキシ';

  @override
  String get settingsPageAiModelInputTooltip => '検出されたモデルを選択';

  @override
  String get settingsPageSectionsTitle13 => 'ショートカットを既定値に戻す';

  @override
  String get settingsPageSectionsSwitchRow7 => '再生位置を記憶しない';

  @override
  String get settingsPageSectionsSection6 => '歌詞とデスクトップ歌詞';

  @override
  String settingsPageSectionsToast(String e) {
    return '接続に失敗しました：$e';
  }

  @override
  String get settingsPageSectionsToast2 => '接続を確認中…';

  @override
  String get settingsPageSectionsSwitchRow8 => 'ヘッドホン切断時に一時停止';

  @override
  String get settingsPageSectionsTitle14 => '再生 / 一時停止のショートカット';

  @override
  String get settingsPageSectionsSub2 => '更新サービスを手動で確認';

  @override
  String get settingsPageSectionsSwitchRow9 => '歌詞ウィンドウを最前面に表示';

  @override
  String get settingsPageAiModelInputTooltip2 => '先にモデル一覧を取得してください';

  @override
  String get settingsPageProxySettingsHelperText => '空欄の場合はプロキシを使用しません';

  @override
  String get settingsPageLabelsLabels => 'OpenAI互換';

  @override
  String get settingsPageSectionsSwitchRow10 => 'ウィンドウを閉じてもトレイに常駐';

  @override
  String get settingsPageDetectOpenAiModelsToast => 'モデル一覧を取得中…';

  @override
  String get settingsPageSectionsSwitchRow11 => '通知のメディア操作を非表示';

  @override
  String get settingsPageSectionsSub3 => '中国語の歌詞を自動変換';

  @override
  String get sourceAndTargetLanguage => '翻訳元 / 翻訳先の言語';

  @override
  String get settingsPageDetectOpenAiModelsToast2 => '先にAPI URLを入力してください';

  @override
  String get settingsPageSectionsSwitchRow12 => 'タイマー終了時にシステムリソースを解放';

  @override
  String get settingsPagePlaybackShortcutRowSub => 'プレイヤーページにフォーカスがあるときに有効';

  @override
  String get settingsPageAiModelInputHintText => 'モデル名を入力、または一覧から選択';

  @override
  String get settingsPageSectionsSub4 => 'システムによるバックグラウンド再生の中断を防止';

  @override
  String get settingsPageStatusStatus => 'URLを保存しました。有効にすると適用されます';

  @override
  String settingsPageLockRowTitle(String label) {
    return '$labelの歌詞をロック';
  }

  @override
  String settingsPageDetectOpenAiModelsToast3(String e) {
    return 'モデル一覧の取得に失敗しました：$e';
  }

  @override
  String get settingsPageSectionsToast3 => 'DeepLを確認中…';

  @override
  String get settingsPageSectionsSwitchRow13 => '効果音ありのフォルダーを優先';

  @override
  String settingsPageSectionsToast4(String e) {
    return '歌詞ライブラリの公開停止に失敗しました：$e';
  }

  @override
  String settingsPageSectionsToast5(String e) {
    return '歌詞ライブラリを公開できませんでした：$e';
  }

  @override
  String get settingsPageSectionsSwitchRow14 => '最適なフォルダーを自動で開く';

  @override
  String settingsPageSectionsToast6(String e) {
    return 'DeepLへの接続に失敗しました：$e';
  }

  @override
  String get settingsPageSectionsSwitchRow15 => 'コピーしたRJリンクを自動検出';

  @override
  String get settingsPageSectionsSwitchRow16 => 'タイマー終了時にロック画面のメディア操作と通知を消去';

  @override
  String get settingsPageSectionsSwitchRow17 => '起動3秒後に更新サービスを確認';

  @override
  String settingsPageSectionsToast7(String r) {
    return 'DeepL接続成功：$r';
  }

  @override
  String get settingsPageOnVersionTapText3 => '本当に開発者モードがあると思いましたか？';

  @override
  String get settingsPageProxySettingsHelperText2 => '編集するにはHTTPプロキシを有効にしてください';

  @override
  String get settingsPageSectionsSwitchRow18 => '有線・Bluetoothヘッドホン切断時に自動で一時停止';

  @override
  String get settingsPageSectionsSwitchRow19 => '他のアプリと同時に再生し、中断を防止';

  @override
  String get settingsPageSectionsSwitchRow20 => '再生中の通知にメディア操作を表示しない';

  @override
  String get settingsPageAiModelInputHintText2 => '例：gpt-4o-mini';

  @override
  String get settingsPageSectionsSwitchRow21 => 'メディア通知にプロジェクトのロゴを使用';

  @override
  String settingsPageBuildText3(String count) {
    return 'リセットの確認（$count秒）';
  }

  @override
  String get settingsPageSectionsSub5 => 'ローカルデータをすべて消去し、初期設定に戻す';

  @override
  String get settingsPageSectionsSub6 => '5～60秒、5秒刻み';

  @override
  String settingsPageEditPlaybackShortcutToast(String conflict) {
    return 'このキーはすでに$conflictに割り当てられています';
  }

  @override
  String get settingsPageDetectOpenAiModelsFormatException =>
      'レスポンスにdata[].idが含まれていません';

  @override
  String get settingsPageSectionsInput => 'APIキー（ローカルサービスでは省略可）';

  @override
  String get settingsPageConfirmResetText => 'リセット完了：アカウントとローカルデータをすべて消去しました';

  @override
  String get settingsPageRequestBatteryIgnoreToast =>
      'システム設定でバッテリー最適化の対象外にしてください';

  @override
  String get settingsPageStatusStatus2 => '有効：HTTPプロキシURLを入力してください';

  @override
  String get settingsPageMediaCacheLimitRowText2 =>
      'オンライン再生のバッファのみ制限します。ダウンロードには影響しません';

  @override
  String get settingsPageSectionsSwitchRow22 =>
      'ウィンドウを閉じるとバックグラウンド処理を停止し、アプリを終了';

  @override
  String get settingsPageSectionsSub7 => 'バックグラウンド再生のバッテリー最適化は無効です';

  @override
  String get settingsPageSectionsInput2 => 'APIベースURL';

  @override
  String get settingsPageSectionsInput3 => 'DeepL Free APIキー';

  @override
  String settingsPageSectionsSub8(String asmrUser) {
    return 'アカウント：$asmrUser';
  }

  @override
  String get settingsPageSectionsSwitchRow23 =>
      'バックグラウンドで再生を継続。システムトレイからウィンドウを復元できます';

  @override
  String get settingsPageSectionsSwitchRow24 => '再起動後に前回のトラックを復元し、先頭から再生';

  @override
  String get settingsPageSectionsSwitchRow25 => '読み取り専用APIサービス · ポート2377';

  @override
  String get settingsPageLockRowSub2 => 'ロック中：歌詞はクリックに反応しません。設定で解除できます';

  @override
  String get settingsPageStatusStatus3 => 'HTTPプロキシのみ対応。すべてのネットワーク要求に適用';

  @override
  String get settingsPageSectionsSwitchRow26 => '実際のジャケット画像の代わりにプロジェクトのロゴを表示';

  @override
  String settingsPageDetectOpenAiModelsToast4(String length) {
    return 'モデルを$length件検出しました';
  }

  @override
  String settingsPageOnVersionTapToast(String value) {
    return '開発者モードまであと$value回';
  }

  @override
  String settingsPageStatusStatus4(String trim) {
    return '有効：$trim';
  }

  @override
  String get settingsPageSectionsInput4 => 'deepl.comで無料キーを取得（api-free）';

  @override
  String get settingsPageSectionsSub9 => 'Space / PageUp / PageDown / 左右矢印';

  @override
  String settingsPageAiModelInputHelperText(String length) {
    return '検出されたモデル：$length';
  }

  @override
  String get settingsPageSectionsSub10 =>
      'Google / Microsoft：無料 · DeepL：無料キー · OpenAI互換';

  @override
  String get settingsPageSectionsInput5 =>
      'https://api.openai.com/v1 または http://127.0.0.1:11434/v1';

  @override
  String settingsPageSectionsSub11(
    String translationSourceLabel,
    String translationTargetLabel,
  ) {
    return '$translationSourceLabel → $translationTargetLabel';
  }

  @override
  String settingsPageNextKeyIdText(String shortcutLabel) {
    return '現在のキー：$shortcutLabel\n\n新しいキーを1つ押してください';
  }

  @override
  String get settingsPageBuildText4 =>
      'すべてのローカルデータを完全に削除します：\n\n· ASMR.ONEアカウントとカスタムサイト設定\n· お気に入り / 再生履歴 / プレイリスト / ブロックリスト\n· 翻訳、イコライザー、デスクトップ歌詞、スリープタイマーを含むすべての設定\n\n続行しますか？';

  @override
  String get mark => 'マーク';

  @override
  String get confirm => '確認';

  @override
  String get refresh => '更新';

  @override
  String get workPageBuildLabel => 'レビュー';

  @override
  String get translate => '翻訳';

  @override
  String get workPageRefreshWorkToast => '更新しました';

  @override
  String get workPageBuildTooltip => '前の画像';

  @override
  String get workPageBuildText => 'お気に入り登録済み';

  @override
  String get workPageBuildText2 => '翻訳中';

  @override
  String get workPageBuildTooltip2 => '次の画像';

  @override
  String get workPageLanguageEditionsButtonText => '言語';

  @override
  String get workPageSimilarWorksSliversText => '類似作品';

  @override
  String get workPageBuildText3 => 'トラック';

  @override
  String get workPageConfirmedText => '進捗マークを削除';

  @override
  String get workPageConfirmedText2 => '作品を削除';

  @override
  String get workPageRefreshWorkToast2 => '更新に失敗しました';

  @override
  String get workPageShowTextViewerTooltip => '文字コードを変更';

  @override
  String get workPageBuildText4 => '自分のレビュー';

  @override
  String get workPageAddToPlaylistText => '確認';

  @override
  String get workPageBuildHintText => 'レビューを入力…';

  @override
  String get workPageBuildText5 => '翻訳をキャンセル';

  @override
  String get workPageOkText => 'ブロックリストに追加';

  @override
  String get workPageAddToPlaylistText2 => 'プレイリストに追加';

  @override
  String get workPageTranslateTitlesToast => '翻訳をキャンセルしました';

  @override
  String get workPageSelectedText => '声優を選択';

  @override
  String get workPageBuildText6 => 'プレイリストに追加';

  @override
  String get workPageBuildText7 => '選択した項目をダウンロード';

  @override
  String get workPageOpenVideoChooserText => '開き方を選択';

  @override
  String get workPageOpenVideoChooserText2 => '音声として再生';

  @override
  String get workPageSelectedText2 => '翻訳エンジンを切り替え';

  @override
  String get workPageTranslateTitlesToast2 => '不明な翻訳エンジン';

  @override
  String get workPageTranslateTitlesFormatException => '翻訳結果が空です';

  @override
  String get workPageAllFilesRowText => 'すべてのファイルを表示';

  @override
  String get workPageDownloadSelectedToast => 'ダウンロードキューに追加しました';

  @override
  String get workPageAddToPlaylistText3 => 'プレイリスト名を入力';

  @override
  String get workPageOpenVideoChooserText3 => '外部プレイヤーで開く';

  @override
  String workPageDeleteNotify(String e) {
    return '削除に失敗しました：$e';
  }

  @override
  String get workPageBuildLabel2 => '再生キューに追加';

  @override
  String workPageSetProgressToast(String e) {
    return '進捗の記録に失敗しました：$e';
  }

  @override
  String get workPageBuildLabel3 => 'メディアファイルのみ表示';

  @override
  String get workPageTreePlaceholderText => 'この作品にトラックはありません';

  @override
  String workPageTranslateTitlesToast3(String e) {
    return '翻訳に失敗しました：$e';
  }

  @override
  String workPageRateWorkToast(String e) {
    return '評価に失敗しました：$e';
  }

  @override
  String workPageApplyEncodingToast(String e) {
    return 'デコードに失敗しました：$e';
  }

  @override
  String workPageSubmitNotify(String e) {
    return '保存に失敗しました：$e';
  }

  @override
  String get workPageSimilarWorksSliversText2 => '類似作品をさらに読み込む';

  @override
  String get workPageDownloadSelectedToast2 => 'トラックの読み込みが完了していません';

  @override
  String workPageClearRatingToast(String e) {
    return '評価の削除に失敗しました：$e';
  }

  @override
  String get workPageRefreshWorkToast3 => 'ローカルのダウンロード履歴を更新しました';

  @override
  String workPageDownloadSelectedToast3(String e) {
    return 'ダウンロードの追加に失敗しました：$e';
  }

  @override
  String get workPageSimilarWorksSliversText3 => '類似作品をすべて表示しました';

  @override
  String get workPageOpenLanguageEditionToast => 'この言語版を読み込めませんでした';

  @override
  String workPageBuildToast(String e) {
    return 'お気に入りの操作に失敗しました：$e';
  }

  @override
  String get workPageConfirmedText3 => 'この進捗マークを削除しますか？';

  @override
  String workPageSetProgressToast2(String e) {
    return '進捗マークの削除に失敗しました：$e';
  }

  @override
  String get workPageBuildLabel4 => 'DLsiteを開く';

  @override
  String get workPageAddToPlaylistToast => '先にファイルまたはフォルダーを選択してください';

  @override
  String get workPageBuildText8 => 'トラック（フォルダーツリー）';

  @override
  String get workPageBuildLabel5 => 'asmr.oneを開く';

  @override
  String workPageAddToPlaylistToast2(String name) {
    return '「$name」に追加しました';
  }

  @override
  String get workPageAddToServerPlaylistToast => '作品を追加できるのは自分のプレイリストのみです';

  @override
  String get workPageOnMoreActionToast => 'トラックを読み込み中です。お待ちください';

  @override
  String get workPageTreePlaceholderText2 => 'この作品に音声・動画ファイルはありません';

  @override
  String get workPageAddToServerPlaylistToast2 => '作品IDがないため追加できません';

  @override
  String get workPageOpenReviewDialogToast => '作品IDがないためレビューできません';

  @override
  String get workPageDeleteSelectedLocalFilesToast => '選択項目にダウンロード済みファイルがありません';

  @override
  String get workPageDeleteSelectedLocalFilesToast2 =>
      '先に削除するローカルファイルを選択してください';

  @override
  String get workPageOnMoreActionToast2 => 'トラックを読み込めませんでした。更新して再試行してください';

  @override
  String get workPageTreePlaceholderText3 => 'ネットワークに接続できず、トラックを読み込めませんでした';

  @override
  String workPageBuildText9(String dur) {
    return '再生時間 $dur';
  }

  @override
  String get workPageEnginesEngines => 'DeepL（Free APIキー）';

  @override
  String get workPageEnginesEngines2 => 'OpenAI互換（設定可能）';

  @override
  String workPageCopyRjToast(String rj) {
    return '$rjをコピーしました';
  }

  @override
  String get workPageDownloadSelectedToast4 => '先にダウンロードする項目またはフォルダーを選択してください';

  @override
  String get workPageAddToPlaylistToast3 => '選択項目に再生可能な音声ファイルがありません';

  @override
  String get workPageOnMoreActionToast3 => '先に文字起こし・翻訳するメディアファイルを選択してください';

  @override
  String get workPagePlayAsAudioToast => 'SFWモードでは全年齢向け作品のみ再生できます';

  @override
  String get workPageOpenLanguageEditionToast2 => 'SFWモードでは全年齢向け作品のみ開けます';

  @override
  String get workPagePlayFilesToast => '音声ファイルがありません（ファイルストリームの取得にはログインが必要です）';

  @override
  String get workPageEnginesEngines3 => 'Google（無料・キー不要）';

  @override
  String workPageNodeRowToast(String title) {
    return 'ファイル名をコピーしました：$title';
  }

  @override
  String workPageDeleteSelectedLocalFilesToast3(String deleted) {
    return 'ローカルファイルを$deleted件削除しました';
  }

  @override
  String get workPageTranslateTitlesToast4 => '先に設定でAPI URLとモデル名を設定してください';

  @override
  String get workPageEnginesEngines4 => 'Microsoft（無料・キー不要）';

  @override
  String workPageOpenFileToast(String title) {
    return 'この形式のファイルは表示できません：$title';
  }

  @override
  String get workPageEnginesEngines5 => 'Index-Translate（公式API）';

  @override
  String get workPageConfirmDeleteWorkToast =>
      '削除に失敗しました。この作品を使用中のプログラムを閉じて再試行してください';

  @override
  String workPageTranslateTitlesToast5(String length) {
    return 'タイトル$length行を翻訳中…';
  }

  @override
  String get workPageTranslateTitlesToast6 => '先に設定でDeepL Free APIキーを入力してください';

  @override
  String workPageAddToPlaylistText4(String length) {
    return '選択した音声ファイル：$length';
  }

  @override
  String get workPageOnMoreActionToast4 =>
      '選択項目にkikoeta-translへ送信可能なメディアファイルがありません';

  @override
  String workPageTranslateTitlesToast7(String length) {
    return '翻訳完了（タイトル + $lengthトラック）';
  }

  @override
  String workPageOkText2(String t) {
    return 'タグ「$t」をブロックしますか？\nこのタグの作品はホームと検索結果に表示されなくなります。';
  }

  @override
  String workPageConfirmedText4(String title) {
    return '「$title」のローカルファイルをすべて削除しますか？この操作は取り消せません。';
  }

  @override
  String get liked => 'お気に入り登録済み';

  @override
  String get privatePlaylist => '非公開';

  @override
  String get publicPlaylist => '公開';

  @override
  String get sharedByLink => 'リンク共有';

  @override
  String get apiServiceMapPlaylistName => '無題のプレイリスト';

  @override
  String get apiServiceMapWorkVa => 'CV. 不明';

  @override
  String get apiServiceFetchWorkFormatException => '作品詳細の形式が無効です';

  @override
  String get apiServiceFetchPlaylistMetadataFormatException =>
      'プレイリスト詳細の形式が無効です';

  @override
  String get apiServiceFetchAdvancedFilterEntriesValue => '未対応の詳細フィルターです';

  @override
  String get apiServiceFetchAdvancedFilterEntriesFormatException =>
      '詳細フィルターのデータ形式が無効です';

  @override
  String get apiServiceToggleFavoriteException => '作品IDがないためお気に入りに追加できません';

  @override
  String get apiServiceClearReviewRatingException => '作品IDがないため評価を削除できません';

  @override
  String get apiServiceClearReviewProgressException => '作品IDがないため進捗マークを解除できません';

  @override
  String get apiServiceDeleteReviewException => '作品IDがないため進捗マークを削除できません';

  @override
  String get search => '検索';

  @override
  String clipboardWatcherCheckText(String rj) {
    return '$rjを検出しました。タップして検索';
  }

  @override
  String get desktopLyricsOverlayEnsureWindowToNativeUtf16 =>
      'Kikoeta デスクトップ歌詞';

  @override
  String get downloadServiceDownloadFileHttpException => 'ダウンロードしたファイルが空です';

  @override
  String get downloadServiceRunStateError => 'ダウンロード可能なファイルはありません';

  @override
  String get downloadServiceRunStateError2 => 'ダウンロードURLが空です';

  @override
  String get downloadTransferDownloadToFileHttpException =>
      'ダウンロードのレスポンスが不完全です';

  @override
  String get downloadTransferDownloadToFileHttpException2 =>
      'ダウンロードチャンクの長さが変わりました';

  @override
  String get downloadTransferDownloadToFileHttpException3 =>
      'ダウンロードしたファイルの長さを検証できませんでした';

  @override
  String get downloadTransferDownloadToFileHttpException4 =>
      'ダウンロードのレスポンスのバイト範囲が一致しません';

  @override
  String get downloadTransferDownloadToFileHttpException5 =>
      'ダウンロードのレスポンスが宣言されたファイル長を超えています';

  @override
  String get downloadTransferDownloadToFileHttpException6 =>
      'ダウンロードのレスポンスのContent-Encodingがidentityではありません';

  @override
  String downloadTransferDownloadToFileHttpException7(String status) {
    return 'ダウンロードに失敗しました：HTTP $status';
  }

  @override
  String get ktServiceNormalizeEndpointFormatException =>
      'IP/ドメイン:ポートの形式で入力してください';

  @override
  String get ktServiceDecodeFormatException =>
      'kikoeta-translから無効なレスポンスが返されました';

  @override
  String get ktServiceNormalizeEndpointFormatException2 =>
      'kikoeta-translのIP/ドメインとポートを入力してください';

  @override
  String ktServiceErrorMessageText(String statusCode) {
    return 'kikoeta-translへの要求に失敗しました（HTTP $statusCode）';
  }

  @override
  String get lyricsLibraryRemoteClientValidateWorkIdFormatException =>
      '作品IDが無効です';

  @override
  String get lyricsLibraryRemoteClientFetchWorksFormatException =>
      'リモート歌詞ライブラリのページネーションカーソルが無効です';

  @override
  String get lyricsLibraryRemoteClientFetchWorksFormatException2 =>
      'リモート歌詞ライブラリから作品一覧が返されませんでした';

  @override
  String get lyricsLibraryRemoteClientFetchLyricsFormatException =>
      'リモート作品に歌詞ファイル一覧がありません';

  @override
  String get lyricsLibraryRemoteClientFetchLyricsFormatException2 =>
      'リモート作品に利用可能な歌詞ファイルがありません';

  @override
  String get lyricsLibraryRemoteClientGetJsonFormatException =>
      'リモート歌詞ライブラリから無効な形式のデータが返されました';

  @override
  String get lyricsLibraryRemoteClientNormalizeBaseUrlFormatException =>
      '有効なHTTPまたはHTTPS URLを入力してください';

  @override
  String lyricsLibraryRemoteClientGetJsonHttpException(String statusCode) {
    return 'リモート歌詞ライブラリからHTTP $statusCodeが返されました';
  }

  @override
  String get lyricsLibraryServiceExtractArchivePhase => '展開中';

  @override
  String get lyricsLibraryServiceCopyTreePhase => 'コピー中';

  @override
  String get lyricsLibraryServiceRemoveRemoteLibraryStateError =>
      'このリモートライブラリはインポートされていません';

  @override
  String get lyricsLibraryServiceSaveTranslatedLyricsArgumentError =>
      '未対応の歌詞形式です';

  @override
  String get lyricsLibraryServiceSaveTranslatedLyricsArgumentError2 =>
      '有効なタイムスタンプが含まれていません';

  @override
  String get lyricsLibraryServiceImportRemoteWorkFormatException =>
      'リモート作品に有効な歌詞ファイルがありません';

  @override
  String get lyricsLibraryServiceSaveTranslatedLyricsArgumentError3 =>
      '保存先は作品ディレクトリ内である必要があります';

  @override
  String get lyricsLibraryServiceSetRemoteLibraryOrderArgumentError =>
      'リモートライブラリ一覧が変更されました。インポート画面を開き直してください';

  @override
  String lyricsLibraryServiceSubscriptionStateError(String message) {
    return '歌詞インポート処理のエラー：$message';
  }

  @override
  String get updateServiceShowUpdateDialogText => '今後表示しない';

  @override
  String get updateServiceShowUpdateDialogText2 => 'ダウンロード';

  @override
  String get updateServiceShowUpdateDialogText3 => '新しいバージョンがあります';

  @override
  String get updateServiceCheckManuallyText => '更新を確認中…';

  @override
  String get updateServiceCheckError => '更新サービスに接続できませんでした';

  @override
  String get updateServiceCheckManuallyToast => '最新バージョンです';

  @override
  String get updateServiceShowUpdateDialogToast => 'ダウンロードページを開けませんでした';

  @override
  String get updateServiceGetUpdateResponseStateError =>
      '更新サービスへの要求が実行されませんでした';

  @override
  String get updateServiceParseReleaseResponseFormatException =>
      '更新レスポンスにバージョン情報がありません';

  @override
  String get updateServiceCheckError2 => '更新サービスから有効なバージョン情報が返されませんでした';

  @override
  String get updateServiceCheckError3 => '更新サービスまたはGitHubに接続できませんでした';

  @override
  String updateServiceShowUpdateDialogText4(
    String version,
    String currentVersion,
  ) {
    return '最新バージョン：$version\n現在のバージョン：$currentVersion';
  }

  @override
  String get pause => '一時停止';

  @override
  String get quit => '終了';

  @override
  String get windowsTrayServiceSetContextMenuLabel => 'ホームを表示';

  @override
  String get sheetsShowSleepSheetSuffixText => '分';

  @override
  String get sheetsBuildText => '適用';

  @override
  String get sheetsShowSiteSheetField => '表示名';

  @override
  String get sheetsShowSiteSheetField2 => 'URL';

  @override
  String get account => 'アカウント';

  @override
  String get sheetsPresetsPresets => 'ボーカル';

  @override
  String get sheetsPresetsPresets2 => '低音';

  @override
  String get sheetsPresetsPresets3 => 'フラット';

  @override
  String get sheetsPresetsPresets4 => 'ポップ';

  @override
  String get sheetsPresetsPresets5 => 'ロック';

  @override
  String get sheetsShowEqSheetText => '無効';

  @override
  String get sheetsShowEqSheetText2 => '適用済み';

  @override
  String get sheetsShowSleepSheetText => 'タイマーをキャンセル';

  @override
  String get sheetsShowSleepSheetText2 => 'タイマーを開始';

  @override
  String get playbackComplete => '再生完了';

  @override
  String get sheetsTimePickerText => '停止時刻';

  @override
  String get sheetsShowSleepSheetLabel => '時刻を指定';

  @override
  String sheetsShowSleepSheetLabel2(String m) {
    return '$m分';
  }

  @override
  String get sheetsShowSleepSheetLabel3 => '指定した分数後';

  @override
  String get sheetsBuildTitle => 'サーバーを選択';

  @override
  String get sheetsShowEqSheetText3 => 'イコライザーを有効にする';

  @override
  String get sheetsShowSiteSheetTitle => 'カスタムサイトを編集';

  @override
  String get sheetsBuildText2 => 'カスタムサイトを管理';

  @override
  String get sheetsShowSleepSheetHintText => '分数を入力';

  @override
  String get sheetsBuildText3 => 'カスタムサイトはありません';

  @override
  String get sheetsBuildText4 => 'カスタムサイトを選択';

  @override
  String get sheetsShowSiteSheetHint => '例：自宅NAS';

  @override
  String get sheetsBuildText5 => '先にカスタムサイトを追加してください';

  @override
  String get sheetsShowOneConfigSheetTitle => 'ASMR.ONEアカウント';

  @override
  String get sheetsShowOneConfigSheetHint => 'asmr.oneアカウント';

  @override
  String get sheetsShowOneConfigSheetSub => 'アカウント情報はローカルにのみ保存されます（デモ）';

  @override
  String get sheetsShowSleepSheetText3 => '現在のプレイリスト終了時に再生を停止して閉じる';

  @override
  String get sheetsShowSleepSheetText4 => '残り時間 · タイマー終了時に再生を停止して終了';

  @override
  String get sheetsBuildSub => '公式サービスまたはカスタムKikoeruサイト';

  @override
  String get sheetsShowEqSheetSub => '10バンド · ±12 dB · 全プラットフォーム対応';

  @override
  String get sheetsShowSleepSheetText5 => '現在のプレイリストの全項目を再生後、再生を停止して閉じる';

  @override
  String get sheetsShowSleepSheetSub =>
      'タイマー終了時に再生を停止してシステムリソースを解放（ロック画面の操作と通知を消去）';

  @override
  String sheetsBuildLabel(String length) {
    return 'カスタム設定（$length）';
  }

  @override
  String playbackSeekSecondsControlBuildTooltip(String label) {
    return '$labelの秒数を減らす';
  }

  @override
  String playbackSeekSecondsControlBuildTooltip2(String label) {
    return '$labelの秒数を増やす';
  }

  @override
  String get name => '名前';

  @override
  String get description => '説明';

  @override
  String get playlistPickerRowsMapEntry => '公開範囲';

  @override
  String get language => '言語';

  @override
  String get confirmAction => '確認';

  @override
  String get create => '作成';

  @override
  String get playlistPickerShowEditorLabelText => '種類';

  @override
  String get playlistPickerRowsMapEntry2 => '作成者';

  @override
  String get playlistPickerRowsMapEntry3 => '更新日時';

  @override
  String get playlistPickerReviewsItemName => 'マイお気に入り';

  @override
  String get playlistPickerRowsMapEntry4 => '再生回数';

  @override
  String get playlistPickerRowsMapEntry5 => '作品数';

  @override
  String get playlistPickerCopyText => 'プレイリスト詳細';

  @override
  String get playlistPickerLinkLabelText => '共有リンク';

  @override
  String get playlistPickerCopyText2 => 'リンクをコピー';

  @override
  String get playlistPickerRowsMapEntry6 => '作成日時';

  @override
  String get playlistPickerBuildText => 'プレイリストを切り替え';

  @override
  String get playlistPickerPlaylistItemTooltip => 'プレイリストを削除';

  @override
  String get playlistPickerPlaylistItemTooltip2 => 'プレイリストを編集';

  @override
  String get playlistPickerShowEditorText => 'プレイリストを作成';

  @override
  String get playlistPickerLinkText => 'プレイリストをインポート';

  @override
  String get playlistPickerOkText => 'プレイリストを削除';

  @override
  String playlistPickerRemoveLikedToast(String e) {
    return '削除に失敗しました：$e';
  }

  @override
  String playlistPickerCreatePlaylistToast(String e) {
    return '作成に失敗しました：$e';
  }

  @override
  String get playlistPickerLoadSetState => 'プレイリストを読み込めませんでした';

  @override
  String get playlistPickerImportPlaylistToast => 'プレイリストのリンクを認識できません';

  @override
  String get playlistPickerReviewsItemSubtitle => '自分のレビュー / お気に入り（全作品）';

  @override
  String get playlistPickerCreatePlaylistToast2 => '作成しましたが、一覧にプレイリストが見つかりません';

  @override
  String get playlistPickerImportPlaylistToast2 => '追加しましたが、まだ一覧に表示されていません';

  @override
  String playlistPickerSubtitleSubtitle(String worksCount) {
    return '作品数：$worksCount';
  }

  @override
  String get playlistPickerLinkText2 => '共有プレイリストのリンクを貼り付けてマイプレイリストに追加します。';

  @override
  String playlistPickerOkText2(String name) {
    return '「$name」を削除しますか？この操作は取り消せません。';
  }

  @override
  String playlistPickerOkText3(String name) {
    return '「$name」をマイプレイリストから削除しますか？';
  }

  @override
  String playlistPickerSubtitleSubtitle2(String worksCount, String replaceAll) {
    return '作品数：$worksCount · $replaceAll';
  }

  @override
  String get widgetsFilterButtonTooltip => 'フィルター';

  @override
  String get widgetsFilterButtonLabel => '字幕付きのみ';

  @override
  String get allAges => '全年齢';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter => '言語を除外';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter2 =>
      'サークルを検索';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter3 => '声優を検索';

  @override
  String get widgetsBuildBuilder => 'AI歌詞';

  @override
  String get widgetsBuildBuilder2 => 'リモート歌詞';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter4 =>
      '言語で絞り込み';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter5 => 'タグを除外';

  @override
  String get widgetsBuildBuilder3 => 'ローカル歌詞';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter6 =>
      'サークルを除外';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter7 => '声優を除外';

  @override
  String get widgetsInputRowMessage => '詳細検索';

  @override
  String get widgetsHistoryPanelText => '検索履歴';

  @override
  String get widgetsBuildBuilder4 => 'オンライン歌詞';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter8 => 'タグを検索';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter9 =>
      '年齢区分で絞り込み';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter10 =>
      '年齢区分を除外';

  @override
  String get widgetsBuildText => '詳細検索パラメーター';

  @override
  String get widgetsHistoryPanelText2 => '検索履歴はありません';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter11 =>
      '低投票数のタグを含める';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter12 =>
      '低投票数のタグを除外';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter13 =>
      '評価が指定値より高い';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter14 =>
      '販売数が指定値より多い';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter15 =>
      '価格が指定値より高い';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter16 =>
      '再生時間が指定値より短い';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter17 =>
      '再生時間が指定値より長い';

  @override
  String widgetsHistoryPanelText3(String value) {
    return '「$value」を削除しました';
  }

  @override
  String get playbackSpeed => '再生速度';

  @override
  String get playbackSpeedDescription => '音程を維持したまま再生速度を変更';

  @override
  String get playbackSpeedEntry => '速度調整を表示';

  @override
  String get playbackSpeedEntryDescription => 'プレイヤーに速度調整を表示。無効にすると1倍速に戻ります';

  @override
  String get audioChannels => 'チャンネル';

  @override
  String get audioChannelsDescription => '左右を入れ替えるか、両チャンネルを統合して両耳で同じ音声を再生';

  @override
  String get audioChannelsOriginal => '元の音声';

  @override
  String get audioChannelsSwap => '左右を入れ替え';

  @override
  String get audioChannelsMerge => 'チャンネルを統合';

  @override
  String get widgetsInputRowHintText => 'RJ番号、タイトル、声優を検索…';

  @override
  String get batchTranslation => '一括翻訳';

  @override
  String get batchTranslationPreparing => 'トラックと既存の歌詞を照合中…';

  @override
  String batchTranslationFailed(String error) {
    return '準備に失敗しました：$error';
  }

  @override
  String batchTranslationSummary(String added, String skipped, String failed) {
    return '$addedトラックをキューに追加、$skipped件をスキップ、$failed作品で失敗';
  }

  @override
  String batchTranslationExistingLyrics(String count) {
    return '$countトラックに歌詞があります。処理方法を選んでください。';
  }

  @override
  String get batchTranslationSkipExisting => '歌詞があるものをスキップ';

  @override
  String get batchTranslationRetranslate => '再翻訳';

  @override
  String get translationSourceLanguage => '翻訳元の言語';

  @override
  String get translationSourceAuto => '自動';

  @override
  String get translationSourceJapanese => '日';

  @override
  String get translationSourceChinese => '中';

  @override
  String get translationSourceEnglish => '英';

  @override
  String get lyricsSkipEmpty => '歌詞の空行をスキップ';

  @override
  String get lyricsSkipEmptyDescription => '次の歌詞まで前の行を表示する';

  @override
  String get androidLyricsHideWhenPaused => '一時停止中はデスクトップ歌詞を非表示';

  @override
  String get androidLyricsHideWhenPausedDescription => '一時停止・停止中は非表示にし、再生時に表示';

  @override
  String get lockDesktopLyrics => '歌詞をロック';

  @override
  String get unlockDesktopLyrics => '歌詞のロックを解除';

  @override
  String get showDesktopLyrics => '歌詞を表示';

  @override
  String get hideDesktopLyrics => '歌詞を非表示';

  @override
  String get androidLyricsLockDescription => 'ロック中はタッチを透過し、縦横の向きで共通';

  @override
  String get homeRandomSort => 'ランダム';

  @override
  String get favoritesSearch => 'お気に入りを検索';

  @override
  String get favoritesSearchHint => 'タイトルまたはRJ番号で検索';
}
