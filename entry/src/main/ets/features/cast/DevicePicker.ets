/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.
 */

import { CastService, DeviceInfo, CastStatus } from './CastService';
import { promptAction, UIContext, ComponentContent } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';

/**
 * 设备选择器参数
 */
export interface DevicePickerParams {
  onDeviceSelected?: (device: DeviceInfo) => void;
  onCancel?: () => void;
  closeDialog?: () => void;
}

/**
 * 设备选择器内容组件
 */
@Component
export struct DevicePickerContent {
  // 参数
  params: DevicePickerParams = {} as DevicePickerParams;
  
  // 投屏服务实例
  private castService: CastService = CastService.getInstance();
  
  // 设备列表
  @State private devices: DeviceInfo[] = [];
  
  // 加载状态
  @State private isLoading: boolean = true;
  
  // 错误信息
  @State private errorMessage: string = '';
  
  // 选中的设备ID
  @State private selectedDeviceId: string | null = null;
  
  aboutToAppear() {
    this.loadDevices();
  }
  
  /**
   * 加载设备列表
   */
  private async loadDevices(): Promise<void> {
    this.isLoading = true;
    this.errorMessage = '';
    
    try {
      const discoveredDevices = await this.castService.startDiscovery();
      this.devices = discoveredDevices;
    } catch (error) {
      console.error('加载设备列表失败:', error);
      this.errorMessage = `加载设备列表失败: ${(error as BusinessError).message || '未知错误'}`;
    } finally {
      this.isLoading = false;
    }
  }
  
  /**
   * 刷新设备列表
   */
  private async refreshDevices(): Promise<void> {
    this.devices = [];
    await this.loadDevices();
  }
  
  /**
   * 选择设备
   */
  private selectDevice(device: DeviceInfo): void {
    this.selectedDeviceId = device.id;
  }
  
  /**
   * 确认选择
   */
  private confirmSelection(): void {
    if (!this.selectedDeviceId) {
      promptAction.showToast({
        message: '请先选择一个设备'
      });
      return;
    }
    
    const selectedDevice = this.devices.find(d => d.id === this.selectedDeviceId);
    if (!selectedDevice) {
      promptAction.showToast({
        message: '选择的设备不存在'
      });
      return;
    }
    
    if (!selectedDevice.online) {
      promptAction.showToast({
        message: '设备已离线，请选择其他设备'
      });
      return;
    }
    
    this.params.onDeviceSelected?.(selectedDevice);
    this.params.closeDialog?.();
  }
  
  /**
   * 渲染设备项
   */
  @Builder
  private renderDeviceItem(device: DeviceInfo) {
    Row() {
      // 设备图标
      Text(device.icon)
        .fontSize(24)
        .width(40)
        .height(40)
        .margin({ right: 12 })
        .textAlign(TextAlign.Center)
      
      // 设备信息
      Column({ space: 4 }) {
        Text(device.name)
          .fontSize(16)
          .fontColor('#333333')
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        
        Row({ space: 8 }) {
          Text(device.type)
            .fontSize(12)
            .fontColor('#666666')
          
          // 在线状态
          if (device.online) {
            Text('在线')
              .fontSize(12)
              .fontColor('#07C160')
          } else {
            Text('离线')
              .fontSize(12)
              .fontColor('#FA5151')
          }
        }
        .alignItems(VerticalAlign.Center)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      
      // 选择指示器
      if (this.selectedDeviceId === device.id) {
        Image($r('app.media.ic_check'))
          .width(20)
          .height(20)
          .margin({ left: 8 })
          .interpolation(ImageInterpolation.High)
      } else {
        // 占位，保持布局一致
        Blank()
          .width(20)
          .height(20)
          .margin({ left: 8 })
      }
    }
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(this.selectedDeviceId === device.id ? '#F0F8FF' : '#FFFFFF')
    .borderRadius(8)
    .onClick(() => {
      if (device.online) {
        this.selectDevice(device);
      } else {
        promptAction.showToast({
          message: '设备已离线，无法选择'
        });
      }
    })
  }
  
  /**
   * 渲染加载状态
   */
  @Builder
  private renderLoading() {
    Column() {
      LoadingProgress()
        .width(40)
        .height(40)
        .color('#007DFF')
      
      Text('正在搜索设备...')
        .fontSize(14)
        .fontColor('#666666')
        .margin({ top: 12 })
    }
    .width('100%')
    .height(200)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
  
  /**
   * 渲染空状态
   */
  @Builder
  private renderEmptyState() {
    Column() {
      Text('📡')
        .fontSize(80)
        .width(120)
        .height(120)
        .margin({ bottom: 16 })
        .textAlign(TextAlign.Center)
      
      Text('未发现设备')
        .fontSize(18)
        .fontColor('#999999')
        .margin({ bottom: 8 })
      
      Text('请确保设备在同一网络下并已登录相同账号')
        .fontSize(14)
        .fontColor('#CCCCCC')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 24 })
      
      Button('重新搜索')
        .fontSize(16)
        .backgroundColor('#007DFF')
        .fontColor('#FFFFFF')
        .padding({ left: 24, right: 24 })
        .onClick(() => {
          this.refreshDevices();
        })
    }
    .width('100%')
    .height(200)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
  
  /**
   * 渲染错误状态
   */
  @Builder
  private renderError() {
    Column() {
      Text('❌')
        .fontSize(80)
        .width(120)
        .height(120)
        .margin({ bottom: 16 })
        .textAlign(TextAlign.Center)
      
      Text('设备搜索失败')
        .fontSize(18)
        .fontColor('#FF6B35')
        .margin({ bottom: 8 })
      
      Text(this.errorMessage)
        .fontSize(14)
        .fontColor('#999999')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 24 })
      
      Button('重试')
        .fontSize(16)
        .backgroundColor('#007DFF')
        .fontColor('#FFFFFF')
        .padding({ left: 24, right: 24 })
        .onClick(() => {
          this.refreshDevices();
        })
    }
    .width('100%')
    .height(200)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
  
  build() {
    Column({ space: 12 }) {
      // 标题
      Text('选择投屏设备')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 24, bottom: 8 })
      
      // 分隔线
      Divider()
        .strokeWidth(1)
        .color('#E5E5E5')
        .margin({ bottom: 16 })
      
      // 设备列表区域
      Column() {
        if (this.isLoading) {
          this.renderLoading()
        } else if (this.errorMessage) {
          this.renderError()
        } else if (this.devices.length === 0) {
          this.renderEmptyState()
        } else {
          List({ space: 8 }) {
            ForEach(this.devices, (device: DeviceInfo) => {
              ListItem() {
                this.renderDeviceItem(device)
              }
            }, (device: DeviceInfo) => device.id)
          }
          .width('100%')
          .height(300)
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 16, right: 16 })
      
      // 按钮区域
      Row({ space: 12 }) {
        // 取消按钮
        Button('取消')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .backgroundColor('#F2F2F2')
          .fontColor('#333333')
          .layoutWeight(1)
          .height(44)
          .onClick(() => {
            this.params.onCancel?.();
            this.params.closeDialog?.();
          })
        
        // 连接按钮
        Button('连接')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .backgroundColor('#007DFF')
          .fontColor('#FFFFFF')
          .layoutWeight(1)
          .height(44)
          .onClick(() => {
            this.confirmSelection();
          })
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: 24 })
    }
    .width('90%')
    .maxWidth(400)
    .height('70%')
    .maxHeight(600)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .shadow({ radius: 24, color: '#1A000000', offsetX: 0, offsetY: 8 })
  }
}

/**
 * 设备选择器构建器
 */
@Builder
function devicePickerBuilder(params: DevicePickerParams) {
  DevicePickerContent({ params: params })
}

/**
 * 显示设备选择器
 * @param context UIContext
 * @param onDeviceSelected 设备选择回调
 * @param onCancel 取消回调
 */
export function showDevicePicker(
  context: UIContext,
  onDeviceSelected?: (device: DeviceInfo) => void,
  onCancel?: () => void
): void {
  try {
    // 创建对话框参数
    const params: DevicePickerParams = {
      onDeviceSelected,
      onCancel,
      closeDialog: () => {
        // 关闭对话框的逻辑由调用者处理
      }
    };
    
    // 打开对话框
    context.getPromptAction().openCustomDialog({
      builder: () => {
        return devicePickerBuilder(params);
      },
      alignment: DialogAlignment.Center,
      maskColor: 0x33000000,
      autoCancel: true
    }).catch((error: BusinessError) => {
      console.error('打开设备选择器失败:', error);
    });
  } catch (error) {
    console.error('创建设备选择器失败:', error);
  }
}