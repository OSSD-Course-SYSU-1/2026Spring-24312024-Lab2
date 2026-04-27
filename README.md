# AI 文字识别 (OCR) 示例项目

### 项目简介
本项目是一款基于 **HarmonyOS Stage 模型** 开发的视觉识别工具类应用。它深度集成了 HarmonyOS 基础视觉服务（HMS Core AI OCR）与多媒体相机服务，演示了如何从相机拍照流程中捕获图像，并实时转换为可编辑文本的完整开发链路。

### 功能特性
* **实时预览**：基于 `@ohos.multimedia.camera` 实现高性能相机预览流。
* **精准识别**：集成 `@hms.ai.ocr.textRecognition` 接口，支持多场景下的文字提取。
* **动态权限处理**：内置权限请求工具类，符合 HarmonyOS 安全开发规范。
* **交互友好**：采用浮窗化设计（CustomDialog），识别结果展示与主界面无缝切换。

### 应用结构说明
工程采用模块化目录结构，清晰分离了 UI、工具类与资源文件：

├── AppScope/                # 应用全局配置
├── entry/                   # 主模块目录
│   ├── src/main/ets/        # ArkTS 源码
│   │   ├── common/          # 公共能力层
│   │   │   ├── constant/    # 全局常量 (如: 字体大小、布局间距)
│   │   │   └── utils/       # 工具类 (权限请求、相机封装、日志记录)
│   │   ├── entryability/    # 应用生命周期管理
│   │   ├── pages/           # 页面层 (Index.ets 首页)
│   │   └── view/            # 自定义组件 (CustomDialogView 识别弹窗)
│   ├── src/main/resources/  # 静态资源 (图标、多语言字符串)
│   └── module.json5         # 模块配置文件 (权限声明)
├── hvigor/                  # 构建脚本工具
└── build-profile.json5      # 编译构建配置

### 核心实现原理
相机初始化：在 Camera.ets 中初始化相机输入流与预览输出流，并在 Index.ets 挂载时启动。

拍照拦截：用户点击识别图标，触发相机拍照动作，获取 photoAsset 或图像缓冲区。

视觉处理：将图像数据传递给 textRecognition 识别器，进行 AI 计算。

结果反馈：识别器返回文本数据后，通过 CustomDialogController 唤起弹窗，将文本渲染在界面上。

### 权限配置
应用运行需要以下权限，请确保在设备设置中允许访问：

ohos.permission.CAMERA：用于访问相机进行实时拍摄。

运行环境约束
设备：华为移动设备 (标准系统)。

操作系统：HarmonyOS 5.0.5 Release 及以上版本。

开发工具：DevEco Studio 5.0.5 Release 及以上。

SDK 版本：HarmonyOS 5.0.5 Release SDK 及以上。

### 使用指南
启动应用，允许相机权限请求。

对准包含文字的物体或文档。

点击底部的 圆形识别图标。

在弹出的层级中查看识别出的文字内容。

点击背景空白区域即可关闭弹窗并继续拍摄。