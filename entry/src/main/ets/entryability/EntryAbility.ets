/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.
 *
 * EntryAbility - 应用入口 UIAbility
 *
 * 已集成自由流转（跨端迁移 / 应用接续）功能：
 *   - onContinue(): 源端设备保存迁移数据
 *   - onCreate(): 对端冷启动时恢复迁移数据
 *   - onNewWant(): 对端热启动时恢复迁移数据
 *   - onWindowStageRestore(): 迁移场景下的窗口恢复
 *
 * 关键注意事项：
 *   1. 迁移启动时不触发 onWindowStageCreate()，而是触发 onWindowStageRestore()
 *   2. 在 onWindowStageCreate() 中的初始化逻辑需同步到 onWindowStageRestore()
 *   3. API 12+ 无需申请 ohos.permission.DISTRIBUTED_DATASYNC 权限
 *   4. 默认迁移状态为 ACTIVE，可在特定页面通过 setMissionContinueState 控制
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { Want, UIAbility, AbilityConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { ContinuationService } from '../features/continuation/ContinuationService';
import {
  ContinuationStateModel,
  ContinuationAppState
} from '../features/continuation/ContinuationStateModel';
import { promptAction } from '@kit.ArkUI';

const TAG: string = '[EntryAbility]';
const DOMAIN: number = 0x0000;

export default class EntryAbility extends UIAbility {
  private storage: LocalStorage = new LocalStorage();
  private continuationService: ContinuationService = ContinuationService.getInstance();

  /**
   * UIAbility 冷启动回调
   * 当应用首次启动或从被销毁状态重新创建时触发
   *
   * 如果启动原因为 CONTINUATION（跨端迁移），
   * 则从 want.parameters 中恢复迁移数据
   */
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG,
      `Ability onCreate, launchReason: ${launchParam.launchReason}`);

    // 初始化 ContinuationService
    this.continuationService.initialize(this.context);

    // 检查是否为跨端迁移启动
    if (launchParam.launchReason === AbilityConstant.LaunchReason.CONTINUATION) {
      hilog.info(DOMAIN, TAG, 'Launched from CONTINUATION, restoring state...');

      // 确保迁移后应用仍可被再次迁移
      this.context.setMissionContinueState(
        AbilityConstant.ContinueState.ACTIVE,
        (result) => {
          hilog.info(DOMAIN, TAG,
            `setMissionContinueState ACTIVE: ${JSON.stringify(result)}`);
        }
      );

      // 恢复迁移数据
      this.restoreContinuationData(want);
    }
  }

  /**
   * UIAbility 热启动回调
   * 当应用已在后台运行，再次被拉起时触发（单实例模式）
   */
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG,
      `Ability onNewWant, launchReason: ${launchParam.launchReason}`);

    if (launchParam.launchReason === AbilityConstant.LaunchReason.CONTINUATION) {
      hilog.info(DOMAIN, TAG, 'Hot start from CONTINUATION, restoring state...');

      // 确保迁移后应用仍可被再次迁移
      this.context.setMissionContinueState(
        AbilityConstant.ContinueState.ACTIVE,
        (result) => {
          hilog.info(DOMAIN, TAG,
            `setMissionContinueState ACTIVE: ${JSON.stringify(result)}`);
        }
      );

      // 恢复迁移数据
      this.restoreContinuationData(want);

      // 触发窗口恢复
      this.context.restoreWindowStage(this.storage);
    }
  }

  /**
   * 跨端迁移 - 源端保存状态数据
   *
   * 当用户触发流转（如点击对端设备 Dock 栏图标）时，
   * 系统回调此方法，开发者在此保存需要迁移的数据。
   *
   * @param wantParam 系统传入的迁移参数（包含 version, targetDevice 等）
   * @returns AGREE(同意) / REJECT(拒绝) / MISMATCH(版本不匹配)
   */
  onContinue(wantParam: Record<string, Object>): AbilityConstant.OnContinueResult {
    hilog.info(DOMAIN, TAG,
      `onContinue - version: ${wantParam['version']}, ` +
      `targetDevice: ${wantParam['targetDevice']}`);

    try {
      // 【可选】版本兼容性检测
      const targetVersion = wantParam['version'] as number | undefined;
      const minimumVersion: number = 0; // 最低兼容版本
      if (targetVersion !== undefined && targetVersion < minimumVersion) {
        hilog.warn(DOMAIN, TAG,
          `Target version ${targetVersion} is below minimum ${minimumVersion}`);
        promptAction.showToast({
          message: '目标端应用版本过低，请升级后再试',
          duration: 2000
        });
        return AbilityConstant.OnContinueResult.MISMATCH;
      }

      // 收集当前应用状态（从 AppStorage 中获取）
      const currentState = ContinuationStateModel.collectFromAppStorage();

      // 保存轻量级数据到 wantParam（<100KB 可直接通过 wantParam 传递）
      // 这里保存关键的 UI 状态字段作为 want.parameters 的补充
      wantParam['selectedTabIndex'] = currentState.selectedTabIndex as Object;
      wantParam['currentFilePath'] = currentState.currentFilePath as Object;
      wantParam['currentBreakpoint'] = currentState.currentBreakpoint as Object;
      wantParam['windowWidth'] = currentState.windowWidth as Object;
      wantParam['continuationTimestamp'] = Date.now() as Object;

      hilog.info(DOMAIN, TAG,
        `onContinue data saved - tabIndex: ${currentState.selectedTabIndex}, ` +
        `path: ${currentState.currentFilePath}`);

      // 返回 AGREE 表示同意此次迁移
      return AbilityConstant.OnContinueResult.AGREE;

    } catch (error) {
      hilog.error(DOMAIN, TAG,
        `onContinue failed: ${JSON.stringify(error)}`);
      return AbilityConstant.OnContinueResult.REJECT;
    }
  }

  /**
   * 窗口创建回调
   * 正常冷启动时加载页面
   */
  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', this.storage, (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG,
          `Failed to load content: ${JSON.stringify(err)}`);
        return;
      }
      hilog.info(DOMAIN, TAG, 'Content loaded successfully');
    });
  }

  /**
   * 窗口恢复回调（迁移场景专用）
   *
   * 跨端迁移时，无论冷启动还是热启动，都会在执行完 onCreate()/onNewWant()
   * 后触发 onWindowStageRestore()，而不触发 onWindowStageCreate()。
   *
   * 开发者如果在 onWindowStageCreate() 中有必要的初始化逻辑，
   * 需要在此处执行相同的操作。
   */
  onWindowStageRestore(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageRestore (migration scenario)');

    // 迁移场景下加载页面（与 onWindowStageCreate 逻辑一致）
    windowStage.loadContent('pages/Index', this.storage, (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG,
          `Failed to load content in restore: ${JSON.stringify(err)}`);
        return;
      }
      hilog.info(DOMAIN, TAG, 'Content loaded successfully in restore');
    });
  }

  /**
   * 窗口即将销毁回调
   */
  onWindowStageWillDestroy(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageWillDestroy');
  }

  /**
   * 窗口销毁回调
   */
  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageDestroy');
  }

  /**
   * 应用转到前台回调
   */
  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onForeground');
  }

  /**
   * 应用转到后台回调
   */
  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onBackground');
  }

  /**
   * UIAbility 销毁回调
   * 释放资源、保存状态等
   */
  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onDestroy');
    // 重置迁移服务状态
    this.continuationService.reset();
  }

  // ==================== 私有辅助方法 ====================

  /**
   * 从 want 中恢复迁移数据（轻量级数据恢复）
   *
   * 对于小于 100KB 的数据，直接在 onContinue 中通过 wantParam 传递，
   * 对端从 want.parameters 中读取即可。
   *
   * 对于更大的数据或文件，需使用分布式数据对象
   * （参见 ContinuationService.restoreStateFromContinuation）
   */
  private restoreContinuationData(want: Want): void {
    try {
      const params = want.parameters;
      if (!params) {
        hilog.warn(DOMAIN, TAG, 'No parameters in continuation want');
        return;
      }

      hilog.info(DOMAIN, TAG, 'Restoring continuation data from want.parameters...');

      // 恢复标签页索引
      const tabIndex = params['selectedTabIndex'] as number | undefined;
      if (tabIndex !== undefined) {
        AppStorage.setOrCreate('selectedTabIndex', tabIndex);
        AppStorage.setOrCreate('continuationRestoredTabIndex', tabIndex);
        hilog.info(DOMAIN, TAG, `Restored selectedTabIndex: ${tabIndex}`);
      }

      // 恢复文件路径
      const filePath = params['currentFilePath'] as string | undefined;
      if (filePath !== undefined && filePath !== '') {
        AppStorage.setOrCreate('currentFilePath', filePath);
        AppStorage.setOrCreate('continuationRestoredFilePath', filePath);
        hilog.info(DOMAIN, TAG, `Restored currentFilePath: ${filePath}`);
      }

      // 恢复断点信息
      const breakpoint = params['currentBreakpoint'] as string | undefined;
      if (breakpoint !== undefined) {
        AppStorage.setOrCreate('currentBreakpoint', breakpoint);
        hilog.info(DOMAIN, TAG, `Restored currentBreakpoint: ${breakpoint}`);
      }

      // 恢复窗口宽度
      const windowWidth = params['windowWidth'] as number | undefined;
      if (windowWidth !== undefined) {
        AppStorage.setOrCreate('windowWidth', windowWidth);
        hilog.info(DOMAIN, TAG, `Restored windowWidth: ${windowWidth}`);
      }

      // 设置已接续标记
      AppStorage.setOrCreate('isContinuationRestored', true);

      hilog.info(DOMAIN, TAG, 'Continuation data restored successfully');

    } catch (error) {
      hilog.error(DOMAIN, TAG,
        `Failed to restore continuation data: ${JSON.stringify(error)}`);
    }
  }
}
