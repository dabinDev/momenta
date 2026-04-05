# 积分/充值/邀请联调验证

时间：2026-04-05
环境：本地

## 代码校验

- `python -m compileall backend/app`
- `node --check elderly-video-app/server.js`
- `node --check elderly-video-app/public/app.js`
- `npm run build`（`frontend/`）
- `flutter analyze`
- `flutter test`

以上均通过。

## 联调链路

### 阶段一：积分开启

- 后台配置：
  - 积分系统：开启
  - 充值系统：开启
  - 单次视频扣积分：10
  - 微信支付：开启
  - 支付宝：关闭
- 管理员邀请码：`VNLZLHKC`
- H5 注册用户：`itest_on_0405131207`
- 注册后数据：
  - 新用户积分：30
  - 管理员积分：0 -> 30
  - 新用户自动获得邀请码：`PVZCF6WY`
- 使用图片 `Z:/同步盘/我的照片/证件/1ae108fe9cf241929af3227df36fb7ae.jpg` 通过 H5 创建视频任务：
  - 任务 ID：68
  - 提交后状态：`queued`
  - 提交后积分：30 -> 20
  - 轮询后状态：`failed`
  - 失败后积分自动退回：20 -> 30

### 阶段二：积分关闭

- 后台配置：
  - 积分系统：关闭
  - 充值系统：自动关闭
  - 微信支付：自动关闭
  - 支付宝：关闭
- H5 注册用户：`itest_off_0405131207`
- 注册后数据：
  - 新用户积分：0
  - 管理员积分：保持 30 不变
  - 新用户自动获得邀请码：`QNPABCP6`
- 使用同一张图片通过 H5 创建视频任务：
  - 任务 ID：69
  - 提交后状态：`queued`
  - 提交前积分：0
  - 提交后积分：0

## 规则联动验证

- 手工提交非法组合：
  - `points_enabled=false`
  - `recharge_enabled=false`
  - `wechat_pay_enabled=true`
- 后端返回归一化结果：
  - `points_enabled=true`
  - `recharge_enabled=true`
  - `wechat_pay_enabled=true`
  - `alipay_pay_enabled=false`

## 收尾状态

- 本地后台配置已恢复为：
  - 积分系统：开启
  - 充值系统：开启
  - 单次视频扣积分：10
  - 微信支付：开启
  - 支付宝：关闭
