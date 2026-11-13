# 在 Kikoeta 中使用 Cookie 登录 DLsite Play

在 Kikoeta 登录页选择「使用 DLsite Play 登录」，或在首页点击当前服务器名称，选择「DLsite Play」并点击「应用」。你也可以在「设置 → 账号设置 → DLsite Play」中点击「配置」。

登录页支持账号和密码，DLsite 要求验证码时按提示输入。如果页面提示在浏览器完成验证，可以按下面的步骤使用 Cookie 登录。

## 安装 Cookie-Editor

### Windows

1. 打开 Microsoft Edge。
2. 访问 [Cookie-Editor 扩展页面](https://microsoftedge.microsoft.com/addons/detail/cookieeditor/neaplmfkghagebokkhpjpoebhdledlfi)，点击 **获取**。

### Android

1. 在手机的应用市场下载 Microsoft Edge，然后打开它。
2. 依次选择 **菜单 → 扩展 → 管理扩展**。
3. 搜索 **Cookie-Editor**，点击 **获取**。

## 导出 Cookie 并登录

1. 在 Microsoft Edge 打开 [DLsite Play](https://play.dlsite.com/)，登录你的 DLsite 账号。
2. 在已登录的 DLsite Play 标签页打开 **Cookie-Editor**，点击右下角的 **Export**，选择 **Header String**。
3. 返回 Kikoeta 的 DLsite Play 登录页，选择 **Cookie**，粘贴刚才导出的完整 **Header String**。
4. 点击 **使用 Cookie 登录**。

如果从「账号设置」进入，保存登录后可在首页切换到 DLsite Play。Cookie 过期时，在浏览器重新登录并导出。Cookie 可用于访问你的账号，请勿发到聊天、反馈或日志中。
