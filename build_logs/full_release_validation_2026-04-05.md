# 正式打包发布验证日志

- 日期: 2026-04-05
- 结论: 通过
- 范围: 后端、H5、Web 管理端、App 打包、真实视频生成闭环、积分与充值链路、注册登录链路

## 已完成验证

- 后端接口与静态校验:
  `python -m compileall backend/app` 通过。
- H5 脚本校验:
  `node --check elderly-video-app/public/app.js` 通过。
- Web 管理端:
  `npm run build` 通过，生产构建产物已刷新。
- App:
  `flutter test` 通过。
- App:
  `flutter analyze` 通过。
- App:
  `flutter build apk --release --dart-define=AUTH_SERVER_BASE_URL=https://api.memovideos.cn` 已完成，生成签名 release APK。
- APK 签名校验:
  使用 `apksigner verify --verbose --print-certs` 校验通过，当前包已通过 v1 和 v2 签名校验。

## 完整业务闭环

- H5 注册闭环:
  使用临时邀请码完成新用户注册、登录、获取用户信息。
- 账户链路:
  完成修改密码、忘记密码、再次登录、更新个人资料。
- 积分链路:
  邀请注册后获得 30 积分，随后创建新用户首充订单并由后台改为已到账，积分提升到 60。
- 语音链路:
  生成本地测试语音 WAV，通过 H5 语音转文字接口识别成功。
- 文案链路:
  完成文本纠错、提示词生成、图片上传。
- 视频生成链路:
  简单模式成功生成并下载成片。
- 视频生成链路:
  入门模式第一次因上游返回 `PUBLIC_ERROR_AUDIO_FILTERED` 失败，积分自动退回；收窄为最小安全输入后再次创建，成功生成并下载成片。
- 视频生成链路:
  自定义模式完成参考视频上传、任务创建、轮询完成、成片下载。
- 后台核对:
  在管理端接口侧核对了用户、任务、语音日志、积分流水、充值订单、用户统计，链路数据一致。
- 清理:
  已删除本轮临时邀请码、临时用户、相关任务记录、积分流水、充值订单、语音日志和本地媒体文件，未在本地数据库留下垃圾测试数据。

## 本轮真实任务结果

- 失败任务:
  `63`，简单模式，上游返回 `PUBLIC_ERROR_AUDIO_FILTERED`，积分已自动退回。
- 成功任务:
  `64`，简单模式。
- 失败任务:
  `65`，入门模式，附加中文补充说明时被上游拦截，积分已自动退回。
- 成功任务:
  `66`，入门模式，最小安全输入。
- 成功任务:
  `67`，自定义模式，包含参考视频上传。

## 产物位置

- 签名 release APK:
  [shiguang-video-v1.2.0-release.apk](E:/FlutterProject/momenta/.deploy-pack/shiguang-video-v1.2.0-release.apk)
- 整体发布归档:
  [momenta-release-20260405-0758.zip](E:/FlutterProject/momenta/.deploy-pack/momenta-release-20260405-0758.zip)
- 完整结构化状态:
  [full_release_validation_state_2026-04-05.json](E:/FlutterProject/momenta/build_logs/full_release_validation_state_2026-04-05.json)
- 先前基础烟测:
  [system_smoke_2026-04-05.md](E:/FlutterProject/momenta/build_logs/system_smoke_2026-04-05.md)

## 补充说明

- Web 管理端构建仍有既有警告:
  `unocss exclude` 弃用提示、`loading.js/loading.css` 运行时资源提示、`naive-ui` 大包体提示。
- App release 构建输出中仍有环境级 Kotlin/NDK 警告，但本次 `assembleRelease` 已成功产出 APK 文件。
