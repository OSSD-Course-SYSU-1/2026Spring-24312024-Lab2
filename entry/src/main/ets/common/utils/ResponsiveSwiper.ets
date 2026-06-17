/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.
 */

import { BreakpointSystem, BreakpointType } from './BreakpointSystem';

/**
 * 轮播项配置接口 - 数据驱动
 */
export interface SwiperItemConfig {
  id: string;
  title: string;
  subtitle: string;
  backgroundColor?: string;
  onClick?: () => void;
}

/**
 * 轮播显示数量配置接口
 */
export interface DisplayCountConfig {
  xs?: number;
  sm?: number;
  md?: number;
  lg?: number;
  xl?: number;
}

/**
 * 响应式轮播组件
 *
 * 根据断点自动调整显示数量：
 * - XS (<320vp): 1个, SM (320-599vp): 1个
 * - MD (600-839vp): 2个
 * - LG (840-1079vp): 3个, XL (>=1080vp): 4个
 */
@Component
export struct ResponsiveSwiper {
  private breakpointSystem: BreakpointSystem = BreakpointSystem.getInstance();

  private items: SwiperItemConfig[] = [];
  private autoPlay: boolean = false;
  private intervalValue: number = 3000;
  private indicatorVisible: boolean = true;
  private loopPlay: boolean = true;
  private verticalMode: boolean = false;
  private animDuration: number = 300;

  private displayCountConfig: DisplayCountConfig = {
    xs: 1,
    sm: 1,
    md: 2,
    lg: 3,
    xl: 4
  };

  @State currentDisplayCount: number = 1;
  private itemWidth: number | string = '100%';
  private itemHeight: number | string = 200;
  private itemSpacing: number = 8;
  private onIndexChange?: (index: number) => void;
  @State currentIndex: number = 0;

  aboutToAppear(): void {
    this.updateDisplayCount();
    this.breakpointSystem.addListener({
      onBreakpointChanged: (): void => {
        this.updateDisplayCount();
      }
    });
  }

  private updateDisplayCount(): void {
    const breakpoint: BreakpointType = this.breakpointSystem.getCurrentBreakpoint();
    switch (breakpoint) {
      case BreakpointType.XS:
        this.currentDisplayCount = this.displayCountConfig.xs ?? 1;
        break;
      case BreakpointType.SM:
        this.currentDisplayCount = this.displayCountConfig.sm ?? this.displayCountConfig.xs ?? 1;
        break;
      case BreakpointType.MD:
        this.currentDisplayCount = this.displayCountConfig.md ?? this.displayCountConfig.sm ?? this.displayCountConfig.xs ?? 2;
        break;
      case BreakpointType.LG:
        this.currentDisplayCount = this.displayCountConfig.lg ?? this.displayCountConfig.md ?? this.displayCountConfig.sm ?? this.displayCountConfig.xs ?? 3;
        break;
      case BreakpointType.XL:
        this.currentDisplayCount = this.displayCountConfig.xl ?? this.displayCountConfig.lg ?? this.displayCountConfig.md ?? this.displayCountConfig.sm ?? this.displayCountConfig.xs ?? 4;
        break;
      default:
        this.currentDisplayCount = 1;
    }
    if (this.currentDisplayCount < 1) {
      this.currentDisplayCount = 1;
    }
    const itemCount: number = this.items.length;
    if (this.currentDisplayCount > itemCount && itemCount > 0) {
      this.currentDisplayCount = itemCount;
    }
  }

  private handleIndexChange(index: number): void {
    this.currentIndex = index;
    if (this.onIndexChange) {
      this.onIndexChange(index);
    }
  }

  /**
   * 渲染单个轮播项
   */
  @Builder
  renderSwiperItem(item: SwiperItemConfig): void {
    Column() {
      Column() {
        Text(item.title)
          .fontSize(24)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 8 })
        Text(item.subtitle)
          .fontSize(16)
          .fontColor('#FFFFFF')
          .opacity(0.9)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(item.backgroundColor || '#FFFFFF')
      .borderRadius(12)
      .shadow({ radius: 8, color: '#1A000000', offsetX: 0, offsetY: 2 })
      .onClick((): void => {
        if (item.onClick) {
          item.onClick();
        }
      })
    }
    .width(this.itemWidth as string)
    .height(this.itemHeight as number)
    .margin({ right: this.itemSpacing })
  }

  build() {
    Column() {
      Swiper() {
        ForEach(this.items, (item: SwiperItemConfig) => {
          this.renderSwiperItem(item)
        }, (item: SwiperItemConfig): string => item.id)
      }
      .autoPlay(this.autoPlay)
      .interval(this.intervalValue)
      .indicator(false)
      .loop(this.loopPlay)
      .vertical(this.verticalMode)
      .duration(this.animDuration)
      .displayCount(this.currentDisplayCount)
      .itemSpace(this.itemSpacing)
      .onChange((index: number): void => {
        this.handleIndexChange(index);
      })
      .width('100%')
      .height(this.itemHeight as number)

      if (this.indicatorVisible && this.items.length > 1) {
        Row() {
          ForEach(this.items, (item: SwiperItemConfig, index: number): void => {
            Circle()
              .width(8)
              .height(8)
              .fill(index === this.currentIndex ? '#007DFF' : '#E5E5E5')
              .margin({ right: 4 })
              .onClick((): void => {
                this.handleIndexChange(index);
              })
          }, (item: SwiperItemConfig): string => item.id)
        }
        .width('100%')
        .height(20)
        .justifyContent(FlexAlign.Center)
        .margin({ top: 12 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
