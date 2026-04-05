# 系统联调测试日志

- 日期: 2026-04-05
- 工作区: `E:\FlutterProject\momenta`
- 结论: 通过
- 结果摘要: 运行态烟测 49 项通过，0 项失败；构建与静态校验均通过，无阻断问题

## 运行态烟测

- 后端直连:
  `admin` 登录、`appuser` 登录、`/api/v1/app_config/global`、`/api/v1/base/userinfo`、`/api/create-workbench`、`/api/prompt-templates`、`/api/video-templates`、`/api/points/summary`、`/api/recharge/products`、`/api/tasks`、`/api/tasks/summary`、`/api/v1/user/list`、`/api/v1/user/metrics`、`/api/v1/point_ledger/list`、`/api/v1/recharge_order/list`、`/api/v1/model_catalog/list` 全部返回成功。
- 后端下载链路:
  使用现有已完成任务验证 `/api/tasks/{id}/download`，返回 `200` 且成功读取到视频字节流。
- H5:
  首页访问成功；通过 H5 代理完成 `appuser` 登录、获取当前用户、读取创作工作台、读取历史汇总、读取历史列表、历史下载链路验证，全部成功。
- H5 注册闭环:
  管理端接口临时生成 1 个邀请码，经 H5 `/api/auth/register` 成功注册临时账号；随后通过 H5 登录并读取用户信息成功；测试结束后已删除临时用户和邀请码。
- Web 管理端:
  本地开发服务启动成功；首页访问成功；通过开发代理完成 `/api/v1/base/access_token`、`/api/v1/base/userinfo`、`/api/v1/base/usermenu`、`/api/v1/user/list` 验证，全部成功。

## 静态与构建校验

- `python -m compileall backend/app`: 通过
- `node --check elderly-video-app/public/app.js`: 通过
- `npm run build` in `frontend`: 通过
- `flutter test`: 通过
- `flutter analyze`: 通过
- `flutter build apk --debug --dart-define=AUTH_SERVER_BASE_URL=http://127.0.0.1:10099`: 通过

## 产物

- 结构化烟测结果:
  [system_smoke_2026-04-05.json](E:/FlutterProject/momenta/build_logs/system_smoke_2026-04-05.json)
- 本地调试 APK:
  [app-debug.apk](E:/FlutterProject/momenta/build/app/outputs/flutter-apk/app-debug.apk)

## 非阻断告警

- 管理端构建存在既有告警:
  `unocss exclude` 弃用提示、`/admin/resource/loading.js` 与 `/admin/resource/loading.css` 运行时资源提示、`naive-ui` 大包体告警。
- Flutter APK 构建存在环境告警:
  Java `source/target 8` 过时提示、Android NDK `source.properties` 缺失提示。
- 上述告警未阻塞本次构建和烟测，当前不影响本地联调结果。
