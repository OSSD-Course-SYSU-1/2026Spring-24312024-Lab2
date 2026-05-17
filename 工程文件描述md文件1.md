# HarmonyOS 预览演示应用

## 项目简介

这是一个基于 HarmonyOS 的预览演示应用（Preview Demo），用于展示 HarmonyOS 应用开发的基本能力和 UI 组件。应用包名为 `com.huawei.hmos.previewdemo`，支持手机、平板和 2in1 设备。应用入口为 `EntryAbility`，主页面为 `pages/Index`，实现了基本的生命周期管理和窗口阶段加载。该演示应用可用于学习和参考 HarmonyOS 应用开发的基础架构，包括 Ability、页面导航、资源管理等功能。

## 效果预览

（建议在此处放置应用运行截图，可参考 `screenshots/device/` 目录下的图片）

- `demo.png`：应用主界面预览
- `demoIndex.png`：首页效果
- `demo_folder.png`：文件夹视图演示

## 工程目录树

```
2026Spring-24312024-Lab2/
├── AppScope/                    # 应用全局资源与配置
│   ├── app.json5               # 应用配置文件（包名、版本、图标等）
│   └── resources/              # 全局资源文件（字符串、颜色、图片等）
├── entry/                       # 主模块
│   └── src/
│       ├── main/
│       │   ├── ets/
│       │   │   ├── entryability/
│       │   │   │   └── EntryAbility.ets    # 应用入口 Ability
│       │   │   └── pages/
│       │   │       └── Index.ets           # 主页面
│       │   ├── module.json5                # 模块配置（设备类型、Ability、页面路由）
│       │   └── resources/                  # 模块资源
│       └── ohosTest/                       # 测试代码
├── hvigor/                      # 构建脚本目录
├── oh_modules/                  # 依赖模块
├── screenshots/                 # 应用截图
│   └── device/
│       ├── demo.png
│       ├── demoIndex.png
│       ├── demoIndex_en.png
│       ├── demo_en.png
│       ├── demo_folder.png
│       └── demo_folder_en.png
├── .hvigor/                     # 构建缓存
├── .idea/                       # IDE 配置文件
├── .clang-format                # 代码格式化配置
├── build-profile.json5          # 构建配置（产品、编译模式等）
├── hvigorfile.ts                # 构建脚本
├── oh-package.json5             # 依赖配置文件
├── oh-package-lock.json5        # 依赖锁文件
├── readme_cn.md                 # 中文说明文档
├── readme_en.md                 # 英文说明文档
└── 初始功能展示.mp4             # 功能演示视频
```

## 使用说明

### 环境要求

- **操作系统**：Windows 10/11 或 macOS
- **开发工具**：DevEco Studio 5.0.0 或更高版本
- **SDK 版本**：HarmonyOS SDK 5.0.0 (API 12)
- **Node.js**：18.19.0 或更高版本（用于 Hvigor 构建）

### 编译运行步骤

1. **克隆项目**：将本仓库克隆到本地。
2. **打开项目**：使用 DevEco Studio 打开工程目录。
3. **同步依赖**：等待 DevEco Studio 自动同步依赖（或手动执行 `ohpm install`）。
4. **选择设备**：在 DevEco Studio 中选择 Phone 或 Tablet 模拟器。
5. **运行应用**：点击运行按钮（▶️）或按 `Shift+F10` 编译并安装到模拟器/真机。

### 核心功能点

- **应用入口 Ability**：继承 `UIAbility`，实现生命周期回调（onCreate、onWindowStageCreate、onForeground 等）。
- **主页面加载**：在 `onWindowStageCreate` 中加载 `pages/Index` 页面。
- **多设备适配**：支持 phone、tablet、2in1 设备类型。
- **日志输出**：使用 `@kit.PerformanceAnalysisKit` 的 hilog 进行调试日志记录。
- **基础 UI 组件**：通过主页面展示 HarmonyOS UI 组件和布局。

## 技术栈

- **开发语言**：ArkTS（基于 TypeScript 的 HarmonyOS 应用开发语言）
- **UI 框架**：ArkUI
- **HarmonyOS API 版本**：5.0.0 (12)
- **应用模型**：Stage 模型
- **Ability 类型**：UIAbility
- **依赖管理**：ohpm（OpenHarmony Package Manager）
- **构建工具**：Hvigor
- **测试框架**：Hypium（`@ohos/hypium` 1.0.15）

## 许可信息

本项目暂未包含明确的 LICENSE 文件，请根据实际使用场景参考相关开源协议。建议在项目根目录添加合适的开源许可证（如 Apache 2.0、MIT 等）。

---

*本 README 基于项目代码自动生成，内容仅供参考，具体实现以实际代码为准。*