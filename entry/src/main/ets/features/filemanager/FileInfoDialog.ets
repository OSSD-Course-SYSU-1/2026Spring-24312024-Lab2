/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.
 */

import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { filePreview } from '@kit.PreviewKit';
import { promptAction, UIContext, ComponentContent } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';

// 文件访问权限常量
interface AccessModeType {
  READ: number;
  WRITE: number;
}

const AccessMode: AccessModeType = {
  READ: 4,    // 读权限
  WRITE: 2    // 写权限
};

/**
 * 文件信息接口
 */
export interface FileInfo {
  fileName: string;           // 文件名
  filePath: string;           // 完整路径
  fileSize: number;           // 文件大小（字节）
  mimeType: string;           // MIME类型
  lastModified: number;       // 修改时间（时间戳）
  canPreview: boolean;        // 是否可预览
  readable: boolean;          // 是否可读
  writable: boolean;          // 是否可写
}

/**
 * 格式化文件大小
 * @param bytes 文件大小（字节）
 * @returns 格式化后的文件大小字符串
 */
export function formatFileSize(bytes: number): string {
  if (bytes === 0) return '0 B';
  
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  const k = 1024;
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + units[i];
}

/**
 * 格式化时间戳为可读字符串 (yyyy-MM-dd HH:mm:ss)
 * @param timestamp 时间戳（毫秒）
 * @returns 格式化后的时间字符串
 */
export function formatTime(timestamp: number): string {
  const date = new Date(timestamp);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const hours = String(date.getHours()).padStart(2, '0');
  const minutes = String(date.getMinutes()).padStart(2, '0');
  const seconds = String(date.getSeconds()).padStart(2, '0');
  return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
}

/**
 * 获取文件信息
 * @param filePath 文件路径
 * @returns Promise<FileInfo> 文件信息
 */
export async function getFileInfo(filePath: string): Promise<FileInfo> {
  try {
    // 获取文件状态
    const stat = fs.statSync(filePath);
    
    // 从路径中提取文件名
    const lastSlashIndex = filePath.lastIndexOf('/');
    const fileName = lastSlashIndex !== -1 ? filePath.substring(lastSlashIndex + 1) : filePath;
    
    // 获取MIME类型（这里简化处理，实际可能需要根据文件扩展名判断）
    let mimeType = 'application/octet-stream';
    const ext = fileName.lastIndexOf('.') !== -1 ? fileName.substring(fileName.lastIndexOf('.') + 1).toLowerCase() : '';
    
    // 根据扩展名设置MIME类型
    switch (ext) {
      case 'txt':
        mimeType = 'text/plain';
        break;
      case 'jpg':
      case 'jpeg':
        mimeType = 'image/jpeg';
        break;
      case 'png':
        mimeType = 'image/png';
        break;
      case 'pdf':
        mimeType = 'application/pdf';
        break;
      case 'doc':
      case 'docx':
        mimeType = 'application/msword';
        break;
      case 'xls':
      case 'xlsx':
        mimeType = 'application/vnd.ms-excel';
        break;
      case 'ppt':
      case 'pptx':
        mimeType = 'application/vnd.ms-powerpoint';
        break;
      case 'mp4':
        mimeType = 'video/mp4';
        break;
      case 'mp3':
        mimeType = 'audio/mpeg';
        break;
      default:
        mimeType = 'application/octet-stream';
    }
    
    // 检查文件是否可读/可写
    let readable = false;
    let writable = false;
    try {
      // 检查读权限
      readable = fs.accessSync(filePath, AccessMode.READ);
    } catch (err) {
      console.log(`文件 ${filePath} 不可读: ${(err as BusinessError).message}`);
    }
    
    try {
      // 检查写权限
      writable = fs.accessSync(filePath, AccessMode.WRITE);
    } catch (err) {
      console.log(`文件 ${filePath} 不可写: ${(err as BusinessError).message}`);
    }
    
    return {
      fileName,
      filePath,
      fileSize: stat.size,
      mimeType,
      lastModified: stat.mtime,
      canPreview: false, // 默认值，实际使用时需要检查
      readable,
      writable
    };
  } catch (err) {
    console.error('获取文件信息失败:', err);
    throw new Error(`获取文件信息失败: ${JSON.stringify(err)}`);
  }
}

/**
 * 文件信息对话框参数
 */
interface FileInfoDialogParams {
  fileInfo: FileInfo;
  onConfirm?: () => void;
  onCancel?: () => void;
  closeDialog?: () => void;
}

// 对话框ID存储
let currentDialogId: number | null = null;

/**
 * 文件信息对话框内容组件
 */
@Component
export struct FileInfoDialogContent {
  // 参数
  params: FileInfoDialogParams = {} as FileInfoDialogParams;
  
  build() {
    Column({ space: 12 }) {
      // 标题
      Text('文件信息')
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
      
      // 文件信息列表
      Column({ space: 8 }) {
        // 文件名
        Row() {
          Text('文件名：')
            .fontSize(16)
            .fontColor('#666666')
            .width(80)
          Text(this.params.fileInfo.fileName)
            .fontSize(16)
            .fontColor('#333333')
            .fontWeight(FontWeight.Medium)
            .layoutWeight(1)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .padding({ bottom: 8 })
        
        // 文件路径
        Row() {
          Text('路径：')
            .fontSize(16)
            .fontColor('#666666')
            .width(80)
          Text(this.params.fileInfo.filePath)
            .fontSize(14)
            .fontColor('#666666')
            .layoutWeight(1)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .padding({ bottom: 8 })
        
        // 文件大小
        Row() {
          Text('大小：')
            .fontSize(16)
            .fontColor('#666666')
            .width(80)
          Text(formatFileSize(this.params.fileInfo.fileSize))
            .fontSize(16)
            .fontColor('#333333')
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ bottom: 8 })
        
        // MIME类型
        Row() {
          Text('类型：')
            .fontSize(16)
            .fontColor('#666666')
            .width(80)
          Text(this.params.fileInfo.mimeType)
            .fontSize(16)
            .fontColor('#333333')
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ bottom: 8 })
        
        // 修改时间
        Row() {
          Text('修改时间：')
            .fontSize(16)
            .fontColor('#666666')
            .width(80)
          Text(formatTime(this.params.fileInfo.lastModified))
            .fontSize(16)
            .fontColor('#333333')
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ bottom: 8 })
        
        // 是否可预览
        Row() {
          Text('可预览：')
            .fontSize(16)
            .fontColor('#666666')
            .width(80)
          Text(this.params.fileInfo.canPreview ? '是' : '否')
            .fontSize(16)
            .fontColor(this.params.fileInfo.canPreview ? '#07C160' : '#FA5151')
            .fontWeight(FontWeight.Medium)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ bottom: 8 })
        
        // 是否可读
        Row() {
          Text('可读：')
            .fontSize(16)
            .fontColor('#666666')
            .width(80)
          Text(this.params.fileInfo.readable ? '是' : '否')
            .fontSize(16)
            .fontColor(this.params.fileInfo.readable ? '#07C160' : '#FA5151')
            .fontWeight(FontWeight.Medium)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ bottom: 8 })
        
        // 是否可写
        Row() {
          Text('可写：')
            .fontSize(16)
            .fontColor('#666666')
            .width(80)
          Text(this.params.fileInfo.writable ? '是' : '否')
            .fontSize(16)
            .fontColor(this.params.fileInfo.writable ? '#07C160' : '#FA5151')
            .fontWeight(FontWeight.Medium)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ bottom: 16 })
      }
      .width('100%')
      .padding({ left: 24, right: 24 })
      
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
        
        // 立即预览按钮
        Button('立即预览')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(this.params.fileInfo.canPreview ? '#007DFF' : '#CCCCCC')
          .fontColor('#FFFFFF')
          .layoutWeight(1)
          .height(44)
          .enabled(this.params.fileInfo.canPreview)
          .onClick(() => {
            if (this.params.fileInfo.canPreview) {
              this.params.onConfirm?.();
              this.params.closeDialog?.();
            }
          })
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: 24 })
    }
    .width('80%')
    .backgroundColor(Color.White)
    .borderRadius(16)
    .shadow({ radius: 24, color: '#1A000000', offsetX: 0, offsetY: 8 })
  }
}

/**
 * 文件信息对话框构建器
 */
@Builder
function fileInfoDialogBuilder(params: FileInfoDialogParams) {
  FileInfoDialogContent({ params: params })
}

/**
 * 显示文件信息对话框
 * @param context UIContext
 * @param fileInfo 文件信息
 * @param onConfirm 确认回调
 * @param onCancel 取消回调
 */
export function showFileInfoDialog(
  context: UIContext,
  fileInfo: FileInfo,
  onConfirm?: () => void,
  onCancel?: () => void
): void {
  try {
    // 如果已经有对话框打开，先关闭它
    if (currentDialogId !== null) {
      try {
        context.getPromptAction().closeCustomDialog(currentDialogId);
      } catch (err) {
        // 忽略关闭错误
      }
      currentDialogId = null;
    }
    
    // 创建对话框参数
    const params: FileInfoDialogParams = {
      fileInfo,
      onConfirm,
      onCancel,
      closeDialog: () => {
        if (currentDialogId !== null) {
          try {
            context.getPromptAction().closeCustomDialog(currentDialogId);
          } catch (err) {
            console.error('关闭对话框失败:', err);
          }
          currentDialogId = null;
        }
      }
    };
    
    // 打开对话框
    context.getPromptAction().openCustomDialog({
      builder: () => {
        return fileInfoDialogBuilder(params);
      },
      alignment: DialogAlignment.Center,
      maskColor: 0x33000000,
      autoCancel: true
    }).then((dialogId: number) => {
      // 保存对话框ID以便后续关闭
      currentDialogId = dialogId;
    }).catch((error: BusinessError) => {
      console.error('打开文件信息对话框失败:', error);
    });
  } catch (error) {
    console.error('创建文件信息对话框失败:', error);
  }
}

/**
 * 通过文件路径显示文件信息对话框
 * @param context UIContext
 * @param filePath 文件路径
 * @param onConfirm 确认回调
 * @param onCancel 取消回调
 * @returns Promise<void> 显示对话框
 */
export async function showFileInfoDialogByPath(
  context: UIContext,
  filePath: string,
  onConfirm?: () => void,
  onCancel?: () => void
): Promise<void> {
  try {
    // 获取文件信息
    const fileInfo = await getFileInfo(filePath);
    
    // 检查文件是否可预览
    const uri = fileUri.getUriFromPath(filePath);
    const hostContext = context.getHostContext();
    if (hostContext) {
      const canPreview = await filePreview.canPreview(hostContext, uri);
      fileInfo.canPreview = canPreview;
    } else {
      console.error('无法获取HostContext');
      fileInfo.canPreview = false;
    }
    
    // 显示对话框
    showFileInfoDialog(context, fileInfo, onConfirm, onCancel);
  } catch (err) {
    console.error('显示文件信息对话框失败:', err);
    throw new Error(`显示文件信息对话框失败: ${JSON.stringify(err)}`);
  }
}