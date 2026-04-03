# 拾光视频

面向中老年用户的 Flutter App，提供从文字/语音输入、AI 矫正文案、提示词生成、参考图上传到视频生成和历史管理的完整链路。

## 技术栈

- Flutter 3.x
- GetX 状态管理与命名路由
- Dio 网络请求
- GetStorage + flutter_secure_storage
- image_picker / record / video_player

## 配置说明

后端服务基地址当前默认为：

```text
http://192.168.101.21:9999
```

设置页可配置：

- LLM Base URL，默认 `https://api.99hub.top`
- LLM API Key，传递方式 `Authorization: Bearer <YOUR_LLM_API_KEY>`
- LLM Model，默认 `gpt-5.4-mini`
- Video Base URL，默认 `https://api.99hub.top`
- Video API Key
- Video Model，默认 `veo_3_1-fast-components-4K`
- Speech Base URL，默认 `https://api.99hub.top`
- Speech API Key
- Speech Model，默认 `gpt-4o-mini-audio-preview`

真实密钥不会写死在源码中，API Key 仅通过设置页输入，并保存到 `flutter_secure_storage`。

占位示例：

```text
sk-xxxxxxxxxxxxxxxxxxxxxxxx
```

`.env.example` 仅作为部署参考，不会自动注入到应用运行时。

## 运行步骤

1. 执行 `flutter pub get`
2. 确认后端服务可访问
3. 执行 `flutter run`
4. 首次进入设置页，保存 LLM / Video / Speech 配置

## 常见排查

### 1. 录音失败

- 确认 Android 已授予麦克风权限
- 确认 iOS 已同意 Microphone 权限弹窗
- 语音失败后仍可继续手动输入文案

### 2. 图片无法选择

- Android 13+ 建议使用系统照片选择器
- iOS 需同意相册访问

### 3. 视频生成超时

- 当前策略为每 2 秒轮询一次，最多 60 次
- 超时后请在“历史记录”页查看最新状态

### 4. 设置保存后未生效

- 确认后端 `/api/config` 可写
- 本地配置也会保存，重启应用后仍会恢复

### 5. 安卓真机调试异常

- 确认 `adb devices` 可看到设备
- 确认 `flutter doctor -v` 无环境报错
