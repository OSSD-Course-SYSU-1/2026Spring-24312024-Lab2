/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.
 *
 * Phone产品定制页面 - 针对手机设备优化
 *
 * 特性：
 * - 默认使用底部标签导航（手机最常用交互模式）
 * - 紧凑的UI间距和字体
 * - 优化的触摸目标大小
 * - 集成SysCap能力检查
 * - 集成自由流转（跨端迁移）状态恢复
 *
 * 注意：此页面为Phone产品独立入口。
 * 主入口 pages/Index.ets 已包含完整响应式布局支持所有设备。
 */

import { FileListView } from '../../../features/filemanager/FileListView';
import { BreakpointSystem, BreakpointType } from '../../../common/utils/BreakpointSystem';
import { SwiperItemConfig } from '../../../common/utils/ResponsiveSwiper';
import { SysCapChecker, SystemCapability } from '../../../common/utils/SysCapChecker';
import { ScreenOrientationHelper, ScrollerStateManager } from '../../../common/utils/ScreenOrientation';
import { filePreview } from '@kit.PreviewKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { promptAction, display } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * 标签项接口
 */
interface TabItem {
  value: string;
  name: string;
  icon: string;
}

/**
 * Phone产品入口页面
 */
@Entry
@Component
struct PhoneIndex {
  /** 断点系统 */
  private breakpointSystem: BreakpointSystem = BreakpointSystem.getInstance();

  /** 系统能力检查器 */
  private sysCapChecker: SysCapChecker = SysCapChecker.getInstance();

  /** 当前选中标签 */
  @State selectedTabIndex: number = 0;

  /** 当前断点 */
  @State currentBreakpoint: BreakpointType = BreakpointType.SM;

  /** 窗口宽度 */
  @State windowWidth: number = 0;

  /** 屏幕方向 */
  @State isLandscape: boolean = false;

  /** 方向辅助工具 */
  private orientationHelper: ScreenOrientationHelper = new ScreenOrientationHelper();

  /** 滚动位置管理器 */
  private scrollerStateManager: ScrollerStateManager = new ScrollerStateManager();

  /** 是否就绪 */
  @State isReady: boolean = false;

  /** 是否从跨端迁移恢复 */
  @StorageLink('isContinuationRestored') isContinuationRestored: boolean = false;

  /** 接续恢复的标签页索引 */
  @StorageLink('continuationRestoredTabIndex') continuationTabIndex: number = 0;

  /** 流转状态模拟 - 是否已保存 */
  @State continuationSaved: boolean = false;
  /** 流转状态模拟 - 上次保存时间 */
  @State continuationSaveTime: string = '';
  /** 流转状态模拟 - 保存数据摘要 */
  @State continuationDataSummary: string = '';

  /** 示例文件名 */
  private fileName: string = 'preview_info.txt';

  /** 标签页配置 */
  private tabs: TabItem[] = [
    { value: 'files', name: '文件', icon: '📁' },
    { value: 'preview', name: '预览', icon: '👁️' },
    { value: 'settings', name: '设置', icon: '⚙️' }
  ];

  /** 轮播图数据 */
  private swiperItems: SwiperItemConfig[] = [];

  aboutToAppear(): void {
    // 初始化轮播图数据（带显式类型）
    const slide1: SwiperItemConfig = {
      id: '1', title: '文件管理', subtitle: '高效管理您的文件',
      backgroundColor: '#007DFF',
      onClick: (): void => { console.log('点击了文件管理轮播图') }
    };
    const slide2: SwiperItemConfig = {
      id: '2', title: '跨设备投屏', subtitle: '无缝投屏到其他设备',
      backgroundColor: '#07C160',
      onClick: (): void => { console.log('点击了跨设备投屏轮播图') }
    };
    const slide3: SwiperItemConfig = {
      id: '3', title: '多端适配', subtitle: '一次开发，多端部署',
      backgroundColor: '#FA5151',
      onClick: (): void => { console.log('点击了多端适配轮播图') }
    };
    this.swiperItems = [slide1, slide2, slide3];

    // 初始化屏幕方向监听（使用多路径检测确保可靠性）
    this.orientationHelper.bind((isLandscape: boolean): void => {
      this.isLandscape = isLandscape;
      console.info(`[PhoneIndex] Orientation → ${isLandscape ? 'Landscape' : 'Portrait'}`);
    });
    this.isLandscape = this.orientationHelper.isLandscape;

    // 初始化断点监听
    this.currentBreakpoint = this.breakpointSystem.getCurrentBreakpoint();
    this.windowWidth = this.breakpointSystem.getCurrentWindowWidth();

    this.breakpointSystem.addListener({
      onBreakpointChanged: (breakpoint: BreakpointType, windowWidth: number) => {
        this.currentBreakpoint = breakpoint;
        this.windowWidth = windowWidth;
      }
    });

    this.isReady = true;

    // 检查设备能力
    setTimeout(() => {
      this.checkContinuationRestore();
      this.checkCapabilities();
    }, 500);
  }

  aboutToDisappear(): void {
    this.orientationHelper.unbind();
    console.info('[PhoneIndex] Screen orientation listener removed');
  }

  /**
   * 检查并恢复跨端迁移状态
   */
  private checkContinuationRestore(): void {
    if (this.isContinuationRestored && this.continuationTabIndex !== undefined) {
      hilog.info(0x0000, 'PhoneIndex',
        `Continuation restored - switching to tab: ${this.continuationTabIndex}`);
      this.selectedTabIndex = this.continuationTabIndex;

      promptAction.showToast({
        message: '已从其他设备恢复状态',
        duration: 2000
      });

      AppStorage.setOrCreate('isContinuationRestored', false);
    }
  }

  private async checkCapabilities(): Promise<void> {
    try {
      const result = await this.sysCapChecker.checkCapability(SystemCapability.FILE_MANAGEMENT);
      if (!result.supported) {
        promptAction.showToast({ message: '文件管理能力受限' });
      }
    } catch (error) {
      console.error('能力检查失败:', error);
    }
  }

  private handleTabChange(index: number): void {
    this.selectedTabIndex = index;
    // 同步状态到 AppStorage，供 onContinue 收集
    AppStorage.setOrCreate('selectedTabIndex', index);
  }

  // ==================== 流转功能 UI 操作（模拟演示） ====================

  private simulateContinuationSave(): void {
    const now = new Date();
    const timeStr = `${now.getHours().toString().padStart(2, '0')}:` +
      `${now.getMinutes().toString().padStart(2, '0')}:` +
      `${now.getSeconds().toString().padStart(2, '0')}`;

    AppStorage.setOrCreate('continuation_selectedTabIndex', this.selectedTabIndex);
    AppStorage.setOrCreate('continuation_currentBreakpoint', this.currentBreakpoint);
    AppStorage.setOrCreate('continuation_windowWidth', this.windowWidth);
    AppStorage.setOrCreate('continuation_timestamp', now.getTime());

    this.continuationSaved = true;
    this.continuationSaveTime = timeStr;
    this.continuationDataSummary =
      `标签页: ${this.tabs[this.selectedTabIndex].name} | ` +
      `断点: ${this.currentBreakpoint} | ` +
      `宽度: ${Math.round(this.windowWidth)}vp`;

    promptAction.showToast({
      message: `✅ 状态已保存 (模拟流转源端)`,
      duration: 2000
    });
  }

  private simulateContinuationRestore(): void {
    if (!this.continuationSaved) {
      promptAction.showToast({
        message: '⚠️ 请先执行「保存状态」',
        duration: 1500
      });
      return;
    }

    try {
      const savedTab = AppStorage.get<number>('continuation_selectedTabIndex');
      const savedBp = AppStorage.get<string>('continuation_currentBreakpoint');
      if (savedTab !== undefined) {
        this.selectedTabIndex = savedTab;
        AppStorage.setOrCreate('selectedTabIndex', savedTab);
      }

      const detail = `恢复标签: ${this.tabs[this.selectedTabIndex].name} | ` +
        `断点: ${savedBp || 'N/A'} | 保存于: ${this.continuationSaveTime}`;
      this.continuationDataSummary = detail;

      promptAction.showToast({
        message: `🔄 状态已恢复 (模拟流转对端)`,
        duration: 2000
      });
    } catch (_e) {
      promptAction.showToast({
        message: '恢复失败：未找到已保存的状态',
        duration: 1500
      });
    }
  }

  private async previewFile(): Promise<void> {
    try {
      let context = this.getUIContext().getHostContext();
      if (!context) return;
      let fileDir = context.filesDir;
      let filePath = fileDir + '/' + this.fileName;
      let file = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      fs.writeSync(file.fd, "hello, world");
      fs.closeSync(file);
      let uri = fileUri.getUriFromPath(filePath);
      let result = await filePreview.canPreview(context, uri);
      if (result) {
        filePreview.openPreview(context, { title: this.fileName, uri: uri, mimeType: 'text/plain' });
      } else if (this.isLandscape) {
      // 横屏：左侧垂直标签栏 + 右侧内容
      Row() {
        // 左侧垂直标签栏
        Column() {
          Text('📁').fontSize(24)
            .margin({ top: 12, bottom: 4 })
          Divider().strokeWidth(1).color('#E5E5E5').margin({ bottom: 8 })

          ForEach(this.tabs, (tab: TabItem, index: number) => {
            Column() {
              Text(tab.icon).fontSize(22)
                .margin({ bottom: 2 })
              Text(tab.name).fontSize(11)
                .fontColor(this.selectedTabIndex === index ? '#007DFF' : '#666666')
                .fontWeight(this.selectedTabIndex === index ? FontWeight.Medium : FontWeight.Normal)
            }
            .width(56).padding({ top: 10, bottom: 10 }).borderRadius(8)
            .backgroundColor(this.selectedTabIndex === index ? '#F0F8FF' : Color.Transparent)
            .margin({ bottom: 4 })
            .onClick(() => this.handleTabChange(index))
          })
        }
        .width(64).height('100%')
        .justifyContent(FlexAlign.Start).alignItems(HorizontalAlign.Center)
        .backgroundColor('#FFFFFF')
        .border({ width: { right: 1 }, color: '#E5E5E5' })
        .padding({ top: 8 })

        // 右侧内容区域
        Column() {
          this.renderContent()
        }
        .layoutWeight(1).height('100%').backgroundColor('#F8F8F8')
      }
      .width('100%').height('100%')
    } else {
        promptAction.showToast({ message: '文件无法预览' });
      }
    } catch (err) {
      promptAction.showToast({ message: '预览失败' });
    }
  }

  @Builder
  private renderFilesTab() {
    Column() {
      Swiper() {
        ForEach(this.swiperItems, (item: SwiperItemConfig): void => {
          Column() {
            Column() {
              Text(item.title).fontSize(22).fontColor('#FFFFFF').fontWeight(FontWeight.Bold).margin({ bottom: 6 })
              Text(item.subtitle).fontSize(14).fontColor('#FFFFFF').opacity(0.9)
            }
            .width('100%').height('100%')
            .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
            .backgroundColor(item.backgroundColor || '#FFFFFF')
            .borderRadius(12)
            .onClick((): void => { if (item.onClick) item.onClick() })
          }
          .width('100%').height(100)
          .margin({ right: 8 })
        }, (item: SwiperItemConfig): string => item.id)
      }
      .autoPlay(true).interval(3000).indicator(true).loop(true)
      .displayCount(1).itemSpace(8)
      .width('100%').height(100)
      .margin({ bottom: 12 })

      Text('文件管理器')
        .fontSize(18).fontWeight(FontWeight.Bold)
        .width('100%').textAlign(TextAlign.Start)
        .margin({ bottom: 8, left: 8 })

      FileListView()
        .layoutWeight(1).width('100%').height('100%')
    }
    .width('100%').height('100%').padding({ top: 4, left: 4, right: 4 })
  }

  @Builder
  private renderPreviewTab() {
    Scroll() {
      Column({ space: 16 }) {
        Text('文件预览功能').fontSize(20).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).margin({ top: 20 })
        Text('使用HarmonyOS预览功能打开文件').fontSize(14).fontColor('#666666').width('100%').textAlign(TextAlign.Center).margin({ bottom: 20 })

        Column({ space: 14 }) {
          Button('预览文件').fontSize(16).fontWeight(FontWeight.Medium).width('75%').height(46)
            .backgroundColor('#007DFF').fontColor('#FFFFFF').borderRadius(23)
            .onClick(() => this.previewFile())
          Button('预览文件夹').fontSize(16).fontWeight(FontWeight.Medium).width('75%').height(46)
            .backgroundColor('#07C160').fontColor('#FFFFFF').borderRadius(23)
            .onClick(() => this.previewFile())
        }.width('100%').alignItems(HorizontalAlign.Center)
      }
      .width('100%').padding(12)
    }
    .width('100%').height('100%')
  }

  @Builder
  private renderSettingsTab() {
    Scroll() {
      Column({ space: 12 }) {
        Text('设置').fontSize(20).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).margin({ top: 16 })

        // ========== 自由流转面板 ==========
        Column({ space: 8 }) {
          Text('🔄 自由流转').fontSize(15).fontWeight(FontWeight.Medium).width('100%').textAlign(TextAlign.Start)
          this.renderInfoItem('流转状态:', this.continuationSaved ? `✅ 已保存 (${this.continuationSaveTime})` : '⏳ 未保存')

          if (this.continuationSaved) {
            Text(this.continuationDataSummary)
              .fontSize(12).fontColor('#333333').width('100%')
              .backgroundColor('#F5F7FA').padding(8).borderRadius(6)
              .margin({ top: 2, bottom: 4 })
          }

          Row({ space: 8 }) {
            Button('💾 模拟保存')
              .fontSize(12).height(36).layoutWeight(1)
              .backgroundColor('#007DFF').fontColor('#FFFFFF').borderRadius(8)
              .onClick((): void => { this.simulateContinuationSave() })
            Button('📥 模拟恢复')
              .fontSize(12).height(36).layoutWeight(1)
              .backgroundColor(this.continuationSaved ? '#07C160' : '#CCCCCC')
              .fontColor('#FFFFFF').borderRadius(8)
              .enabled(this.continuationSaved)
              .onClick((): void => { this.simulateContinuationRestore() })
          }.width('100%')

          Text('真机上点击对端 Dock 栏即可自动流转')
            .fontSize(11).fontColor('#999999').width('100%')
        }
        .width('100%').padding(14).backgroundColor('#FFFFFF').borderRadius(10)
        .shadow({ radius: 4, color: '#0A000000', offsetX: 0, offsetY: 2 })

        // ========== 设备信息面板 ==========
        Column({ space: 8 }) {
          Text('设备信息').fontSize(15).fontWeight(FontWeight.Medium).width('100%').textAlign(TextAlign.Start)
          this.renderInfoItem('当前断点:', this.currentBreakpoint)
          this.renderInfoItem('窗口宽度:', `${Math.round(this.windowWidth)}vp`)
          this.renderInfoItem('栅格列数:', this.breakpointSystem.getGridColumns().toString())
        }
        .width('100%').padding(14).backgroundColor('#FFFFFF').borderRadius(10)
        .shadow({ radius: 4, color: '#0A000000', offsetX: 0, offsetY: 2 })

        Column({ space: 6 }) {
          Text('关于').fontSize(15).fontWeight(FontWeight.Medium).width('100%').textAlign(TextAlign.Start)
          Text('文件管理器 v1.0').fontSize(13).fontColor('#666666').width('100%')
          Text('HarmonyOS NEXT').fontSize(13).fontColor('#666666').width('100%')
          Text('Phone产品定制版').fontSize(13).fontColor('#666666').width('100%')
          Text('✓ 自由流转（跨端迁移）').fontSize(13).fontColor('#07C160').width('100%')
        }
        .width('100%').padding(14).backgroundColor('#FFFFFF').borderRadius(10)
        .shadow({ radius: 4, color: '#0A000000', offsetX: 0, offsetY: 2 })
      }
      .width('100%').padding(14)
    }
    .width('100%').height('100%')
  }

  @Builder
  private renderInfoItem(label: string, value: string) {
    Row() {
      Text(label).fontSize(13).fontColor('#666666').layoutWeight(1)
      Text(value).fontSize(13).fontColor('#333333').fontWeight(FontWeight.Medium)
    }
    .width('100%').padding({ top: 4, bottom: 4 }).border({ width: { bottom: 1 }, color: '#F5F5F5' })
  }

  @Builder
  private renderBottomTabBar() {
    Row() {
      ForEach(this.tabs, (tab: TabItem, index: number) => {
        Column() {
          Text(tab.icon).fontSize(20).margin({ bottom: 2 })
          Text(tab.name)
            .fontSize(11)
            .fontColor(this.selectedTabIndex === index ? '#007DFF' : '#999999')
            .fontWeight(this.selectedTabIndex === index ? FontWeight.Medium : FontWeight.Normal)
        }
        .width(56).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .padding({ top: 4, bottom: 4 })
        .onClick(() => this.handleTabChange(index))
      })
    }
    .width('100%').height(50)
    .justifyContent(FlexAlign.SpaceAround).alignItems(VerticalAlign.Center)
    .backgroundColor('#FFFFFF')
    .border({ width: { top: 1 }, color: '#E5E5E5' })
  }

  @Builder
  private renderContent() {
    if (this.selectedTabIndex === 0) {
      this.renderFilesTab()
    } else if (this.selectedTabIndex === 1) {
      this.renderPreviewTab()
    } else {
      this.renderSettingsTab()
    }
  }

  build() {
    if (!this.isReady) {
      Column() {
        LoadingProgress().width(40).height(40).color('#007DFF')
        Text('初始化...').fontSize(13).fontColor('#666666').margin({ top: 12 })
      }
      .width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .backgroundColor('#FFFFFF')
    } else {
      Column() {
        // 内容区域
        Column() {
          this.renderContent()
        }
        .layoutWeight(1).width('100%').backgroundColor('#F8F8F8')

        // 底部标签栏（Phone特征）
        this.renderBottomTabBar()
      }
      .width('100%').height('100%').backgroundColor('#FFFFFF')
    }
  }
}
