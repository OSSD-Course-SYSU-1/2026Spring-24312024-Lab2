/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.
 *
 * 自由流转（跨端迁移）核心服务
 *
 * 封装了 HarmonyOS 分布式数据对象（distributedDataObject）的完整生命周期管理，
 * 实现应用在不同设备间的无缝迁移。
 *
 * 运作机制（三步骤）：
 *   Step A（源端）：onContinue 回调中创建分布式数据对象，
 *                  调用 genSessionId / setSessionId 激活，
 *                  调用 save() 持久化，将 dataSessionId 通过 wantParam 传递。
 *
 *   Step B（文件资产）：涉及图片、文档等文件时，
 *                      拷贝到分布式文件目录 context.distributedFilesDir，
 *                      构建 commonType.Asset 对象作为数据对象根属性。
 *
 *   Step C（对端）：onCreate/onNewWant 中创建空的分布式数据对象（属性全 undefined），
 *                  注册 on('status', ...) 监听 'restored' 事件，
 *                  从 want.parameters.dataSessionId 解析组网 ID，
 *                  调用 setSessionId 激活并加入组网，数据恢复后更新 AppStorage。
 *
 * 关键约束：
 *   - 分布式数据对象大小不超过 150KB（跨端迁移场景）
 *   - wantParam 中 "sessionId" 字段被系统占用，使用 "dataSessionId" 作为自定义 key
 *   - 对端恢复时属性必须置为 undefined，否则会覆盖源端数据
 *   - 必须在 setSessionId() 之后调用 save()（先激活再持久化）
 *   - 对端必须先注册 on('status') 监听，再调用 setSessionId()（防止错过 restored 事件）
 *   - 分布式数据对象必须使用类成员变量，防止异步回调时临时变量被释放
 *   - API 12+ 无需申请 ohos.permission.DISTRIBUTED_DATASYNC 权限
 *   - 迁移启动时走 onWindowStageRestore()，不走 onWindowStageCreate()
 */

import { distributedDataObject } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  ContinuationAppState,
  ContinuationStateModel,
  ContinuationTransferStatus,
  ContinuationResultCallback
} from './ContinuationStateModel';

const TAG: string = '[ContinuationService]';
const DOMAIN: number = 0x0000;

/**
 * 自由流转核心服务 - 单例模式
 */
export class ContinuationService {
  private static instance: ContinuationService | null = null;

  /** 分布式数据对象实例（必须为类成员变量，防止异步回调时被释放） */
  private distributedObject: distributedDataObject.DataObject | undefined = undefined;

  /** 当前迁移状态 */
  private transferStatus: ContinuationTransferStatus = ContinuationTransferStatus.IDLE;

  /** 分布式组网会话 ID */
  private sessionId: string = '';

  /** 目标设备 ID */
  private targetDeviceId: string = '';

  /** 错误信息 */
  private errorMessage: string = '';

  /** 源端迁移时间戳 */
  private continuationTimestamp: number = 0;

  /** 迁移结果回调 */
  private resultCallback: ContinuationResultCallback | null = null;

  /** 上下文引用（在 EntryAbility 中初始化） */
  private uiAbilityContext: common.UIAbilityContext | undefined = undefined;

  /** 是否已完成数据恢复（对端标识） */
  private isDataRestored: boolean = false;

  private constructor() {
    // 私有构造函数，单例模式
  }

  /**
   * 获取单例实例
   */
  public static getInstance(): ContinuationService {
    if (!ContinuationService.instance) {
      ContinuationService.instance = new ContinuationService();
    }
    return ContinuationService.instance;
  }

  /**
   * 初始化服务，设置 UIAbility 上下文
   * @param context UIAbility 上下文
   */
  public initialize(context: common.UIAbilityContext): void {
    this.uiAbilityContext = context;
    hilog.info(DOMAIN, TAG, 'ContinuationService initialized with UIAbility context');
  }

  /**
   * 获取当前迁移状态
   */
  public getStatus(): ContinuationTransferStatus {
    return this.transferStatus;
  }

  /**
   * 获取错误信息
   */
  public getErrorMessage(): string {
    return this.errorMessage;
  }

  /**
   * 数据是否已恢复
   */
  public isRestored(): boolean {
    return this.isDataRestored;
  }

  // ==================== Step A：源端保存迁移数据 ====================

  /**
   * 步骤 A：源端保存状态数据（在 EntryAbility.onContinue 中调用）
   *
   * 执行流程：
   * 1. 收集当前应用状态（从 AppStorage 或直接传入）
   * 2. 创建分布式数据对象 distributedDataObject.create(context, source)
   * 3. 生成组网 ID：distributedDataObject.genSessionId()
   * 4. 激活数据对象：dataObject.setSessionId(sessionId)
   * 5. 将 dataSessionId 存入 wantParam 传递给对端
   * 6. 持久化保存：await dataObject.save(targetDeviceId)
   *
   * @param wantParam onContinue 传入的 wantParam 参数（会被修改以携带迁移数据）
   * @param state 要迁移的应用状态数据
   * @param callback 迁移结果回调
   */
  public async saveStateForContinuation(
    wantParam: Record<string, Object>,
    state: ContinuationAppState,
    callback: ContinuationResultCallback
  ): Promise<void> {
    if (!this.uiAbilityContext) {
      const errorMsg = 'ContinuationService not initialized: UIAbility context is undefined';
      hilog.error(DOMAIN, TAG, errorMsg);
      callback.onError(errorMsg);
      throw new Error(errorMsg);
    }

    this.transferStatus = ContinuationTransferStatus.SAVING;
    this.resultCallback = callback;
    this.errorMessage = '';

    try {
      // 设置迁移时间戳和源设备信息
      state.continuationTimestamp = Date.now();

      // 从 wantParam 获取目标设备 networkId
      const targetDevice = wantParam['targetDevice'] as string;
      this.targetDeviceId = targetDevice || '';

      hilog.info(DOMAIN, TAG,
        `onContinue - targetDevice: ${targetDevice}, ` +
        `state: tabIndex=${state.selectedTabIndex}, path=${state.currentFilePath}`);

      // A.1 - 创建分布式数据对象
      this.distributedObject = distributedDataObject.create(
        this.uiAbilityContext,
        state
      );
      hilog.info(DOMAIN, TAG, 'Distributed data object created');

      // A.2 - 生成组网 ID 并激活
      this.sessionId = distributedDataObject.genSessionId();
      hilog.info(DOMAIN, TAG, `Generated sessionId: ${this.sessionId}`);

      // 注意：wantParam 中 "sessionId" 被系统占用，使用 "dataSessionId"
      wantParam['dataSessionId'] = this.sessionId;
      this.distributedObject.setSessionId(this.sessionId);
      hilog.info(DOMAIN, TAG, `SessionId set, distributed object activated`);

      // A.3 - 持久化保存数据到对端设备
      // 使用 await 确保 save 完成后再退出，防止数据丢失
      if (this.targetDeviceId) {
        await this.distributedObject.save(this.targetDeviceId);
        hilog.info(DOMAIN, TAG,
          `Data saved to target device: ${this.targetDeviceId}`);
      } else {
        hilog.warn(DOMAIN, TAG,
          'targetDevice is empty, saving to local as fallback');
        await this.distributedObject.save('local');
      }

      this.transferStatus = ContinuationTransferStatus.SAVED;
      this.continuationTimestamp = state.continuationTimestamp || Date.now();
      callback.onSuccess();

    } catch (error) {
      const err = error as BusinessError;
      this.transferStatus = ContinuationTransferStatus.ERROR;
      this.errorMessage = `Failed to save state: ${err.message || 'Unknown error'}`;
      hilog.error(DOMAIN, TAG, `Save state failed: ${this.errorMessage}`);
      callback.onError(this.errorMessage);
      // 不重新抛出，避免影响 onContinue 流程
    }
  }

  // ==================== Step C：对端恢复迁移数据 ====================

  /**
   * 步骤 C：对端恢复状态数据（在 EntryAbility.onCreate / onNewWant 中调用）
   *
   * 执行流程：
   * 1. 检查 launchReason 是否为 CONTINUATION
   * 2. 创建空的分布式数据对象（属性全 undefined）
   * 3. 注册 on('status', ...) 监听 'restored' 事件
   * 4. 从 want.parameters 中读取 dataSessionId
   * 5. 调用 setSessionId(dataSessionId) 加入组网
   * 6. 收到 'restored' 状态后，从数据对象读取数据并更新 AppStorage
   *
   * @param context UIAbility 上下文
   * @param want 启动 want 参数
   * @param callback 迁移结果回调
   */
  public restoreStateFromContinuation(
    context: common.UIAbilityContext,
    want: Record<string, Object>,
    callback: ContinuationResultCallback
  ): void {
    // C.0 - 初始化上下文
    this.uiAbilityContext = context;
    this.transferStatus = ContinuationTransferStatus.RESTORING;
    this.resultCallback = callback;
    this.errorMessage = '';
    this.isDataRestored = false;

    try {
      // 从 want.parameters 中读取组网 ID
      const parameters = want['parameters'] as Record<string, Object> | undefined;
      if (!parameters) {
        const errorMsg = 'Missing want.parameters in continuation request';
        hilog.error(DOMAIN, TAG, errorMsg);
        this.transferStatus = ContinuationTransferStatus.ERROR;
        this.errorMessage = errorMsg;
        callback.onError(errorMsg);
        return;
      }

      const dataSessionId = parameters['dataSessionId'] as string | undefined;
      if (!dataSessionId) {
        const errorMsg = 'Missing dataSessionId in continuation parameters';
        hilog.error(DOMAIN, TAG, errorMsg);
        this.transferStatus = ContinuationTransferStatus.ERROR;
        this.errorMessage = errorMsg;
        callback.onError(errorMsg);
        return;
      }

      this.sessionId = dataSessionId;
      hilog.info(DOMAIN, TAG, `Restoring from sessionId: ${dataSessionId}`);

      // C.1 - 创建空的分布式数据对象（属性全 undefined，防止数据覆盖）
      const emptyState = ContinuationStateModel.createEmptyState();
      this.distributedObject = distributedDataObject.create(this.uiAbilityContext, emptyState);
      hilog.info(DOMAIN, TAG, 'Empty distributed data object created for restoration');

      // C.2 - 注册状态监听（必须在 setSessionId 之前注册，防止错过 restored 事件）
      this.distributedObject.on('status',
        (sessionId: string, networkId: string, status: string) => {
          hilog.info(DOMAIN, TAG,
            `Status changed - sessionId: ${sessionId}, ` +
            `networkId: ${networkId}, status: ${status}`);

          if (status === 'restored') {
            this.handleDataRestored(callback);
          }
        }
      );

      // C.3 - 激活分布式数据对象并加入组网
      this.distributedObject.setSessionId(dataSessionId);
      hilog.info(DOMAIN, TAG, `Joined session with id: ${dataSessionId}`);

    } catch (error) {
      const err = error as BusinessError;
      this.transferStatus = ContinuationTransferStatus.ERROR;
      this.errorMessage = `Failed to restore state: ${err.message || 'Unknown error'}`;
      hilog.error(DOMAIN, TAG, `Restore state failed: ${this.errorMessage}`);
      callback.onError(this.errorMessage);
    }
  }

  /**
   * 处理数据恢复完成事件
   */
  private handleDataRestored(callback: ContinuationResultCallback): void {
    if (!this.distributedObject) {
      const errorMsg = 'Distributed object is null during restore';
      hilog.error(DOMAIN, TAG, errorMsg);
      this.transferStatus = ContinuationTransferStatus.ERROR;
      this.errorMessage = errorMsg;
      callback.onError(errorMsg);
      return;
    }

    hilog.info(DOMAIN, TAG, 'Data restored event received, reading from distributed object...');

    try {
      // 读取恢复的数据
      const selectedTabIndex = this.distributedObject['selectedTabIndex'] as number | undefined;
      const currentFilePath = this.distributedObject['currentFilePath'] as string | undefined;
      const isMultiSelectMode = this.distributedObject['isMultiSelectMode'] as boolean | undefined;
      const currentBreakpoint = this.distributedObject['currentBreakpoint'] as string | undefined;
      const windowWidth = this.distributedObject['windowWidth'] as number | undefined;
      const continuationTimestamp = this.distributedObject['continuationTimestamp'] as number | undefined;

      hilog.info(DOMAIN, TAG,
        `Restored data - tabIndex: ${selectedTabIndex}, ` +
        `path: ${currentFilePath}, multiSelect: ${isMultiSelectMode}, ` +
        `breakpoint: ${currentBreakpoint}, width: ${windowWidth}`);

      // 将恢复的数据写入 AppStorage，供页面组件使用
      if (selectedTabIndex !== undefined) {
        AppStorage.setOrCreate('selectedTabIndex', selectedTabIndex);
        AppStorage.setOrCreate('continuationRestoredTabIndex', selectedTabIndex);
      }

      if (currentFilePath !== undefined && currentFilePath !== '') {
        AppStorage.setOrCreate('currentFilePath', currentFilePath);
        AppStorage.setOrCreate('continuationRestoredFilePath', currentFilePath);
      }

      if (isMultiSelectMode !== undefined) {
        AppStorage.setOrCreate('isMultiSelectMode', isMultiSelectMode);
      }

      if (currentBreakpoint !== undefined) {
        AppStorage.setOrCreate('currentBreakpoint', currentBreakpoint);
      }

      if (windowWidth !== undefined) {
        AppStorage.setOrCreate('windowWidth', windowWidth);
      }

      if (continuationTimestamp !== undefined) {
        AppStorage.setOrCreate('continuationTimestamp', continuationTimestamp);
      }

      // 设置已接续标记
      AppStorage.setOrCreate('isContinuationRestored', true);

      this.transferStatus = ContinuationTransferStatus.RESTORED;
      this.isDataRestored = true;
      this.continuationTimestamp = continuationTimestamp || Date.now();

      if (callback.onRestored) {
        callback.onRestored();
      }
      callback.onSuccess();

    } catch (error) {
      const err = error as BusinessError;
      this.transferStatus = ContinuationTransferStatus.ERROR;
      this.errorMessage = `Failed to read restored data: ${err.message || 'Unknown error'}`;
      hilog.error(DOMAIN, TAG, `Read restored data failed: ${this.errorMessage}`);
      callback.onError(this.errorMessage);
    }
  }

  // ==================== 辅助方法 ====================

  /**
   * 获取恢复后的迁移状态数据（供页面读取）
   */
  public getRestoredState(): ContinuationAppState | null {
    if (!this.isDataRestored) {
      return null;
    }

    return new ContinuationAppState(
      AppStorage.get<number>('selectedTabIndex') || 0,
      AppStorage.get<string>('currentFilePath') || '',
      AppStorage.get<boolean>('isMultiSelectMode') || false,
      AppStorage.get<string>('currentBreakpoint') || '',
      AppStorage.get<number>('windowWidth') || 0,
      this.continuationTimestamp,
      'Restored Device'
    );
  }

  /**
   * 重置服务状态
   */
  public reset(): void {
    this.transferStatus = ContinuationTransferStatus.IDLE;
    this.distributedObject = undefined;
    this.sessionId = '';
    this.targetDeviceId = '';
    this.errorMessage = '';
    this.resultCallback = null;
    this.isDataRestored = false;
    this.continuationTimestamp = 0;

    // 清除 AppStorage 中的迁移标记
    AppStorage.setOrCreate('isContinuationRestored', false);
    hilog.info(DOMAIN, TAG, 'ContinuationService reset');
  }

  /**
   * 销毁服务（释放资源）
   */
  public destroy(): void {
    this.reset();
    this.uiAbilityContext = undefined;
    ContinuationService.instance = null;
    hilog.info(DOMAIN, TAG, 'ContinuationService destroyed');
  }
}
