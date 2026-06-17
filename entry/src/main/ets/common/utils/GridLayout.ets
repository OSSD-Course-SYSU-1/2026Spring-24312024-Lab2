/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.
 */

import { BreakpointSystem, BreakpointType } from './BreakpointSystem';

/**
 * 栅格列配置接口
 */
export interface GridColumnConfig {
  xs?: number;
  sm?: number;
  md?: number;
  lg?: number;
  xl?: number;
}

/**
 * 栅格偏移配置接口
 */
export interface GridOffsetConfig {
  xs?: number;
  sm?: number;
  md?: number;
  lg?: number;
  xl?: number;
}

/**
 * 栅格布局组件 - 封装HarmonyOS GridRow
 */
@Component
export struct GridLayout {
  private breakpointSystem: BreakpointSystem = BreakpointSystem.getInstance();
  private columns: number = 12;
  private gutter: number | string = 0;

  @BuilderParam
  content: () => void = () => {};

  build() {
    GridRow({
      columns: this.columns,
      gutter: this.gutter as number
    }) {
      this.content()
    }
  }
}

/**
 * 响应式栅格列组件 - 封装HarmonyOS GridCol
 * 注意：避免使用GridCol作为struct名称（与系统GridCol冲突），使用ResponsiveGridCol
 */
@Component
export struct ResponsiveGridCol {
  private breakpointSystem: BreakpointSystem = BreakpointSystem.getInstance();

  private spanConfig: GridColumnConfig = {};
  private offsetConfig: GridOffsetConfig = {};

  @State private currentSpan: number = 12;
  @State private currentOffset: number = 0;

  @BuilderParam
  content: () => void = () => {};

  aboutToAppear(): void {
    this.updateForCurrentBreakpoint();
    this.breakpointSystem.addListener({
      onBreakpointChanged: (): void => {
        this.updateForCurrentBreakpoint();
      }
    });
  }

  private updateForCurrentBreakpoint(): void {
    const breakpoint: BreakpointType = this.breakpointSystem.getCurrentBreakpoint();
    switch (breakpoint) {
      case BreakpointType.XS:
        this.currentSpan = this.spanConfig.xs ?? 12;
        this.currentOffset = this.offsetConfig.xs ?? 0;
        break;
      case BreakpointType.SM:
        this.currentSpan = this.spanConfig.sm ?? this.spanConfig.xs ?? 12;
        this.currentOffset = this.offsetConfig.sm ?? this.offsetConfig.xs ?? 0;
        break;
      case BreakpointType.MD:
        this.currentSpan = this.spanConfig.md ?? this.spanConfig.sm ?? this.spanConfig.xs ?? 12;
        this.currentOffset = this.offsetConfig.md ?? this.offsetConfig.sm ?? this.offsetConfig.xs ?? 0;
        break;
      case BreakpointType.LG:
        this.currentSpan = this.spanConfig.lg ?? this.spanConfig.md ?? this.spanConfig.sm ?? this.spanConfig.xs ?? 12;
        this.currentOffset = this.offsetConfig.lg ?? this.offsetConfig.md ?? this.offsetConfig.sm ?? this.offsetConfig.xs ?? 0;
        break;
      case BreakpointType.XL:
        this.currentSpan = this.spanConfig.xl ?? this.spanConfig.lg ?? this.spanConfig.md ?? this.spanConfig.sm ?? this.spanConfig.xs ?? 12;
        this.currentOffset = this.offsetConfig.xl ?? this.offsetConfig.lg ?? this.offsetConfig.md ?? this.offsetConfig.sm ?? this.offsetConfig.xs ?? 0;
        break;
      default:
        this.currentSpan = 12;
        this.currentOffset = 0;
    }
  }

  build() {
    GridCol({
      span: this.currentSpan,
      offset: this.currentOffset
    }) {
      this.content()
    }
  }
}

/**
 * 响应式值配置接口
 */
export interface ResponsiveValue<T> {
  xs?: T;
  sm?: T;
  md?: T;
  lg?: T;
  xl?: T;
  default: T;
}

/**
 * 响应式布局工具函数
 */
export class ResponsiveUtils {
  private static breakpointSystem: BreakpointSystem = BreakpointSystem.getInstance();

  static getValueByBreakpoint<T>(values: ResponsiveValue<T>): T {
    const breakpoint: BreakpointType = ResponsiveUtils.breakpointSystem.getCurrentBreakpoint();
    switch (breakpoint) {
      case BreakpointType.XS:
        return values.xs ?? values.default;
      case BreakpointType.SM:
        return values.sm ?? values.xs ?? values.default;
      case BreakpointType.MD:
        return values.md ?? values.sm ?? values.xs ?? values.default;
      case BreakpointType.LG:
        return values.lg ?? values.md ?? values.sm ?? values.xs ?? values.default;
      case BreakpointType.XL:
        return values.xl ?? values.lg ?? values.md ?? values.sm ?? values.xs ?? values.default;
      default:
        return values.default;
    }
  }

  static isSmallScreen(): boolean {
    return ResponsiveUtils.breakpointSystem.isSmallScreen();
  }

  static isMediumScreen(): boolean {
    return ResponsiveUtils.breakpointSystem.isMediumScreen();
  }

  static isLargeScreen(): boolean {
    return ResponsiveUtils.breakpointSystem.isLargeScreen();
  }

  static getCurrentBreakpoint(): BreakpointType {
    return ResponsiveUtils.breakpointSystem.getCurrentBreakpoint();
  }

  static getGridColumns(): number {
    return ResponsiveUtils.breakpointSystem.getGridColumns();
  }
}

// 保留GridCol别名以兼容旧代码
export { ResponsiveGridCol as GridCol };
