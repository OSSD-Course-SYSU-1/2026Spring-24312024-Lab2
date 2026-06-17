/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.
 */

import { BreakpointSystem, BreakpointType } from './BreakpointSystem';
import { ResponsiveUtils } from './GridLayout';

/**
 * 标签页配置接口
 */
export interface TabConfig {
  value: string;           // 标签值
  name: string;           // 标签名称
  icon?: string;          // 图标（可选）
  badge?: number;         // 徽章数字（可选）
  disabled?: boolean;     // 是否禁用（可选）
}

/**
 * 响应式标签页组件属性
 */
export interface ResponsiveTabsProps {
  tabs: TabConfig[];                    // 标签页配置数组
  selectedIndex?: number;               // 选中的标签索引
  onTabChange?: (index: number) => void; // 标签切换回调
  barWidth?: number | string;           // 标签栏宽度
  barHeight?: number | string;          // 标签栏高度
  vertical?: boolean;                   // 是否垂直显示（大屏时自动启用）
  position?: 'start' | 'center' | 'end'; // 标签对齐方式
  children?: any;                       // 标签内容
}

/**
 * 响应式标签页组件
 * 小屏（XS/SM: <600vp）：底部横向标签
 * 中屏（MD: 600-839vp）：顶部横向标签
 * 大屏（LG/XL: >=840vp）：左侧纵向标签
 */
@Component
export struct ResponsiveTabs {
  // 断点系统实例
  private breakpointSystem: BreakpointSystem = BreakpointSystem.getInstance();
  
  // 标签页配置
  private tabs: TabConfig[] = [];
  
  // 当前选中的标签索引
  @State private selectedIndex: number = 0;
  
  // 标签切换回调
  private onTabChange?: (index: number) => void;
  
  // 标签栏宽度
  private barWidth: number | string = '100%';
  
  // 标签栏高度
  private barHeight: number | string = 48;
  
  // 是否垂直显示
  @State private isVertical: boolean = false;
  
  // 标签对齐方式
  private position: 'start' | 'center' | 'end' = 'start';
  
  // 标签内容
  private children: any = null;
  
  /**
   * 构造函数
   */
  constructor(params: ResponsiveTabsProps) {
    this.tabs = params.tabs;
    
    if (params.selectedIndex !== undefined) {
      this.selectedIndex = params.selectedIndex;
    }
    
    if (params.onTabChange !== undefined) {
      this.onTabChange = params.onTabChange;
    }
    
    if (params.barWidth !== undefined) {
      this.barWidth = params.barWidth;
    }
    
    if (params.barHeight !== undefined) {
      this.barHeight = params.barHeight;
    }
    
    // 根据断点决定是否垂直显示
    if (params.vertical !== undefined) {
      this.isVertical = params.vertical;
    } else {
      // 大屏设备默认垂直显示
      this.isVertical = this.breakpointSystem.isLargeScreen();
    }
    
    if (params.position !== undefined) {
      this.position = params.position;
    }
    
    if (params.children !== undefined) {
      this.children = params.children;
    }
  }
  
  /**
   * 设置选中的标签索引
   */
  setSelectedIndex(index: number): ResponsiveTabs {
    if (index >= 0 && index < this.tabs.length) {
      this.selectedIndex = index;
    }
    return this;
  }
  
  /**
   * 设置标签切换回调
   */
  setOnTabChange(callback: (index: number) => void): ResponsiveTabs {
    this.onTabChange = callback;
    return this;
  }
  
  /**
   * 设置标签栏宽度
   */
  setBarWidth(width: number | string): ResponsiveTabs {
    this.barWidth = width;
    return this;
  }
  
  /**
   * 设置标签栏高度
   */
  setBarHeight(height: number | string): ResponsiveTabs {
    this.barHeight = height;
    return this;
  }
  
  /**
   * 设置垂直显示
   */
  setVertical(vertical: boolean): ResponsiveTabs {
    this.isVertical = vertical;
    return this;
  }
  
  /**
   * 设置标签对齐方式
   */
  setPosition(position: 'start' | 'center' | 'end'): ResponsiveTabs {
    this.position = position;
    return this;
  }
  
  /**
   * 设置标签内容
   */
  setChildren(children: any): ResponsiveTabs {
    this.children = children;
    return this;
  }
  
  /**
   * 处理标签点击
   */
  private handleTabClick(index: number): void {
    if (index === this.selectedIndex) {
      return;
    }
    
    if (this.tabs[index].disabled) {
      return;
    }
    
    this.selectedIndex = index;
    
    if (this.onTabChange) {
      this.onTabChange(index);
    }
  }
  
  /**
   * 根据断点获取标签栏方向
   */
  private updateOrientation(): void {
    // 大屏设备使用垂直标签，小屏设备使用水平标签
    this.isVertical = this.breakpointSystem.isLargeScreen();
  }
  
  /**
   * 渲染标签项
   */
  @Builder
  private renderTabItem(tab: TabConfig, index: number) {
    const isSelected = index === this.selectedIndex;
    const isDisabled = tab.disabled === true;
    
    Column() {
      // 图标
      if (tab.icon) {
        Text(tab.icon)
          .fontSize(20)
          .fontColor(isSelected ? '#007DFF' : (isDisabled ? '#CCCCCC' : '#666666'))
          .margin({ bottom: 4 })
      }
      
      // 标签名称
      Text(tab.name)
        .fontSize(14)
        .fontColor(isSelected ? '#007DFF' : (isDisabled ? '#CCCCCC' : '#333333'))
        .fontWeight(isSelected ? FontWeight.Medium : FontWeight.Normal)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      
      // 徽章
      if (tab.badge !== undefined && tab.badge > 0) {
        Text(tab.badge.toString())
          .fontSize(10)
          .fontColor('#FFFFFF')
          .backgroundColor('#FA5151')
          .padding({ left: 4, right: 4, top: 2, bottom: 2 })
          .borderRadius(10)
          .position({ x: '80%', y: -8 })
          .zIndex(1)
      }
    }
    .width(this.isVertical ? '100%' : 80)
    .height(this.isVertical ? 60 : '100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(isSelected ? (this.isVertical ? '#F0F8FF' : '#FFFFFF') : '#FFFFFF')
    .borderRadius(8)
    .opacity(isDisabled ? 0.5 : 1)
    .onClick(() => {
      if (!isDisabled) {
        this.handleTabClick(index);
      }
    })
  }
  
  /**
   * 渲染水平标签栏
   */
  @Builder
  private renderHorizontalTabs() {
    Row() {
      ForEach(this.tabs, (tab: TabConfig, index: number) => {
        this.renderTabItem(tab, index);
      }, (tab: TabConfig) => tab.value)
    }
    .width(this.barWidth)
    .height(this.barHeight)
    .justifyContent(this.getJustifyContent())
    .padding({ left: 12, right: 12 })
    .backgroundColor('#F8F8F8')
    .borderRadius(12)
  }
  
  /**
   * 渲染垂直标签栏
   */
  @Builder
  private renderVerticalTabs() {
    Column() {
      ForEach(this.tabs, (tab: TabConfig, index: number) => {
        this.renderTabItem(tab, index);
      }, (tab: TabConfig) => tab.value)
    }
    .width(this.barWidth)
    .height(this.barHeight)
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 12, bottom: 12 })
    .backgroundColor('#F8F8F8')
    .borderRadius(12)
  }
  
  /**
   * 获取对齐方式对应的JustifyContent
   */
  private getJustifyContent(): FlexAlign {
    switch (this.position) {
      case 'start':
        return FlexAlign.Start;
      case 'center':
        return FlexAlign.Center;
      case 'end':
        return FlexAlign.End;
      default:
        return FlexAlign.Start;
    }
  }
  
  aboutToAppear() {
    // 监听断点变化
    this.breakpointSystem.addListener({
      onBreakpointChanged: () => {
        this.updateOrientation();
      }
    });
  }
  
  build() {
    Column() {
      if (this.isVertical) {
        // 垂直布局：标签栏在左侧，内容在右侧
        Row() {
          // 左侧标签栏
          this.renderVerticalTabs()
            .width(100)
            .height('100%')
            .margin({ right: 12 })
          
          // 右侧内容区域
          Column() {
            if (this.children) {
              this.children();
            }
          }
          .layoutWeight(1)
          .height('100%')
        }
        .width('100%')
        .height('100%')
      } else {
        // 水平布局：标签栏在上方，内容在下方
        Column() {
          // 上方标签栏
          this.renderHorizontalTabs()
            .width('100%')
            .margin({ bottom: 12 })
          
          // 下方内容区域
          Column() {
            if (this.children) {
              this.children();
            }
          }
          .layoutWeight(1)
          .width('100%')
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}

/**
 * 响应式标签页工具函数
 */
export class ResponsiveTabsUtils {
  private static breakpointSystem = BreakpointSystem.getInstance();
  
  /**
   * 获取标签栏推荐高度
   */
  static getRecommendedBarHeight(): number {
    if (this.breakpointSystem.isSmallScreen()) {
      return 56; // 小屏设备：底部标签栏高度
    } else if (this.breakpointSystem.isMediumScreen()) {
      return 48; // 中屏设备：顶部标签栏高度
    } else {
      return 60; // 大屏设备：侧边标签栏高度
    }
  }
  
  /**
   * 获取标签栏推荐宽度
   */
  static getRecommendedBarWidth(): string | number {
    if (this.breakpointSystem.isLargeScreen()) {
      return 100; // 大屏设备：侧边标签栏宽度
    } else {
      return '100%'; // 小/中屏设备：全宽
    }
  }
  
  /**
   * 获取标签图标大小
   */
  static getTabIconSize(): number {
    if (this.breakpointSystem.isSmallScreen()) {
      return 20; // 小屏设备：较小的图标
    } else if (this.breakpointSystem.isMediumScreen()) {
      return 22; // 中屏设备：中等图标
    } else {
      return 24; // 大屏设备：较大的图标
    }
  }
  
  /**
   * 获取标签字体大小
   */
  static getTabFontSize(): number {
    if (this.breakpointSystem.isSmallScreen()) {
      return 12; // 小屏设备：较小的字体
    } else if (this.breakpointSystem.isMediumScreen()) {
      return 14; // 中屏设备：中等字体
    } else {
      return 16; // 大屏设备：较大的字体
    }
  }
  
  /**
   * 判断是否应该显示标签图标
   */
  static shouldShowTabIcon(): boolean {
    // 小屏设备优先显示图标，大屏设备图标和文字都显示
    return true;
  }
  
  /**
   * 判断是否应该显示标签文字
   */
  static shouldShowTabText(): boolean {
    // 所有设备都显示文字
    return true;
  }
}