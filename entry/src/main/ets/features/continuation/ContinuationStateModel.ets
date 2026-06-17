/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.
 *
 * 自由流转（跨端迁移）状态数据模型
 *
 * 该模型定义了跨设备迁移时需要同步的应用状态数据。
 * 支持基本类型（string, number, boolean）和对象类型的迁移。
 *
 * 关键约束：
 * - 分布式数据对象大小不超过 150KB（跨端迁移场景）
 * - 仅支持根属性修改，不支持下级属性修改
 * - 对端恢复时必须将属性置为 undefined，否则会覆盖源端数据
 */

/**
 * 应用页面状态数据类
 * 用于跨端迁移时保存和恢复应用的当前页面状态
 */
export class ContinuationAppState {
  /** 当前选中的标签页索引（0=文件, 1=预览, 2=设置） */
  selectedTabIndex: number | undefined;

  /** 文件管理器中当前浏览的目录路径 */
  currentFilePath: string | undefined;

  /** 是否处于多选模式 */
  isMultiSelectMode: boolean | undefined;

  /** 当前设备断点类型（用于UI自适应恢复） */
  currentBreakpoint: string | undefined;

  /** 窗口宽度（虚拟像素） */
  windowWidth: number | undefined;

  /** 迁移时间戳 */
  continuationTimestamp: number | undefined;

  /** 源设备名称 */
  sourceDeviceName: string | undefined;

  constructor(
    selectedTabIndex: number | undefined,
    currentFilePath: string | undefined,
    isMultiSelectMode: boolean | undefined,
    currentBreakpoint: string | undefined,
    windowWidth: number | undefined,
    continuationTimestamp: number | undefined,
    sourceDeviceName: string | undefined
  ) {
    this.selectedTabIndex = selectedTabIndex;
    this.currentFilePath = currentFilePath;
    this.isMultiSelectMode = isMultiSelectMode;
    this.currentBreakpoint = currentBreakpoint;
    this.windowWidth = windowWidth;
    this.continuationTimestamp = continuationTimestamp;
    this.sourceDeviceName = sourceDeviceName;
  }
}

/**
 * 迁移状态枚举
 */
export enum ContinuationTransferStatus {
  /** 空闲 */
  IDLE = 'idle',
  /** 正在保存状态 */
  SAVING = 'saving',
  /** 已保存，等待对端恢复 */
  SAVED = 'saved',
  /** 正在恢复状态 */
  RESTORING = 'restoring',
  /** 已恢复 */
  RESTORED = 'restored',
  /** 迁移失败 */
  ERROR = 'error'
}

/**
 * 迁移结果回调接口
 */
export interface ContinuationResultCallback {
  /** 迁移成功回调 */
  onSuccess: () => void;
  /** 迁移失败回调 */
  onError: (errorMessage: string) => void;
  /** 状态恢复完成回调（对端设备触发） */
  onRestored?: () => void;
}

/**
 * 迁移数据模型工具类
 * 提供序列化/反序列化辅助方法
 */
export class ContinuationStateModel {
  /**
   * 创建空的迁移状态对象（对端恢复时使用，所有属性必须为 undefined）
   */
  public static createEmptyState(): ContinuationAppState {
    return new ContinuationAppState(
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      undefined
    );
  }

  /**
   * 创建带数据的迁移状态对象（源端保存时使用）
   */
  public static createState(
    selectedTabIndex: number,
    currentFilePath: string,
    isMultiSelectMode: boolean,
    currentBreakpoint: string,
    windowWidth: number,
    sourceDeviceName: string
  ): ContinuationAppState {
    return new ContinuationAppState(
      selectedTabIndex,
      currentFilePath,
      isMultiSelectMode,
      currentBreakpoint,
      windowWidth,
      Date.now(),
      sourceDeviceName
    );
  }

  /**
   * 验证迁移状态数据是否有效（已恢复）
   */
  public static isValidRestored(state: ContinuationAppState): boolean {
    return state.selectedTabIndex !== undefined &&
      state.continuationTimestamp !== undefined;
  }

  /**
   * 从 AppStorage 收集当前应用状态
   */
  public static collectFromAppStorage(): ContinuationAppState {
    let tabIndex: number = 0;
    let filePath: string = '';
    let multiSelect: boolean = false;
    let breakpoint: string = 'md';
    let width: number = 0;

    try {
      const storedTab = AppStorage.get<number>('selectedTabIndex');
      if (storedTab !== undefined && storedTab !== null) {
        tabIndex = storedTab;
      }
    } catch (_e) {
      // 忽略读取错误
    }

    try {
      const storedPath = AppStorage.get<string>('currentFilePath');
      if (storedPath !== undefined && storedPath !== null) {
        filePath = storedPath;
      }
    } catch (_e) {
      // 忽略读取错误
    }

    try {
      const storedMulti = AppStorage.get<boolean>('isMultiSelectMode');
      if (storedMulti !== undefined && storedMulti !== null) {
        multiSelect = storedMulti;
      }
    } catch (_e) {
      // 忽略读取错误
    }

    try {
      const storedBp = AppStorage.get<string>('currentBreakpoint');
      if (storedBp !== undefined && storedBp !== null) {
        breakpoint = storedBp;
      }
    } catch (_e) {
      // 忽略读取错误
    }

    try {
      const storedWidth = AppStorage.get<number>('windowWidth');
      if (storedWidth !== undefined && storedWidth !== null) {
        width = storedWidth;
      }
    } catch (_e) {
      // 忽略读取错误
    }

    return ContinuationStateModel.createState(
      tabIndex,
      filePath,
      multiSelect,
      breakpoint,
      width,
      'Unknown Device'
    );
  }
}
