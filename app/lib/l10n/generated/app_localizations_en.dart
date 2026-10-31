// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get dataExport => 'Export local data';

  @override
  String get dataImport => 'Import local data';

  @override
  String get dataScope =>
      'Favorites, playlists, blacklist, history and preferences. Excludes downloads, lyrics libraries, passwords and keys.';

  @override
  String get dataImportConfirm =>
      'Replace local data within the backup scope? A local recovery copy is saved first. Playback continues.';

  @override
  String get dataExportDone => 'Data exported';

  @override
  String get dataImportDone => 'Data imported';

  @override
  String get dataOperationFailed => 'Operation failed. Please retry.';

  @override
  String get backupInvalid => 'Invalid, incompatible or damaged backup';

  @override
  String get backupTooLarge => 'Backup exceeds the 16 MB limit';

  @override
  String get webdavTitle => 'WebDAV cloud sync';

  @override
  String get webdavUrl => 'Server URL';

  @override
  String get webdavUsername => 'Account';

  @override
  String get webdavPassword => 'App password';

  @override
  String get webdavFolder => 'Sync folder';

  @override
  String get webdavAuto => 'Sync automatically every hour';

  @override
  String get webdavAutoHint =>
      'Checks hourly while the app runs, and checks when due on resume. Uploads only changes.';

  @override
  String get webdavTest => 'Test connection';

  @override
  String get webdavTestDone => 'Connected. Test file deleted.';

  @override
  String get webdavSyncNow => 'Sync now';

  @override
  String get webdavUploadOverwrite => 'Upload local data and overwrite cloud';

  @override
  String get webdavDownloadOverwrite => 'Overwrite local data with cloud data';

  @override
  String get webdavMergeData => 'Merge local and cloud data';

  @override
  String get webdavMergeHint => 'Combines favorites, blacklist, playlists and history. Keeps local preferences on conflicts.';

  @override
  String get webdavSyncDone => 'Sync complete';

  @override
  String get webdavNever => 'Not synced yet';

  @override
  String get webdavSyncing => 'Syncing…';

  @override
  String get webdavConflict =>
      'Both local and cloud data changed. Choose which version to keep.';

  @override
  String get webdavUseLocal => 'Keep local';

  @override
  String get webdavUseCloud => 'Use cloud';

  @override
  String get webdavConflictConfirm =>
      'The selected version replaces the other copy. A local recovery copy is saved before applying cloud data.';

  @override
  String get webdavInvalidConfig =>
      'Enter an HTTPS URL, account, app password and a single folder name.';

  @override
  String get webdavAuthError =>
      'Authentication failed. Check the account and app password.';

  @override
  String get webdavTimeout => 'Connection timed out. Please retry later.';

  @override
  String get webdavNetworkError =>
      'Network connection failed. Check the network and server URL.';

  @override
  String get webdavRateLimited =>
      'Server rate limit reached. Please retry later.';

  @override
  String get webdavRequestFailed =>
      'Sync failed. Check the server configuration and retry.';

  @override
  String get webdavNoEtag =>
      'The server has no usable ETag for safely replacing cloud data.';

  @override
  String get webdavNoBackup => 'No cloud backup exists';

  @override
  String get webdavCleanupFailed =>
      'Test file cleanup failed. Check the server connection.';

  @override
  String get webdavBusy => 'A data operation is in progress. Please wait.';

  @override
  String get appName => 'Kikoeta';

  @override
  String get playbackShortcuts => 'Keyboard shortcuts';

  @override
  String get dictationQueueTitle => 'Transcription and translation queue';

  @override
  String get dictationQueueClear => 'Clear queue';

  @override
  String get dictationQueueEmpty => 'No tasks';

  @override
  String dictationQueueTracks(String count) {
    return 'Audio files: $count';
  }

  @override
  String dictationQueueActions(String name) {
    return 'Actions for $name';
  }

  @override
  String get dictationQueueJump => 'Move to front';

  @override
  String get dictationQueuePending => 'Pending';

  @override
  String get dictationQueueRunning => 'Processing';

  @override
  String get dictationQueueCompleted => 'Completed';

  @override
  String get dictationQueueFailed => 'Failed';

  @override
  String get dictationQueueCancelled => 'Cancelled';

  @override
  String get dictationQueueDrag => 'Drag to reorder pending tasks';

  @override
  String dictationQueueProcessing(String name) {
    return 'Processing queue batch: $name';
  }

  @override
  String get invertSelection => 'Invert selection';

  @override
  String get traditionalChinese => '繁體中文';

  @override
  String get home => 'Home';

  @override
  String get favorites => 'Favorites';

  @override
  String get more => 'More';

  @override
  String get voiceActor => 'Voice actor';

  @override
  String get circle => 'Circle';

  @override
  String get tag => 'Tag';

  @override
  String get retry => 'Retry';

  @override
  String get advancedFilterPageBuildText => 'Advanced filters';

  @override
  String get advancedFilterPageBuildContentText => 'No data';

  @override
  String get advancedFilterPageBuildContentText2 => 'No matching options';

  @override
  String advancedFilterPageBuildSearchFieldHintText(String placeholder) {
    return 'Search $placeholder…';
  }

  @override
  String get add => 'Add';

  @override
  String get cancel => 'Cancel';

  @override
  String get blacklistPageTypeLabelsTypeLabels => 'RJ ID';

  @override
  String get blacklist => 'Blacklist';

  @override
  String get blacklistPageResultText => 'Add to blacklist';

  @override
  String get blacklistPageResultHintText => 'RJ ID / name to block';

  @override
  String get blacklistPageBuildText =>
      'No blacklist entries\nBlacklisted works are hidden from Home and search';

  @override
  String get local => 'Local';

  @override
  String get network => 'Network';

  @override
  String get password => 'Password';

  @override
  String get dictationTranslationPageWorkCardTitle => 'Work';

  @override
  String get username => 'Username';

  @override
  String get dictationTranslationPageWorkCardText => 'Cancel task';

  @override
  String get dictationTranslationPageInitStateText => 'Ready to start';

  @override
  String get dictationTranslationPageTestConnectionToast => 'Connected';

  @override
  String get dictationTranslationPageLogCardTitle => 'Logs';

  @override
  String get dictationTranslationPageStartUpdate => 'Task failed';

  @override
  String get dictationTranslationPageBuildText =>
      'Transcription and translation';

  @override
  String get dictationTranslationPageConnectionCardTitle =>
      'Service connection';

  @override
  String get dictationTranslationPageConnectionCardInputDecoration =>
      'Service URL';

  @override
  String get dictationTranslationPageConnectionCardTooltip => 'Show password';

  @override
  String get dictationTranslationPageConnectionCardTooltip2 => 'Hide password';

  @override
  String get testConnection => 'Test connection';

  @override
  String get dictationTranslationPageProgressCardTitle =>
      'Transcription progress';

  @override
  String get dictationTranslationPageStartUpdate2 => 'Task queued';

  @override
  String get dictationTranslationPageStartUpdate3 => 'Task cancelled';

  @override
  String get dictationTranslationPageWorkCardTitle2 => 'Audio to process';

  @override
  String get dictationTranslationPageWorkCardText2 => 'Cancelling…';

  @override
  String get dictationTranslationPageStartUpdate4 =>
      'Transcription and translation complete';

  @override
  String get dictationTranslationPageSyncCachedResultsUpdate =>
      'Cache sync complete';

  @override
  String get dictationTranslationPageConnectionCardText =>
      'Use default credentials';

  @override
  String get dictationTranslationPageWorkCardText3 =>
      'Start transcription and translation';

  @override
  String get dictationTranslationPageStartUpdate5 => 'Saving to lyrics library';

  @override
  String dictationTranslationPageStartAppendLog(String error) {
    return 'Error: $error';
  }

  @override
  String get dictationTranslationPageConnectionCardInputDecoration2 =>
      'Local service URL (fixed)';

  @override
  String get dictationTranslationPageConnectionCardText2 =>
      'Android devices only support network connections';

  @override
  String dictationTranslationPageTestConnectionToast2(String error) {
    return 'Connection failed: $error';
  }

  @override
  String dictationTranslationPageCancelToast(String error) {
    return 'Cancellation failed: $error';
  }

  @override
  String get dictationTranslationPageConnectionCardText3 =>
      'Download from GitHub';

  @override
  String dictationTranslationPageSyncCachedResultsAppendLog(String error) {
    return 'Cache sync failed: $error';
  }

  @override
  String dictationTranslationPageStartToast(String error) {
    return 'Transcription and translation failed: $error';
  }

  @override
  String dictationTranslationPageSyncCachedResultsToast(String skipped) {
    return ', duplicates skipped: $skipped';
  }

  @override
  String get dictationTranslationPageStartUpdate6 =>
      'Connecting to kikoeta-transl';

  @override
  String get dictationTranslationPageStartException =>
      'kikoeta-transl task failed';

  @override
  String get dictationTranslationPageBuildTooltip =>
      'Sync kikoeta-transl cache';

  @override
  String get dictationTranslationPageConnectionCardText4 =>
      'Need to install kikoeta-transl?';

  @override
  String get dictationTranslationPageTestConnectionFormatException =>
      'kikoeta-transl service is not ready';

  @override
  String get dictationTranslationPageLogCardSelectableText =>
      'Waiting for kikoeta-transl logs…';

  @override
  String get dictationTranslationPageStartToast2 =>
      'Start transcription and translation from More on the work details page';

  @override
  String get dictationTranslationPageStartToast3 =>
      'Return to the work details page and select media files to transcribe and translate';

  @override
  String get dictationTranslationPageStartFormatException =>
      'kikoeta-transl did not return a task ID';

  @override
  String get dictationTranslationPageOpenKikoetaTranslDownloadToast =>
      'Could not open the kikoeta-transl project page';

  @override
  String get dictationTranslationPageServiceFormatException =>
      'The kikoeta-transl username cannot contain a colon';

  @override
  String get dictationTranslationPageCancelAppendLog =>
      'Cancellation request sent to kikoeta-transl';

  @override
  String get dictationTranslationPageServiceFormatException2 =>
      'Enter your kikoeta-transl username and password';

  @override
  String get dictationTranslationPageSyncCachedResultsToast2 =>
      'No cached kikoeta-transl results to sync';

  @override
  String get dictationTranslationPageStartFormatException2 =>
      'kikoeta-transl did not return any usable LRC files';

  @override
  String dictationTranslationPageProgressCardText(String savedFiles) {
    return ' · Saved: $savedFiles';
  }

  @override
  String dictationTranslationPageStartToast4(String missing) {
    return 'Audio files without download URLs: $missing. Sign in to the work server and try again';
  }

  @override
  String dictationTranslationPageStartAppendLog2(String jobId, String length) {
    return 'Created task $jobId with $length audio files';
  }

  @override
  String get dictationTranslationPageConnectionCardText5 =>
      'Download and start kikoeta-transl to transcribe and translate locally or over the network.';

  @override
  String dictationTranslationPageSyncCachedResultsAppendLog2(
    String jobId,
    String name,
    String error,
  ) {
    return 'Failed to sync $jobId/$name: $error';
  }

  @override
  String dictationTranslationPageSyncCachedResultsAppendLog3(
    String saved,
    String skipped,
    String failed,
  ) {
    return 'Cache sync complete: saved $saved, duplicates skipped $skipped, failed $failed';
  }

  @override
  String dictationTranslationPageSyncCachedResultsAppendLog4(String length) {
    return 'Syncing $length cached kikoeta-transl tasks';
  }

  @override
  String get dictationTranslationPageWorkCardText4 =>
      'To create a task, open a work details page and choose Transcription and translation from More in the upper right. If no files are selected, files are matched automatically, preferring versions without sound effects and keeping separate bonus tracks. You can also select files manually first.';

  @override
  String get dictationAutoSelectionHint =>
      'Files matched automatically: versions without sound effects are preferred, and separate bonus tracks are kept. Check the media list; to adjust it, return to the work page and select files manually.';

  @override
  String dictationTranslationPageStartAppendLog3(String rj, String savedFiles) {
    return 'Saved $savedFiles lyrics files under $rj';
  }

  @override
  String dictationTranslationPageWorkCardText5(String rj, String length) {
    return '$rj · Media files selected on the work details page: $length';
  }

  @override
  String dictationTranslationPageStartToast5(String savedFiles, String rj) {
    return 'Done: saved $savedFiles lyrics files to the $rj lyrics library';
  }

  @override
  String dictationTranslationPageSyncCachedResultsToast3(
    String saved,
    String value,
  ) {
    return 'Sync complete: saved $saved lyrics files$value';
  }

  @override
  String dictationTranslationPageProgressCardText2(
    String finishedFiles,
    String length,
    String value,
  ) {
    return 'Processed $finishedFiles / $length$value';
  }

  @override
  String get selectMultiple => 'Select multiple';

  @override
  String get selectAll => 'Select all';

  @override
  String get downloads => 'Downloads';

  @override
  String get downloading => 'Downloading';

  @override
  String get downloadsPageStatusStatus => 'Waiting';

  @override
  String get downloadsPageStatusStatus2 => 'Completed';

  @override
  String get downloadsPageStatusStatus3 => 'Paused';

  @override
  String get exitSelection => 'Exit selection';

  @override
  String get downloadsPageBuildTooltip => 'Close search';

  @override
  String get downloadsPageStatusStatus4 => 'Download failed';

  @override
  String get downloadsPageStatusStatus5 => 'Queued';

  @override
  String get deselectAll => 'Deselect all';

  @override
  String get downloadsPageBuildText => 'Download files';

  @override
  String get downloadsPageBuildText2 => 'No downloaded audio works';

  @override
  String get downloadsPageBuildText3 => 'Full file tree';

  @override
  String get downloadsPageBuildTooltip2 => 'Delete selected works';

  @override
  String get downloadsPageBuildText4 => 'No downloaded files';

  @override
  String get downloadsPageBuildTooltip3 => 'Search downloaded works';

  @override
  String get downloadsPageBuildTooltip4 => 'Start/pause all';

  @override
  String get downloadsPageBuildTooltip5 => 'Delete selected download records';

  @override
  String get downloadsPageFileNameFileName => 'No files downloading';

  @override
  String downloadsPageProgressTextText(String percent) {
    return 'Downloading $percent%';
  }

  @override
  String downloadsPageBuildText5(String value) {
    return 'Load more ($value)';
  }

  @override
  String downloadsPageBuildText6(String rj, String downloaded, String length) {
    return '$rj  $downloaded/$length files downloaded';
  }

  @override
  String downloadsPageStatusStatus6(String round) {
    return 'Downloading $round%';
  }

  @override
  String get postponed => 'On hold';

  @override
  String get remove => 'Remove';

  @override
  String get all => 'All';

  @override
  String get wantToListen => 'Plan to listen';

  @override
  String get listening => 'Listening';

  @override
  String get listened => 'Finished';

  @override
  String get replay => 'Listen again';

  @override
  String get favoritesPageReviewFilterButtonTooltip => 'Filter by progress';

  @override
  String get favoritesPageLabelLabel => 'Unfavorite';

  @override
  String get loading => 'Loading…';

  @override
  String get favoritesPageReviewSortDropdownTooltip => 'Sort by';

  @override
  String get favoritesPageReviewSortLabelsReviewSortLabels => 'Review count';

  @override
  String get favoritesPageBodyText => 'Tap to retry';

  @override
  String get favoritesPageReviewSortLabelsReviewSortLabels2 => 'Sales';

  @override
  String get favoritesPageBuildTooltip => 'Switch playlist';

  @override
  String get favoritesPageReviewSortLabelsReviewSortLabels3 => 'Release date';

  @override
  String get favoritesPageReviewSortLabelsReviewSortLabels4 => 'My rating';

  @override
  String get favoritesPageReviewSortLabelsReviewSortLabels5 => 'Date marked';

  @override
  String get ageRating => 'Age rating';

  @override
  String get favoritesPageInputText => 'Add works';

  @override
  String get favoritesPageBodyText2 => 'All items shown';

  @override
  String get favoritesPageLabelLabel2 => 'Remove from playlist';

  @override
  String get favoritesPagePlaylistHeaderActionsTooltip => 'Copy share link';

  @override
  String favoritesPageAddWorksByRjToast(String e) {
    return 'Failed to add: $e';
  }

  @override
  String get shareLinkCopied => 'Share link copied';

  @override
  String get favoritesPageRemoveSelectedWorksToast =>
      'Could not get the work ID';

  @override
  String get favoritesPageBodyText3 => 'No favorite works yet';

  @override
  String favoritesPageRemoveCurrentLikedPlaylistToast(String e) {
    return 'Failed to unfavorite: $e';
  }

  @override
  String get favoritesPagePlaylistHeaderActionsTooltip2 =>
      'Unfavorite this playlist';

  @override
  String get favoritesPageBodyText4 => 'This playlist has no works yet';

  @override
  String get favoritesPagePlaylistHeaderActionsTooltip3 => 'Add works by RJ ID';

  @override
  String get favoritesPageAddWorksByRjToast2 => 'No RJ IDs found';

  @override
  String favoritesPageSelectionBarText(String count) {
    return 'Selected: $count';
  }

  @override
  String favoritesPageRemoveSelectedWorksToast2(String label, String e) {
    return '$label failed: $e';
  }

  @override
  String get favoritesPageBodyText5 => 'Favorites are hidden in SFW mode';

  @override
  String get favoritesPageBodyText6 =>
      'Failed to load. Make sure you are signed in under Settings';

  @override
  String get favoritesPageOkText => 'Remove this playlist from My playlists?';

  @override
  String favoritesPageAddWorksByRjToast3(String length) {
    return 'Works added: $length';
  }

  @override
  String favoritesPageOkText2(String count, String label) {
    return 'Apply $label to $count works?';
  }

  @override
  String favoritesPageRemoveSelectedWorksToast3(String label, String length) {
    return '$label: $length works';
  }

  @override
  String get favoritesPageInputHintText =>
      'Enter one or more RJ IDs\nFor example: RJ01367541 RJ01417842\nSeparate with new lines, spaces, or commas';

  @override
  String get clear => 'Clear';

  @override
  String get historyPageEntryWorkTitle => 'Unknown work';

  @override
  String get playHistory => 'Playback history';

  @override
  String get historyPageBuildText => 'No playback history';

  @override
  String get historyPageBuildText2 => 'Playback history is hidden in SFW mode';

  @override
  String historyPageFmtTimeText(String padLeft, String padLeft2) {
    return 'Today $padLeft:$padLeft2';
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
  String get homePageServerLabelText => 'Custom';

  @override
  String get homePageLabelsLabels => 'Popular';

  @override
  String get homePageLabelsLabels2 => 'Recommended';

  @override
  String get homePageSortLabelsSortLabels => 'Overall rating';

  @override
  String get homePageSortLabelsSortLabels2 => 'Date added';

  @override
  String get homePageSortLabelsSortLabels3 => 'Price';

  @override
  String get homePageEmptyHintText => 'No works';

  @override
  String get homePageSearchResultsViewText => 'Searching…';

  @override
  String get homePageEmptyHintText2 => 'Loading…';

  @override
  String get homePageGridText => 'All works shown';

  @override
  String get homePageEmptyHintText3 => 'Tap anywhere to retry';

  @override
  String get homePageSearchResultsViewText2 => 'No matching works found';

  @override
  String get homePageSearchResultsViewText3 => 'All search results shown';

  @override
  String get homePageEmptyHintText4 => 'No works match the current filters';

  @override
  String get homePageEmptyHintText5 =>
      'No network connection. Check your network or server settings';

  @override
  String get homePageHeaderTooltip =>
      'SFW mode is on: showing all-ages content only';

  @override
  String get homePageHeaderTooltip2 =>
      'Enable SFW mode (all-ages content only)';

  @override
  String get save => 'Save';

  @override
  String get loginPageBuildLoginText => 'Sign in';

  @override
  String get loginPageShowNoAccountText => 'About accounts';

  @override
  String get loginPageShowNoAccountText2 => 'Got it';

  @override
  String get loginPageBuildSiteConfigTooltip => 'Back to sign in';

  @override
  String get loginPageBuildSiteConfigText => 'Saved sites';

  @override
  String get loginPageBuildSiteConfigHint => 'Site password';

  @override
  String get loginPageShowProxyDialogLabelText => 'Proxy server';

  @override
  String get loginPageBuildLoginText2 => 'I do not have an account';

  @override
  String get loginPageBuildSiteConfigText2 => 'Use this site';

  @override
  String get loginPageBuildSiteConfigText3 => 'Add a new site';

  @override
  String get loginPageBuildSiteConfigText4 => 'Save and continue';

  @override
  String get loginPageShowProxyDialogText => 'Configure network proxy';

  @override
  String get loginPageBuildLoginText3 => 'Configure a custom site';

  @override
  String get loginPageBuildSiteConfigHint2 => 'Site username';

  @override
  String get loginPageShowProxyDialogToast => 'Network proxy enabled';

  @override
  String get loginPageShowProxyDialogToast2 => 'Network proxy disabled';

  @override
  String get loginPageBuildLoginHint => 'one site account';

  @override
  String get loginPageLoginToast => 'Enter your username and password';

  @override
  String get loginPageLoginToast2 => 'Check your network or credentials';

  @override
  String get loginPageShowProxyDialogText2 => 'Use HTTP proxy';

  @override
  String get loginPageBuildLoginText4 => 'Sign in to the one site';

  @override
  String get loginPageShowProxyDialogHelperText =>
      'Only HTTP proxies are supported';

  @override
  String get loginPageBuildSiteConfigHint3 => 'Alias, e.g. Home NAS';

  @override
  String get loginPageSaveNewSiteToast =>
      'Enter an alias, URL, username, and password';

  @override
  String get loginPageShowProxyDialogHintText =>
      'e.g. http://proxy-address:port';

  @override
  String get loginPageBuildSiteConfigText5 =>
      'IP and port supported, e.g. http://192.168.1.100:3000';

  @override
  String loginPageLoginToast3(String value) {
    return 'Sign-in failed: $value';
  }

  @override
  String get loginPageShowNoAccountText3 =>
      'This project does not provide account registration.\n\nYou must obtain your own username and password. This project does not provide ways to obtain them.\n\nOwnership of and responsibility for any content accessed or played with your account in this app remain with the content provider and account holder. This project accepts no responsibility for that content.\n\nAccount information is stored only on your device and is not uploaded to any third-party server.';

  @override
  String get close => 'Close';

  @override
  String get delete => 'Delete';

  @override
  String get remote => 'Remote';

  @override
  String get continueAction => 'Continue';

  @override
  String get online => 'Online';

  @override
  String get importAction => 'Import';

  @override
  String get lyricsLibraryPageBuildNavItem => 'Remote libraries';

  @override
  String get lyricsLibrary => 'Lyrics library';

  @override
  String get lyricsLibraryPageBuildNavItem2 => 'Local files';

  @override
  String get lyricsLibraryPageProceedText => 'Continue import';

  @override
  String get lyricsLibraryPageImportText => 'Cancel import';

  @override
  String get lyricsLibraryPageProgressPhase => 'Preparing import';

  @override
  String get lyricsLibraryPageOkText => 'Deep refresh';

  @override
  String get lyricsLibraryPageOkText2 => 'Delete lyrics';

  @override
  String get lyricsLibraryPageSectionContentText => 'Choose folder';

  @override
  String get lyricsLibraryPageConfirmedText => 'Remove remote library';

  @override
  String get lyricsLibraryPageSectionContentText2 => 'Import remote library';

  @override
  String get lyricsLibraryPageBuildText => 'Import lyrics library';

  @override
  String get lyricsLibraryPageBuildLabel => 'Refresh lyrics library';

  @override
  String get lyricsLibraryPageBuildTooltip => 'Search lyrics library';

  @override
  String get lyricsLibraryPageBuildText2 => 'Importing lyrics';

  @override
  String get lyricsLibraryPageImportText2 => 'Skip existing files';

  @override
  String get lyricsLibraryPageImportText3 => 'Overwrite existing files';

  @override
  String get lyricsLibraryPageOkText3 => 'Remove remote work';

  @override
  String get lyricsLibraryPageProceedText2 => 'Large import';

  @override
  String get lyricsLibraryPageImportText4 => 'Import conflicts found';

  @override
  String get lyricsLibraryPageRemoteSourceListTooltip =>
      'Refresh only this remote library';

  @override
  String get lyricsLibraryPageOkText4 => 'Delete work from lyrics library';

  @override
  String get lyricsLibraryPageBuildLabel2 => 'Refresh all remote libraries';

  @override
  String get lyricsLibraryPageBuildText3 => 'Preparing files…';

  @override
  String get lyricsLibraryPageSelectionDialogTitle => 'Choose lyrics folder';

  @override
  String get lyricsLibraryPageSectionContentText3 => 'Connecting and syncing';

  @override
  String get lyricsLibraryPageSearchFieldHintText => 'Search work ID';

  @override
  String lyricsLibraryPageImportText5(String e) {
    return 'Import failed: $e';
  }

  @override
  String get lyricsLibraryPageRemoteSourceListText =>
      'No remote libraries imported';

  @override
  String get lyricsLibraryPageBuildHint => 'Long press for a deep refresh';

  @override
  String get lyricsLibraryPageBuildText4 => 'Counting lyrics files';

  @override
  String get lyricsLibraryPageScanProgressPhase =>
      'Checking for file conflicts';

  @override
  String get lyricsLibraryPageResultDialogTitle => 'Choose ZIP file';

  @override
  String get lyricsLibraryPageSectionContentText4 => 'Choose ZIP archive';

  @override
  String get lyricsLibraryPageBuildText5 =>
      'Lyrics file count is currently unavailable';

  @override
  String lyricsLibraryPageRefreshText(String error) {
    return 'Refresh failed: $error';
  }

  @override
  String get lyricsLibraryPageShowFilesText =>
      'No lyrics or subtitle files available';

  @override
  String get lyricsLibraryPageBuildText6 =>
      'No data. Tap Import in the upper right';

  @override
  String get lyricsLibraryPageShowFilesText2 =>
      'Failed to load lyrics files. Try again';

  @override
  String lyricsLibraryPageReorderSetState(String error) {
    return 'Failed to change priority: $error';
  }

  @override
  String get lyricsLibraryPageSectionContentLabelText => 'HTTP / HTTPS URL';

  @override
  String get lyricsLibraryPageBuildHint2 =>
      'Sync work indexes from all imported remote libraries';

  @override
  String get lyricsLibraryPageImportText6 =>
      'The selected folder contains no lyrics or subtitle files';

  @override
  String get lyricsLibraryPageSectionContentText5 =>
      'Choose lyrics files or an archive to import.';

  @override
  String get lyricsLibraryPageSectionContentText6 =>
      'Enter the address of a device broadcasting its lyrics library.';

  @override
  String lyricsLibraryPageRefreshOneSetState(String url, String error) {
    return 'Failed to refresh $url: $error';
  }

  @override
  String lyricsLibraryPageRemoveRemoteLibrarySetState(
    String url,
    String error,
  ) {
    return 'Failed to remove $url: $error';
  }

  @override
  String lyricsLibraryPageBuildText7(String directoryCount) {
    return 'Directories: $directoryCount';
  }

  @override
  String lyricsLibraryPageBuildText8(String length) {
    return 'Items: $length';
  }

  @override
  String get lyricsLibraryPageBuildText9 =>
      'No remote works. Tap Import in the upper right to connect a remote library';

  @override
  String lyricsLibraryPageOkText5(String workId) {
    return 'Remove the remote work index for $workId?';
  }

  @override
  String lyricsLibraryPageOkText6(String workId) {
    return 'Delete all lyrics files for $workId?';
  }

  @override
  String get lyricsLibraryPageOkText7 =>
      'Work directories without lyrics or subtitle files will be deleted. Continue?';

  @override
  String get lyricsLibraryPageSectionContentText7 =>
      'Imported remote libraries (highest priority first; drag to reorder)';

  @override
  String lyricsLibraryPageRemoteSourceListText2(String value) {
    return 'Priority $value · Long press to remove';
  }

  @override
  String lyricsLibraryPageConfirmedText2(String url) {
    return 'Remove remote library $url and its synced work index?';
  }

  @override
  String get lyricsLibraryPageSectionContentText8 =>
      'Import syncs only the work index. All lyrics for a work are downloaded when you play it.';

  @override
  String get lyricsLibraryPageProceedText3 =>
      'A large archive or folder was detected. Importing may take a while.';

  @override
  String lyricsLibraryPageOkText8(String length) {
    return 'Delete the $length selected work directories?';
  }

  @override
  String lyricsLibraryPageImportText7(String length) {
    return 'Found $length existing files. How should they be handled?';
  }

  @override
  String lyricsLibraryPageOkText9(String length) {
    return 'Remove the $length selected remote work indexes?';
  }

  @override
  String lyricsLibraryPageBuildText10(String fileCount, String value) {
    return 'Lyrics/subtitle files: $fileCount · $value';
  }

  @override
  String get morePageBuildRow => 'Playlists';

  @override
  String get settings => 'Settings';

  @override
  String get morePageBuildRow2 => 'Random play';

  @override
  String morePageBuildText(String server) {
    return 'Server: $server';
  }

  @override
  String get morePageOpenRandomWorkText =>
      'No playable works match the current filters';

  @override
  String get morePageOpenRandomWorkText2 =>
      'Failed to load a random work. Try again later';

  @override
  String get playerPageShowLyricSettingsText => 'Reset';

  @override
  String get back => 'Back';

  @override
  String get seekBackward => 'Seek backward';

  @override
  String get seekForward => 'Seek forward';

  @override
  String get playerPageUtilsUtil => 'Timer';

  @override
  String get equalizer => 'Equalizer';

  @override
  String get playerPageUtilsUtil2 => 'Timer on';

  @override
  String get playerPageShowLyricSettingsText2 => 'Chinese conversion';

  @override
  String get autoMatch => 'Auto-match';

  @override
  String get workDetails => 'Work details';

  @override
  String get playlist => 'Playlist';

  @override
  String get sleepTimer => 'Sleep timer';

  @override
  String get playerPageWideLyricsPanelText => 'No lyrics';

  @override
  String get playerPageTopBarText => 'Now playing';

  @override
  String get desktopLyrics => 'Desktop lyrics';

  @override
  String get playerPagePlayModeLabelText => 'Repeat all';

  @override
  String get playerPagePlayModeLabelText2 => 'Repeat one';

  @override
  String get playerPagePlayModeLabelText3 => 'Play in order';

  @override
  String get playerPageShowLyricSettingsText3 => 'Lyrics settings';

  @override
  String get playerPageShowLyricSettingsText4 => 'Subtitle offset';

  @override
  String get simplifiedToTraditional => 'Simplified → Traditional';

  @override
  String get traditionalToSimplified => 'Traditional → Simplified';

  @override
  String get playerPageShowQueueText => 'The playlist is empty';

  @override
  String get playerPageResDialogTitle => 'Choose lyrics file';

  @override
  String get playerPagePickOnlineLyricText => 'Choose online lyrics';

  @override
  String get playerPageBuildText => 'Nothing playing';

  @override
  String get playerPageShowLyricSettingsTitle => 'Choose offline lyrics';

  @override
  String get playerPagePickOnlineLyricToast => 'No online lyrics found';

  @override
  String get playerPageShowLyricSettingsTitle2 => 'Choose library lyrics';

  @override
  String get playerPageLoadOnlineLyricToast => 'Could not parse these lyrics';

  @override
  String get playerPageLyricsPanelText => 'Loading lyrics…';

  @override
  String get playerAlreadyFirstTrack => 'Already at the first track';

  @override
  String get playerAlreadyLastTrack => 'Already at the last track';

  @override
  String get playerPageNextToast => 'Reached the end of the playlist';

  @override
  String get playerPageOpenCurrentToast => 'Sign in to access the file stream';

  @override
  String get playerPageShowLyricSettingsSub =>
      'This work is not in the lyrics library';

  @override
  String get playerPageOpenMediaToast => 'Opening media timed out. Try again';

  @override
  String get playerPageLibraryAutoTileText =>
      'Auto-match lyrics from the library';

  @override
  String get playerPageOpenMediaToast2 => 'Failed to open. Retrying…';

  @override
  String get playerPageFriendlyPlayErrorText =>
      'Media stream proxy error. Try again';

  @override
  String get playerLoudnessBoostLabel => 'Boost';

  @override
  String get playerPageVolumeControlTooltip => 'Loudness boost (up to 120)';

  @override
  String get playerPageShowLyricSettingsSub2 =>
      'Choose a local lyrics or subtitle file';

  @override
  String get playerPageInitStateToast =>
      'Connection interrupted. Reconnecting…';

  @override
  String get playerPagePickLibraryLyricToast =>
      'No lyrics for this work in the library';

  @override
  String get playerPageOpenMediaToast3 => 'Opening media timed out. Retrying…';

  @override
  String get playerPageShowLyricSettingsSub3 =>
      'Show only lyrics files for the current work';

  @override
  String get playerPageCheckSleepToast =>
      'Playback stopped and system resources released';

  @override
  String get playerPagePickOnlineLyricSub =>
      'Auto-select by track name, preferring Chinese';

  @override
  String get playerPageFriendlyPlayErrorText2 =>
      'Server error. Try again later';

  @override
  String get playerPageVolumeControlTooltip2 =>
      'Enable loudness boost (up to 120)';

  @override
  String get playerPageFriendlyPlayErrorText3 =>
      'Your session has expired. Sign in again and retry';

  @override
  String get playerPagePickOfflineLyricToast =>
      'The file contains no readable timed lyrics';

  @override
  String get playerPageFriendlyPlayErrorText4 =>
      'Could not connect to the media stream. Check your network and retry';

  @override
  String get playerPageVolumeControlTooltip3 =>
      'Loudness boost Plus (up to 200)';

  @override
  String get playerPageToggleDesktopLyricsToast =>
      'Overlay permission is required to show desktop lyrics';

  @override
  String playerPageSeekCircleMessage(String label, String seconds) {
    return '$label ${seconds}s';
  }

  @override
  String get playerPageLibraryAutoTileText2 =>
      'Prefer local lyrics; use online lyrics if none are found';

  @override
  String playerPageShowQueueText2(String length) {
    return 'Playlist ($length)';
  }

  @override
  String playerPageInitStateToast2(String friendlyPlayError) {
    return 'Playback failed: $friendlyPlayError';
  }

  @override
  String playerPageOpenMediaToast4(String friendlyPlayError) {
    return 'Could not open media stream: $friendlyPlayError';
  }

  @override
  String get playlistsPageNameText => 'Create';

  @override
  String get playlistsPageBuildText => 'Rename';

  @override
  String get playlistsPageBuildText2 => 'New playlist';

  @override
  String get playlistsPageNameHintText => 'Playlist name';

  @override
  String get playlistsPageBuildText3 => 'The playlist is empty';

  @override
  String get playlistsPageHeaderTooltip => 'Remove work';

  @override
  String get playlistsPageNameText2 => 'Rename playlist';

  @override
  String get playlistsPageHeaderMessage => 'Drag to reorder works';

  @override
  String get playlistsPageRowMessage => 'Drag to reorder tracks';

  @override
  String get playlistsPagePlayTrackText => 'No playable audio in the playlist';

  @override
  String get playlistsPageBuildText4 => 'Playlists are hidden in SFW mode';

  @override
  String get playlistsPageBuildText5 =>
      'No playlists yet. Tap New in the lower right';

  @override
  String get playlistsPageBuildText6 =>
      'Playlist contents are hidden in SFW mode';

  @override
  String playlistsPageBuildText7(String length) {
    return 'Items: $length';
  }

  @override
  String get playlistsPagePlayTrackText2 =>
      'This audio has no usable file stream. Add it again from the work details page';

  @override
  String get playlistsPageBuildText8 =>
      'Drag a title to reorder works; drag media to reorder tracks';

  @override
  String get playlistsPageBuildText9 =>
      'Long press a title to reorder works; long press media to reorder tracks';

  @override
  String playlistsPageHeaderText(String length) {
    return 'Audio files: $length';
  }

  @override
  String get traditionalChineseShort => 'Traditional Chinese';

  @override
  String get englishLanguage => 'English';

  @override
  String get simplifiedChineseShort => 'Simplified Chinese';

  @override
  String get settingsPageHealthBadgeStartsWith => 'OK';

  @override
  String get settingsPageSectionsMiniBtn => 'Check';

  @override
  String get settingsPageSectionsMiniBtn2 => 'Configure';

  @override
  String get settingsPageLockRowText => 'Unlock';

  @override
  String get play => 'Play';

  @override
  String get lyrics => 'Lyrics';

  @override
  String get settingsPageSectionsSection => 'Tracks';

  @override
  String get settingsPageOnVersionTapText => 'OK';

  @override
  String get settingsPageSectionsSection2 => 'Data & Network';

  @override
  String get settingsPageSectionsSection3 => 'Appearance';

  @override
  String get settingsPageSectionsText => 'Theme';

  @override
  String get settingsPageSectionsText2 => 'Light';

  @override
  String get settingsPageSectionsText3 => 'Dark';

  @override
  String get settingsPageSectionsText4 => 'Reset';

  @override
  String get settingsPageSectionsSection4 => 'About';

  @override
  String get settingsPageSectionTitleText => 'Privacy';

  @override
  String get settingsPageSectionsTitle => 'Version';

  @override
  String get settingsPageSectionsTitle2 => 'Repository';

  @override
  String get settingsPageLockRowSub => 'Unlocked';

  @override
  String get settingsPageSectionsMiniBtn3 => 'Disable';

  @override
  String get settingsPageShortcutConflictText => 'Next track';

  @override
  String get settingsPageShortcutConflictText2 => 'Previous track';

  @override
  String get settingsPageSectionsLockRow => 'Desktop';

  @override
  String get settingsPageSectionsMiniBtn4 => 'Disabled';

  @override
  String get settingsPageShortcutLabelText => 'Not set';

  @override
  String get translationEngine => 'Translation engine';

  @override
  String get settingsPageSectionsLabel => 'Text color';

  @override
  String get settingsPageSectionsLabel2 => 'Outline color';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get settingsPageAutoCheckSetState => 'Checking…';

  @override
  String get settingsPageSectionsTitle3 => 'Seek backward seconds';

  @override
  String get interfaceLanguage => 'Interface language';

  @override
  String get settingsPageSectionsTitle4 => 'Seek forward seconds';

  @override
  String get settingsPageAiModelInputLabelText => 'Model name';

  @override
  String get settingsPageShortcutLabelText2 => 'Right arrow';

  @override
  String get chineseConversion => 'Chinese conversion';

  @override
  String get settingsPageSectionsText5 => 'Outline width';

  @override
  String get settingsPageSectionsSection5 => 'Accounts';

  @override
  String get settingsPageSectionsText6 => 'Font size';

  @override
  String get settingsPageShortcutLabelText3 => 'Left arrow';

  @override
  String get settingsPageBuildText => 'Reset all data';

  @override
  String get settingsPageSectionsSwitchRow => 'Smart navigation';

  @override
  String get settingsPageAutoCheckSetState2 => 'Connection failed';

  @override
  String get followSystem => 'Follow system';

  @override
  String get settingsPageOpenRepoToast => 'Failed to open';

  @override
  String get settingsPageEditAudioTypePreferenceText => 'Restore defaults';

  @override
  String get settingsPageSectionsText7 => 'Interface scale';

  @override
  String get settingsPageBuildText2 => 'Confirm reset';

  @override
  String get settingsPageSectionsTitle5 => 'Check for updates';

  @override
  String get targetLanguage => 'Target language';

  @override
  String get languageAndTranslation => 'Language and translation';

  @override
  String get settingsPageSectionsSwitchRow2 => 'Broadcast lyrics library';

  @override
  String get settingsPageSectionsSwitchRow3 => 'Clipboard detection';

  @override
  String get settingsPageShortcutConflictText3 => 'Play/pause';

  @override
  String get settingsPageSectionsTitle6 => 'Seek backward shortcut';

  @override
  String get settingsPageSectionsSwitchRow4 => 'Sound effects preference';

  @override
  String get settingsPageSectionsTitle7 => 'Seek forward shortcut';

  @override
  String get settingsPageOnVersionTapText2 => 'Developer mode';

  @override
  String get settingsPageSectionsSub => 'No account configured';

  @override
  String get settingsPageRowSub => 'Open settings';

  @override
  String get settingsPageSectionsTitle8 => 'Audio format preference';

  @override
  String get settingsPageSectionsText8 => 'Fetch model list';

  @override
  String get settingsPageProxySettingsTooltip => 'Clear proxy URL';

  @override
  String get settingsPageSectionsTitle9 => 'Previous track shortcut';

  @override
  String get settingsPageSectionsTitle10 => 'Disable battery optimization';

  @override
  String get settingsPageSectionsSwitchRow5 => 'Ignore audio focus';

  @override
  String get settingsPageSectionsSwitchRow6 =>
      'Check for updates automatically';

  @override
  String get settingsPageMediaCacheLimitRowText => 'Media cache limit';

  @override
  String get settingsPageSectionsTitle11 => 'Next track shortcut';

  @override
  String get translationTargetLanguage => 'Translation target language';

  @override
  String get followInterfaceLanguage => 'Follow interface language';

  @override
  String get settingsPageSectionsText9 => 'Add custom site';

  @override
  String get settingsPageSectionsLockRow2 => 'Android (landscape)';

  @override
  String get settingsPageSectionsLockRow3 => 'Android (portrait)';

  @override
  String get settingsPageSectionsTitle12 => 'Reset the app';

  @override
  String get settingsPageProxySettingsSwitchRow => 'HTTP proxy';

  @override
  String get settingsPageAiModelInputTooltip => 'Choose a detected model';

  @override
  String get settingsPageSectionsTitle13 => 'Restore default shortcuts';

  @override
  String get settingsPageSectionsSwitchRow7 =>
      'Do not remember playback position';

  @override
  String get settingsPageSectionsSection6 => 'Lyrics and desktop lyrics';

  @override
  String settingsPageSectionsToast(String e) {
    return 'Connection failed: $e';
  }

  @override
  String get settingsPageSectionsToast2 => 'Checking connection…';

  @override
  String get settingsPageSectionsSwitchRow8 =>
      'Pause when headphones disconnect';

  @override
  String get settingsPageSectionsTitle14 => 'Play/pause shortcut';

  @override
  String get settingsPageSectionsSub2 => 'Check the update service manually';

  @override
  String get settingsPageSectionsSwitchRow9 => 'Keep lyrics window on top';

  @override
  String get settingsPageAiModelInputTooltip2 => 'Fetch the model list first';

  @override
  String get settingsPageProxySettingsHelperText =>
      'Leave blank to use no proxy';

  @override
  String get settingsPageLabelsLabels => 'OpenAI-compatible';

  @override
  String get settingsPageSectionsSwitchRow10 =>
      'Keep in tray when closing the window';

  @override
  String get settingsPageDetectOpenAiModelsToast => 'Fetching model list…';

  @override
  String get settingsPageSectionsSwitchRow11 =>
      'Hide notification media controls';

  @override
  String get settingsPageSectionsSub3 => 'Automatically convert Chinese lyrics';

  @override
  String get sourceAndTargetLanguage => 'Source / target language';

  @override
  String get settingsPageDetectOpenAiModelsToast2 => 'Enter the API URL first';

  @override
  String get settingsPageSectionsSwitchRow12 =>
      'Release system resources when the timer ends';

  @override
  String get settingsPagePlaybackShortcutRowSub =>
      'Active when the player page has focus';

  @override
  String get settingsPageAiModelInputHintText =>
      'Enter a model name or choose from the list';

  @override
  String get settingsPageSectionsSub4 =>
      'Prevent the system from interrupting background playback';

  @override
  String get settingsPageStatusStatus => 'URL saved; takes effect when enabled';

  @override
  String settingsPageLockRowTitle(String label) {
    return '$label lyrics lock';
  }

  @override
  String settingsPageDetectOpenAiModelsToast3(String e) {
    return 'Failed to fetch model list: $e';
  }

  @override
  String get settingsPageSectionsToast3 => 'Checking DeepL…';

  @override
  String get settingsPageSectionsSwitchRow13 =>
      'Prefer folders with sound effects';

  @override
  String settingsPageSectionsToast4(String e) {
    return 'Failed to stop lyrics library broadcast: $e';
  }

  @override
  String settingsPageSectionsToast5(String e) {
    return 'Could not start lyrics library broadcast: $e';
  }

  @override
  String get settingsPageSectionsSwitchRow14 =>
      'Open the best matching folder automatically';

  @override
  String settingsPageSectionsToast6(String e) {
    return 'DeepL connection failed: $e';
  }

  @override
  String get settingsPageSectionsSwitchRow15 =>
      'Automatically detect copied RJ links';

  @override
  String get settingsPageSectionsSwitchRow16 =>
      'Clear lock screen media controls and notifications when the timer ends';

  @override
  String get settingsPageSectionsSwitchRow17 =>
      'Check the update service 3 seconds after startup';

  @override
  String settingsPageSectionsToast7(String r) {
    return 'DeepL connection OK: $r';
  }

  @override
  String get settingsPageOnVersionTapText3 =>
      'Did you really think there was a developer mode?';

  @override
  String get settingsPageProxySettingsHelperText2 =>
      'Enable HTTP proxy to edit';

  @override
  String get settingsPageSectionsSwitchRow18 =>
      'Pause automatically when wired or Bluetooth headphones disconnect';

  @override
  String get settingsPageSectionsSwitchRow19 =>
      'Play alongside other apps without interruptions';

  @override
  String get settingsPageSectionsSwitchRow20 =>
      'Do not show media controls in notifications during playback';

  @override
  String get settingsPageAiModelInputHintText2 => 'e.g. gpt-4o-mini';

  @override
  String get settingsPageSectionsSwitchRow21 =>
      'Use the project logo in media notifications';

  @override
  String settingsPageBuildText3(String count) {
    return 'Confirm reset (${count}s)';
  }

  @override
  String get settingsPageSectionsSub5 =>
      'Clear all local data and restore initial settings';

  @override
  String get settingsPageSectionsSub6 => '5–60 seconds, in steps of 5';

  @override
  String settingsPageEditPlaybackShortcutToast(String conflict) {
    return 'This key is already assigned to $conflict';
  }

  @override
  String get settingsPageDetectOpenAiModelsFormatException =>
      'Response does not contain data[].id';

  @override
  String get settingsPageSectionsInput =>
      'API key (optional for local services)';

  @override
  String get settingsPageConfirmResetText =>
      'Reset complete: accounts and all local data cleared';

  @override
  String get settingsPageRequestBatteryIgnoreToast =>
      'Allow the app to ignore battery optimization in system settings';

  @override
  String get settingsPageStatusStatus2 => 'Enabled; enter an HTTP proxy URL';

  @override
  String get settingsPageMediaCacheLimitRowText2 =>
      'Limits online playback buffering only; downloads are unaffected';

  @override
  String get settingsPageSectionsSwitchRow22 =>
      'Closing the window stops background activity and exits the app';

  @override
  String get settingsPageSectionsSub7 =>
      'Exempted from battery optimization for background playback';

  @override
  String get settingsPageSectionsInput2 => 'API base URL';

  @override
  String get settingsPageSectionsInput3 => 'DeepL Free API key';

  @override
  String settingsPageSectionsSub8(String asmrUser) {
    return 'Account: $asmrUser';
  }

  @override
  String get settingsPageSectionsSwitchRow23 =>
      'Keep playing in the background; restore the window from the system tray';

  @override
  String get settingsPageSectionsSwitchRow24 =>
      'Restore the last track after restarting, but play it from the beginning';

  @override
  String get settingsPageSectionsSwitchRow25 =>
      'Read-only API service · Port 2377';

  @override
  String get settingsPageLockRowSub2 =>
      'Locked: lyrics do not respond to clicks. Unlock in Settings';

  @override
  String get settingsPageStatusStatus3 =>
      'HTTP proxies only; applies to all network requests';

  @override
  String get settingsPageSectionsSwitchRow26 =>
      'Show the project logo instead of the actual cover';

  @override
  String settingsPageDetectOpenAiModelsToast4(String length) {
    return 'Models found: $length';
  }

  @override
  String settingsPageOnVersionTapToast(String value) {
    return 'Steps remaining to enter developer mode: $value';
  }

  @override
  String settingsPageStatusStatus4(String trim) {
    return 'Enabled: $trim';
  }

  @override
  String get settingsPageSectionsInput4 =>
      'Get a free key at deepl.com (api-free)';

  @override
  String get settingsPageSectionsSub9 =>
      'Space / PageUp / PageDown / Left and Right arrows';

  @override
  String settingsPageAiModelInputHelperText(String length) {
    return 'Models detected: $length';
  }

  @override
  String get settingsPageSectionsSub10 =>
      'Google / Microsoft: free · DeepL: free key · OpenAI-compatible';

  @override
  String get settingsPageSectionsInput5 =>
      'https://api.openai.com/v1 or http://127.0.0.1:11434/v1';

  @override
  String settingsPageSectionsSub11(String translationTargetLabel) {
    return 'Japanese → $translationTargetLabel';
  }

  @override
  String settingsPageNextKeyIdText(String shortcutLabel) {
    return 'Current key: $shortcutLabel\n\nPress a single new key';
  }

  @override
  String get settingsPageBuildText4 =>
      'All local data will be permanently deleted:\n\n· ASMR.ONE account and custom site settings\n· Favorites / playback history / playlists / blacklist\n· All settings, including translations, equalizer, desktop lyrics, and sleep timer\n\nDo you want to continue?';

  @override
  String get mark => 'Mark';

  @override
  String get confirm => 'Confirm';

  @override
  String get refresh => 'Refresh';

  @override
  String get workPageBuildLabel => 'Reviews';

  @override
  String get translate => 'Translate';

  @override
  String get workPageRefreshWorkToast => 'Refreshed';

  @override
  String get workPageBuildTooltip => 'Previous image';

  @override
  String get workPageBuildText => 'Favorited';

  @override
  String get workPageBuildText2 => 'Translating';

  @override
  String get workPageBuildTooltip2 => 'Next image';

  @override
  String get workPageLanguageEditionsButtonText => 'Languages';

  @override
  String get workPageSimilarWorksSliversText => 'Similar works';

  @override
  String get workPageBuildText3 => 'Tracks';

  @override
  String get workPageConfirmedText => 'Remove progress mark';

  @override
  String get workPageConfirmedText2 => 'Delete work';

  @override
  String get workPageRefreshWorkToast2 => 'Refresh failed';

  @override
  String get workPageShowTextViewerTooltip => 'Change encoding';

  @override
  String get workPageBuildText4 => 'My review';

  @override
  String get workPageAddToPlaylistText => 'Confirm';

  @override
  String get workPageBuildHintText => 'Write a review…';

  @override
  String get workPageBuildText5 => 'Cancel translation';

  @override
  String get workPageOkText => 'Add to blacklist';

  @override
  String get workPageAddToPlaylistText2 => 'Add to playlist';

  @override
  String get workPageTranslateTitlesToast => 'Translation cancelled';

  @override
  String get workPageSelectedText => 'Choose voice actor';

  @override
  String get workPageBuildText6 => 'Add to playlist';

  @override
  String get workPageBuildText7 => 'Download selected items';

  @override
  String get workPageOpenVideoChooserText => 'Choose how to open';

  @override
  String get workPageOpenVideoChooserText2 => 'Play as audio';

  @override
  String get workPageSelectedText2 => 'Switch translation engine';

  @override
  String get workPageTranslateTitlesToast2 => 'Unknown translation engine';

  @override
  String get workPageTranslateTitlesFormatException =>
      'Translation result is empty';

  @override
  String get workPageAllFilesRowText => 'View all files';

  @override
  String get workPageDownloadSelectedToast => 'Added to download queue';

  @override
  String get workPageAddToPlaylistText3 => 'Enter a playlist name';

  @override
  String get workPageOpenVideoChooserText3 => 'Open in external player';

  @override
  String workPageDeleteNotify(String e) {
    return 'Deletion failed: $e';
  }

  @override
  String get workPageBuildLabel2 => 'Add to playback queue';

  @override
  String workPageSetProgressToast(String e) {
    return 'Failed to mark progress: $e';
  }

  @override
  String get workPageBuildLabel3 => 'Show media files only';

  @override
  String get workPageTreePlaceholderText => 'This work has no tracks yet';

  @override
  String workPageTranslateTitlesToast3(String e) {
    return 'Translation failed: $e';
  }

  @override
  String workPageRateWorkToast(String e) {
    return 'Rating failed: $e';
  }

  @override
  String workPageApplyEncodingToast(String e) {
    return 'Decoding failed: $e';
  }

  @override
  String workPageSubmitNotify(String e) {
    return 'Failed to save: $e';
  }

  @override
  String get workPageSimilarWorksSliversText2 => 'Load more similar works';

  @override
  String get workPageDownloadSelectedToast2 => 'Tracks have not loaded yet';

  @override
  String workPageClearRatingToast(String e) {
    return 'Failed to remove rating: $e';
  }

  @override
  String get workPageRefreshWorkToast3 => 'Local download records refreshed';

  @override
  String workPageDownloadSelectedToast3(String e) {
    return 'Failed to queue download: $e';
  }

  @override
  String get workPageSimilarWorksSliversText3 => 'All similar works shown';

  @override
  String get workPageOpenLanguageEditionToast =>
      'Could not load this language edition';

  @override
  String workPageBuildToast(String e) {
    return 'Favorite action failed: $e';
  }

  @override
  String get workPageConfirmedText3 => 'Remove this progress mark?';

  @override
  String workPageSetProgressToast2(String e) {
    return 'Failed to remove progress mark: $e';
  }

  @override
  String get workPageBuildLabel4 => 'Open DLsite';

  @override
  String get workPageAddToPlaylistToast => 'Select files or folders first';

  @override
  String get workPageBuildText8 => 'Tracks (folder tree)';

  @override
  String get workPageBuildLabel5 => 'Open asmr.one';

  @override
  String workPageAddToPlaylistToast2(String name) {
    return 'Added to “$name”';
  }

  @override
  String get workPageAddToServerPlaylistToast =>
      'Works can only be added to your own playlists';

  @override
  String get workPageOnMoreActionToast => 'Tracks are loading. Please wait';

  @override
  String get workPageTreePlaceholderText2 =>
      'This work has no audio or video files';

  @override
  String get workPageAddToServerPlaylistToast2 =>
      'This work has no ID and cannot be added';

  @override
  String get workPageOpenReviewDialogToast =>
      'This work has no ID and cannot be reviewed';

  @override
  String get workPageDeleteSelectedLocalFilesToast =>
      'The selection contains no downloaded files';

  @override
  String get workPageDeleteSelectedLocalFilesToast2 =>
      'Select local files to delete first';

  @override
  String get workPageOnMoreActionToast2 =>
      'Failed to load tracks. Refresh and try again';

  @override
  String get workPageTreePlaceholderText3 =>
      'No network connection. Could not load tracks';

  @override
  String workPageBuildText9(String dur) {
    return 'Duration $dur';
  }

  @override
  String get workPageEnginesEngines => 'DeepL (Free API key)';

  @override
  String get workPageEnginesEngines2 => 'OpenAI-compatible (configurable)';

  @override
  String workPageCopyRjToast(String rj) {
    return 'Copied $rj';
  }

  @override
  String get workPageDownloadSelectedToast4 =>
      'Select items or folders to download first';

  @override
  String get workPageAddToPlaylistToast3 =>
      'The selection contains no playable audio files';

  @override
  String get workPageOnMoreActionToast3 =>
      'Select media files to transcribe and translate first';

  @override
  String get workPagePlayAsAudioToast =>
      'Only all-ages works can be played in SFW mode';

  @override
  String get workPageOpenLanguageEditionToast2 =>
      'Only all-ages works can be opened in SFW mode';

  @override
  String get workPagePlayFilesToast =>
      'No audio files available (sign in to access file streams)';

  @override
  String get workPageEnginesEngines3 => 'Google (free, no key required)';

  @override
  String workPageNodeRowToast(String title) {
    return 'Filename copied: $title';
  }

  @override
  String workPageDeleteSelectedLocalFilesToast3(String deleted) {
    return 'Local files deleted: $deleted';
  }

  @override
  String get workPageTranslateTitlesToast4 =>
      'Configure the API URL and model name in Settings first';

  @override
  String get workPageEnginesEngines4 => 'Microsoft (free, no key required)';

  @override
  String workPageOpenFileToast(String title) {
    return 'Viewing this file type is not supported: $title';
  }

  @override
  String get workPageEnginesEngines5 => 'Index-Translate (official API)';

  @override
  String get workPageConfirmDeleteWorkToast =>
      'Deletion failed. Close any programs using this work and try again';

  @override
  String workPageTranslateTitlesToast5(String length) {
    return 'Translating $length title lines…';
  }

  @override
  String get workPageTranslateTitlesToast6 =>
      'Enter your DeepL Free API key in Settings first';

  @override
  String workPageAddToPlaylistText4(String length) {
    return 'Audio files selected: $length';
  }

  @override
  String get workPageOnMoreActionToast4 =>
      'The selection contains no media files that can be sent to kikoeta-transl';

  @override
  String workPageTranslateTitlesToast7(String length) {
    return 'Translation complete (title + $length tracks)';
  }

  @override
  String workPageOkText2(String t) {
    return 'Blacklist the tag “$t”?\nWorks with this tag will be hidden from Home and search.';
  }

  @override
  String workPageConfirmedText4(String title) {
    return 'Delete all local files for “$title”? This cannot be undone.';
  }

  @override
  String get liked => 'Liked';

  @override
  String get privatePlaylist => 'Private';

  @override
  String get publicPlaylist => 'Public';

  @override
  String get sharedByLink => 'Shared by link';

  @override
  String get apiServiceMapPlaylistName => 'Untitled playlist';

  @override
  String get apiServiceMapWorkVa => 'CV. Unknown';

  @override
  String get apiServiceFetchWorkFormatException =>
      'Invalid work details format';

  @override
  String get apiServiceFetchPlaylistMetadataFormatException =>
      'Invalid playlist details format';

  @override
  String get apiServiceFetchAdvancedFilterEntriesValue =>
      'Unsupported advanced filter type';

  @override
  String get apiServiceFetchAdvancedFilterEntriesFormatException =>
      'Invalid advanced filter data format';

  @override
  String get apiServiceToggleFavoriteException =>
      'This work has no ID and cannot be favorited';

  @override
  String get apiServiceClearReviewRatingException =>
      'This work has no ID; its rating cannot be removed';

  @override
  String get apiServiceClearReviewProgressException =>
      'This work has no ID; its progress mark cannot be removed';

  @override
  String get apiServiceDeleteReviewException =>
      'This work has no ID; its progress mark cannot be deleted';

  @override
  String get search => 'Search';

  @override
  String clipboardWatcherCheckText(String rj) {
    return 'Detected $rj. Tap to search';
  }

  @override
  String get desktopLyricsOverlayEnsureWindowToNativeUtf16 =>
      'Kikoeta Desktop Lyrics';

  @override
  String get downloadServiceDownloadFileHttpException =>
      'The downloaded file is empty';

  @override
  String get downloadServiceRunStateError => 'No downloadable files';

  @override
  String get downloadServiceRunStateError2 => 'Download URL is empty';

  @override
  String get downloadTransferDownloadToFileHttpException =>
      'Incomplete download response';

  @override
  String get downloadTransferDownloadToFileHttpException2 =>
      'Download chunk length changed';

  @override
  String get downloadTransferDownloadToFileHttpException3 =>
      'Downloaded file length verification failed';

  @override
  String get downloadTransferDownloadToFileHttpException4 =>
      'Download response byte range does not match';

  @override
  String get downloadTransferDownloadToFileHttpException5 =>
      'Download response exceeds the declared file length';

  @override
  String get downloadTransferDownloadToFileHttpException6 =>
      'Download response uses a non-identity content encoding';

  @override
  String downloadTransferDownloadToFileHttpException7(String status) {
    return 'Download failed: HTTP $status';
  }

  @override
  String get ktServiceNormalizeEndpointFormatException =>
      'Use the address format IP/domain:port';

  @override
  String get ktServiceDecodeFormatException =>
      'kikoeta-transl returned an invalid response';

  @override
  String get ktServiceNormalizeEndpointFormatException2 =>
      'Enter the IP/domain and port for kikoeta-transl';

  @override
  String ktServiceErrorMessageText(String statusCode) {
    return 'kikoeta-transl request failed (HTTP $statusCode)';
  }

  @override
  String get lyricsLibraryRemoteClientValidateWorkIdFormatException =>
      'Invalid work ID';

  @override
  String get lyricsLibraryRemoteClientFetchWorksFormatException =>
      'Invalid remote lyrics library pagination cursor';

  @override
  String get lyricsLibraryRemoteClientFetchWorksFormatException2 =>
      'The remote lyrics library did not provide a work list';

  @override
  String get lyricsLibraryRemoteClientFetchLyricsFormatException =>
      'The remote work has no lyrics file list';

  @override
  String get lyricsLibraryRemoteClientFetchLyricsFormatException2 =>
      'The remote work has no usable lyrics files';

  @override
  String get lyricsLibraryRemoteClientGetJsonFormatException =>
      'The remote lyrics library returned an invalid data format';

  @override
  String get lyricsLibraryRemoteClientNormalizeBaseUrlFormatException =>
      'Enter a valid HTTP or HTTPS URL';

  @override
  String lyricsLibraryRemoteClientGetJsonHttpException(String statusCode) {
    return 'The remote lyrics library returned HTTP $statusCode';
  }

  @override
  String get lyricsLibraryServiceExtractArchivePhase => 'Extracting';

  @override
  String get lyricsLibraryServiceCopyTreePhase => 'Copying';

  @override
  String get lyricsLibraryServiceRemoveRemoteLibraryStateError =>
      'This remote library has not been imported';

  @override
  String get lyricsLibraryServiceSaveTranslatedLyricsArgumentError =>
      'Unsupported lyrics format';

  @override
  String get lyricsLibraryServiceSaveTranslatedLyricsArgumentError2 =>
      'The file contains no valid timestamps';

  @override
  String get lyricsLibraryServiceImportRemoteWorkFormatException =>
      'The remote work has no valid lyrics files';

  @override
  String get lyricsLibraryServiceSaveTranslatedLyricsArgumentError3 =>
      'The target file must be inside the work directory';

  @override
  String get lyricsLibraryServiceSetRemoteLibraryOrderArgumentError =>
      'The remote library list has changed. Reopen the import dialog';

  @override
  String lyricsLibraryServiceSubscriptionStateError(String message) {
    return 'Lyrics import worker error: $message';
  }

  @override
  String get updateServiceShowUpdateDialogText => 'Do not show again';

  @override
  String get updateServiceShowUpdateDialogText2 => 'Download';

  @override
  String get updateServiceShowUpdateDialogText3 => 'New version available';

  @override
  String get updateServiceCheckManuallyText => 'Checking for updates…';

  @override
  String get updateServiceCheckError =>
      'Could not connect to the update service';

  @override
  String get updateServiceCheckManuallyToast => 'You are up to date';

  @override
  String get updateServiceShowUpdateDialogToast =>
      'Could not open the download page';

  @override
  String get updateServiceGetUpdateResponseStateError =>
      'The update service request did not run';

  @override
  String get updateServiceParseReleaseResponseFormatException =>
      'Update response is missing version information';

  @override
  String get updateServiceCheckError2 =>
      'The update service did not return valid version information';

  @override
  String get updateServiceCheckError3 =>
      'Could not connect to the update service or GitHub';

  @override
  String updateServiceShowUpdateDialogText4(
    String version,
    String currentVersion,
  ) {
    return 'Latest version: $version\nCurrent version: $currentVersion';
  }

  @override
  String get pause => 'Pause';

  @override
  String get quit => 'Quit';

  @override
  String get windowsTrayServiceSetContextMenuLabel => 'Show Home';

  @override
  String get sheetsShowSleepSheetSuffixText => 'min';

  @override
  String get sheetsBuildText => 'Apply';

  @override
  String get sheetsShowSiteSheetField => 'Alias';

  @override
  String get sheetsShowSiteSheetField2 => 'URL';

  @override
  String get account => 'Account';

  @override
  String get sheetsPresetsPresets => 'Vocals';

  @override
  String get sheetsPresetsPresets2 => 'Bass';

  @override
  String get sheetsPresetsPresets3 => 'Flat';

  @override
  String get sheetsPresetsPresets4 => 'Pop';

  @override
  String get sheetsPresetsPresets5 => 'Rock';

  @override
  String get sheetsShowEqSheetText => 'Disabled';

  @override
  String get sheetsShowEqSheetText2 => 'Applied';

  @override
  String get sheetsShowSleepSheetText => 'Cancel timer';

  @override
  String get sheetsShowSleepSheetText2 => 'Start timer';

  @override
  String get playbackComplete => 'Playback complete';

  @override
  String get sheetsTimePickerText => 'Stop time';

  @override
  String get sheetsShowSleepSheetLabel => 'At a set time';

  @override
  String sheetsShowSleepSheetLabel2(String m) {
    return '$m min';
  }

  @override
  String get sheetsShowSleepSheetLabel3 => 'After N minutes';

  @override
  String get sheetsBuildTitle => 'Choose server';

  @override
  String get sheetsShowEqSheetText3 => 'Enable equalizer';

  @override
  String get sheetsShowSiteSheetTitle => 'Edit custom site';

  @override
  String get sheetsBuildText2 => 'Manage custom sites';

  @override
  String get sheetsShowSleepSheetHintText => 'Custom minutes';

  @override
  String get sheetsBuildText3 => 'No custom sites';

  @override
  String get sheetsBuildText4 => 'Choose custom site';

  @override
  String get sheetsShowSiteSheetHint => 'e.g. Home NAS';

  @override
  String get sheetsBuildText5 => 'Add a custom site first';

  @override
  String get sheetsShowOneConfigSheetTitle => 'ASMR.ONE account';

  @override
  String get sheetsShowOneConfigSheetHint => 'asmr.one account';

  @override
  String get sheetsShowOneConfigSheetSub =>
      'Account information is stored locally only (demo)';

  @override
  String get sheetsShowSleepSheetText3 =>
      'Stop playback and close when the current playlist ends';

  @override
  String get sheetsShowSleepSheetText4 =>
      'Time remaining · Stop playback and exit when the timer ends';

  @override
  String get sheetsBuildSub => 'Official service or a custom Kikoeru site';

  @override
  String get sheetsShowEqSheetSub => 'True 10-band · ±12 dB · All platforms';

  @override
  String get sheetsShowSleepSheetText5 =>
      'Stop playback and close after all items in the current playlist finish';

  @override
  String get sheetsShowSleepSheetSub =>
      'Stop playback and release system resources when the timer ends (clear lock screen controls and notifications)';

  @override
  String sheetsBuildLabel(String length) {
    return 'Custom configurations ($length)';
  }

  @override
  String playbackSeekSecondsControlBuildTooltip(String label) {
    return 'Decrease $label seconds';
  }

  @override
  String playbackSeekSecondsControlBuildTooltip2(String label) {
    return 'Increase $label seconds';
  }

  @override
  String get name => 'Name';

  @override
  String get description => 'Description';

  @override
  String get playlistPickerRowsMapEntry => 'Visibility';

  @override
  String get language => 'Language';

  @override
  String get confirmAction => 'Confirm';

  @override
  String get create => 'Create';

  @override
  String get playlistPickerShowEditorLabelText => 'Type';

  @override
  String get playlistPickerRowsMapEntry2 => 'Created by';

  @override
  String get playlistPickerRowsMapEntry3 => 'Updated';

  @override
  String get playlistPickerReviewsItemName => 'My favorites';

  @override
  String get playlistPickerRowsMapEntry4 => 'Play count';

  @override
  String get playlistPickerRowsMapEntry5 => 'Work count';

  @override
  String get playlistPickerCopyText => 'Playlist details';

  @override
  String get playlistPickerLinkLabelText => 'Share link';

  @override
  String get playlistPickerCopyText2 => 'Copy link';

  @override
  String get playlistPickerRowsMapEntry6 => 'Created';

  @override
  String get playlistPickerBuildText => 'Switch playlist';

  @override
  String get playlistPickerPlaylistItemTooltip => 'Remove playlist';

  @override
  String get playlistPickerPlaylistItemTooltip2 => 'Edit playlist';

  @override
  String get playlistPickerShowEditorText => 'Create playlist';

  @override
  String get playlistPickerLinkText => 'Import playlist';

  @override
  String get playlistPickerOkText => 'Delete playlist';

  @override
  String playlistPickerRemoveLikedToast(String e) {
    return 'Removal failed: $e';
  }

  @override
  String playlistPickerCreatePlaylistToast(String e) {
    return 'Creation failed: $e';
  }

  @override
  String get playlistPickerLoadSetState => 'Could not load playlists';

  @override
  String get playlistPickerImportPlaylistToast => 'Unrecognized playlist link';

  @override
  String get playlistPickerReviewsItemSubtitle =>
      'My reviews/favorites (all works)';

  @override
  String get playlistPickerCreatePlaylistToast2 =>
      'Created, but the playlist was not found in the list';

  @override
  String get playlistPickerImportPlaylistToast2 =>
      'Added, but the playlist is not in the list yet';

  @override
  String playlistPickerSubtitleSubtitle(String worksCount) {
    return 'Works: $worksCount';
  }

  @override
  String get playlistPickerLinkText2 =>
      'Paste a shared playlist link to add it to My playlists.';

  @override
  String playlistPickerOkText2(String name) {
    return 'Delete “$name”? This cannot be undone.';
  }

  @override
  String playlistPickerOkText3(String name) {
    return 'Remove “$name” from My playlists?';
  }

  @override
  String playlistPickerSubtitleSubtitle2(String worksCount, String replaceAll) {
    return 'Works: $worksCount · $replaceAll';
  }

  @override
  String get widgetsFilterButtonTooltip => 'Filter';

  @override
  String get widgetsFilterButtonLabel => 'Subtitles only';

  @override
  String get allAges => 'All ages';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter =>
      'Exclude language';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter2 =>
      'Search circles';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter3 =>
      'Search voice actors';

  @override
  String get widgetsBuildBuilder => 'AI lyrics';

  @override
  String get widgetsBuildBuilder2 => 'Remote lyrics';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter4 =>
      'Filter by language';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter5 =>
      'Exclude tag';

  @override
  String get widgetsBuildBuilder3 => 'Local lyrics';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter6 =>
      'Exclude circle';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter7 =>
      'Exclude voice actor';

  @override
  String get widgetsInputRowMessage => 'Advanced search';

  @override
  String get widgetsHistoryPanelText => 'Search history';

  @override
  String get widgetsBuildBuilder4 => 'Online lyrics';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter8 =>
      'Search tags';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter9 =>
      'Filter by age rating';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter10 =>
      'Exclude age rating';

  @override
  String get widgetsBuildText => 'Advanced search parameters';

  @override
  String get widgetsHistoryPanelText2 => 'No search history';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter11 =>
      'Include low-vote tags';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter12 =>
      'Exclude low-vote tags';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter13 =>
      'Rating greater than';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter14 =>
      'Sales greater than';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter15 =>
      'Price greater than';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter16 =>
      'Duration shorter than';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter17 =>
      'Duration longer than';

  @override
  String widgetsHistoryPanelText3(String value) {
    return 'Deleted “$value”';
  }

  @override
  String get playbackSpeed => 'Speed';

  @override
  String get playbackSpeedDescription =>
      'Change playback speed while preserving pitch';

  @override
  String get playbackSpeedEntry => 'Show speed control';

  @override
  String get playbackSpeedEntryDescription =>
      'Show speed controls in the player; turning this off restores 1×';

  @override
  String get audioChannels => 'Channels';

  @override
  String get audioChannelsDescription =>
      'Swap left and right, or merge both channels to play the same audio in both ears';

  @override
  String get audioChannelsOriginal => 'Original';

  @override
  String get audioChannelsSwap => 'Swap left/right';

  @override
  String get audioChannelsMerge => 'Merge channels';

  @override
  String get widgetsInputRowHintText => 'Search RJ ID, title, voice actor…';
}
