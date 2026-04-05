# H5 Vue 发布验证 2026-04-05

## 本次调整

- 将 `elderly-video-app/` 彻底收口为新的 `Vue 3 + Vite` 用户侧 H5 工程
- 明确旧 `server.js + public/` Node/Express H5 形态已废弃，不再维护
- H5 本地开发改为同源 `/api` + Vite 代理，避免浏览器联调被 CORS 拦截
- H5 正式环境改为同源 `/api`，由 Nginx 统一反向代理到 FastAPI
- 修复注册链路字段超长时直接报 500 的问题

## 本地开发态联调

环境：

- H5 Dev: `http://127.0.0.1:3012`
- Backend: `http://127.0.0.1:10099`

验证结果：

1. 通过后台接口创建一次性邀请码。
2. 使用 Playwright 打开 H5 登录页，进入注册页。
3. 填写新用户、邀请码并完成注册。
4. 注册成功后自动回到登录页，并自动带入刚注册的用户名。
5. 使用新账号完成登录，成功进入 `/app/create`。
6. 切换到 `/app/history` 和 `/app/settings`，页面正常渲染。
7. 打开“我的邀请”，成功读取个人邀请码与邀请记录入口。

结果：通过。

## 注册链路额外修复

发现问题：

- 注册用户名超过数据库 `User.username` 的 `max_length=20` 时，后端此前没有前置校验，浏览器会看到 500。

修复：

- 后端 `CredentialsSchema`、`RegisterRequest`、`UserCreate`、`UserUpdate`、`ForgotPasswordRequest`、`UpdateCurrentUserProfile` 补齐长度约束。
- H5 注册页增加用户名长度前置校验和 `maxlength=20`。
- App 注册页控制器同步增加用户名长度校验。

回归结果：

- 正常长度用户名注册：200 成功。
- 超长用户名注册：422 参数校验失败，不再出现 500。

## 正式构建校验

执行：

```bash
cd elderly-video-app
npm run build
npm run preview -- --host 127.0.0.1 --port 3011
```

验证：

- 生产构建成功输出到 `elderly-video-app/dist`
- 预览站点 `http://127.0.0.1:3011` 可正常打开
- 登录页、注册页静态渲染正常，无页面脚本报错

说明：

- 本地 `preview` 仅用于校验正式包可启动
- 生产接口闭环以线上同源部署后的实际冒烟为准

## 线上发布与冒烟

发布时间：

- 2026-04-05 16:26 CST

线上变更：

- `https://memovideos.cn/` 从旧 Express H5 切换为 Nginx 静态站点
- `https://memovideos.cn/` 的 `/api/*` 同源转发从旧 `127.0.0.1:3000` 改为后端 `127.0.0.1:10099`
- `momenta-h5.service` 已停止并禁用
- `momenta-backend.service` 已重启并加载新的注册字段校验

线上验证结果：

1. `curl -I https://memovideos.cn/` 返回 `200`，响应头不再带 `X-Powered-By: Express`。
2. `curl https://memovideos.cn/` 返回新的 Vite `index.html`，已引用 `/assets/index-*.js`。
3. `curl -I https://memovideos.cn/admin/` 返回 `200`，管理端入口未受影响。
4. `curl https://api.memovideos.cn/api/v1/base/userinfo -H "Authorization: Bearer invalid"` 返回统一 401 JSON。
5. 通过线上管理员接口创建邀请码。
6. 使用 Playwright 在 `https://memovideos.cn` 完成受邀注册、登录、进入创作页、切换记录页、打开设置页和邀请中心。

结果：通过。
