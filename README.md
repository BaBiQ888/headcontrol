# HeadControl

通过 Mac 摄像头识别快速摆头动作，把它映射成系统按键或滚轮事件 — 看文档时翻页、切桌面、控制窗口都可以脱手完成。

基于 SwiftUI + Vision + AVFoundation，纯本地推理（不联网），低 CPU 占用，常驻菜单栏。

---

## 特性

- **基准 + 速度门控** 检测器：抬头不会触发"低头"反向手势；慢速漂移自动忽略
- 实时摄像头预览 + 鼻尖追踪 + 触发阈值可视化
- 一键将四个方向手势映射到：方向键 / Page Up·Down / 切桌面 / 浏览器前进后退 / 滚轮
- 菜单栏 agent，无 Dock 图标，常驻后台
- 全部参数实时可调（窗口、阈值、平滑、冷却），调到合适一改默认值即可
- 自动记录最近手势历史 + 注入诊断信息

---

## 系统要求

- macOS 14 (Sonoma) 或更高
- Swift 6.0+（Xcode 16 / Command Line Tools 自带）
- Mac 内置 / USB 摄像头

---

## 快速开始

### 克隆 + 安装

```bash
git clone https://github.com/BaBiQ888/headcontrol.git
cd headcontrol
./Scripts/install.sh
```

`install.sh` 会自动构建、签名、拷到 `/Applications`、启动。

### 一次性证书设置（强烈推荐）

不做这一步，每次重新构建后 macOS 都会撤销 Camera / Accessibility 授权 — 因为 ad-hoc 签名身份每次会变。

打开 **钥匙串访问 → 证书助理 → 创建证书...**：

| 字段 | 值 |
|---|---|
| 名称（Name） | `HeadControl Dev` （必须一字不差） |
| 身份类型 | 自签名根证书（Self Signed Root） |
| 证书类型 | 代码签名（Code Signing） |

创建完后第一次运行 codesign 时会弹"是否允许 codesign 访问 HeadControl Dev"对话框，点 **始终允许**，输入登录密码。

之后每次 `./Scripts/install.sh` 都会自动用这个证书签名，授权永久有效。

### 授权摄像头 + 辅助功能

第一次启动后：

1. 弹窗"HeadControl 想要使用摄像头" → **允许**
2. 主窗口侧栏 → `Open Accessibility Settings`
3. 在系统设置里把 `/Applications/HeadControl.app` 拖进列表并勾上
4. 状态点变绿后，注入按键的开关才生效

如果之前授权失效过，重新授权前先清缓存：

```bash
tccutil reset Camera local.headcontrol
tccutil reset Accessibility local.headcontrol
```

---

## 工作原理

```
┌────────────────┐
│  AVFoundation  │  摄像头采样（前置，水平镜像）
│  (640×480)     │
└───────┬────────┘
        ▼
┌────────────────┐
│ Vision         │  人脸 landmarks → 鼻尖归一化坐标
│ FaceLandmarks  │  (x, y) ∈ [0, 1]²
└───────┬────────┘
        ▼
┌────────────────┐
│  EMA Smoother  │  α 可调，去抖动
└───────┬────────┘
        ▼
┌────────────────┐
│  Detector FSM  │  warmup → rest ⇄ cooling
│  baseline +    │  - 慢速 EMA 跟踪 baseline
│  velocity gate │  - 触发需越过 trigger radius 且速度足够
│                │  - cooling 期间不触发反向手势
└───────┬────────┘
        ▼
┌────────────────┐
│ Key Injector   │  CGEvent → 键码 / 滚轮
└────────────────┘
```

### 检测器状态机

| 状态 | 触发条件 | 动作 |
|---|---|---|
| **rest** | 鼻尖在 baseline 附近（< restRadius） | 慢速 EMA 更新 baseline，等待手势 |
| **rest → fire** | 离开 > triggerRadius 且 速度 > velocityThreshold | 触发主导轴方向的手势，进入 cooling |
| **cooling** | 已触发，等头返回 | 不再触发任何手势，避免回程误识别 |
| **cooling → rest** | 鼻尖回到 baseline 附近 | 重新进入 rest，可触发下一个手势 |
| **settle** | 长时间停在新位置（> settleTimeout） | 把当前位置收编为新 baseline |

这套设计的核心：
- **抬头必低头** — 抬头触发 `up`，进入 cooling，回头时不再触发 `down`
- **慢速漂移 = 噪声** — velocity 过低永远不触发
- **姿势改变会自动适应** — settle 超时机制让 baseline 跟随用户姿势

---

## 项目结构

```
headcontrol/
├── Sources/HeadControl/
│   ├── HeadControlApp.swift       @main + MenuBarExtra 装配
│   ├── ContentView.swift          主窗口（预览 + 调参侧栏）
│   ├── MenuBarView.swift          菜单栏弹出面板
│   ├── HeadController.swift       @Observable 状态总线
│   ├── CameraSession.swift        AVFoundation 取流
│   ├── FaceLandmarkTracker.swift  Vision 关键点检测
│   ├── GestureDetector.swift      检测器状态机（baseline + velocity）
│   ├── Smoother.swift             EMA 平滑（线程安全）
│   ├── KeyInjector.swift          CGEvent 系统按键 / 滚轮注入
│   ├── CameraPreview.swift        NSViewRepresentable 包装预览层
│   └── Info.plist                 bundle 元数据 + 权限说明
├── Resources/
│   ├── MenuBarIcon.png            54×54 黑色透明 (template image)
│   └── AppIcon.png                1024×1024 全彩
├── Scripts/
│   ├── make-app.sh                构建 + 打包 + 签名
│   ├── install.sh                 部署到 /Applications + 启动
│   └── generate-placeholder-logos.swift
├── Package.swift
├── LICENSE
└── README.md
```

---

## 调参指南

打开主窗口右侧 `Detector` 区，按这组起点试，根据手感微调：

| 滑块 | 推荐起点 | 调大的现象 | 调小的现象 |
|---|---|---|---|
| Trigger radius | 0.060 | 需要更大幅度的摆头 | 容易触发，但也容易误触 |
| Rest radius | 0.022 | "静止"判定更宽松 | baseline 跟踪更精确，对小晃动敏感 |
| Min velocity | 0.25 /s | 必须更快才触发，过滤更多慢动作 | 慢动作也能触发 |
| Cooldown | 0.35s | 一次摆头肯定不会触发两次 | 反应更快但有重复触发风险 |
| Smoothing α | 0.5 | 响应快，但绿圈抖 | 绿圈非常稳，但响应迟钝 |

调到合适后改 `Sources/HeadControl/HeadController.swift` 顶部的默认值，下次启动直接是优解。

---

## 自定义

### 替换 Logo

直接覆盖 `Resources/` 下的两个 PNG：

| 文件 | 规格 | 用途 |
|---|---|---|
| `MenuBarIcon.png` | 18×18 / 36×36 / 54×54 任选，**纯黑 + Alpha 透明** | 菜单栏图标，macOS 自动按浅色/深色模式反色 |
| `AppIcon.png` | 1024×1024 方形画布，主体留 ~10% 边距 | Finder / Cmd+Tab / 关于面板 |

然后 `./Scripts/install.sh` 重新部署。

### 新增按键映射

在 `Sources/HeadControl/KeyInjector.swift` 的 `KeyAction` 枚举里加一个 case，并在 `keycode(for:)` 或 `inject(_:)` 里实现对应的 CGEvent 行为。

### 新增 preset

在同一文件的 `BindingPreset` 里加一个 case，并在 `mappings` 计算属性里返回对应的 4 个手势映射。

---

## 开发

```bash
# 仅编译（不打包），最快
swift build

# 编译 + 打 .app
./Scripts/make-app.sh

# make-app + 部署到 /Applications + 启动（推荐日常用这条）
./Scripts/install.sh

# 重置授权（调试用）
tccutil reset Camera local.headcontrol
tccutil reset Accessibility local.headcontrol
```

`install.sh` 会检测 source 是否比 `.app` 新，决定是否需要重新构建 — 不需要每次都跑 `make-app.sh`。

---

## 已知限制

- 只检测**单张人脸**（取置信度最高的那一张）
- 距离摄像头变化大时，相同物理摆头幅度对应的归一化位移会变 — 后续可考虑改用 yaw/pitch 角度而不是位置
- ad-hoc 签名（不创建证书时）对应的 TCC 授权每次重打包都会失效

---

## License

MIT
