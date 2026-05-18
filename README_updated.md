# HarmonyOS 文件管理器与预览应用

## 项目简介

这是一个基于 HarmonyOS 的完整文件管理器与预览应用（Preview Demo），支持文件列表浏览、文件信息详情预览、多选操作和批量预览功能。应用包名为 `com.huawei.hmos.previewdemo`，支持手机、平板和 2in1 设备。应用入口为 `EntryAbility`，主页面为 `pages/Index`，实现了完整的文件管理系统，包括目录导航、文件预览、元数据展示、权限检测等功能。

该应用展示了 HarmonyOS 应用开发中文件操作、UI组件、对话框管理和权限处理等核心技术。通过模块化设计，将文件列表浏览、文件信息详情预览和批量操作等功能分离为可复用的组件，可作为学习和参考 HarmonyOS 文件管理相关开发的范例。

## 效果预览

（建议在此处放置应用运行截图，可参考 `screenshots/device/` 目录下的图片）

- `demo.png`：应用主界面预览
- `demoIndex.png`：首页效果
- `demo_folder.png`：文件夹视图演示

**新增功能截图建议**：
1. 文件列表浏览界面截图
2. 文件信息详情对话框截图
3. 长按上下文菜单截图
4. 多选模式界面截图
5. 批量预览流程截图

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
│       │   │   ├── components/          # 自定义组件目录
│       │   │   │   ├── FileList.ets     # 文件列表基础功能组件
│       │   │   │   ├── FileListView.ets # 文件列表视图组件（主界面）
│       │   │   │   └── FileInfoDialog.ets # 文件信息详情对话框组件（新增）
│       │   │   ├── entryability/
│       │   │   │   └── EntryAbility.ets # 应用入口 Ability
│       │   │   └── pages/
│       │   │       └── Index.ets        # 主页面，集成文件列表视图
│       │   ├── module.json5             # 模块配置（设备类型、Ability、页面路由）
│       │   └── resources/               # 模块资源
│       └── ohosTest/                    # 测试代码
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
├── 工程文件描述md文件1.md      # 原始工程描述文档
├── 新增功能文件描述2.md        # 新增功能详细描述文档（新增）
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
6. **授予权限**：首次运行需要授予文件访问权限。

### 核心功能点

#### 基础功能
- **应用入口 Ability**：继承 `UIAbility`，实现生命周期回调（onCreate、onWindowStageCreate、onForeground 等）
- **主页面加载**：在 `onWindowStageCreate` 中加载 `pages/Index` 页面
- **多设备适配**：支持 phone、tablet、2in1 设备类型
- **权限管理**：申请文件读写权限（Download目录、Documents目录、持久化文件访问）

#### 文件列表浏览模块
- **目录导航**：支持浏览设备公共目录（如Download），单击文件夹进入子目录，提供返回上级目录功能
- **文件列表**：显示文件和文件夹，支持图标、名称、大小、修改时间等信息展示
- **排序功能**：文件夹在前，文件在后，按名称排序
- **空状态提示**：空文件夹时显示友好提示
- **错误处理**：加载失败时显示错误状态和重试按钮

#### 文件信息详情预览功能（新增）
- **模态对话框**：单击文件时弹出文件信息详情对话框
- **完整元数据**：显示文件名、完整路径、文件大小（自动转换B/KB/MB/GB）、MIME类型、修改时间（yyyy-MM-dd HH:mm:ss）、可读/可写状态、可预览状态
- **智能按钮**："立即预览"按钮根据可预览状态动态启用/禁用
- **多种触发方式**：单击文件、长按菜单选择"详情"、多选模式下的"详情"按钮
- **外部关闭支持**：支持点击外部区域或返回键关闭对话框

#### 多选与批量操作
- **多选模式**：长按文件进入多选模式，可勾选多个文件
- **批量预览**：按顺序逐个打开选中的可预览文件
- **批量详情**：查看选中文件的详细信息（显示第一个文件详情）
- **操作栏**：多选模式下显示操作栏，提供取消、详情、批量预览功能

#### 文件预览功能
- **预览检测**：通过 `filePreview.canPreview()` 检测文件是否可预览
- **系统预览**：使用 `filePreview.openPreview()` 调用系统预览功能
- **错误处理**：预览失败时显示友好提示

## 技术栈

### 开发语言与框架
- **开发语言**：ArkTS（基于 TypeScript 的 HarmonyOS 应用开发语言）
- **UI 框架**：ArkUI
- **应用模型**：Stage 模型
- **Ability 类型**：UIAbility

### HarmonyOS API 版本
- **API 版本**：HarmonyOS SDK 5.0.0 (API 12)
- **编译模式**：Stage 模式

### 使用的 HarmonyOS Kit

#### 文件操作相关
- **`@kit.CoreFileKit`**：
  - `fileIo`：文件读写操作（`statSync`, `accessSync`, `listFileSync`）
  - `fileUri`：URI转换（`getUriFromPath`）
  - `picker`：文件选择器（目录选择）

#### 预览功能相关
- **`@kit.PreviewKit`**：
  - `filePreview`：文件预览功能（`canPreview`, `openPreview`）

#### UI 组件相关
- **`@kit.ArkUI`**：
  - `promptAction`：显示对话框、Toast和上下文菜单
  - `UIContext`：UI上下文管理
  - `ComponentContent`：组件内容封装
  - 基础UI组件：`Column`, `Row`, `Text`, `Button`, `List`, `ListItem`等

#### 基础服务
- **`@kit.BasicServicesKit`**：
  - `BusinessError`：错误处理

### 构建与依赖管理
- **依赖管理**：ohpm（OpenHarmony Package Manager）
- **构建工具**：Hvigor
- **测试框架**：Hypium（`@ohos/hypium` 1.0.15）

### 关键技术与实现

#### 1. 自定义对话框
- 使用 `UIContext.getPromptAction().openCustomDialog()` 打开自定义对话框
- 通过 `@Builder` 装饰器构建对话框内容
- 支持对话框ID管理，避免重复打开

#### 2. 文件信息获取
- 同步获取文件状态信息（大小、修改时间）
- 异步检查文件预览能力
- 权限检查（读/写权限）

#### 3. 状态管理
- 使用 `@State` 装饰器管理组件状态
- 响应式UI更新
- 多选状态管理

#### 4. 异步处理
- 使用 `async/await` 处理异步操作
- 错误捕获和用户提示
- 加载状态管理

## 文件说明

### 核心文件

#### 1. `FileInfoDialog.ets`（新增）
文件信息详情预览对话框组件，提供完整的文件元数据展示功能。

**主要功能**：
- 定义 `FileInfo` 接口和工具函数（`formatFileSize`, `formatTime`, `getFileInfo`）
- 实现 `FileInfoDialogContent` 对话框内容组件
- 提供 `showFileInfoDialog` 和 `showFileInfoDialogByPath` 接口
- 集成文件预览检测和权限检查

#### 2. `FileListView.ets`
文件列表视图组件，主界面组件。

**主要功能**：
- 文件列表展示和目录导航
- 文件点击和长按事件处理
- 多选模式管理
- 集成文件信息详情预览功能
- 批量操作实现

#### 3. `FileList.ets`
文件列表基础功能组件，提供文件操作工具函数。

**主要功能**：
- 定义 `FileItem` 接口和 `FileType` 枚举
- 提供目录列表、文件信息获取、预览检查等工具函数
- MIME类型识别和文件大小格式化

#### 4. `Index.ets`
应用主页面，集成文件列表视图组件。

#### 5. `EntryAbility.ets`
应用入口Ability，管理应用生命周期。

### 配置文件

#### 1. `module.json5`
模块配置文件，定义设备类型、权限和Ability。

**关键配置**：
- 设备类型：`phone`, `tablet`, `2in1`
- 权限申请：文件读写权限
- Ability配置：EntryAbility

#### 2. `app.json5`
应用配置文件，定义应用名称、版本和图标。

#### 3. `build-profile.json5`
构建配置文件，定义构建选项和编译模式。

## 权限说明

应用需要以下权限以正常使用文件管理功能：

1. **`ohos.permission.READ_WRITE_DOWNLOAD_DIRECTORY`**：读写Download目录
2. **`ohos.permission.READ_WRITE_DOCUMENTS_DIRECTORY`**：读写Documents目录  
3. **`ohos.permission.FILE_ACCESS_PERSIST`**：持久化文件访问权限

权限在 `module.json5` 中声明，首次使用时会向用户请求授权。

## 使用方法

### 基本操作

1. **启动应用**：应用启动后显示文件列表界面
2. **浏览目录**：
   - 单击文件夹进入子目录
   - 点击"<"按钮返回上级目录
   - 点击"选择目录"按钮选择其他目录
3. **查看文件信息**：
   - 单击文件弹出文件信息详情对话框
   - 查看文件完整元数据
   - 点击"立即预览"打开文件（如果可预览）
4. **多选操作**：
   - 长按文件弹出上下文菜单
   - 选择"多选"进入多选模式
   - 勾选多个文件
   - 使用底部操作栏进行批量操作

### 高级功能

#### 文件信息详情预览
- **触发方式**：单击文件、长按菜单选择"详情"、多选模式下点击"详情"按钮
- **显示内容**：文件名、路径、大小、类型、修改时间、权限状态、预览状态
- **交互**：可预览文件显示蓝色"立即预览"按钮，不可预览文件按钮置灰

#### 批量预览
- 进入多选模式，勾选多个文件
- 点击"批量预览"按钮
- 系统按顺序打开每个可预览文件
- 每个预览关闭后自动打开下一个

#### 上下文菜单
- 长按文件显示上下文菜单
- 选项："详情"（查看文件信息）、"多选"（进入多选模式并选中当前文件）、"取消"

## 开发说明

### 模块设计

#### 组件分层
1. **数据层**：`FileList.ets` 提供文件操作工具函数
2. **业务层**：`FileListView.ets` 实现文件列表业务逻辑
3. **UI层**：`FileInfoDialog.ets` 和 `FileListView.ets` 的UI组件
4. **集成层**：`Index.ets` 集成所有组件

#### 接口设计
- `FileItem`：文件项接口，包含文件基本信息
- `FileInfo`：文件详细信息接口，扩展 `FileItem`
- `FileListOptions`：文件列表配置选项（可扩展）

### 扩展建议

#### 功能扩展
1. **文件操作**：添加复制、移动、删除、重命名功能
2. **搜索功能**：添加文件搜索和过滤
3. **排序选项**：支持按名称、大小、修改时间排序
4. **视图切换**：支持列表视图和网格视图切换
5. **收藏功能**：添加常用文件收藏

#### UI优化
1. **主题支持**：添加深色主题
2. **动画效果**：添加列表项动画和过渡效果
3. **手势支持**：添加滑动手势操作
4. **加载优化**：添加虚拟滚动支持大量文件

#### 性能优化
1. **缓存机制**：缓存文件信息和预览状态
2. **懒加载**：图片和缩略图懒加载
3. **批量处理**：优化批量操作性能

### 注意事项

#### 1. 权限处理
- 文件访问可能因权限限制而失败
- 需要处理权限拒绝的情况
- 提供友好的错误提示

#### 2. 性能考虑
- 大量文件时列表渲染性能
- 文件信息获取的异步处理
- 内存使用优化

#### 3. 兼容性
- 不同设备类型的适配
- 不同HarmonyOS版本的API差异
- 不同文件系统的兼容性

## 许可信息

本项目暂未包含明确的 LICENSE 文件，请根据实际使用场景参考相关开源协议。建议在项目根目录添加合适的开源许可证（如 Apache 2.0、MIT 等）。

---

*本 README 基于项目代码自动生成，内容仅供参考，具体实现以实际代码为准。*

**更新记录**：
- 2026-05-18：新增文件信息详情预览功能，完善文件列表浏览模块
- 2025-12-12：初始版本，基础预览演示功能