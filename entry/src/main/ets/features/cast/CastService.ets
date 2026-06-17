/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.
 */

import { BusinessError } from '@kit.BasicServicesKit';

/**
 * 投屏服务状态枚举
 */
export enum CastStatus {
  IDLE = 'idle',
  DISCOVERING = 'discovering',
  CONNECTING = 'connecting',
  TRANSFERRING = 'transferring',
  SUCCESS = 'success',
  ERROR = 'error'
}

/**
 * 设备信息接口
 */
export interface DeviceInfo {
  id: string;
  name: string;
  type: string;
  online: boolean;
  icon: string;
}

/**
 * 投屏进度回调接口
 */
export interface CastProgressCallback {
  onProgress: (progress: number) => void;
  onSuccess: () => void;
  onError: (error: BusinessError) => void;
}

/**
 * 投屏服务类 - 单例模式
 */
export class CastService {
  private static instance: CastService | null = null;
  
  // 当前状态
  private status: CastStatus = CastStatus.IDLE;
  
  // 发现的设备列表
  private devices: DeviceInfo[] = [];
  
  // 当前投屏的文件URI
  private currentFileUri: string | null = null;
  
  // 当前投屏的目标设备ID
  private targetDeviceId: string | null = null;
  
  // 投屏进度（0-100）
  private progress: number = 0;
  
  // 错误信息
  private errorMessage: string = '';
  
  // 投屏进度回调
  private progressCallback: CastProgressCallback | null = null;
  
  // MIME类型映射
  private readonly mimeTypeMap: Map<string, string> = new Map([
    ['jpg', 'image/jpeg'],
    ['jpeg', 'image/jpeg'],
    ['png', 'image/png'],
    ['gif', 'image/gif'],
    ['bmp', 'image/bmp'],
    ['mp4', 'video/mp4'],
    ['avi', 'video/x-msvideo'],
    ['mov', 'video/quicktime'],
    ['mp3', 'audio/mpeg'],
    ['wav', 'audio/wav'],
    ['pdf', 'application/pdf'],
    ['doc', 'application/msword'],
    ['docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
    ['xls', 'application/vnd.ms-excel'],
    ['xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
    ['ppt', 'application/vnd.ms-powerpoint'],
    ['pptx', 'application/vnd.openxmlformats-officedocument.presentationml.presentation'],
    ['txt', 'text/plain']
  ]);
  
  private constructor() {
    // 私有构造函数，防止外部实例化
  }
  
  /**
   * 获取单例实例
   */
  public static getInstance(): CastService {
    if (!CastService.instance) {
      CastService.instance = new CastService();
    }
    return CastService.instance;
  }
  
  /**
   * 获取当前状态
   */
  public getStatus(): CastStatus {
    return this.status;
  }
  
  /**
   * 获取发现的设备列表
   */
  public getDevices(): DeviceInfo[] {
    return [...this.devices];
  }
  
  /**
   * 获取当前投屏进度
   */
  public getProgress(): number {
    return this.progress;
  }
  
  /**
   * 获取错误信息
   */
  public getErrorMessage(): string {
    return this.errorMessage;
  }
  
  /**
   * 检查文件是否支持投屏
   * @param fileUri 文件URI
   * @returns 是否支持
   */
  public canCastFile(fileUri: string): boolean {
    // 根据文件扩展名判断是否支持
    const extension = this.getFileExtension(fileUri);
    return this.mimeTypeMap.has(extension.toLowerCase());
  }
  
  /**
   * 开始设备发现
   */
  public async startDiscovery(): Promise<DeviceInfo[]> {
    if (this.status !== CastStatus.IDLE) {
      throw new Error('投屏服务忙，无法开始设备发现');
    }
    
    this.status = CastStatus.DISCOVERING;
    this.devices = [];
    this.errorMessage = '';
    
    try {
      // 模拟设备发现
      await this.simulateDeviceDiscovery();
      return this.devices;
    } catch (error) {
      this.status = CastStatus.ERROR;
      this.errorMessage = `设备发现失败: ${(error as BusinessError).message || '未知错误'}`;
      throw error;
    }
  }
  
  /**
   * 停止设备发现
   */
  public stopDiscovery(): void {
    if (this.status === CastStatus.DISCOVERING) {
      this.status = CastStatus.IDLE;
    }
  }
  
  /**
   * 投屏文件到设备
   * @param fileUri 文件URI
   * @param deviceId 设备ID
   * @param callback 进度回调
   */
  public async castToDevice(
    fileUri: string,
    deviceId: string,
    callback: CastProgressCallback
  ): Promise<void> {
    if (!this.canCastFile(fileUri)) {
      throw new Error('不支持的文件类型');
    }
    
    const device = this.devices.find(d => d.id === deviceId);
    if (!device) {
      throw new Error('设备不存在或已离线');
    }
    
    if (!device.online) {
      throw new Error('设备已离线');
    }
    
    if (this.status !== CastStatus.IDLE && this.status !== CastStatus.DISCOVERING) {
      throw new Error('投屏服务忙，请稍后重试');
    }
    
    this.currentFileUri = fileUri;
    this.targetDeviceId = deviceId;
    this.progressCallback = callback;
    this.progress = 0;
    this.errorMessage = '';
    
    try {
      this.status = CastStatus.CONNECTING;
      
      // 模拟连接设备
      await this.simulateConnectDevice(deviceId);
      
      this.status = CastStatus.TRANSFERRING;
      
      // 模拟文件传输
      await this.simulateFileTransfer(fileUri, deviceId, (progress) => {
        this.progress = progress;
        callback.onProgress(progress);
      });
      
      this.status = CastStatus.SUCCESS;
      callback.onSuccess();
      
      // 重置状态
      setTimeout(() => {
        this.reset();
      }, 2000);
      
    } catch (error) {
      this.status = CastStatus.ERROR;
      this.errorMessage = `投屏失败: ${(error as BusinessError).message || '未知错误'}`;
      callback.onError(error as BusinessError);
      
      // 重置状态
      setTimeout(() => {
        this.reset();
      }, 3000);
      
      throw error;
    }
  }
  
  /**
   * 取消当前投屏
   */
  public cancelCast(): void {
    if (this.status === CastStatus.TRANSFERRING || this.status === CastStatus.CONNECTING) {
      this.status = CastStatus.IDLE;
      this.progress = 0;
      this.errorMessage = '用户取消投屏';
      
      if (this.progressCallback) {
        const error: BusinessError = {
          code: -1,
          message: '用户取消投屏'
        } as BusinessError;
        this.progressCallback.onError(error);
      }
      
      this.reset();
    }
  }
  
  /**
   * 重试上次失败的投屏
   */
  public async retryCast(callback: CastProgressCallback): Promise<void> {
    if (!this.currentFileUri || !this.targetDeviceId) {
      throw new Error('没有可重试的投屏任务');
    }
    
    if (this.status !== CastStatus.ERROR) {
      throw new Error('当前没有失败的投屏任务');
    }
    
    return this.castToDevice(this.currentFileUri, this.targetDeviceId, callback);
  }
  
  /**
   * 重置服务状态
   */
  private reset(): void {
    this.status = CastStatus.IDLE;
    this.progress = 0;
    this.errorMessage = '';
    this.progressCallback = null;
  }
  
  /**
   * 模拟设备发现
   */
  private async simulateDeviceDiscovery(): Promise<void> {
    return new Promise((resolve) => {
      // 模拟网络延迟
      setTimeout(() => {
        this.devices = [
          {
            id: 'device-1',
            name: '客厅智慧屏',
            type: 'TV',
            online: true,
            icon: '📺'
          },
          {
            id: 'device-2',
            name: '卧室平板',
            type: 'Tablet',
            online: true,
            icon: '📱'
          },
          {
            id: 'device-3',
            name: '书房电脑',
            type: 'PC',
            online: false,
            icon: '💻'
          },
          {
            id: 'device-4',
            name: '手机',
            type: 'Phone',
            online: true,
            icon: '📱'
          }
        ];
        this.status = CastStatus.IDLE;
        resolve();
      }, 1500);
    });
  }
  
  /**
   * 模拟连接设备
   */
  private async simulateConnectDevice(deviceId: string): Promise<void> {
    return new Promise((resolve, reject) => {
      // 模拟网络延迟
      setTimeout(() => {
        const device = this.devices.find(d => d.id === deviceId);
        if (!device || !device.online) {
          reject(new Error('设备连接失败'));
          return;
        }
        
        // 模拟连接成功率90%
        if (Math.random() > 0.1) {
          resolve();
        } else {
          reject(new Error('设备连接超时'));
        }
      }, 1000);
    });
  }
  
  /**
   * 模拟文件传输
   */
  private async simulateFileTransfer(
    fileUri: string,
    deviceId: string,
    progressCallback: (progress: number) => void
  ): Promise<void> {
    return new Promise((resolve, reject) => {
      // 模拟传输过程
      let progress = 0;
      const interval = setInterval(() => {
        progress += Math.random() * 10 + 5; // 每次增加5-15%
        if (progress >= 100) {
          progress = 100;
          clearInterval(interval);
          progressCallback(progress);
          resolve();
          return;
        }
        progressCallback(progress);
      }, 200);
      
      // 模拟10%的失败率
      if (Math.random() < 0.1) {
        setTimeout(() => {
          clearInterval(interval);
          reject(new Error('网络中断，传输失败'));
        }, 3000);
      }
    });
  }
  
  /**
   * 获取文件扩展名
   */
  private getFileExtension(fileUri: string): string {
    const lastDotIndex = fileUri.lastIndexOf('.');
    if (lastDotIndex === -1) {
      return '';
    }
    return fileUri.substring(lastDotIndex + 1);
  }
}