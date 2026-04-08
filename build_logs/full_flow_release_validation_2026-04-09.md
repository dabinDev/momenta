# 2026-04-09 全流程回归与 1.3.2 发版记录

## 环境
- H5: `https://cylonai.cn/`
- 管理端: `https://cylonai.cn/admin/`
- API: `https://api.cylonai.cn/`
- 文件下载: `https://file.cylonai.cn/`

## 版本发布
- Flutter 版本号: `1.3.2+6`
- 发布记录 ID: `9`
- 发布标题: `Shiguang Video V1.3.2`
- APK 下载地址: `https://file.cylonai.cn/api/app/releases/files/V1.3.2.apk`
- 本地构建产物:
  - `build/app/outputs/flutter-apk/app-release.apk`
  - `build/app/outputs/flutter-apk/V1.3.2.apk`

## 业务闭环回归
### 1. 邀请与注册
- 使用后台接口创建种子邀请码，完成邀请人注册与登录。
- 在 H5 设置页打开“我的邀请”，成功获取邀请人专属邀请码。
- 使用邀请人邀请码完成被邀请用户注册与登录。
- 积分校验通过:
  - 邀请人注册后积分: `30`
  - 被邀请用户注册后积分: `30`
  - 被邀请用户注册完成后，邀请人积分: `60`

### 2. H5 创建视频
- 参考图: `.codex-test/safe-reference.jpg`
- 任务 ID: `65`
- 用户: `flow_invitee_1775673`
- 任务类型: `image_to_video`
- 时长: `10s`
- 状态: `completed`
- 积分扣减: `10`
- COS 视频地址: `https://memofile-1251742036.cos.ap-shanghai.myqcloud.com/videos/task_65.mp4`
- 服务端兜底地址: `https://api.cylonai.cn/media/generated_videos/task_65.mp4`

### 3. H5 历史与下载
- H5 历史页成功返回任务 `65`。
- H5 下载按钮成功触发 `/api/tasks/65/download`。
- 下载文件已落地验证:
  - `elderly-video-app/.codex-test/task_65.mp4`

### 4. 管理端查看记录
- 管理端任务页 `https://cylonai.cn/admin/operation/task` 成功加载。
- 页面列表能看到任务 `65`，状态为 `completed`。

## 版本更新校验
- `GET /api/app/releases/latest?platform=android&channel=lan&current_version=1.3.1&current_build_number=5`
  - `has_update = true`
  - `latest.version_name = 1.3.2`
  - `latest.build_number = 6`
- `GET /api/app/releases/latest?platform=android&channel=lan&current_version=1.3.2&current_build_number=6`
  - `has_update = false`

## 文件下载校验
- `https://file.cylonai.cn/api/app/releases/files/V1.3.2.apk`
  - 支持范围下载
  - `Content-Type = application/vnd.android.package-archive`

## 备注
- 回归中曾有一条测试任务 `64` 被第三方返回 `PUBLIC_ERROR_AUDIO_FILTERED`，未作为正式通过结果。
- 最终以成功任务 `65` 作为本次发版回归通过依据。
