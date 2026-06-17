/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.
 *
 * 一多架构 - 响应式入口页面
 * 一套代码，适配小（手机）、中（折叠屏）、大（平板/PC）设备
 *
 * 已集成自由流转（跨端迁移）功能：
 *   - aboutToAppear 中检查 isContinuationRestored 标记
 *   - 若为接续恢复，自动切换到源设备的标签页
 *   - tab 切换时自动保存状态到 AppStorage 供 onContinue 收集
 */

import { FileListView } from '../features/filemanager/FileListView';
import { BreakpointSystem, BreakpointType } from '../common/utils/BreakpointSystem';
import { SwiperItemConfig } from '../common/utils/ResponsiveSwiper';
import { SysCapChecker, SystemCapability } from '../common/utils/SysCapChecker';
import { ScreenOrientationHelper, ScrollerStateManager } from '../common/utils/ScreenOrientation';
import { filePreview } from '@kit.PreviewKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { promptAction, display } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * 标签页数据接口
 */
interface TabItem {
  value: string;
  name: string;
  icon: string;
}

/**
 * 信息行数据接口
 */
interface InfoRowData {
  label: string;
  value: string;
}

@Entry
@Component
struct Index {
  private breakpointSystem: BreakpointSystem = BreakpointSystem.getInstance();
  private sysCapChecker: SysCapChecker = SysCapChecker.getInstance();

  @State currentBreakpoint: BreakpointType = BreakpointType.MD;
  @State windowWidth: number = 0;
  @State gridColumns: number = 8;
  @State selectedTabIndex: number = 0;
  @State showSideBar: boolean = false;
  @State isReady: boolean = false;
  @State swiperDisplayCount: number = 1;
  @State swiperCurrentIndex: number = 0;

  /** 屏幕方向 */
  @State isLandscape: boolean = false;
  @State orientationLabel: string = '竖屏';

  /** Scroller 实例 - 用于保存/恢复滚动位置 */
  private filesTabScroller: Scroller = new Scroller();
  private previewTabScroller: Scroller = new Scroller();
  private settingsTabScroller: Scroller = new Scroller();

  /** 方向辅助工具 */
  private orientationHelper: ScreenOrientationHelper = new ScreenOrientationHelper();

  /** 滚动位置管理器 */
  private scrollerStateManager: ScrollerStateManager = new ScrollerStateManager();

  /** 是否从跨端迁移恢复（从 AppStorage 读取，由 EntryAbility 设置） */
  @StorageLink('isContinuationRestored') isContinuationRestored: boolean = false;

  /** 接续恢复的标签页索引 */
  @StorageLink('continuationRestoredTabIndex') continuationTabIndex: number = 0;

  /** 流转状态模拟 - 是否已保存 */
  @State continuationSaved: boolean = false;
  /** 流转状态模拟 - 上次保存时间 */
  @State continuationSaveTime: string = '';
  /** 流转状态模拟 - 保存的数据摘要 */
  @State continuationDataSummary: string = '';
  /** 是否显示流转面板 */
  @State showContinuationPanel: boolean = false;

  private fileName: string = 'preview_info.txt';

  private tabs: TabItem[] = [
    { value: 'files', name: '文件', icon: '📁' },
    { value: 'preview', name: '预览', icon: '👁️' },
    { value: 'settings', name: '设置', icon: '⚙️' }
  ];

  private swiperItems: SwiperItemConfig[] = [
    { id: 'slide-1', title: '文件管理', subtitle: '高效管理您的文件',
      backgroundColor: '#007DFF', onClick: (): void => { console.log('swiper-1') } },
    { id: 'slide-2', title: '跨设备投屏', subtitle: '无缝投屏到其他设备',
      backgroundColor: '#07C160', onClick: (): void => { console.log('swiper-2') } },
    { id: 'slide-3', title: '多端适配', subtitle: '一次开发，多端部署',
      backgroundColor: '#FA5151', onClick: (): void => { console.log('swiper-3') } }
  ];

  private displayCountConfig: Record<string, number> = {
    'xs': 1, 'sm': 1, 'md': 2, 'lg': 3, 'xl': 3
  };

  aboutToAppear(): void {
    this.initBreakpointSystem();
    this.initOrientation();

    // 检查是否从跨端迁移恢复
    setTimeout((): void => {
      this.checkContinuationRestore();
      this.checkDeviceCapabilities();
    }, 500);
  }

  aboutToDisappear(): void {
    // 解绑屏幕方向监听
    this.orientationHelper.unbind();
    console.info('[Index] Screen orientation listener removed');
  }

  /**
   * 初始化屏幕方向监听（使用多路径检测确保可靠性）
   */
  private initOrientation(): void {
    this.orientationHelper.bind((isLandscape: boolean): void => {
      this.saveScrollPositions();
      this.isLandscape = isLandscape;
      this.orientationLabel = isLandscape ? '横屏' : '竖屏';
      AppStorage.setOrCreate('isLandscape', isLandscape);
    });

    this.isLandscape = this.orientationHelper.isLandscape;
    this.orientationLabel = this.orientationHelper.getLabel();
  }

  /**
   * 保存所有滚动位置（旋转前调用）
   */
  private saveScrollPositions(): void {
    this.scrollerStateManager.savePosition('filesTab', this.filesTabScroller);
    this.scrollerStateManager.savePosition('previewTab', this.previewTabScroller);
    this.scrollerStateManager.savePosition('settingsTab', this.settingsTabScroller);
  }

  /**
   * 恢复滚动位置（旋转后调用）
   */
  private restoreScrollPositions(): void {
    this.scrollerStateManager.restorePosition('filesTab', this.filesTabScroller);
    this.scrollerStateManager.restorePosition('previewTab', this.previewTabScroller);
    this.scrollerStateManager.restorePosition('settingsTab', this.settingsTabScroller);
  }

  /**
   * 检查并恢复跨端迁移状态
   * 如果是从其他设备迁移过来的，恢复之前选择的标签页
   */
  private checkContinuationRestore(): void {
    if (this.isContinuationRestored && this.continuationTabIndex !== undefined) {
      hilog.info(0x0000, 'Index', 
        `Continuation restored - switching to tab: ${this.continuationTabIndex}`);
      this.selectedTabIndex = this.continuationTabIndex;
      
      // 显示迁移提示
      promptAction.showToast({
        message: '已从其他设备恢复状态',
        duration: 2000
      });

      // 清除恢复标记（仅首次恢复时生效）
      AppStorage.setOrCreate('isContinuationRestored', false);
    }
  }

  private initBreakpointSystem(): void {
    // 获取初始屏幕宽度
    try {
      const defaultDisplay = display.getDefaultDisplaySync();
      const density: number = defaultDisplay.densityDPI / 160;
      const widthVp: number = defaultDisplay.width / density;
      this.breakpointSystem.updateWindowWidth(widthVp);
    } catch (e) {
      // 使用默认宽度750vp（常见手机宽度）作为降级
      this.breakpointSystem.updateWindowWidth(750);
    }

    this.currentBreakpoint = this.breakpointSystem.getCurrentBreakpoint();
    this.windowWidth = this.breakpointSystem.getCurrentWindowWidth();
    this.gridColumns = this.breakpointSystem.getGridColumns();
    this.updateSwiperDisplayCount();
    this.updateLayoutForBreakpoint(this.currentBreakpoint);

    this.breakpointSystem.addListener({
      onBreakpointChanged: (breakpoint: BreakpointType, windowWidth: number): void => {
        this.currentBreakpoint = breakpoint;
        this.windowWidth = windowWidth;
        this.gridColumns = this.breakpointSystem.getGridColumns();
        this.updateSwiperDisplayCount();
        this.updateLayoutForBreakpoint(breakpoint);
        // 同步断点和窗口宽度到 AppStorage，供 onContinue 收集
        AppStorage.setOrCreate('currentBreakpoint', breakpoint);
        AppStorage.setOrCreate('windowWidth', windowWidth);
      }
    });
    this.isReady = true;

    // 初始时也同步一次状态
    AppStorage.setOrCreate('currentBreakpoint', this.currentBreakpoint);
    AppStorage.setOrCreate('windowWidth', this.windowWidth);
    AppStorage.setOrCreate('selectedTabIndex', this.selectedTabIndex);
    AppStorage.setOrCreate('isMultiSelectMode', false);
  }

  private updateSwiperDisplayCount(): void {
    const key: string = this.currentBreakpoint;
    const count: number = this.displayCountConfig[key] ?? 1;
    this.swiperDisplayCount = Math.min(count, this.swiperItems.length);
  }

  private updateLayoutForBreakpoint(breakpoint: BreakpointType): void {
    this.showSideBar = (breakpoint === BreakpointType.LG || breakpoint === BreakpointType.XL);
  }

  private async checkDeviceCapabilities(): Promise<void> {
    try {
      const fr = await this.sysCapChecker.checkCapability(SystemCapability.FILE_MANAGEMENT);
      if (!fr.supported) { promptAction.showToast({ message: '文件管理能力受限' }) }
      const dr = await this.sysCapChecker.checkCapability(SystemCapability.DISTRIBUTED_HARDWARE);
      if (!dr.supported) { console.warn('不支持分布式能力') }
    } catch (e) { console.error('能力检查失败:', e) }
  }

  private handleTabChange(index: number): void {
    this.selectedTabIndex = index;
    // 将当前标签页状态同步到 AppStorage，供 onContinue 收集迁移数据
    AppStorage.setOrCreate('selectedTabIndex', index);
    // 关闭流转面板（切tab时自动收起）
    this.showContinuationPanel = false;
  }

  // ==================== 流转功能 UI 操作（模拟演示） ====================

  /**
   * 模拟「源端保存」操作
   * 在真机上，onContinue 由系统自动调用；此处模拟手动触发效果
   */
  private simulateContinuationSave(): void {
    const now = new Date();
    const timeStr = `${now.getHours().toString().padStart(2, '0')}:` +
      `${now.getMinutes().toString().padStart(2, '0')}:` +
      `${now.getSeconds().toString().padStart(2, '0')}`;

    // 保存当前状态到 AppStorage（模拟 onContinue 效果）
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

  /**
   * 模拟「对端恢复」操作
   * 在真机上由 EntryAbility.onCreate/onNewWant 自动完成；此处模拟手动恢复
   */
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
      const savedTs = AppStorage.get<number>('continuation_timestamp');

      if (savedTab !== undefined) {
        this.selectedTabIndex = savedTab;
        AppStorage.setOrCreate('selectedTabIndex', savedTab);
      }

      const detail = `恢复标签: ${this.tabs[this.selectedTabIndex].name} | ` +
        `断点: ${savedBp || 'N/A'} | ` +
        `保存于: ${this.continuationSaveTime}`;

      promptAction.showToast({
        message: `🔄 状态已恢复 (模拟流转对端)`,
        duration: 2000
      });

      // 显示恢复详情
      this.continuationDataSummary = detail;

    } catch (_e) {
      promptAction.showToast({
        message: '恢复失败：未找到已保存的状态',
        duration: 1500
      });
    }
  }

  /**
   * 切换流转面板显示
   */
  private toggleContinuationPanel(): void {
    this.showContinuationPanel = !this.showContinuationPanel;
  }

  private getTitleFontSize(): number {
    return this.breakpointSystem.isSmallScreen() ? 18 : 22;
  }

  private getSwiperHeight(): number {
    return this.breakpointSystem.isSmallScreen() ? 100 : 140;
  }

  private async previewFile(): Promise<void> {
    try {
      let context = this.getUIContext().getHostContext();
      if (!context) return;
      let fileDir: string = context.filesDir;
      let filePath: string = fileDir + '/' + this.fileName;
      let file: fs.File = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      let uri: string = fileUri.getUriFromPath(filePath);
      fs.writeSync(file.fd, "hello, world");
      fs.closeSync(file);
      let result: boolean = await filePreview.canPreview(context, uri);
      if (result) {
        filePreview.openPreview(context, { title: this.fileName, uri: uri, mimeType: 'text/plain' });
      } else {
        promptAction.showToast({ message: '文件无法预览' });
      }
    } catch (err) {
      promptAction.showToast({ message: '预览文件失败' });
    }
  }

  private async previewFolder(): Promise<void> {
    try {
      let context = this.getUIContext().getHostContext();
      if (!context) return;
      let fileDir: string = context.filesDir;
      let folderUri: string = fileUri.getUriFromPath(fileDir);
      let filePath: string = fileDir + '/' + this.fileName;
      let file: fs.File = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      fs.writeSync(file.fd, "hello, world");
      fs.closeSync(file);
      let result: boolean = await filePreview.canPreview(context, folderUri);
      if (result) {
        filePreview.openPreview(context, { title: '文件夹', uri: folderUri, mimeType: '' });
      } else {
        promptAction.showToast({ message: '文件夹无法预览' });
      }
    } catch (err) {
      promptAction.showToast({ message: '预览文件夹失败' });
    }
  }

  // ==================== Builders ====================

  @Builder
  renderSwiperArea(): void {
    Column() {
      Swiper() {
        ForEach(this.swiperItems, (item: SwiperItemConfig): void => {
          Column() {
            Column() {
              Text(item.title).fontSize(24).fontColor('#FFFFFF').fontWeight(FontWeight.Bold).margin({ bottom: 8 })
              Text(item.subtitle).fontSize(16).fontColor('#FFFFFF').opacity(0.9)
            }
            .width('100%').height('100%')
            .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
            .backgroundColor(item.backgroundColor || '#FFFFFF')
            .borderRadius(12)
            .onClick((): void => { if (item.onClick) item.onClick() })
          }
          .width('100%').height(this.getSwiperHeight())
          .margin({ right: 12 })
        }, (item: SwiperItemConfig): string => item.id)
      }
      .autoPlay(true)
      .interval(3000)
      .indicator(true)
      .loop(true)
      .displayCount(this.swiperDisplayCount)
      .itemSpace(12)
      .onChange((index: number): void => { this.swiperCurrentIndex = index })
      .width('100%')
      .height(this.getSwiperHeight())
    }
    .width('100%')
    .margin({ bottom: 16 })
  }

  @Builder
  renderFilesTab(): void {
    if (this.isLandscape && this.breakpointSystem.isSmallScreen()) {
      // 横屏：左右分栏 - 左侧预览区(40%) + 右侧文件列表(60%)
      Row() {
        // 左侧：轮播图预览区
        Scroll(this.filesTabScroller) {
          Column() {
            this.renderSwiperArea()
            Text('文件管理器').fontSize(this.getTitleFontSize()).fontWeight(FontWeight.Bold)
              .width('100%').textAlign(TextAlign.Start).margin({ bottom: 8, left: 8 })
          }
          .width('100%')
        }
        .width('40%').height('100%').padding({ top: 8, left: 8, right: 4 })
        .scrollBar(BarState.Off)
        .border({ width: { right: 1 }, color: '#E5E5E5' })

        // 右侧：文件列表
        FileListView().layoutWeight(1).height('100%')
      }
      .width('100%').height('100%')
    } else {
      // 竖屏/中屏以上：单栏流式布局
      Scroll(this.filesTabScroller) {
        Column() {
          this.renderSwiperArea()
          Text('文件管理器').fontSize(this.getTitleFontSize()).fontWeight(FontWeight.Bold)
            .width('100%').textAlign(TextAlign.Start).margin({ bottom: 12, left: 8 })
          FileListView().layoutWeight(1).width('100%').height('100%')
        }
        .width('100%').height('100%')
      }
      .width('100%').height('100%').padding({ top: 8, left: 8, right: 8 })
    }
  }

  @Builder
  renderPreviewTab(): void {
    Scroll(this.previewTabScroller) {
      Column({ space: 16 }) {
        Text('文件预览功能').fontSize(this.breakpointSystem.isSmallScreen() ? 20 : 24)
          .fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).margin({ top: 20, bottom: 8 })
        Text('使用HarmonyOS预览功能打开文件').fontSize(14).fontColor('#666666')
          .width('100%').textAlign(TextAlign.Center).margin({ bottom: 24 })

        Column({ space: 16 }) {
          Button('预览文件').fontSize(18).width('80%').height(50)
            .backgroundColor('#007DFF').fontColor('#FFFFFF').borderRadius(25)
            .onClick((): void => { this.previewFile() })
          Button('预览文件夹').fontSize(18).width('80%').height(50)
            .backgroundColor('#07C160').fontColor('#FFFFFF').borderRadius(25)
            .onClick((): void => { this.previewFolder() })
        }.width('100%').alignItems(HorizontalAlign.Center)
      }
      .width('100%').padding(16)
    }
    .width('100%').height('100%')
  }

  @Builder
  renderSettingsTab(): void {
    Scroll() {
      Column({ space: 16 }) {
        Text('设置').fontSize(this.breakpointSystem.isSmallScreen() ? 20 : 24)
          .fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).margin({ top: 20, bottom: 8 })

        // ========== 自由流转（跨端迁移）面板 ==========
        Column({ space: 10 }) {
          Row() {
            Text('🔄 自由流转').fontSize(16).fontWeight(FontWeight.Medium)
            Blank()
            Text(this.continuationSaved ? '✅ 已保存' : '⏳ 待保存')
              .fontSize(13).fontColor(this.continuationSaved ? '#07C160' : '#FF9500')
          }.width('100%')

          Divider().strokeWidth(1).color('#F0F0F0')

          Text('跨端迁移允许将当前应用状态无缝切换至另一台设备继续操作。')
            .fontSize(13).fontColor('#999999').width('100%')
            .margin({ bottom: 4 })

          // 保存时间与摘要
          if (this.continuationSaved) {
            Text(`保存时间: ${this.continuationSaveTime}`)
              .fontSize(12).fontColor('#666666').width('100%')
            Text(this.continuationDataSummary)
              .fontSize(12).fontColor('#333333').width('100%')
              .backgroundColor('#F5F7FA').padding(8).borderRadius(6)
              .margin({ top: 4, bottom: 6 })
          }

          // 操作按钮行
          Row({ space: 10 }) {
            Button('💾 模拟保存（源端）')
              .fontSize(13).height(38).layoutWeight(1)
              .backgroundColor('#007DFF').fontColor('#FFFFFF').borderRadius(8)
              .onClick((): void => { this.simulateContinuationSave() })

            Button('📥 模拟恢复（对端）')
              .fontSize(13).height(38).layoutWeight(1)
              .backgroundColor(this.continuationSaved ? '#07C160' : '#CCCCCC')
              .fontColor('#FFFFFF').borderRadius(8)
              .enabled(this.continuationSaved)
              .onClick((): void => { this.simulateContinuationRestore() })
          }.width('100%')

          Divider().strokeWidth(1).color('#F0F0F0')

          // 使用说明
          Text('📋 使用说明')
            .fontSize(13).fontWeight(FontWeight.Medium).width('100%').margin({ top: 4 })
          Text('• 真机流转：点击对端 Dock 栏图标即可自动触发')
            .fontSize(12).fontColor('#999999').width('100%')
          Text('• 虚拟机演示：点击上方按钮模拟流转流程')
            .fontSize(12).fontColor('#999999').width('100%')
          Text('• 需双端登录同一华为账号并开启 Wi-Fi/蓝牙')
            .fontSize(12).fontColor('#999999').width('100%')
        }
        .width('100%').padding(16).backgroundColor('#FFFFFF').borderRadius(12)
        .shadow({ radius: 4, color: '#0A000000', offsetX: 0, offsetY: 2 })

        // ========== 设备信息面板 ==========
        Column({ space: 10 }) {
          Text('设备信息').fontSize(16).fontWeight(FontWeight.Medium).width('100%').textAlign(TextAlign.Start)
          this.renderInfoRow({ label: '当前断点:', value: this.currentBreakpoint })
          this.renderInfoRow({ label: '窗口宽度:', value: `${Math.round(this.windowWidth)}vp` })
          this.renderInfoRow({ label: '屏幕方向:', value: `${this.orientationHelper.getIcon()} ${this.orientationLabel}` })
          this.renderInfoRow({ label: '栅格列数:', value: this.gridColumns.toString() })
          this.renderInfoRow({ label: '流转状态:', value: this.continuationSaved ? `已保存 (${this.continuationSaveTime})` : '未保存' })
        }.width('100%').padding(16).backgroundColor('#FFFFFF').borderRadius(12)
          .shadow({ radius: 4, color: '#0A000000', offsetX: 0, offsetY: 2 })

        // ========== 横竖屏适配演示 ==========
        Column({ space: 10 }) {
          Text('📱 横竖屏适配演示').fontSize(16).fontWeight(FontWeight.Medium).width('100%').textAlign(TextAlign.Start)
          Text('旋转手机体验自适应布局变化：')
            .fontSize(13).fontColor('#999999').width('100%')
          Text(this.isLandscape
            ? '✅ 横屏模式：左右分栏 + 左侧标签栏 + 宽网格'
            : '✅ 竖屏模式：单栏流式 + 底部标签栏 + 窄网格')
            .fontSize(13).fontColor('#333333').width('100%')
            .padding(10).backgroundColor('#F5F7FA').borderRadius(6)
        }.width('100%').padding(16).backgroundColor('#FFFFFF').borderRadius(12)
          .shadow({ radius: 4, color: '#0A000000', offsetX: 0, offsetY: 2 })

        Column({ space: 8 }) {
          Text('关于').fontSize(16).fontWeight(FontWeight.Medium).width('100%').textAlign(TextAlign.Start)
          Text('文件管理器 v1.0.0').fontSize(14).fontColor('#666666').width('100%')
          Text('基于HarmonyOS NEXT开发').fontSize(14).fontColor('#666666').width('100%')
          Text('支持一次开发，多端部署').fontSize(14).fontColor('#666666').width('100%')
          Text('三种布局模式自动切换').fontSize(14).fontColor('#666666').width('100%')
          Text('✓ 自由流转（跨端迁移）').fontSize(14).fontColor('#07C160').width('100%')
          Text('✓ 横竖屏自适应布局').fontSize(14).fontColor('#07C160').width('100%')
        }.width('100%').padding(16).backgroundColor('#FFFFFF').borderRadius(12)
          .shadow({ radius: 4, color: '#0A000000', offsetX: 0, offsetY: 2 })
      }
      .width('100%').padding(16)
    }
    .width('100%').height('100%')
  }

  @Builder
  renderInfoRow(data: InfoRowData): void {
    Row() {
      Text(data.label).fontSize(14).fontColor('#666666').layoutWeight(1)
      Text(data.value).fontSize(14).fontColor('#333333').fontWeight(FontWeight.Medium)
    }
    .width('100%').padding({ top: 6, bottom: 6 }).border({ width: { bottom: 1 }, color: '#F0F0F0' })
  }

  @Builder
  renderHorizontalTabBar(): void {
    Row() {
      ForEach(this.tabs, (tab: TabItem, index: number): void => {
        Column() {
          Text(tab.icon).fontSize(20).margin({ bottom: 2 })
          Text(tab.name).fontSize(12)
            .fontColor(this.selectedTabIndex === index ? '#007DFF' : '#666666')
            .fontWeight(this.selectedTabIndex === index ? FontWeight.Medium : FontWeight.Normal)
        }
        .width(60).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .padding({ top: 6, bottom: 6 }).borderRadius(8)
        .backgroundColor(this.selectedTabIndex === index ? '#F0F8FF' : Color.Transparent)
        .onClick((): void => { this.handleTabChange(index) })
      }, (tab: TabItem): string => tab.value)
    }
    .width('100%').height(52).justifyContent(FlexAlign.SpaceAround).alignItems(VerticalAlign.Center)
    .backgroundColor('#FFFFFF').border({ width: { top: 1 }, color: '#E5E5E5' })
  }

  @Builder
  renderSidebar(): void {
    Column() {
      Text('📁 文件管理器').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#333333')
        .width('100%').textAlign(TextAlign.Center).padding({ top: 24, bottom: 24 })
      Divider().strokeWidth(1).color('#E5E5E5')

      Column({ space: 8 }) {
        ForEach(this.tabs, (tab: TabItem, index: number): void => {
          Row({ space: 8 }) {
            Text(tab.icon).fontSize(22)
            Text(tab.name).fontSize(16)
              .fontWeight(this.selectedTabIndex === index ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.selectedTabIndex === index ? '#007DFF' : '#333333')
          }
          .width('100%').height(48).justifyContent(FlexAlign.Start).alignItems(VerticalAlign.Center)
          .padding({ left: 16, right: 16 }).borderRadius(8)
          .backgroundColor(this.selectedTabIndex === index ? '#F0F8FF' : Color.Transparent)
          .onClick((): void => { this.handleTabChange(index) })
        }, (tab: TabItem): string => tab.value)
      }
      .width('100%').padding({ top: 16, left: 8, right: 8 }).layoutWeight(1)

      Column({ space: 4 }) {
        Divider().strokeWidth(1).color('#E5E5E5').margin({ bottom: 8 })
        Text(`设备: ${this.currentBreakpoint.toUpperCase()}`).fontSize(11).fontColor('#999999')
          .width('100%').textAlign(TextAlign.Center)
        Text(`${Math.round(this.windowWidth)}vp · ${this.gridColumns}列栅格`).fontSize(11).fontColor('#999999')
          .width('100%').textAlign(TextAlign.Center)
      }.width('100%').padding({ bottom: 16 })
    }
    .width('100%').height('100%').backgroundColor('#FAFAFA')
  }

  @Builder
  renderTabContent(): void {
    if (this.selectedTabIndex === 0) { this.renderFilesTab() }
    else if (this.selectedTabIndex === 1) { this.renderPreviewTab() }
    else { this.renderSettingsTab() }
  }

  @Builder
  renderTopTabBar(): void {
    Row() {
      ForEach(this.tabs, (tab: TabItem, index: number): void => {
        Column() {
          Text(tab.icon).fontSize(18)
          Text(tab.name).fontSize(13)
            .fontColor(this.selectedTabIndex === index ? '#007DFF' : '#666666')
            .fontWeight(this.selectedTabIndex === index ? FontWeight.Medium : FontWeight.Normal)
        }
        .padding({ left: 16, right: 16, top: 8, bottom: 8 }).borderRadius(8)
        .backgroundColor(this.selectedTabIndex === index ? '#F0F8FF' : Color.Transparent)
        .border({ width: { bottom: this.selectedTabIndex === index ? 3 : 0 }, color: '#007DFF' })
        .onClick((): void => { this.handleTabChange(index) })
      }, (tab: TabItem): string => tab.value)
    }
    .width('100%').height(56).justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
    .backgroundColor('#FFFFFF').border({ width: { bottom: 1 }, color: '#E5E5E5' })
  }

  build() {
    if (!this.isReady) {
      Column() {
        LoadingProgress().width(50).height(50).color('#007DFF')
        Text('正在初始化...').fontSize(14).fontColor('#666666').margin({ top: 16 })
      }
      .width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .backgroundColor('#FFFFFF')
    } else if (this.showSideBar) {
      // LG/XL: SideBarContainer 侧边栏+双栏布局
      SideBarContainer(SideBarContainerType.Embed) {
        this.renderSidebar()
        Column() { this.renderTabContent() }.layoutWeight(1).height('100%').backgroundColor('#F8F8F8')
      }
      .showSideBar(true).sideBarWidth(200).minSideBarWidth(180).maxSideBarWidth(280)
      .autoHide(false).showControlButton(false)
      .width('100%').height('100%').backgroundColor('#FFFFFF')
    } else if (this.currentBreakpoint === BreakpointType.MD) {
      // MD: 顶部标签栏 + 内容区域（横屏时使用左侧标签栏）
      if (this.isLandscape) {
        this.renderLandscapeTabLayout()
      } else {
        Column() {
          this.renderTopTabBar()
          Column() { this.renderTabContent() }.layoutWeight(1).width('100%').backgroundColor('#F8F8F8')
        }
        .width('100%').height('100%').backgroundColor('#FFFFFF')
      }
    } else {
      // XS/SM: 根据屏幕方向选择布局
      if (this.isLandscape) {
        // 横屏：左侧垂直标签栏 + 右侧内容
        this.renderLandscapeTabLayout()
      } else {
        // 竖屏：底部标签栏 + 上方内容
        Column() {
          Column() { this.renderTabContent() }.layoutWeight(1).width('100%').backgroundColor('#F8F8F8')
          this.renderHorizontalTabBar()
        }
        .width('100%').height('100%').backgroundColor('#FFFFFF')
      }
    }
  }

  /**
   * 横屏标签布局 - 左侧垂直标签栏 + 右侧内容
   */
  @Builder
  renderLandscapeTabLayout(): void {
    Row() {
      // 左侧垂直标签栏
      Column() {
        Text('📁').fontSize(24)
          .margin({ top: 12, bottom: 4 })
        Divider().strokeWidth(1).color('#E5E5E5').margin({ bottom: 8 })

        ForEach(this.tabs, (tab: TabItem, index: number): void => {
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
          .onClick((): void => { this.handleTabChange(index) })
        }, (tab: TabItem): string => tab.value)
      }
      .width(64).height('100%')
      .justifyContent(FlexAlign.Start).alignItems(HorizontalAlign.Center)
      .backgroundColor('#FFFFFF')
      .border({ width: { right: 1 }, color: '#E5E5E5' })
      .padding({ top: 8 })

      // 右侧内容区域
      Column() {
        this.renderTabContent()
      }
      .layoutWeight(1).height('100%').backgroundColor('#F8F8F8')
    }
    .width('100%').height('100%')
  }
}
