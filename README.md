# HarmonyOS 文件管理器（多端适配 + 自由流转）

## 项目简介

本项目是一个基于 HarmonyOS NEXT 开发的多设备文件管理器演示应用，采用 **"一次开发，多端部署"（一多）** 架构规范设计。项目实现了完整的文件列表浏览模块（目录导航、文件预览、多选批量操作、跨设备投屏），并深度集成了 **自由流转（跨端迁移/应用接续）** 功能。工程架构遵循标准三层结构（common 公共能力层、features 基础特性层、products 产品定制层），通过自适应布局（Row/Column/Flex 容器）与响应式布局（基于窗口宽度的五档断点 XS/SM/MD/LG/XL 及栅格系统 GridRow/GridCol）实现一套代码在小（手机）、中（折叠屏）、大（平板/PC）设备上的完美适配。应用还集成了 SysCap 系统能力检查机制，确保在功能受限设备上提供降级体验。

> **效果预览：**  
> *（请在此处放置应用在不同设备形态下的运行截图，建议包含手机竖屏、平板横屏、PC 大屏三种预览图）*

## 工程目录树

```
entry/src/main/ets/
├── common/                                    # 公共能力层（仅可被上层依赖）
│   ├── components/                            #   公共 UI 组件（可扩展）
│   └── utils/
│       ├── BreakpointSystem.ets               #   断点系统工具类（单例，定义 XS/SM/MD/LG/XL 五档断点，监听窗口宽度变化）
│       ├── GridLayout.ets                     #   栅格布局组件（封装 GridRow/GridCol，支持跨断点的 span/offset 配置）
│       ├── ResponsiveSwiper.ets               #   响应式轮播组件（根据断点调整 displayCount：小屏1张/中屏2张/大屏3-4张）
│       ├── ResponsiveTabs.ets                 #   响应式标签页组件（小屏水平/大屏垂直，自动切换方向）
│       ├── ScreenOrientation.ets              #   屏幕方向适配系统（多路径检测横竖屏，含滚动位置管理器）
│       └── SysCapChecker.ets                  #   系统能力检查器（SysCap 枚举、能力检测、降级策略映射、条件渲染组件）
│
├── entryability/
│   └── EntryAbility.ets                       # 应用入口 UIAbility（已集成自由流转 onContinue/onCreate/onNewWant/onWindowStageRestore 生命周期）
│
├── features/                                  # 基础特性层（功能独立的业务模块，可依赖 common）
│   ├── cast/
│   │   ├── CastService.ets                    #   投屏服务类（单例：设备发现、文件传输、状态管理、MIME 类型映射）
│   │   └── DevicePicker.ets                   #   设备选择器组件（模态对话框，展示可用设备列表，含加载/空/错误状态）
│   ├── continuation/
│   │   ├── ContinuationService.ets            #   自由流转核心服务（分布式数据对象生命周期管理、三步流转机制实现）
│   │   ├── ContinuationStateModel.ets         #   流转状态数据模型（迁移状态枚举、数据收集/恢复工具类）
│   │   └── ContinuationAssetHelper.ets        #   文件资产迁移辅助类（文件复制到分布式目录、Asset 对象构建/恢复）
│   └── filemanager/
│       ├── FileList.ets                       #   文件列表工具函数（目录列表、文件信息、MIME 类型、预览检查、路径处理）
│       ├── FileInfoDialog.ets                 #   文件详情预览对话框（元数据展示 + 立即预览按钮）
│       └── FileListView.ets                   #   文件列表视图组件（目录导航、多选模式、长按菜单、投屏集成、加载/空/错误状态）
│
├── pages/
│   └── Index.ets                              # 一多架构响应式主入口页面（适配小/中/大屏，集成流转模拟 UI 面板）
│
└── products/                                  # 产品定制层（针对特定设备形态的个性化配置和入口）
    ├── 2in1/
    │   └── pages/                             #   2in1 设备入口（可扩展）
    ├── phone/
    │   └── pages/
    │       └── Index.ets                      #   Phone 产品定制入口（底部标签导航、紧凑 UI、流转模拟面板）
    └── tablet/
        └── pages/                             #   平板设备入口（可扩展）
```

## 环境要求与编译运行步骤

### 环境要求

| 项目 | 要求 |
|------|------|
| 操作系统 | Windows 10/11 |
| IDE | DevEco Studio 5.0+ |
| SDK | HarmonyOS NEXT SDK 5.0.0 (API 12) |
| 设备 | 支持 phone / tablet / 2in1 模拟器或真机 |
| 双端流转 | 需两台设备登录同一华为账号，并开启 Wi-Fi 和蓝牙 |

### 编译运行步骤

1. **克隆项目**  
   将项目导入 DevEco Studio：
   ```bash
   git clone <项目仓库地址>
   ```

2. **打开项目**  
   使用 DevEco Studio 打开项目根目录，IDE 将自动识别 `build-profile.json5` 和 `oh-package.json5` 配置。

3. **安装依赖**  
   如果 `oh-package.json5` 中有依赖需要安装，在终端执行：
   ```bash
   ohpm install
   ```

4. **配置签名**  
   在 `build-profile.json5` 的 `signingConfigs` 中配置您的签名证书，或使用自动签名。

5. **选择目标设备**  
   在 IDE 的设备选择器中选择：
   - `Phone`（手机模拟器/真机）
   - `Tablet`（折叠屏/平板模拟器）
   - `2in1`（PC 模拟器）

6. **构建与运行**  
   点击 `Run` 按钮（或按 `Shift+F10`），IDE 会自动编译并安装应用到目标设备。

7. **体验自由流转（真机）**  
   - 在两台设备上安装应用并登录同一华为账号
   - 在源端设备打开应用
   - 在对端设备 Dock 栏点击应用图标，系统自动触发流转
   - 应用状态（选中的标签页、当前路径等）将无缝迁移到对端设备

8. **虚拟机模拟流转**  
   - 在设置的"自由流转"面板中，点击"模拟保存（源端）"按钮
   - 再点击"模拟恢复（对端）"按钮，可模拟流转的保存与恢复过程

## 核心功能点

### 1. 文件管理
- ✅ **目录导航**：支持进入子目录、返回上级目录、路径堆栈管理
- ✅ **文件列表**：按文件夹/文件排序展示，显示名称、大小、修改时间
- ✅ **文件详情预览**：单击文件弹出模态对话框，展示文件名、路径、大小、MIME 类型、修改时间、可读/可写状态
- ✅ **文件预览**：集成 `filePreview` API，支持图片、文档、音视频等文件的即时预览
- ✅ **多选模式**：长按文件进入多选，支持批量选中、批量预览（逐个打开）、批量查看详情
- ✅ **加载/空/错误状态**：完整的 UI 状态处理，LoadingProgress 加载动画、空文件夹提示、错误重试

### 2. 跨设备投屏
- ✅ **设备发现**：通过 CastService 发现同一网络下的可用设备
- ✅ **文件类型检测**：支持图片（jpg/png/gif/bmp）、视频（mp4/avi/mov）、音频（mp3/wav）、文档（pdf/doc/xls/ppt/txt）投屏
- ✅ **传输进度**：实时传输进度回调（0-100%）
- ✅ **设备选择器**：模态对话框展示设备列表，含在线/离线状态、设备图标、刷新与重试
- ✅ **投屏状态管理**：IDLE → DISCOVERING → CONNECTING → TRANSFERRING → SUCCESS/ERROR
- ✅ **取消与重试**：支持取消传输和失败重试

### 3. 一多（多端适配）
- ✅ **五档断点系统**：XS (<320vp)、SM (320-599vp)、MD (600-839vp)、LG (840-1079vp)、XL (≥1080vp)
- ✅ **栅格系统**：小屏 4 列、中屏 8 列、大屏 12 列，配合 span/offset 实现布局重构
- ✅ **响应式标签页**：小屏水平/底部标签、大屏垂直/左侧标签
- ✅ **响应式轮播**：手机 1 张、折叠屏 2 张、平板/PC 3-4 张
- ✅ **自适应布局**：Row、Column、Flex、List、Scroll 容器的拉伸、占比、延伸、隐藏
- ✅ **横竖屏适配**：竖屏单栏流式、横屏左右分栏（预览区+文件列表）
- ✅ **产品定制层**：Phone 入口（底部标签导航），Tablet/2in1 入口可扩展

### 4. 自由流转（跨端迁移）
- ✅ **onContinue 生命周期**：源端状态数据保存（wantParam 轻量传递）
- ✅ **onCreate/onNewWant 恢复**：对端冷启动/热启动状态恢复
- ✅ **onWindowStageRestore**：迁移场景下的窗口恢复
- ✅ **分布式数据对象**：`distributedDataObject` 的创建、组网、激活、持久化
- ✅ **AppStorage 状态同步**：迁移状态通过 AppStorage 在 Ability 与 UI 间传递
- ✅ **文件资产迁移**：文件复制到 `distributedFilesDir`，构建 Asset 对象跨端迁移
- ✅ **模拟面板**：设置页中提供"模拟保存/模拟恢复"按钮，便于虚拟机调试

### 5. SysCap 系统能力检查
- ✅ **能力枚举**：文件管理、分布式数据、分布式硬件、NFC、蓝牙、位置、相机、音频等
- ✅ **运行时检查**：通过 `canIUse()` 判断设备能力，支持缓存
- ✅ **降级策略**：为每个不支持的能力提供备选方案（如"使用本地存储替代分布式数据同步"）
- ✅ **条件渲染组件**：`CapabilityConditional` 组件根据能力检查结果渲染不同 UI
- ✅ **权限管理**：权限检查与请求辅助方法

## 技术栈

| 技术 | 版本/说明 |
|------|----------|
| 开发语言 | ArkTS（HarmonyOS 声明式 UI 开发语言） |
| HarmonyOS API | 12（SDK 5.0.0） |
| 编译工具 | Hvigor（HarmonyOS 构建系统） |
| 核心框架 | ArkUI（声明式 UI 框架） |
| 分布式能力 | Kit.DistributedService（`@kit.ArkData`） |
| 文件服务 | Kit.CoreFileKit（`fileIo`, `fileUri`） |
| 预览服务 | Kit.PreviewKit（`filePreview`） |
| UI 组件 | `@kit.ArkUI`（Button, Text, List, Swiper, GridRow/GridCol, Dialog 等） |
| 性能分析 | Kit.PerformanceAnalysisKit（`hilog`） |
| 应用权限 | `DISTRIBUTED_DATASYNC`, `ACCESS_SERVICE_DM`, `FILE_ACCESS_PERSIST` 等 |
| 工程架构 | 标准三层架构（common → features → products） |
| 应用接续 | `continuable: true`（module.json5 配置） |

## 许可证说明

本项目未包含 LICENSE 文件，代码仅供学习参考。部分代码头部包含 `Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.` 版权声明，表明参考或使用了华为提供的示例代码实现。

如需用于商业用途，请联系项目维护者获取授权。
