/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.
 */

import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

/**
 * 系统能力枚举
 */
export enum SystemCapability {
  FILE_MANAGEMENT = 'SystemCapability.FileManagement.FileManager',
  DISTRIBUTED_DATA = 'SystemCapability.DistributedDataManager.DataShare',
  DISTRIBUTED_HARDWARE = 'SystemCapability.DistributedHardware.DeviceManager',
  NFC = 'SystemCapability.Communication.NFC.Core',
  BLUETOOTH = 'SystemCapability.Communication.Bluetooth.Core',
  LOCATION = 'SystemCapability.Location.Location.Core',
  CAMERA = 'SystemCapability.Multimedia.Camera.Core',
  AUDIO = 'SystemCapability.Multimedia.Audio.Core',
  NETWORK = 'SystemCapability.Communication.NetManager',
  SENSOR = 'SystemCapability.Sensors.Sensor',
  DISPLAY = 'SystemCapability.WindowManager.WindowManager.Core',
  NOTIFICATION = 'SystemCapability.Notification.Notification',
  ACCOUNT = 'SystemCapability.Account.AppAccount',
  SECURITY = 'SystemCapability.Security.Capability'
}

/**
 * 能力检查结果接口
 */
export interface CapabilityCheckResult {
  supported: boolean;
  capability: SystemCapability;
  message?: string;
  fallback?: () => void;
}

/**
 * 降级策略接口
 */
export interface FallbackStrategy {
  capability: SystemCapability;
  strategy: string;
  action: () => void;
}

/**
 * 检查结果汇总接口
 */
export interface CapabilityCheckSummary {
  allSupported: boolean;
  results: CapabilityCheckResult[];
  unsupportedCapabilities: SystemCapability[];
}

/**
 * 系统能力检查器 - 单例模式
 */
export class SysCapChecker {
  private static instance: SysCapChecker | null = null;

  private fallbackStrategies: Map<SystemCapability, FallbackStrategy> = new Map();
  private capabilityCache: Map<SystemCapability, boolean> = new Map();

  private constructor() {
    this.initializeFallbackStrategies();
  }

  public static getInstance(): SysCapChecker {
    if (!SysCapChecker.instance) {
      SysCapChecker.instance = new SysCapChecker();
    }
    return SysCapChecker.instance;
  }

  private initializeFallbackStrategies(): void {
    this.fallbackStrategies.set(SystemCapability.FILE_MANAGEMENT, {
      capability: SystemCapability.FILE_MANAGEMENT,
      strategy: '使用应用沙箱目录替代公共目录',
      action: (): void => {
        console.warn('文件管理能力不可用，降级到应用沙箱目录');
      }
    });

    this.fallbackStrategies.set(SystemCapability.DISTRIBUTED_DATA, {
      capability: SystemCapability.DISTRIBUTED_DATA,
      strategy: '使用本地存储替代分布式数据同步',
      action: (): void => {
        console.warn('分布式数据能力不可用，降级到本地存储');
      }
    });

    this.fallbackStrategies.set(SystemCapability.DISTRIBUTED_HARDWARE, {
      capability: SystemCapability.DISTRIBUTED_HARDWARE,
      strategy: '禁用跨设备投屏功能',
      action: (): void => {
        console.warn('分布式硬件能力不可用，禁用跨设备投屏功能');
      }
    });

    this.fallbackStrategies.set(SystemCapability.NFC, {
      capability: SystemCapability.NFC,
      strategy: '使用二维码扫描替代NFC',
      action: (): void => {
        console.warn('NFC能力不可用，降级到二维码扫描');
      }
    });

    this.fallbackStrategies.set(SystemCapability.BLUETOOTH, {
      capability: SystemCapability.BLUETOOTH,
      strategy: '使用Wi-Fi直连替代蓝牙',
      action: (): void => {
        console.warn('蓝牙能力不可用，降级到Wi-Fi直连');
      }
    });

    this.fallbackStrategies.set(SystemCapability.LOCATION, {
      capability: SystemCapability.LOCATION,
      strategy: '使用IP地址定位或手动输入位置',
      action: (): void => {
        console.warn('位置服务能力不可用，降级到IP定位或手动输入');
      }
    });

    this.fallbackStrategies.set(SystemCapability.CAMERA, {
      capability: SystemCapability.CAMERA,
      strategy: '使用相册选择图片替代相机拍摄',
      action: (): void => {
        console.warn('相机能力不可用，降级到相册选择');
      }
    });

    this.fallbackStrategies.set(SystemCapability.NETWORK, {
      capability: SystemCapability.NETWORK,
      strategy: '使用离线模式或缓存数据',
      action: (): void => {
        console.warn('网络能力不可用，降级到离线模式');
      }
    });
  }

  public async checkCapability(capability: SystemCapability): Promise<CapabilityCheckResult> {
    if (this.capabilityCache.has(capability)) {
      const supported: boolean = this.capabilityCache.get(capability)!;
      return this.createCheckResult(capability, supported);
    }

    let supported: boolean = false;
    let message: string = '';

    try {
      supported = await this.simulateCanIUse(capability);

      if (supported) {
        message = `设备支持 ${capability}`;
      } else {
        message = `设备不支持 ${capability}`;
      }

      this.capabilityCache.set(capability, supported);
    } catch (error) {
      console.error(`检查系统能力 ${capability} 失败:`, error);
      message = `检查系统能力失败`;
      supported = false;
    }

    return this.createCheckResult(capability, supported, message);
  }

  private async simulateCanIUse(capability: SystemCapability): Promise<boolean> {
    const unsupportedCapabilities: SystemCapability[] = [
      SystemCapability.DISTRIBUTED_HARDWARE,
      SystemCapability.NFC,
      SystemCapability.BLUETOOTH
    ];
    return !unsupportedCapabilities.includes(capability);
  }

  private createCheckResult(
    capability: SystemCapability,
    supported: boolean,
    message?: string
  ): CapabilityCheckResult {
    const result: CapabilityCheckResult = {
      supported,
      capability,
      message: message || (supported ? '能力支持' : '能力不支持')
    };

    if (!supported) {
      const fallbackStrategy: FallbackStrategy | undefined = this.fallbackStrategies.get(capability);
      if (fallbackStrategy) {
        result.fallback = fallbackStrategy.action;
      }
    }

    return result;
  }

  public async checkCapabilities(capabilities: SystemCapability[]): Promise<CapabilityCheckResult[]> {
    const results: CapabilityCheckResult[] = [];

    for (const capability of capabilities) {
      const result: CapabilityCheckResult = await this.checkCapability(capability);
      results.push(result);
    }

    return results;
  }

  public async checkRequiredCapabilities(requiredCapabilities: SystemCapability[]): Promise<CapabilityCheckSummary> {
    const results: CapabilityCheckResult[] = await this.checkCapabilities(requiredCapabilities);
    const unsupportedCapabilities: SystemCapability[] = [];
    let allSupported: boolean = true;

    for (const result of results) {
      if (!result.supported) {
        allSupported = false;
        unsupportedCapabilities.push(result.capability);
      }
    }

    const summary: CapabilityCheckSummary = {
      allSupported,
      results,
      unsupportedCapabilities
    };

    return summary;
  }

  public executeFallback(capability: SystemCapability): void {
    const strategy: FallbackStrategy | undefined = this.fallbackStrategies.get(capability);
    if (strategy) {
      console.log(`执行降级方案: ${strategy.strategy}`);
      strategy.action();
    } else {
      console.warn(`没有找到 ${capability} 的降级方案`);
    }
  }

  public getFallbackStrategies(): FallbackStrategy[] {
    return Array.from(this.fallbackStrategies.values());
  }

  public addFallbackStrategy(strategy: FallbackStrategy): void {
    this.fallbackStrategies.set(strategy.capability, strategy);
  }

  public clearCache(): void {
    this.capabilityCache.clear();
  }

  public async checkPermission(permission: string): Promise<boolean> {
    try {
      return true;
    } catch (error) {
      console.error(`检查权限 ${permission} 失败:`, error);
      return false;
    }
  }

  public async requestPermission(permission: string): Promise<boolean> {
    try {
      console.log(`请求权限: ${permission}`);
      return true;
    } catch (error) {
      console.error(`请求权限 ${permission} 失败:`, error);
      return false;
    }
  }
}

/**
 * 能力条件渲染组件
 */
@Component
export struct CapabilityConditional {
  private capability: SystemCapability = SystemCapability.FILE_MANAGEMENT;
  private checker: SysCapChecker = SysCapChecker.getInstance();

  @State private supported: boolean = false;
  @State private checking: boolean = true;

  @BuilderParam
  supportedContent: () => void = this.defaultSupportedContent;

  @BuilderParam
  fallbackContent: () => void = this.defaultFallbackContent;

  @Builder
  defaultSupportedContent(): void {}

  @Builder
  defaultFallbackContent(): void {}

  aboutToAppear(): void {
    this.checkCapability();
  }

  private async checkCapability(): Promise<void> {
    this.checking = true;
    try {
      const result: CapabilityCheckResult = await this.checker.checkCapability(this.capability);
      this.supported = result.supported;
    } catch (error) {
      console.error(`检查能力 ${this.capability} 失败:`, error);
      this.supported = false;
    } finally {
      this.checking = false;
    }
  }

  build() {
    Column() {
      if (this.checking) {
        LoadingProgress()
          .width(30)
          .height(30)
          .color('#007DFF')
      } else if (this.supported) {
        this.supportedContent()
      } else {
        this.fallbackContent()
      }
    }
  }
}
