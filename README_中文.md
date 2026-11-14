# GPS Joystick v0.3 — 持续移动 + 其他 App 测试版

**目标设备**：iPhone 7 Plus、iOS 15.8.8、Dopamine Rootless、ElleKit。

这是基于 v0.2 的修复源码，**尚未通过 iPhone 真机验证**。不是已编译的 `.deb`。

## 本次修改

1. **持续移动**：把 SpringBoard 摇杆移动计时器从默认 RunLoop 模式改为 `NSRunLoopCommonModes`。旧版在手指持续拖动时可能停止计时。
2. **其他 App**：新增针对使用 UIKit/CoreLocation 的第三方 App 的运行时定位 Hook，应用 `CLLocationManager.location` 及 `CLLocation.coordinate` 返回当前生效的虚拟坐标。
3. **更新回调**：对于调用 `startUpdatingLocation` 的 App，每约 0.3 秒尝试通过 `locationManager:didUpdateLocations:` 提供最新虚拟位置；`stopUpdatingLocation` 会停止此更新。`requestLocation` 也会尝试发送一次更新。
4. **安全范围**：浮窗仅在 SpringBoard 创建，系统守护进程和除 Apple Maps 外的 Apple 系统 App 不主动安装定位 Hook；真实 GPS 恢复保留。
5. 保留 **先输入坐标，点击确认后生效** 的机制。每次确认新坐标都会重置移动起点并暂停摇杆，之前的坐标不会成为起点。

## 重要限制

- 本项目是 **App 侧 CoreLocation 注入**，不是修改整个 iOS 的 `locationd` 定位服务；应用是否接受模拟坐标取决于它的定位实现及是否允许越狱插件注入。
- 某些应用使用非 `CLLocationManager` 方式获取位置，或阻止注入，因此可能不生效。
- 为获得更多兼容性，当前 `CLLocation.coordinate` 也被替换；这可能影响应用里用 `CLLocation` 表示的其他坐标，请在测试机谨慎试用。
- 这个版本会尝试注入更多第三方 App，**风险高于 v0.2**；需要先具备 Dopamine 关闭 Tweak Injection 和 Sileo 卸载方法。
- `startUpdatingLocation` 的回调主动在主线程发送；某些 App 可能要求其他线程或内部状态，不保证兼容。
- 不保证某些有反模拟定位检查的软件或游戏接受虚拟定位，更不提供绕过检查的机制。
- 恢复真实 GPS 仅清除本插件的坐标状态，其他定位工具需分别关闭。

## GitHub 自动编译

将本 ZIP 解压后，**把内部文件和目录直接上传到 GitHub 仓库根目录**，替换原有 `overlay/Controller.m`、`overlay/Tweak.xm`、`overlay/GPSJoystick.plist`、`overlay/GPSIPC.h`、`control`；保留 `.github/workflows/build-deb.yml`、`Makefile` 等现有内容。

GitHub Actions 会尝试生成 Rootless `.deb`，文件名预计为 `com.mj.gpsjoystick_0.3.0_iphoneos-arm64.deb`。若编译失败，查看日志而不是强行安装。

## 实机测试流程

1. 保留旧 `.deb` 备份，并确认 Dopamine 中可禁用 Tweak Injection。
2. 关闭 GPS Master、其他模拟定位插件。
3. 安装新版本 `.deb`，Respring，并**重启需要测试的第三方 App**以便重新注入。
4. 先在 Apple Maps：输入坐标，点击「确认定位」；按住摇杆 3–5 秒，看位置是否持续移动；松手后应停止。
5. 再在普通第三方定位 App 中测试当前虚拟位置。不要一开始就测试对定位模拟敏感的 App。
6. 点「恢复真实 GPS」，确认 Apple Maps 和其他测试 App 恢复真实位置。
7. 若出现闪退、异常定位或循环 Respring，立刻关闭 Tweak Injection 并通过 Sileo 卸载。

## 回滚

保留 v0.2 原来的 `.deb`：如果 v0.3 不稳定，先通过 Sileo 卸载 v0.3 并 Respring，再安装旧包；如果无法正常进入桌面，先用 Dopamine 禁用 Tweak Injection 再操作。

## 已知技术限制

不提供已签名的二进制文件。Apple iOS SDK 与 Theos 需要通过 GitHub Actions 或本地 macOS 编译，代码中的新 Hook 仍需 iOS 15 真机测试。
