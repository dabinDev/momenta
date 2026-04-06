# 拾光视频 Flutter 客户端

面向中老年用户的 AI 短视频创作 App。当前仓库是移动端 Flutter 客户端，负责账号登录、AI 创作、历史记录、下载管理、积分充值、邀请体系、版本更新等用户侧能力。

本仓库不包含完整后端服务源码。App 运行时通过 `AUTH_SERVER_BASE_URL` 连接外部服务端，服务端再负责账号体系、模板配置、视频任务、积分、支付、邀请、版本发布等业务能力。

## 1. 项目概览

### 1.1 产品定位

- 产品名称：拾光视频
- 产品形态：Android / iOS 移动端 App
- 用户人群：中老年用户、家人代操作用户、社区活动视频制作场景
- 核心目标：降低短视频创作门槛，让用户通过文字、语音、图片、链接、模板等输入快速生成视频

### 1.2 当前仓库边界

- 本仓库是 Flutter 客户端工程，不是后端单体仓库
- App 所有业务数据均来自服务端接口
- App 内不保存真实 AI 模型密钥，服务端地址通过 `dart-define` 注入
- 仓库中的 `.env.example` 主要用于配套服务端部署参考，Flutter 客户端运行时不会自动读取这个文件

### 1.3 当前版本

- App Version：`1.3.1`
- Build Number：`5`
- 更新平台标识：`android`
- 更新渠道标识：`lan`

对应常量文件：`lib/app/constants.dart`

## 2. 技术栈与架构

### 2.1 技术栈

- Flutter 3.x
- Dart 3.6.x
- 状态管理与路由：GetX
- 网络请求：Dio
- 本地存储：GetStorage
- 安全存储：flutter_secure_storage
- 图片/视频选择：image_picker
- 视频播放：video_player
- 语音识别：speech_to_text
- 相册保存：gal
- 链接打开：url_launcher
- 扫码能力：mobile_scanner

### 2.2 分层结构

项目整体遵循清晰分层，核心目录如下：

```text
lib/
├─ app/                         # 应用级配置：主题、路由、全局依赖注入、常量
├─ core/
│  ├─ errors/                  # 统一异常封装
│  ├─ services/                # 本地存储、安全存储、下载管理等基础服务
│  └─ utils/                   # Snackbar、文件处理、视频保存等工具
├─ data/
│  ├─ api/                     # Dio 客户端、接口服务
│  ├─ models/                  # 数据模型
│  └─ repositories/            # Repository 实现层
├─ domain/
│  └─ repositories/            # Repository 抽象定义
├─ presentation/               # 页面、Controller、Binding
└─ shared/
   └─ widgets/                 # 公共 UI 组件
```

### 2.3 依赖注入与启动

- 应用入口：`lib/main.dart`
- 全局依赖注册：`lib/app/app_binding.dart`
- 路由表：`lib/app/routes.dart`
- 主题：`lib/app/theme.dart`

启动流程：

1. `main()` 中执行 `GetStorage.init()`
2. 通过 `GetMaterialApp` 挂载全局主题、Binding 和命名路由
3. `AppBinding` 注册存储服务、API、Repository、全局 `AuthController`
4. 首屏进入启动页，根据本地登录态决定跳转登录或主页

## 3. 页面与模块说明

### 3.1 命名路由总览

当前项目的核心路由如下：

| 路由 | 页面 | 作用 |
| --- | --- | --- |
| `/` | LaunchPage | 启动页，做登录态判断 |
| `/login` | LoginPage | 登录 |
| `/register` | RegisterPage | 注册 |
| `/forgot-password` | ForgotPasswordPage | 忘记密码 |
| `/change-password` | ChangePasswordPage | 修改密码 |
| `/home` | MainShellPage | 主框架页，包含三大主 Tab |
| `/create` | CreatePage | 独立创作页 |
| `/history` | HistoryPage | 历史任务页 |
| `/settings` | SettingsPage | 个人中心 |
| `/recharge` | RechargePage | 积分充值 |
| `/profile-detail` | ProfileDetailPage | 个人资料详情 |
| `/edit-profile` | EditProfilePage | 编辑资料 |
| `/invite-center` | InviteCenterPage | 邀请中心 |
| `/download-manager` | DownloadManagerPage | 下载管理 |
| `/video-player` | VideoPlayerPage | 视频播放页 |

### 3.2 主框架页

主框架页位于 `lib/presentation/shell/main_shell_page.dart`，底部导航固定为三大主 Tab：

- `AI`：创作工作台
- `历史`：历史任务与生成结果
- `我的`：账号信息、积分、邀请、下载、版本更新

### 3.3 账号与鉴权模块

账号模块包含登录、注册、忘记密码、修改密码、资料编辑等完整流程。

当前实现特点：

- 登录成功后，将 `auth_access_token` 写入 `flutter_secure_storage`
- 用户名、资料缓存写入 `GetStorage`
- 注册时必须填写邀请码
- 注册页支持邀请码扫码填充
- App 启动时可从本地恢复登录态
- 退出登录时清理 Token 和本地资料缓存

关键文件：

- `lib/presentation/auth/auth_controller.dart`
- `lib/data/repositories/auth_repository_impl.dart`
- `lib/core/services/secure_storage_service.dart`
- `lib/core/services/local_storage_service.dart`

### 3.4 AI 创作模块

创作页位于 `lib/presentation/create/create_page.dart`，是当前项目最核心的业务页面。

当前版本不是单一表单，而是三种创作模式共用一套工作台：

| 模式 | 代码标识 | 适用场景 | 主要输入 |
| --- | --- | --- | --- |
| 简单模式 | `simple` | 快速从文案生成视频 | 文本、提示词、图片、时长 |
| 入门模式 | `starter` | 参考公开视频链接快速跟做 | 文本、链接、提示词、图片、时长 |
| 自定义模式 | `custom` | 基于模板或参考视频做更高自由度创作 | 文本、链接、模板、提示词、图片、参考视频、时长 |

创作模块支持的核心能力：

- 手动输入文案
- 设备侧语音识别转文字
- AI 文案纠正
- AI 生成英文提示词
- 提示词模板与视频模板选择
- 上传最多 3 张参考图
- 自定义模式上传参考视频
- 选择视频时长
- 提交生成任务
- 轮询任务进度
- 成功后直接播放或下载
- 失败后重试或删除

当前代码中的默认业务规则：

- 默认时长选项：`5 / 10 / 20` 秒
- 最多上传图片数：`3`
- 轮询间隔：`3` 秒
- 最大轮询次数：`180`
- 最大语音识别时长：`60` 秒

### 3.5 历史记录模块

历史页位于 `lib/presentation/history/history_page.dart`。

它不是简单列表，而是生成任务的操作中心，支持：

- 查看总任务数
- 下拉刷新
- 分页加载更多
- 查看任务状态
- 播放已完成视频
- 下载视频到本地
- 失败任务重试
- 删除单条任务
- 清空全部历史

状态表现与交互对中老年用户做了简化，优先保证“能看懂现在是否成功、失败、可播放、可下载”。

### 3.6 下载管理模块

下载管理页位于 `lib/presentation/downloads/download_manager_page.dart`。

这个模块用于承接“下载到本地”后的全链路管理，支持：

- 下载中 / 已完成 / 失败数量概览
- 本地下载记录持久化
- 自动恢复下载列表
- 查看本地文件路径
- 重新下载失败项
- 删除单条下载记录
- 清理全部已完成下载
- 保存到系统相册

下载记录会按当前登录账号隔离保存，不同账号切换后互不干扰。

### 3.7 个人中心模块

个人中心页位于 `lib/presentation/settings/settings_page.dart`，除“设置”外还承载了账号资产和运营入口。

当前页面可见能力包括：

- 头像、昵称、用户名展示
- 手机号展示
- 当前积分展示
- 单次视频生成积分消耗说明
- 积分充值入口
- 邀请中心入口
- 下载管理入口
- 版本检查入口
- 资料详情入口
- 退出登录

### 3.8 邀请中心与充值模块

这是当前项目相对完整的一块运营能力：

- 邀请中心展示当前邀请码、使用次数、被邀请用户列表
- 注册流程要求邀请码，形成闭环
- 充值中心支持按服务端配置的支付方式发起充值订单
- 新用户尝鲜包、积分余额、每次生成消耗都由服务端返回

### 3.9 视频播放模块

视频播放页负责承接以下场景：

- 播放刚生成成功的视频
- 播放历史记录中的成片
- 播放本地下载成功的视频
- 从播放页直接发起下载或跳转下载管理

## 4. 功能使用说明

### 4.1 首次使用

1. 启动 App。
2. 若未登录，进入登录页。
3. 没有账号时进入注册页。
4. 注册时填写用户名、邮箱、邀请码、密码。
5. 注册成功后返回登录页。
6. 登录成功进入主框架页。

说明：

- 邀请码是必填项，不填或无效会注册失败
- 邀请码可以手动输入，也可以通过扫码页识别填充
- 登录后会自动恢复用户信息和下载记录

### 4.2 创作页使用流程

推荐按下面顺序使用创作页：

1. 先选择创作模式。
2. 输入创作文案。
3. 如需快速输入，可使用语音识别。
4. 点击 AI 校正文案。
5. 点击生成提示词，得到英文视频提示词。
6. 选择图片、模板、链接或参考视频。
7. 选择视频时长。
8. 点击提交生成。
9. 等待轮询完成。
10. 成功后播放或下载。

#### 简单模式

适合“有文案，想直接生成”的场景。

- 只需要输入文本即可启动基本创作
- 可叠加参考图提升画面一致性
- 可通过 AI 自动润色文案和生成英文提示词

#### 入门模式

适合“有参考视频链接，想快速模仿节奏”的场景。

- 在简单模式基础上增加链接输入
- 适合把抖音、视频号等公开视频当作节奏参考
- 仍可叠加图片与提示词

#### 自定义模式

适合“要按模板做更像的成片”的场景。

- 支持选择视频模板
- 支持查看模板样片
- 支持上传参考视频
- 更适合运营、活动宣传、节日祝福等固定模板场景

### 4.3 语音识别说明

当前创作页的语音输入主要依赖设备侧 `speech_to_text`：

- 需要系统麦克风权限
- 识别失败后不影响继续手动输入
- 语音识别结果会自动回填到文本框

代码层面同时预留了服务端转写接口能力，但当前创作页面主流程优先走设备侧识别。

### 4.4 历史记录使用说明

进入历史页后，可以完成以下操作：

- 查看最近生成任务
- 按状态判断任务是否完成
- 播放已完成视频
- 下载已完成视频
- 对失败任务发起重试
- 删除不需要的记录
- 清空全部历史记录

### 4.5 下载管理使用说明

下载管理适合处理“下载后去哪里找、下载失败怎么办”的问题。

建议使用方式：

1. 在创作页或历史页点击下载。
2. 进入下载管理查看进度。
3. 下载完成后可直接播放。
4. 需要保存到系统相册时执行保存操作。
5. 失败项点击重试。
6. 不需要的记录或文件可以删除。

### 4.6 个人中心使用说明

个人中心适合做账号与运营操作：

- 刷新当前用户资料
- 查看积分余额与扣费规则
- 进入充值中心购买积分
- 查看邀请奖励与邀请记录
- 查看下载管理
- 检查新版本并跳转下载地址
- 修改资料或退出登录

## 5. 服务端依赖与接口说明

### 5.1 客户端连接方式

Flutter 客户端只认一个服务端入口：

```text
AUTH_SERVER_BASE_URL
```

默认值定义在 `lib/app/constants.dart`：

```text
https://api.memovideos.cn
```

运行时通过 `--dart-define` 注入即可覆盖。

### 5.2 当前客户端实际使用的接口能力

按业务划分如下。

#### 鉴权与用户

- `POST /api/v1/base/access_token`
- `POST /api/v1/base/register`
- `GET /api/v1/base/userinfo`
- `POST /api/v1/base/forgot_password`
- `POST /api/v1/base/change_password`
- `POST /api/v1/base/update_profile`

#### 创作工作台与模板

- `GET /api/create-workbench`
- `GET /api/prompt-templates`
- `GET /api/video-templates`

#### 素材与 AI 处理

- `POST /api/upload-images`
- `POST /api/upload-reference-video`
- `POST /api/voice/transcribe`
- `POST /api/correct-text`
- `POST /api/generate-prompt`

#### 视频任务

- `POST /api/tasks`
- `POST /api/starter-tasks`
- `POST /api/custom-tasks`
- `GET /api/tasks/:id`
- `GET /api/tasks?page=1&limit=10&filter=all`
- `GET /api/tasks/summary`
- `POST /api/tasks/:id/retry`
- `DELETE /api/tasks/:id`
- `DELETE /api/tasks`
- `GET /api/tasks/:id/download`

#### 运营能力

- `GET /api/recharge/products`
- `GET /api/recharge/orders`
- `POST /api/recharge/orders`
- `GET /api/invite/overview`
- `GET /api/app/releases/latest`

### 5.3 认证方式

登录成功后，客户端会把访问令牌保存到安全存储中。后续请求统一自动带上：

```text
Authorization: Bearer <token>
```

同时兼容带上 `token` 头，便于适配已有服务端。

## 6. 本地存储说明

### 6.1 安全存储

通过 `flutter_secure_storage` 保存敏感数据：

- `auth_access_token`

### 6.2 普通存储

通过 `GetStorage` 保存普通数据：

- 用户名缓存
- 用户资料缓存
- 下载记录

下载记录按当前用户名分桶保存，避免多账号互相覆盖。

## 7. 配置说明

### 7.1 Flutter 客户端运行配置

最常用的是下面这一项：

```powershell
flutter run --dart-define=AUTH_SERVER_BASE_URL=http://127.0.0.1:10099
```

真机联调时不要使用 `127.0.0.1`，应改成电脑局域网 IP 或可访问域名。

### 7.2 `.env.example` 的正确理解

仓库中的 `.env.example` 不是 Flutter 客户端自动加载的配置文件，它更像是配套服务端的环境变量模板，主要包含：

- 服务端基础地址
- Moonshot / Kimi LLM 配置
- 视频模型服务配置
- COS 对象存储配置
- 讯飞 ASR 配置

如果你在同时部署配套服务端，可以参考这个文件补齐环境变量；如果你只运行本 Flutter 客户端，则只需要保证 `AUTH_SERVER_BASE_URL` 正确即可。

### 7.3 版本更新相关配置

客户端发起版本检查时会带上：

- `platform`
- `channel`
- `current_version`
- `current_build_number`

这些值来自 `lib/app/constants.dart`。如果服务端要正确返回升级信息，发布平台、渠道和版本号必须与客户端实际构建保持一致。

## 8. 开发环境准备

### 8.1 基础要求

- Flutter 3.x
- Dart SDK 3.6.x
- JDK 17
- Android SDK
- Android Studio
- 已安装设备驱动或可用模拟器

Android 构建要求见 `android/app/build.gradle`：

- `minSdk = 23`

### 8.2 Windows 示例环境

如果你的 SDK 都放在 F 盘，可以参考下面的布局：

```text
F:\AndroidSdk
F:\AndroidSdk\platform-tools
F:\AndroidSdk\cmdline-tools\latest
F:\Android Studio
F:\java\jdk-17
```

推荐执行：

```powershell
flutter config --android-sdk F:\AndroidSdk
[Environment]::SetEnvironmentVariable('ANDROID_SDK_ROOT', 'F:\AndroidSdk', 'User')
[Environment]::SetEnvironmentVariable('ANDROID_HOME', 'F:\AndroidSdk', 'User')
[Environment]::SetEnvironmentVariable('JAVA_HOME', 'F:\java\jdk-17', 'User')
```

然后把以下目录加入用户级 `Path`：

```text
F:\AndroidSdk\platform-tools
F:\AndroidSdk\cmdline-tools\latest\bin
F:\java\jdk-17\bin
```

重新打开终端后检查：

```powershell
flutter doctor -v
adb devices
flutter devices
```

### 8.3 获取依赖与启动

```powershell
flutter pub get
flutter run --dart-define=AUTH_SERVER_BASE_URL=https://api.memovideos.cn
```

如果需要指定设备：

```powershell
flutter run -d windows
flutter run -d chrome
flutter run -d android
```

## 9. 构建与发布

### 9.1 Android Debug 构建

```powershell
flutter build apk --debug --dart-define=AUTH_SERVER_BASE_URL=https://api.memovideos.cn
```

输出文件：

```text
build/app/outputs/flutter-apk/app-debug.apk
```

### 9.2 Android Release APK

```powershell
flutter build apk --release --dart-define=AUTH_SERVER_BASE_URL=https://api.memovideos.cn
```

### 9.3 Android App Bundle

```powershell
flutter build appbundle --release --dart-define=AUTH_SERVER_BASE_URL=https://api.memovideos.cn
```

### 9.4 Android 签名配置

发布签名文件位置：

```text
android/key.properties
```

示例内容：

```properties
storeFile=../release.jks
storePassword=your-password
keyAlias=your-alias
keyPassword=your-password
```

当前 Gradle 配置特点：

- 如果存在 `android/key.properties`，Release 构建会使用正式签名
- 如果不存在，Release 构建会回退到 Debug 签名

这适合内部联调，不适合正式上架。要发布到应用市场，必须补齐正式签名。

### 9.5 iOS 构建说明

iOS 构建需要在 macOS 上执行：

```powershell
flutter build ios --release --dart-define=AUTH_SERVER_BASE_URL=https://api.memovideos.cn
```

或在 Xcode 中打开 `ios/Runner.xcworkspace` 做签名和归档。

当前 iOS 已声明的关键权限：

- 麦克风权限
- 语音识别权限
- 相册读取权限
- 相册写入权限

对应文件：`ios/Runner/Info.plist`

### 9.6 发布前检查建议

建议每次发版前至少完成以下检查：

- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter doctor -v`
- 真机完成一次完整登录流程
- 真机完成一次创作提交流程
- 真机验证历史页、下载页、个人中心
- 服务端 `/api/app/releases/latest` 已配置当前渠道和平台

## 10. 配套服务端部署说明

如果你要部署完整系统，而不只是运行客户端，需要额外准备一个可用服务端。

建议至少满足以下条件：

- 提供本 README 第 5 节列出的接口
- 返回统一可解析的数据包结构
- 能处理账号体系、视频任务、模板、积分、邀请、更新信息
- 可选对接 Moonshot / Kimi、视频模型服务、对象存储、ASR 服务

`.env.example` 中可以重点关注这些分组：

- 基础地址：`SERVER_BASE_URL`、`PUBLIC_BASE_URL`
- LLM：`LLM_BASE_URL`、`LLM_MODEL`、`LLM_API_KEY`
- 视频模型：`VIDEO_BASE_URL`、`VIDEO_MODEL`、`VIDEO_API_KEY`
- 存储：`COS_*`
- 语音：`XFYUN_ASR_*`

注意：

- 真实密钥不要写入 Flutter 源码
- 客户端只连接自己的业务后端
- 业务后端再去连接大模型、视频模型或对象存储

## 11. 常见问题排查

### 11.1 `adb` 无法识别

现象：

```powershell
adb : 无法将“adb”项识别为 cmdlet、函数、脚本文件或可运行程序的名称
```

排查方法：

- 确认 `platform-tools` 已安装
- 确认 `F:\AndroidSdk\platform-tools` 已加入 `Path`
- 关闭并重新打开终端
- 再执行 `adb devices`

### 11.2 `flutter doctor` 提示 Android SDK 异常

优先确认：

- `flutter config --android-sdk F:\AndroidSdk`
- `ANDROID_SDK_ROOT` 是否指向正确目录
- `cmdline-tools` 是否完整安装
- Android Studio 是否能正常打开 SDK Manager

### 11.3 JDK 版本不匹配

如果出现 Gradle、AGP、Java 相关报错，优先切换到 JDK 17：

```powershell
[Environment]::SetEnvironmentVariable('JAVA_HOME', 'F:\java\jdk-17', 'User')
```

重新打开终端后执行：

```powershell
java -version
flutter doctor -v
```

### 11.4 Windows 中文用户名导致缓存或构建异常

如果 Flutter、Gradle、Kotlin 缓存路径落在中文目录下，部分机器会出现奇怪编译错误。可以把缓存迁移到纯英文路径：

```powershell
[Environment]::SetEnvironmentVariable('PUB_CACHE', 'F:\PubCache', 'User')
[Environment]::SetEnvironmentVariable('GRADLE_USER_HOME', 'F:\GradleCache', 'User')
```

### 11.5 真机访问不到本地服务

检查以下问题：

- 手机和电脑是否在同一局域网
- 是否误用了 `127.0.0.1`
- 服务端端口是否已开放
- Windows 防火墙是否拦截
- Nginx 或反向代理是否正确转发

### 11.6 语音识别不可用

优先检查：

- 系统麦克风权限是否已授权
- 系统语音识别服务是否可用
- 当前设备是否支持 `speech_to_text`

即使语音失败，用户仍可继续手动输入文案，不会阻塞主流程。

### 11.7 下载完成但本地文件找不到

下载管理服务会在启动时自动校验文件是否还存在。如果文件已被系统清理或手动删除，会把记录标记为失败，提示重新下载。

### 11.8 版本更新检测无效

检查以下项是否一致：

- `lib/app/constants.dart` 中的 `appVersion`
- `lib/app/constants.dart` 中的 `appBuildNumber`
- `lib/app/constants.dart` 中的 `releasePlatform`
- `lib/app/constants.dart` 中的 `releaseChannelCode`
- 服务端发布信息配置

## 12. 关键文件索引

- 应用入口：`lib/main.dart`
- 全局依赖：`lib/app/app_binding.dart`
- 路由定义：`lib/app/routes.dart`
- 应用常量：`lib/app/constants.dart`
- 主题定义：`lib/app/theme.dart`
- API 客户端：`lib/data/api/api_client.dart`
- API 服务：`lib/data/api/api_service.dart`
- 创作控制器：`lib/presentation/create/create_controller.dart`
- 历史控制器：`lib/presentation/history/history_controller.dart`
- 下载管理服务：`lib/core/services/download_manager_service.dart`
- 个人中心控制器：`lib/presentation/settings/settings_controller.dart`
- Android 构建配置：`android/app/build.gradle`
- iOS 权限配置：`ios/Runner/Info.plist`

## 13. 快速命令清单

```powershell
flutter pub get
flutter doctor -v
adb devices
flutter devices
flutter run --dart-define=AUTH_SERVER_BASE_URL=https://api.memovideos.cn
flutter analyze
flutter test
flutter build apk --release --dart-define=AUTH_SERVER_BASE_URL=https://api.memovideos.cn
flutter build appbundle --release --dart-define=AUTH_SERVER_BASE_URL=https://api.memovideos.cn
```

---

如果这份 README 还需要继续补“接口返回示例”“发布流程图”“后台部署参数说明表”，可以在此基础上继续扩展，但作为当前 Flutter 客户端仓库说明，它已经覆盖了项目介绍、模块说明、功能使用、构建发布和排障使用。
