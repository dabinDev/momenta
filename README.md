# 拾光视频

面向中老年用户的 AI 短视频项目，当前仓库包含 4 个主要端：

- Flutter App 端
- H5 Web 端
- Web 管理端
- FastAPI 后端服务端

后端已经承担了 AI 创作工作台、提示词模板、视频模板、文本纠错、提示词生成、视频任务、语音转写、版本发布等核心能力；App、H5、管理端都围绕同一套后端接口工作。

## 1. 仓库结构

| 目录 | 角色 | 技术栈 | 主要职责 |
| --- | --- | --- | --- |
| `/` | App 端 | Flutter 3.x + GetX | 用户登录、AI 创作、历史记录、设置、版本更新 |
| `backend/` | 后端服务端 | FastAPI + Tortoise ORM + SQLite | 统一 API、任务管理、媒体存储、AI 网关、管理后台 API |
| `frontend/` | Web 管理端 | Vue 3 + Vite + Naive UI | 用户/角色/菜单/API/任务/语音日志/发布管理/应用配置/AI 调试 |
| `elderly-video-app/` | H5 Web 端 | Express + 静态页面 | Web 演示入口、登录、转发 App 业务接口、运行时切换后端地址 |

## 2. 整体架构

```text
Flutter App ----------------------\
                                   \
H5 Web (Express + public) ---------> FastAPI Backend -----------------> 第三方 LLM / 视频 / 语音服务
                                   /        |
Web Admin (Vue3) -----------------/         +--> SQLite (backend/db.sqlite3)
                                            +--> 本地媒体目录 (backend/media)
                                            +--> App 发布记录 / 任务 / 语音日志
```

### 后端当前实际承载的业务接口

App/H5 业务接口：

- `/api/create-workbench`：下发创作工作台配置
- `/api/prompt-templates`：提示词模板列表
- `/api/video-templates`：视频模板列表
- `/api/upload-images`：上传参考图片
- `/api/upload-reference-video`：上传参考视频
- `/api/correct-text`：AI 纠错
- `/api/generate-prompt`：AI 生成英文提示词
- `/api/voice/transcribe`：语音转文字
- `/api/tasks`：简单模式创建任务
- `/api/starter-tasks`：入门模式创建任务
- `/api/custom-tasks`：自定义模式创建任务
- `/api/tasks/*`：任务查询、历史、删除、汇总
- `/api/app/releases/latest`：App 更新检测

管理端接口：

- `/api/v1/*`：登录、鉴权、用户、角色、菜单、接口、部门、审计日志、任务、语音日志、App 发布、应用配置等

静态资源：

- `/media/*`：参考图片、参考视频、生成视频

## 3. 端口和地址统一规则

这是当前仓库最需要注意的发布点。当前已经整理为“本地开发”和“远端部署”两套可共存配置，不需要再来回手改同一个 `.env`。

### 当前推荐的最终结构

| 场景 | 地址 | 说明 |
| --- | --- | --- |
| H5 首页 | `https://memovideos.cn/` | 对外 Web 入口 |
| Web 管理端 | `https://memovideos.cn/admin/` | 对外管理后台入口 |
| 后端 API | `https://api.memovideos.cn` | App / 管理端 / 对外 API 入口 |
| 后端服务内部监听 | `http://127.0.0.1:10099` | 服务器内部服务互调 |
| H5 服务内部监听 | `http://127.0.0.1:3000` | 服务器内部服务互调 |

### 本地开发与远端部署共存规则

| 模块 | 本地默认 | 远端发布 |
| --- | --- | --- |
| backend | `backend/.env` | `backend/.env.production` |
| backend 默认值 | `http://127.0.0.1:10099` | 由 `.env.production` 覆盖到 `https://api.memovideos.cn` |
| frontend 开发 | `frontend/.env.development` | 本地代理到 `127.0.0.1:10099` |
| frontend 生产 | `frontend/.env.production` | 构建后走同源 `/api/v1` |
| H5 本地 | `elderly-video-app/config.json` | 默认 `http://127.0.0.1:10099` |
| H5 远端 | `BACKEND_BASE_URL` 环境变量 | 由 systemd 注入 `http://127.0.0.1:10099` |
| Flutter | `dart-define` | 本地调试与远端打包分别传入不同地址 |

### 代码里的现状

| 模块 | 当前默认值 | 来源 |
| --- | --- | --- |
| 后端服务端口 | `10099` | `deploy/tencent-cvm/momenta-backend.service` |
| 后端 `PUBLIC_BASE_URL` 默认值 | `http://127.0.0.1:10099` | `backend/app/settings/config.py` |
| App 编译时默认后端地址 | `https://api.memovideos.cn` | `lib/app/constants.dart` |
| 管理端开发代理目标 | `http://127.0.0.1:10099` | `frontend/.env.development` |
| H5 默认后端地址 | `http://127.0.0.1:10099` | `elderly-video-app/config.json` |
| H5 自身服务端口 | `3000` | `elderly-video-app/server.js` |
| 管理端开发端口 | `3100` | `frontend/.env.development` |

### 发布时必须统一

建议先确定一个对外统一地址，再让所有端都指向它。推荐两种方式：

#### 方式 A：后端对外直接暴露 `9999`

适合本地联调。

- App 用 `--dart-define=AUTH_SERVER_BASE_URL=http://<IP>:9999`
- 管理端开发代理改到 `http://<IP>:9999`
- H5 `config.json` 改到 `http://<IP>:9999`
- 后端 `PUBLIC_BASE_URL` 也改到 `http://<IP>:9999`

#### 方式 B：对外统一暴露 `10099` 或域名，后端内部仍跑 `9999`

适合正式部署。

- Nginx/网关对外监听 `10099` 或 `443`
- 反向代理到 `127.0.0.1:9999`
- App、H5、管理端全部只认公网地址
- 后端 `PUBLIC_BASE_URL` 也要改成公网地址

如果这一层不统一，会直接影响：

- App 登录和任务创建
- H5 登录和接口转发
- 管理端代理转发
- `/media/*` 生成的资源访问地址
- 生成视频回写后的下载地址

## 4. 后端服务端发布文档

### 4.1 技术和数据落点

- Python：`>=3.11`
- Web 框架：FastAPI
- ORM：Tortoise ORM
- 默认数据库：`backend/db.sqlite3`
- 媒体目录：`backend/media`
- 环境变量读取顺序：`backend/.env` -> 仓库根目录 `.env`

### 4.2 当前后端负责的核心能力

- 鉴权和管理后台接口
- 用户 AI 配置存储
- 提示词模板、视频模板、工作台模式下发
- 文本纠错和提示词生成
- 简单 / 入门 / 自定义三种视频任务编排
- 本地图片、参考视频、生成视频存储
- 语音转写日志
- App 发布记录和更新检测

### 4.3 AI 配置的真实生效方式

当前代码已经改成“后端统一维护，全局生效”模式。

- 平台 `base URL` 与全局 `SK` 由管理端“平台配置”统一维护
- 图片生成、视频生成、音频解析、文字解析四类模型由管理端“模型管理”统一维护
- App、H5、后台 AI 调试台默认都读取这一套全局模型配置
- 少量付费用户如果开通专属通道，才会覆盖全局配置，且入口隐藏在管理端内部

当前代码默认值对应的是：

- 图片模型：`gemini-2.5-flash-image`
- 文案模型：`gpt-5.4-mini`
- 视频模型：`veo_3_1-fast-components-4K`
- 语音识别模型：`gpt-4o-mini-audio-preview`
- 默认 AI Base URL：`https://api.99hub.top`

说明：

- `.env.example` 里的平台地址与默认模型仅作为部署参考
- 发布前应在管理端确认“平台配置”和“模型管理”两页都已配置完成

### 4.4 本地开发启动

推荐先复制一份本地环境文件：

```bash
cd backend
copy .env.example .env
```

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app:app --host 0.0.0.0 --port 10099 --reload
```

本地默认监听：

```text
http://127.0.0.1:10099
```

### 4.5 建议的生产启动方式

生产环境不要直接依赖本地 `.env`，而应使用单独的生产环境文件：

```bash
cp backend/.env.production.example backend/.env.production
```

并填写生产地址，例如：

```env
SERVER_BASE_URL=https://api.memovideos.cn
PUBLIC_BASE_URL=https://api.memovideos.cn
```

`backend/run.py` 默认带 `reload=True`，适合开发，不建议直接作为生产守护命令。

生产建议改用：

```bash
cd backend
.venv\Scripts\activate
uvicorn app:app --host 0.0.0.0 --port 10099
```

如果是 Linux 服务器，可配合 `systemd` / `supervisor` / `pm2` 守护。

### 4.6 必配环境变量

本地至少确认以下配置：

```env
SERVER_BASE_URL=http://127.0.0.1:10099
PUBLIC_BASE_URL=http://127.0.0.1:10099
IMAGE_PROXY_UPLOAD_URL=https://imageproxy.zhongzhuan.chat/api/upload
```

说明：

- `SERVER_BASE_URL` 仍用于部分 legacy 业务网关
- `PUBLIC_BASE_URL` 决定 `/media/*` 的对外访问地址
- 如果 `PUBLIC_BASE_URL` 填错，前端会拿到无法访问的图片和视频 URL

### 4.7 默认管理员账号

首次初始化且数据库里没有用户时，会自动创建：

- 用户名：`admin`
- 邮箱：`admin@admin.com`
- 密码：`123456`

发布后应第一时间修改该账号密码。

### 4.8 推荐反向代理

如果后端内部跑 `9999`，对外统一暴露 `10099`，可参考：

```nginx
server {
    listen 10099;
    server_name _;
    client_max_body_size 100m;

    location /api/ {
        proxy_pass http://127.0.0.1:9999;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /media/ {
        alias /path/to/momenta/backend/media/;
    }
}
```

### 4.9 生产验收清单

- `GET /api/app/releases/latest` 可正常返回
- 管理端“平台配置”可读取并保存全局平台配置
- 管理端“模型管理”可同步目录、推荐模型并应用为全局模型
- `/api/create-workbench` 能拿到 3 种模式和模板列表
- 图片上传后 `/media/*` 可外网访问
- 简单 / 入门 / 自定义任务都能创建
- 生成完成后视频地址可直接下载
- 语音转写日志能在后台看到

## 5. Web 管理端发布文档

### 5.1 技术栈和职责

- Vue 3
- Vite
- Naive UI

当前管理端覆盖的模块包括：

- 工作台
- 用户管理
- 角色管理
- 菜单管理
- 接口管理
- 部门管理
- 审计日志
- 视频任务
- 语音日志
- 版本发布
- 应用配置
- AI 调试

### 5.2 本地开发启动

```bash
cd frontend
npm install
npm run dev
```

默认本地访问：

```text
http://127.0.0.1:3100
```

当前开发代理默认指向：

```text
http://127.0.0.1:10099
```

当前仓库已经默认按本地 `10099` 配置好，一般不需要再改。

### 5.3 生产构建

生产环境直接使用：

```text
frontend/.env.production
```

该文件会让管理端构建后通过同源 `/api/v1` 访问后端，因此适合部署到：

- `https://memovideos.cn/admin/`

构建命令：

```bash
cd frontend
npm install
npm run build
```

构建产物目录：

```text
frontend/dist
```

### 5.4 生产发布方式

推荐把 `frontend/dist` 当静态站点发布，再将 `/api/v1` 反向代理到后端。

示例：

```nginx
server {
    listen 8080;
    server_name _;
    root /path/to/momenta/frontend/dist;
    index index.html;

    location / {
        try_files $uri /index.html;
    }

    location /api/v1/ {
        proxy_pass http://127.0.0.1:9999/api/v1/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 5.5 登录和发布配合

管理端上线后，建议优先做三件事：

1. 修改默认管理员密码
2. 检查“应用配置 / AI 调试”页面能否正常联通后端
3. 在“版本发布”页面创建一条有效发布记录，供 App 检测更新

## 6. H5 Web 端发布文档

### 6.1 当前定位

`elderly-video-app/` 不是纯静态页面，它本身是一个 Express 服务，负责：

- 托管 `public/` 页面
- 处理登录
- 转发 App 业务接口到后端
- 通过 `config.json` 或环境变量切换后端地址

### 6.2 本地开发启动

```bash
cd elderly-video-app
npm install
node server.js
```

默认端口：

```text
http://127.0.0.1:3000
```

### 6.3 后端地址配置

H5 当前本地默认从这里读取后端地址：

- `elderly-video-app/config.json`

当前仓库里的值是：

```json
{
  "backendBaseUrl": "http://127.0.0.1:10099"
}
```

当前仓库已经默认按本地 `10099` 配置好。

远端部署时，不建议改这个文件，而是通过环境变量覆盖：

```bash
BACKEND_BASE_URL=http://127.0.0.1:10099
```

当前远端 systemd 已按这种方式配置，因此本地 `config.json` 和远端发布不会互相污染。

### 6.4 H5 对后端依赖的关键接口

- `/api/auth/login`
- `/api/create-workbench`
- `/api/prompt-templates`
- `/api/video-templates`
- `/api/upload-images`
- `/api/upload-reference-video`
- `/api/correct-text`
- `/api/generate-prompt`
- `/api/voice/transcribe`
- `/api/tasks`
- `/api/starter-tasks`
- `/api/custom-tasks`
- `/api/app/releases/latest`

### 6.5 生产发布方式

H5 端没有单独前端构建流程，直接运行 Node 服务即可：

```bash
cd elderly-video-app
npm install --production
set BACKEND_BASE_URL=http://127.0.0.1:10099
node server.js
```

建议放在 `pm2` 或系统服务中守护，并保留 `config.json` 的持久化。

### 6.6 发布后检查点

- 登录是否正常
- 设置页是否能保存 AI 配置
- 工作台是否能拉到模式和模板
- 图片、参考视频上传是否成功
- 语音识别、AI 纠错、提示词生成是否成功
- 任务轮询后是否能看到视频结果

## 7. App 端发布文档

### 7.1 基础信息

- 应用名称：`拾光视频`
- Flutter 包名：`momenta`
- Android `applicationId`：`com.dabindev.momenta.momenta`
- iOS Bundle Identifier：`com.dabindev.momenta.momenta`
- Android `minSdk`：`23`

### 7.2 App 当前能力

- 登录和个人设置
- 语音录入
- AI 文本纠错
- AI 提示词生成
- 简单 / 入门 / 自定义三种创作入口
- 上传参考图片
- 上传参考短视频
- 历史记录和结果下载
- 检查后端下发的最新版本

### 7.3 App 连接后端的方式

App 后端地址来自编译时参数：

```dart
String.fromEnvironment('AUTH_SERVER_BASE_URL')
```

当前默认值写在 `lib/app/constants.dart` 中：

```text
https://api.memovideos.cn
```

因此发布和联调时，建议始终显式传入正确地址。

### 7.4 本地调试

```bash
flutter pub get
flutter run --dart-define=AUTH_SERVER_BASE_URL=http://127.0.0.1:10099
```

如果是真机调试：

- Android 真机不要用 `127.0.0.1`
- 应改为电脑可访问的局域网 IP 或正式域名

### 7.5 Android 打包发布

签名读取自：

- `android/key.properties`

格式示例：

```properties
storeFile=../release.jks
storePassword=your-password
keyAlias=your-alias
keyPassword=your-password
```

构建命令：

```bash
flutter build apk --release --dart-define=AUTH_SERVER_BASE_URL=https://api.memovideos.cn
```

如果需要 `aab`：

```bash
flutter build appbundle --release --dart-define=AUTH_SERVER_BASE_URL=https://api.memovideos.cn
```

默认图标资源：

- `assets/app_icon/app_icon.png`

如果替换图标后需要重新生成平台图标：

```bash
dart run flutter_launcher_icons
```

### 7.6 iOS 发布

iOS 侧已配置：

- 麦克风权限
- 语音识别权限
- 相册读取权限
- 相册写入权限

发布步骤：

1. 用 Xcode 打开 `ios/Runner.xcworkspace`
2. 配置签名证书和 Team
3. 确认 Bundle Identifier
4. 用 Release 模式构建归档
5. 保持 `AUTH_SERVER_BASE_URL` 指向正式后端地址

示例：

```bash
flutter build ios --release --dart-define=AUTH_SERVER_BASE_URL=https://your-host
```

### 7.7 App 更新发布链路

App 不直接内置安装包地址，而是通过后端接口查询：

- `/api/app/releases/latest`

所以 Android 包发版的完整流程是：

1. 打出 APK
2. 把 APK 上传到可下载地址
3. 登录管理端
4. 在“版本发布”里新增版本记录
5. 填写 `platform`、`channel`、`version_name`、`build_number`、`download_url`
6. 设为激活版本
7. App 再通过更新检测接口拿到最新版本

## 8. 推荐发布顺序

推荐按下面顺序上线：

1. 准备远端配置文件：`backend/.env.production`
2. 部署后端，先确保 `https://api.memovideos.cn` 和 `/media/*` 可用
3. 登录后台修改默认管理员密码
4. 用测试账号在 App 或 H5 中完成 AI 配置
5. 发布管理端到 `https://memovideos.cn/admin/`
6. 发布 H5 到 `https://memovideos.cn/`
7. 打包 App，显式传 `https://api.memovideos.cn`
8. 在管理端录入 App 发布记录
9. 用真机完整回归简单 / 入门 / 自定义三种链路

## 9. 联调与回归建议

至少做以下复测：

### 通用

- 用户能正常登录
- H5 与 App 设置页不再展示服务器地址和 AI 配置
- `/api/create-workbench` 返回 3 个模式
- 模板列表正常显示

### AI 链路

- 语音识别成功
- 纠错成功
- 提示词生成成功
- 简单模式任务成功
- 入门模式任务成功
- 自定义模式任务成功

### 资源链路

- 图片上传成功
- 参考视频上传成功
- 生成后视频可在线播放或下载
- 管理端能看到任务记录和语音日志

### 发版链路

- 管理端新建发布记录后，App 能检测到更新
- 下载地址可用
- 强制更新开关符合预期

## 10. 当前仓库需要特别注意的事项

### 10.1 `9999` 和 `10099` 并不统一

这是当前最容易踩坑的点。发布前必须统一后再打包 App、启动 H5、启动管理端。

### 10.2 `backend/run.py` 仅适合开发

因为它固定 `reload=True`，生产不要直接拿它做守护进程入口。

### 10.3 `backend/Dockerfile` 仍按旧目录结构写的

当前 `backend/Dockerfile` 和 `backend/deploy/web.conf` 仍使用历史上的 `web/` 目录约定，但仓库里的管理端实际在 `frontend/`。

这意味着：

- 现有 Dockerfile 不能直接无改动拿来打当前仓库的一体化镜像
- 如果要走一体化镜像方案，需要先把 Dockerfile 里的前端构建路径改成当前 `frontend/`
- 更稳妥的做法是先按“后端、管理端、H5 分开发布”的方式落地

### 10.4 `.env.example` 不是完整真实运行态

当前 AI 实际调用依赖的是用户侧配置，不要只改 `.env.example` 就认为已经完成 AI 接入。

## 11. 建议的最小上线方案

如果你要尽快稳定上线，推荐这样做：

1. 后端内部监听 `127.0.0.1:10099`
2. `https://api.memovideos.cn` 对外提供 FastAPI
3. `https://memovideos.cn` 对外提供 H5 和管理端
4. backend 使用 `.env.production`
5. 管理端单独 `npm run build` 后以静态站部署到 `/admin/`
6. H5 单独跑 Node 服务，并通过 `BACKEND_BASE_URL` 指向 `127.0.0.1:10099`
7. App 打包时通过 `--dart-define` 写入 `https://api.memovideos.cn`
8. 先录一条有效发布记录，再发安装包给测试人员

这样最接近当前仓库真实结构，也最不容易因为目录或端口不一致导致发布失败。
