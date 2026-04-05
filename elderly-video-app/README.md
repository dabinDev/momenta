# 拾光视频 H5 前端

当前目录名仍保留为 `elderly-video-app`，只是为了兼容历史脚本和已有部署引用。

需要明确的是：

- 旧的 `server.js + public/` 独立 Node/Express H5 形态已经废弃
- 旧形态后续不再维护
- 当前目录现在承载的是新的 `Vue 3 + Vite` 用户侧 H5 前端

## 当前职责

- 登录、注册、找回密码
- AI 创作工作台
- 历史任务记录
- 设置、邀请码、App 下载入口

## 环境

- 本地开发：`.env.development`
- 正式构建：`.env.production`
- 本地开发默认不再直连跨域后端，而是通过 Vite 代理同源转发 `/api/*` 和 `/media/*`
- 正式环境默认使用同源 `/api/*`，由 Nginx 反向代理到 FastAPI

## 启动

```bash
npm install
npm run dev
```

## 构建

```bash
npm run build
```

构建产物输出到：

```text
dist/
```

## 部署说明

- 正式环境按静态站点部署 `dist/`
- `/api/*` 统一走后端 FastAPI
- 本地 `npm run dev` 依赖 `vite.config.js` 中的代理配置完成联调
- 不再通过 Node 服务做 H5 代理层
