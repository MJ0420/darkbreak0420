# GPS Joystick — Dopamine Rootless 预览源码 v0.2

> **性质：未经 iPhone 实机编译/运行的工程原型，不是可直接安装的 `.deb`。** 当前代码只在 Apple Maps 范围内注入测试定位；不要把它当成全系统定位修改器或 Pokémon GO 兼容工具。

## 设计目标

- 系统桌面 / 其他应用之上的可拖动小齿轮（浮窗由 SpringBoard 插件提供；跨 App 行为需要实机验证）
- 点击齿轮展开面板；地图选点、MapKit 地点搜索/搜索建议
- 输入纬度经度后**只更新草稿**；点击「确认定位 / Teleport」才发送定位指令
- 确认定位时清空摇杆方向，将**新生效的模拟坐标作为唯一移动起点**
- 推动摇杆按当前坐标连续计算移动；5–50 km/h；松手/暂停停止移动
- 一键恢复真实定位：本原型关闭自身模拟坐标并隐藏摇杆
- 收藏地点只回填输入框，仍须再次点击「确认定位」才能跳转

## 当前实现结构

- `overlay/Tweak.xm`: 仅注入 SpringBoard + Apple Maps（`overlay/GPSJoystick.plist`），对 `CLLocation` / `CLLocationManager` 的读取进行有限替换
- `overlay/Controller.m`: 系统悬浮窗、地图搜索、待确认坐标、摇杆、速度、收藏/恢复
- `overlay/GPSIPC.m`: 使用 Darwin notify 状态传递已确认坐标（需要实机检查进程通信）
- `src/GPSModel.c`: 与系统界面无关的坐标状态机和地球球面移动算法
- `tests/`: Linux/macOS 下可运行的纯 C 单元测试

## 兼容目标

- iPhone 7 Plus / iOS 15.8.8 / Dopamine Rootless / ElleKit
- Theos（需要 iPhoneOS SDK）+ 可编译 iOS ARM64 的工具链
- 不注入 GPS Master，包名为 `com.mj.gpsjoystick`，不会修改其他软件的授权文件

## 编译（推荐你已使用过的 Mac）

1. 按 [Theos 官方安装说明](https://theos.dev/docs/installation) 安装 Theos、Theos SDK 和 Xcode 命令行工具，并确保环境变量 `$THEOS` 正确。
2. 终端进入本工程根目录，运行：

   ```sh
   make clean
   make package THEOS_PACKAGE_SCHEME=rootless
   ```

3. 成功后生成的 `.deb` 在 `packages/`。请只用测试机，并先确保 Dopamine 可以进入 Safe Mode / 在 Sileo 里卸载出问题的插件。
4. 把 `.deb` 发送到手机，用 Sileo / Filza 安装并按提示 Respring。**这里不能保证你当前环境一次编译通过，需根据 Theos、SDK 版本处理构建错误。**

Theos Rootless 官方文档：https://theos.dev/docs/rootless

## 第一次实机验证（不要先在敏感 App 测试）

1. 在 Sileo 中确认插件可卸载，退出 GPS Master 的模拟定位，避免两套引擎冲突。
2. 重启 SpringBoard 后，检查小齿轮是否显示。
3. 先在搜索框搜索位置/地图选点。确认 Apple Maps 位置**不应**改变。
4. 输入坐标，点击「确认定位」。Apple Maps 中的模拟位置**应该尝试**改变；如果未改变则说明当前 CLLocation Hook 路线仍不完整。
5. 摇杆移动 5 km/h，查看地图是否连续变化；松开后停止。
6. 点击「恢复真实 GPS」，检查模拟坐标被清理。
7. 出现 SpringBoard 崩溃/循环 Respring 时，使用 Dopamine Safe Mode 禁用或卸载该包。

## 重要限制

- **未在真实 iPhone 上编译、安装或验证。** 当前运行的仅是底层模型自动化测试。
- Apple Maps 中的定位数据通常通过 CoreLocation 委托回调推送；当前只 Hook 位置属性和坐标 Getter，不能保证所有持续回调路径都立即更新。因此它是技术验证原型，不是已完成的真实系统级 GPS 引擎。
- 浮窗受 SpringBoard UIWindow 管理机制影响，不保证每个 App 上方都能持续显示。
- 首版只对 Apple Maps 测试定位；其他 App 的定位不应被假定已经修改。
- 不建议同时启用 GPS Master 或其他虚拟定位软件；可能发生冲突。
- 恢复功能仅撤销**本项目的**模拟定位；不会清理其他定位工具设定的状态。
- 应只用于获授权的软件测试及开发调试；游戏对模拟定位可能有额外检测。
