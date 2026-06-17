/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.
 */

import { FileItem, FileType, listDirectory, getParentDirectory, formatFileSize, formatTime, checkCanPreview, openFilePreview, pickDirectory } from './FileList';
import { showFileInfoDialogByPath } from './FileInfoDialog';
import { fileIo as fs } from '@kit.CoreFileKit';
import { promptAction, UIContext } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';

interface ActionMenuResult {
  index: number;
}

/**
 * 文件列表视图组件
 */
@Component
export struct FileListView {
  // 上下文
  private context: UIContext | undefined;
  
  // 当前路径
  @State private currentPath: string = '';
  
  // 文件列表
  @State private fileList: FileItem[] = [];
  
  // 加载状态
  @State private isLoading: boolean = false;
  
  // 错误信息
  @State private errorMessage: string = '';
  
  // 多选模式
  @State private isMultiSelectMode: boolean = false;
  
  // 选中的文件
  @State private selectedFiles: FileItem[] = [];
  
  // 历史路径堆栈（用于返回）
  private pathHistory: string[] = [];
  
  // 构造函数
  aboutToAppear() {
    this.context = this.getUIContext();
    this.initialize();
  }
  
  // 初始化，选择初始目录
  private async initialize() {
    const context = this.context;
    if (!context) {
      console.error('UIContext未初始化');
      return;
    }
    try {
      // 尝试获取公共下载目录
      // 这里简化处理，实际可能需要请求权限或使用FilePicker
      // 暂时使用应用沙箱目录作为示例
      const hostContext = context.getHostContext();
      if (!hostContext) {
        console.error('无法获取HostContext');
        this.errorMessage = '无法获取应用上下文';
        return;
      }
      const sandboxDir = hostContext.filesDir;
      this.currentPath = sandboxDir;
      await this.loadDirectory(sandboxDir);
    } catch (err) {
      console.error('初始化失败:', err);
      this.errorMessage = '初始化失败，请尝试选择目录';
    }
  }
  
  // 加载目录
  private async loadDirectory(path: string): Promise<void> {
    this.isLoading = true;
    this.errorMessage = '';
    
    try {
      const items = await listDirectory(path);
      this.fileList = items;
      
      // 检查每个文件是否可预览（异步）
      this.checkFilesPreviewStatus(items);
      
    } catch (err) {
      console.error(`加载目录失败 ${path}:`, err);
      this.errorMessage = `无法访问目录: ${(err as BusinessError).message || '未知错误'}`;
      this.fileList = [];
    } finally {
      this.isLoading = false;
    }
  }
  
  // 检查文件预览状态（异步）
  private async checkFilesPreviewStatus(items: FileItem[]): Promise<void> {
    if (!this.context) {
      console.error('UIContext未初始化');
      return;
    }
    for (const item of items) {
      if (item.type === FileType.FILE) {
        try {
          item.canPreview = await checkCanPreview(this.context, item.path);
        } catch (err) {
          item.canPreview = false;
        }
      }
    }
    // 更新UI
    this.fileList = [...this.fileList];
  }
  
  // 选择目录
  private async selectDirectory(): Promise<void> {
    if (!this.context) {
      console.error('UIContext未初始化');
      return;
    }
    try {
      const pickedUri = await pickDirectory(this.context);
      if (pickedUri) {
        // 将URI转换为路径（简化处理，实际可能需要使用fileUri模块）
        // 这里假设pickedUri已经是路径格式
        this.pathHistory.push(this.currentPath);
        this.currentPath = pickedUri;
        await this.loadDirectory(pickedUri);
      }
    } catch (err) {
      console.error('选择目录失败:', err);
      promptAction.showToast({
        message: '选择目录失败'
      });
    }
  }
  
  // 进入子目录
  private async enterDirectory(folder: FileItem): Promise<void> {
    this.pathHistory.push(this.currentPath);
    this.currentPath = folder.path;
    await this.loadDirectory(folder.path);
  }
  
  // 返回上级目录
  private async goBack(): Promise<void> {
    if (this.pathHistory.length > 0) {
      const parentPath = this.pathHistory.pop()!;
      this.currentPath = parentPath;
      await this.loadDirectory(parentPath);
    } else {
      // 已经是根目录，尝试获取父目录
      const parentPath = getParentDirectory(this.currentPath);
      if (parentPath) {
        this.pathHistory.push(this.currentPath);
        this.currentPath = parentPath;
        await this.loadDirectory(parentPath);
      } else {
        promptAction.showToast({
          message: '已经是根目录'
        });
      }
    }
  }
  
  // 处理文件点击
  private async handleFileClick(file: FileItem): Promise<void> {
    if (this.isMultiSelectMode) {
      // 多选模式下，切换选中状态
      this.toggleFileSelection(file);
    } else {
      // 普通模式下，显示文件信息对话框
      await this.showFileInfo(file);
    }
  }
  
  // 处理文件夹点击
  private async handleFolderClick(folder: FileItem): Promise<void> {
    if (this.isMultiSelectMode) {
      // 多选模式下，忽略文件夹点击或可以进入目录
      // 这里选择进入目录
      await this.enterDirectory(folder);
    } else {
      // 普通模式下，进入目录
      await this.enterDirectory(folder);
    }
  }
  
  // 显示文件信息对话框
  private async showFileInfo(file: FileItem): Promise<void> {
    if (!this.context) {
      console.error('UIContext未初始化');
      return;
    }
    try {
      await showFileInfoDialogByPath(
        this.context,
        file.path,
        () => {
          // 确认预览回调
          this.previewFile(file);
        },
        () => {
          // 取消回调
          console.log('用户取消预览');
        }
      );
    } catch (err) {
      console.error('显示文件信息对话框失败:', err);
      promptAction.showToast({
        message: '无法获取文件信息'
      });
    }
  }
  
  // 预览文件
  private async previewFile(file: FileItem): Promise<void> {
    if (!this.context) {
      console.error('UIContext未初始化');
      return;
    }
    try {
      await openFilePreview(this.context, file);
    } catch (err) {
      console.error('预览文件失败:', err);
      promptAction.showToast({
        message: '预览文件失败'
      });
    }
  }
  
  // 切换文件选中状态
  private toggleFileSelection(file: FileItem) {
    const index = this.selectedFiles.findIndex(f => f.path === file.path);
    if (index >= 0) {
      // 已选中，取消选中
      this.selectedFiles.splice(index, 1);
    } else {
      // 未选中，添加到选中列表
      this.selectedFiles.push(file);
    }
    this.selectedFiles = [...this.selectedFiles];
  }
  
  // 进入多选模式
  private enterMultiSelectMode() {
    this.isMultiSelectMode = true;
    this.selectedFiles = [];
  }
  
  // 退出多选模式
  private exitMultiSelectMode() {
    this.isMultiSelectMode = false;
    this.selectedFiles = [];
  }
  
  // 批量预览选中的文件
  private async batchPreview(): Promise<void> {
    if (!this.context) {
      console.error('UIContext未初始化');
      return;
    }
    if (this.selectedFiles.length === 0) {
      promptAction.showToast({
        message: '请先选择文件'
      });
      return;
    }
    
    // 过滤出可预览的文件
    const previewableFiles = this.selectedFiles.filter(file => file.canPreview);
    
    if (previewableFiles.length === 0) {
      promptAction.showToast({
        message: '选中的文件均不支持预览'
      });
      return;
    }
    
    // 按顺序预览文件
    for (const file of previewableFiles) {
      try {
        await openFilePreview(this.context, file);
        // 等待用户关闭预览（这里简化处理，实际可能需要监听预览关闭事件）
        // 可以添加一个确认对话框让用户决定是否继续预览下一个文件
      } catch (err) {
        console.error(`预览文件 ${file.name} 失败:`, err);
        // 继续预览下一个文件
      }
    }
    
    // 预览完成后退出多选模式
    this.exitMultiSelectMode();
  }
  
  // 批量显示文件详情
  private async batchShowDetails(): Promise<void> {
    if (this.selectedFiles.length === 0) {
      promptAction.showToast({
        message: '请先选择文件'
      });
      return;
    }
    
    // 显示第一个选中文件的详情
    const file = this.selectedFiles[0];
    
    // 如果选择了多个文件，显示提示
    if (this.selectedFiles.length > 1) {
      promptAction.showToast({
        message: `显示第1个文件的详情（共${this.selectedFiles.length}个）`
      });
    }
    
    await this.showFileInfo(file);
    
    // 注意：这里只显示第一个文件的详情，实际可能需要显示所有选中文件的详情
    // 或者创建一个批量详情对话框
  }

  // 显示文件上下文菜单（长按触发）
  private async showFileContextMenu(file: FileItem): Promise<void> {
    try {
      const result = await promptAction.showActionMenu({
        title: file.name,
        buttons: [
          {
            text: '详情',
            color: '#007DFF'
          },
          {
            text: '多选',
            color: '#333333'
          },
          {
            text: '取消',
            color: '#999999'
          }
        ]
      });
      if (result.index === 0) {
        // 详情
        await this.showFileInfo(file);
      } else if (result.index === 1) {
        // 多选
        this.enterMultiSelectMode();
        // 自动选中当前文件
        this.toggleFileSelection(file);
      }
      // 取消操作不做任何处理
    } catch (err) {
      console.error('显示上下文菜单失败:', err);
    }
  }
  
  // 渲染文件项
  @Builder
  private renderFileItem(item: FileItem) {
    Row() {
      // 图标
      Text(item.type === FileType.DIRECTORY ? '📁' : '📄')
        .fontSize(24)
        .width(40)
        .height(40)
        .margin({ right: 12 })
        .textAlign(TextAlign.Center)
      
      // 文件信息
      Column({ space: 4 }) {
        Text(item.name)
          .fontSize(16)
          .fontColor(this.selectedFiles.some(f => f.path === item.path) ? '#007DFF' : '#333333')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        
        if (item.type === FileType.FILE) {
          if (item.size !== undefined) {
            Text(formatFileSize(item.size))
              .fontSize(12)
              .fontColor('#666666')
          }
          
          if (item.lastModified !== undefined) {
            Text(formatTime(item.lastModified))
              .fontSize(12)
              .fontColor('#666666')
          }
        } else {
          Text('文件夹')
            .fontSize(12)
            .fontColor('#666666')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      
      // 多选复选框
      if (this.isMultiSelectMode) {
        Checkbox()
          .select(this.selectedFiles.some(f => f.path === item.path))
          .onChange((checked: boolean) => {
            this.toggleFileSelection(item);
          })
          .margin({ left: 8 })
      }
      
      // 预览状态指示器
      if (item.type === FileType.FILE && item.canPreview) {
        Text('👁️')
          .fontSize(16)
          .width(20)
          .height(20)
          .margin({ left: 8 })
      }
    }
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(this.selectedFiles.some(f => f.path === item.path) ? '#F0F8FF' : '#FFFFFF')
    .borderRadius(8)
    .onClick(() => {
      if (item.type === FileType.DIRECTORY) {
        this.handleFolderClick(item);
      } else {
        this.handleFileClick(item);
      }
    })
    .gesture(
      LongPressGesture()
        .onAction(() => {
          this.showFileContextMenu(item);
        })
    )
  }
  
  // 渲染空状态
  @Builder
  private renderEmptyState() {
    Column() {
      Text('📁')
        .fontSize(80)
        .width(120)
        .height(120)
        .margin({ bottom: 16 })
        .textAlign(TextAlign.Center)
      
      Text('文件夹为空')
        .fontSize(18)
        .fontColor('#999999')
        .margin({ bottom: 8 })
      
      Text('请选择其他目录或添加文件')
        .fontSize(14)
        .fontColor('#CCCCCC')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
  
  // 渲染加载状态
  @Builder
  private renderLoading() {
    Column() {
      LoadingProgress()
        .width(40)
        .height(40)
        .color('#007DFF')
      
      Text('加载中...')
        .fontSize(14)
        .fontColor('#666666')
        .margin({ top: 12 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
  
  // 渲染错误状态
  @Builder
  private renderError() {
    Column() {
      Text('❌')
        .fontSize(80)
        .width(120)
        .height(120)
        .margin({ bottom: 16 })
        .textAlign(TextAlign.Center)
      
      Text('加载失败')
        .fontSize(18)
        .fontColor('#FF6B35')
        .margin({ bottom: 8 })
      
      Text(this.errorMessage)
        .fontSize(14)
        .fontColor('#999999')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 24 })
      
      Button('重试')
        .fontSize(16)
        .backgroundColor('#007DFF')
        .fontColor('#FFFFFF')
        .padding({ left: 24, right: 24 })
        .onClick(() => {
          this.loadDirectory(this.currentPath);
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
  
  // 渲染多选操作栏
  @Builder
  private renderMultiSelectActions() {
    Row({ space: 12 }) {
      // 取消按钮
      Button('取消')
        .fontSize(16)
        .backgroundColor('#F2F2F2')
        .fontColor('#333333')
        .layoutWeight(1)
        .height(44)
        .onClick(() => {
          this.exitMultiSelectMode();
        })
      
      // 详情按钮
      Button('详情')
        .fontSize(16)
        .backgroundColor('#F2F2F2')
        .fontColor('#333333')
        .layoutWeight(1)
        .height(44)
        .enabled(this.selectedFiles.length > 0)
        .onClick(() => {
          this.batchShowDetails();
        })
      
      // 批量预览按钮
      Button('批量预览')
        .fontSize(16)
        .backgroundColor('#007DFF')
        .fontColor('#FFFFFF')
        .layoutWeight(1)
        .height(44)
        .enabled(this.selectedFiles.length > 0)
        .onClick(() => {
          this.batchPreview();
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 8 })
  }
  
  build() {
    Column() {
      // 导航栏
      Row({ space: 8 }) {
        // 返回按钮
        if (this.pathHistory.length > 0 || getParentDirectory(this.currentPath)) {
          Button('<')
            .fontSize(16)
            .backgroundColor('#F2F2F2')
            .fontColor('#333333')
            .width(40)
            .height(40)
            .onClick(() => {
              this.goBack();
            })
        } else {
          // 占位
          Blank()
            .width(40)
            .height(40)
        }
        
        // 当前路径
        Text(this.currentPath)
          .fontSize(14)
          .fontColor('#666666')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        
        // 选择目录按钮
        Button('选择目录')
          .fontSize(14)
          .backgroundColor('#F2F2F2')
          .fontColor('#333333')
          .padding({ left: 12, right: 12 })
          .height(36)
          .onClick(() => {
            this.selectDirectory();
          })
        
        // 多选模式按钮（仅在普通模式下显示）
        if (!this.isMultiSelectMode) {
          Button('多选')
            .fontSize(14)
            .backgroundColor('#F2F2F2')
            .fontColor('#333333')
            .padding({ left: 12, right: 12 })
            .height(36)
            .onClick(() => {
              this.enterMultiSelectMode();
            })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor('#FFFFFF')
      .border({ width: 1, color: '#E5E5E5' })
      
      // 多选操作栏
      if (this.isMultiSelectMode) {
        this.renderMultiSelectActions()
      }
      
      // 文件列表区域
      Column() {
        if (this.isLoading) {
          this.renderLoading()
        } else if (this.errorMessage) {
          this.renderError()
        } else if (this.fileList.length === 0) {
          this.renderEmptyState()
        } else {
          List({ space: 8 }) {
            ForEach(this.fileList, (item: FileItem) => {
              ListItem() {
                this.renderFileItem(item)
              }
            }, (item: FileItem) => item.path)
          }
          .width('100%')
          .layoutWeight(1)
        }
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor('#F8F8F8')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F8F8')
  }
}