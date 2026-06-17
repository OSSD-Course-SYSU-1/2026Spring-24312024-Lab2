/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.
 *
 * 断点系统 - 纯数据驱动，无窗口API依赖
 * 遵循HarmonyOS一多架构标准断点规范
 */

/**
 * 断点类型枚举
 * XS: <320vp, SM: 320-599vp, MD: 600-839vp, LG: 840-1079vp, XL: >=1080vp
 */
export enum BreakpointType {
  XS = 'xs',
  SM = 'sm',
  MD = 'md',
  LG = 'lg',
  XL = 'xl'
}

/**
 * 断点范围定义
 */
export interface BreakpointRange {
  min: number;
  max: number;
  type: BreakpointType;
}

/**
 * 断点变化监听器接口
 */
export interface BreakpointListener {
  onBreakpointChanged: (breakpoint: BreakpointType, windowWidth: number) => void;
}

/**
 * 断点系统工具类 - 单例模式
 */
export class BreakpointSystem {
  private static instance: BreakpointSystem | null = null;

  private readonly breakpoints: BreakpointRange[] = [
    { min: 0, max: 320, type: BreakpointType.XS },
    { min: 320, max: 600, type: BreakpointType.SM },
    { min: 600, max: 840, type: BreakpointType.MD },
    { min: 840, max: 1080, type: BreakpointType.LG },
    { min: 1080, max: Infinity, type: BreakpointType.XL }
  ];

  private currentBreakpoint: BreakpointType = BreakpointType.MD;
  private currentWindowWidth: number = 0;
  private listeners: BreakpointListener[] = [];

  private constructor() {}

  public static getInstance(): BreakpointSystem {
    if (!BreakpointSystem.instance) {
      BreakpointSystem.instance = new BreakpointSystem();
    }
    return BreakpointSystem.instance;
  }

  /**
   * 更新窗口尺寸（由外部调用）
   * @param widthVp 窗口宽度（虚拟像素）
   */
  public updateWindowWidth(widthVp: number): void {
    this.currentWindowWidth = widthVp;
    this.updateBreakpoint(widthVp);
  }

  private updateBreakpoint(widthVp: number): void {
    const oldBreakpoint: BreakpointType = this.currentBreakpoint;

    for (const bp of this.breakpoints) {
      if (widthVp >= bp.min && widthVp < bp.max) {
        this.currentBreakpoint = bp.type;
        break;
      }
    }

    if (oldBreakpoint !== this.currentBreakpoint) {
      this.notifyListeners();
    }
  }

  private notifyListeners(): void {
    for (const listener of this.listeners) {
      try {
        listener.onBreakpointChanged(this.currentBreakpoint, this.currentWindowWidth);
      } catch (error) {
        console.error('通知监听器失败:', error);
      }
    }
  }

  public getCurrentBreakpoint(): BreakpointType {
    return this.currentBreakpoint;
  }

  public getCurrentWindowWidth(): number {
    return this.currentWindowWidth;
  }

  public isBreakpoint(breakpoint: BreakpointType | BreakpointType[]): boolean {
    if (Array.isArray(breakpoint)) {
      return breakpoint.includes(this.currentBreakpoint);
    }
    return this.currentBreakpoint === breakpoint;
  }

  public isSmallScreen(): boolean {
    return this.isBreakpoint([BreakpointType.XS, BreakpointType.SM]);
  }

  public isMediumScreen(): boolean {
    return this.isBreakpoint(BreakpointType.MD);
  }

  public isLargeScreen(): boolean {
    return this.isBreakpoint([BreakpointType.LG, BreakpointType.XL]);
  }

  public getGridColumns(): number {
    switch (this.currentBreakpoint) {
      case BreakpointType.XS:
      case BreakpointType.SM:
        return 4;
      case BreakpointType.MD:
        return 8;
      case BreakpointType.LG:
      case BreakpointType.XL:
        return 12;
      default:
        return 8;
    }
  }

  public addListener(listener: BreakpointListener): void {
    if (!this.listeners.includes(listener)) {
      this.listeners.push(listener);
    }
  }

  public removeListener(listener: BreakpointListener): void {
    const index: number = this.listeners.indexOf(listener);
    if (index >= 0) {
      this.listeners.splice(index, 1);
    }
  }

  public destroy(): void {
    this.listeners = [];
    BreakpointSystem.instance = null;
  }

  public getBreakpoints(): BreakpointRange[] {
    return [...this.breakpoints];
  }

  public getBreakpointByWidth(widthVp: number): BreakpointType {
    for (const bp of this.breakpoints) {
      if (widthVp >= bp.min && widthVp < bp.max) {
        return bp.type;
      }
    }
    return BreakpointType.MD;
  }
}
