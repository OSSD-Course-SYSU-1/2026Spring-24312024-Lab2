/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2024. All rights reserved.
 *
 * 屏幕方向适配系统
 *
 * 检测策略（多路径保障）：
 *   路径1：mediaquery.matchMediaSync('(orientation: landscape)') - 标准API
 *   路径2：display.getDefaultDisplaySync().orientation - 快速读取
 *   路径3：display.on('change') - 显示变化监听
 *
 * 使用方式（在 @Component 的 aboutToAppear 中）：
 *   const helper = new ScreenOrientationHelper();
 *   helper.bind((isLandscape) => { this.isLandscape = isLandscape; });
 *   // aboutToDisappear 中: helper.unbind();
 */

import { display, mediaquery } from '@kit.ArkUI';

/**
 * 屏幕方向枚举
 */
export enum ScreenOrientation {
  PORTRAIT = 'portrait',
  LANDSCAPE = 'landscape'
}

/**
 * 屏幕方向辅助类
 */
export class ScreenOrientationHelper {
  /** 当前是否为横屏 */
  public isLandscape: boolean = false;

  /** 当前方向 */
  public currentOrientation: ScreenOrientation = ScreenOrientation.PORTRAIT;

  /** mediaquery 监听器 */
  private landscapeListener: mediaquery.MediaQueryListener | null = null;

  /** 用户回调 */
  private onChangeCallback: ((isLandscape: boolean) => void) | null = null;

  /** display change 是否已绑定 */
  private displayChangeBound: boolean = false;

  /**
   * 绑定所有方向检测（在 @Component 的 aboutToAppear 中调用）
   * @param onChange 方向变化回调
   */
  public bind(onChange: (isLandscape: boolean) => void): void {
    this.onChangeCallback = onChange;

    // 1. 先用 display 读取初始值
    this.detectFromDisplay();

    // 2. mediaquery 监听
    this.bindMediaQuery();

    // 3. display.on('change') 作为监听补充
    this.bindDisplayChange();
  }

  /**
   * 解绑所有监听
   */
  public unbind(): void {
    if (this.landscapeListener) {
      try {
        this.landscapeListener.off('change');
      } catch (_e) { /* pass */ }
      this.landscapeListener = null;
    }
    if (this.displayChangeBound) {
      try {
        display.off('change');
      } catch (_e) { /* pass */ }
      this.displayChangeBound = false;
    }
    this.onChangeCallback = null;
  }

  /**
   * 通过 display 检测当前方向
   */
  private detectFromDisplay(): void {
    try {
      const orientation: number = display.getDefaultDisplaySync().orientation;
      // display.Orientation: 0=PORTRAIT, 1=LANDSCAPE, 2=PORTRAIT_INVERTED, 3=LANDSCAPE_INVERTED
      const isLand: boolean = (orientation === 1 || orientation === 3);
      this.updateOrientation(isLand, 'display');
    } catch (_e) { /* pass */ }
  }

  /**
   * mediaquery 监听横屏事件
   */
  private bindMediaQuery(): void {
    try {
      this.landscapeListener = mediaquery.matchMediaSync('(orientation: landscape)');
      if (this.landscapeListener) {
        this.landscapeListener.on('change', (result: mediaquery.MediaQueryResult): void => {
          this.updateOrientation(result.matches, 'mediaquery');
        });
      }
    } catch (_e) {
      console.error('[ScreenOrientation] mediaquery bind failed');
    }
  }

  /**
   * display.on('change') 补充监听
   */
  private bindDisplayChange(): void {
    try {
      display.on('change', (): void => {
        this.detectFromDisplay();
      });
      this.displayChangeBound = true;
    } catch (_e) { /* pass */ }
  }

  /**
   * 统一更新方向（去重）
   */
  private updateOrientation(isLand: boolean, source: string): void {
    if (this.isLandscape !== isLand) {
      this.isLandscape = isLand;
      this.currentOrientation = isLand
        ? ScreenOrientation.LANDSCAPE
        : ScreenOrientation.PORTRAIT;

      console.info(`[ScreenOrientation] → ${this.currentOrientation} (source: ${source})`);

      if (this.onChangeCallback) {
        this.onChangeCallback(isLand);
      }
    }
  }

  /**
   * 获取方向标签
   */
  public getLabel(): string {
    return this.isLandscape ? '横屏' : '竖屏';
  }

  /**
   * 获取方向图标
   */
  public getIcon(): string {
    return this.isLandscape ? '↔️' : '↕️';
  }
}

/**
 * Scroller 状态管理器
 * 用于在横竖屏切换时保存和恢复滚动位置
 */
export class ScrollerStateManager {
  private scrollPositions: Map<string, number> = new Map();

  public savePosition(key: string, scroller: Scroller): void {
    try {
      const offset: number = scroller.currentOffset()?.yOffset ?? 0;
      this.scrollPositions.set(key, offset);
    } catch (_e) { /* pass */ }
  }

  public restorePosition(key: string, scroller: Scroller): void {
    const offset: number = this.scrollPositions.get(key) ?? 0;
    if (offset > 0) {
      setTimeout((): void => {
        try {
          scroller.scrollTo({ xOffset: 0, yOffset: offset, animation: false });
        } catch (_e) { /* pass */ }
      }, 120);
    }
  }

  public clear(): void {
    this.scrollPositions.clear();
  }
}
