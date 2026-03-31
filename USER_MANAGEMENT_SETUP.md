# 用户管理系统说明

当前目录已包含两部分：

- `backend`：FastAPI 用户管理后台
- `frontend`：Vue 3 管理端

采用的 GitHub 模板：

- `mizhexiaoxiao/vue-fastapi-admin`

为了适配你当前这台 Windows 机器，我做了本地兼容调整：

- 后端改为使用 Tortoise 直接建表
- 密码散列改为 `pbkdf2_sha256`
- 新增移动端可用的登录、忘记密码、修改密码接口
- 同时兼容 `token` 头和 `Authorization: Bearer <token>`

## 已验证

- `frontend` 已成功执行 `npm run build`
- `backend` 已成功初始化 SQLite 数据库
- 后端登录、创建用户、忘记密码、修改密码接口都已通过真实 HTTP 测试
- Flutter 已通过 `flutter analyze`

默认管理员账号：

- 用户名：`admin`
- 密码：`123456`

## 启动方式

### 启动后端

```powershell
cd E:\FlutterProject\momenta\backend
.\.venv\Scripts\Activate.ps1
python run.py
```

启动后可访问：

- API 文档：`http://127.0.0.1:9999/docs`
- 管理后台登录接口：`http://127.0.0.1:9999/api/v1/base/access_token`

数据库文件：

- `E:\FlutterProject\momenta\backend\db.sqlite3`

### 启动前端管理端

```powershell
cd E:\FlutterProject\momenta\frontend
npm run dev
```

默认地址：

- `http://127.0.0.1:3100`

## App 登录接口

Flutter App 当前写死的认证服务地址是：

- `http://192.168.12.197:9999`

接口如下：

- 登录：`POST /api/v1/base/access_token`
- 当前用户信息：`GET /api/v1/base/userinfo`
- 忘记密码：`POST /api/v1/base/forgot_password`
- 修改密码：`POST /api/v1/base/change_password`

### 登录请求体

```json
{
  "username": "appuser",
  "password": "123456"
}
```

### 忘记密码请求体

```json
{
  "username": "appuser",
  "email": "appuser@example.com",
  "new_password": "654321"
}
```

### 修改密码请求体

```json
{
  "old_password": "654321",
  "new_password": "123456"
}
```

修改密码时支持两种认证头：

- `Authorization: Bearer <token>`
- `token: <token>`

## 目录说明

### backend

- `app/api`：接口层
- `app/controllers`：业务逻辑
- `app/models`：数据模型
- `app/schemas`：请求和响应结构
- `app/settings`：配置
- `run.py`：后端入口

### frontend

- `src/views`：页面
- `src/api`：前端接口封装
- `src/router`：路由
- `src/store`：状态管理
- `settings`：主题与布局配置

### Flutter App

- `lib/presentation/auth`：登录、忘记密码、修改密码页面
- `lib/presentation/settings`：账号安全入口
- `lib/presentation/history`：按登录账号管理本地历史记录
- `lib/data/repositories/auth_repository_impl.dart`：登录态持久化
- `lib/data/api/api_service.dart`：App 调后端认证接口
- `lib/data/repositories/history_repository_impl.dart`：历史记录本地持久化与分页管理
