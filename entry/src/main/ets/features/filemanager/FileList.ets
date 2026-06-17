/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.
 */

import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { filePreview } from '@kit.PreviewKit';
import { picker } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { promptAction, UIContext } from '@kit.ArkUI';

// 文件项类型
export enum FileType {
  FILE = 'file',
  DIRECTORY = 'directory'
}

// 文件项接口
export interface FileItem {
  name: string;
  path: string;
  type: FileType;
  size?: number;
  lastModified?: number;
  mimeType?: string;
  canPreview?: boolean;
  readable?: boolean;
  writable?: boolean;
}

// 文件列表组件属性
export interface FileListOptions {
  initialPath?: string; // 初始路径，如果不提供则使用Download目录或让用户选择
  onFileClick?: (file: FileItem) => void; // 文件点击回调
  onFolderClick?: (folder: FileItem) => void; // 文件夹点击回调
  onMultiSelectChange?: (selectedFiles: FileItem[]) => void; // 多选变化回调
}

/**
 * 获取公共目录路径（Download目录）
 * 注意：仅支持2in1设备，手机设备需要申请权限或使用FilePicker
 */
export function getPublicDownloadPath(): string | undefined {
  try {
    // 检查系统能力
    // 注意：这里简化处理，实际需要检查设备类型和权限
    // 对于手机设备，可能需要使用FilePicker选择目录
    return undefined;
  } catch (err) {
    console.error('获取公共目录失败:', err);
    return undefined;
  }
}

/**
 * 使用FilePicker选择目录
 * 注意：由于DocumentSelectMode.DIR可能不存在，暂时返回应用沙箱目录
 */
export async function pickDirectory(context: UIContext): Promise<string | undefined> {
  try {
    // 暂时返回应用沙箱目录作为示例
    const hostContext = context.getHostContext();
    if (!hostContext) {
      console.error('无法获取HostContext');
      return undefined;
    }
    return hostContext.filesDir;
    // 实际实现应该使用FilePicker，但需要确认正确的API
    // const documentPicker = new picker.DocumentViewPicker(context);
    // const options = new picker.DocumentSelectOptions();
    // options.selectMode = picker.DocumentSelectMode.FOLDER; // 可能的值
    // const uris = await documentPicker.select(options);
    // if (uris && uris.length > 0) {
    //   return uris[0];
    // }
    // return undefined;
  } catch (err) {
    console.error('选择目录失败:', err);
    return undefined;
  }
}

/**
 * 列出目录中的文件和文件夹
 */
export async function listDirectory(path: string): Promise<FileItem[]> {
  try {
    const files: string[] = fs.listFileSync(path);
    const items: FileItem[] = [];
    
    for (const fileName of files) {
      const fullPath = path.endsWith('/') ? path + fileName : path + '/' + fileName;
      try {
        const stat = fs.statSync(fullPath);
        const item: FileItem = {
          name: fileName,
          path: fullPath,
          type: stat.isDirectory() ? FileType.DIRECTORY : FileType.FILE,
          size: stat.isFile() ? stat.size : undefined,
          lastModified: stat.mtime,
        };
        
        // 如果是文件，尝试获取MIME类型
        if (stat.isFile()) {
          item.mimeType = getMimeType(fileName);
        }
        
        items.push(item);
      } catch (err) {
        console.warn(`无法获取文件信息 ${fullPath}:`, err);
        // 添加一个基本项
        items.push({
          name: fileName,
          path: fullPath,
          type: FileType.FILE, // 默认为文件
        });
      }
    }
    
    // 排序：文件夹在前，文件在后，按名称排序
    items.sort((a, b) => {
      if (a.type === b.type) {
        return a.name.localeCompare(b.name);
      }
      return a.type === FileType.DIRECTORY ? -1 : 1;
    });
    
    return items;
  } catch (err) {
    console.error(`列出目录 ${path} 失败:`, err);
    throw new Error(`列出目录失败: ${JSON.stringify(err)}`);
  }
}

/**
 * 根据文件扩展名获取MIME类型
 */
function getMimeType(fileName: string): string {
  const ext = fileName.lastIndexOf('.') !== -1 ? fileName.substring(fileName.lastIndexOf('.') + 1).toLowerCase() : '';
  
  switch (ext) {
    case 'txt':
      return 'text/plain';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'pdf':
      return 'application/pdf';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'xls':
      return 'application/vnd.ms-excel';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'ppt':
      return 'application/vnd.ms-powerpoint';
    case 'pptx':
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    case 'mp4':
      return 'video/mp4';
    case 'mp3':
      return 'audio/mpeg';
    case 'zip':
      return 'application/zip';
    case 'rar':
      return 'application/x-rar-compressed';
    default:
      return 'application/octet-stream';
  }
}

/**
 * 检查文件是否可预览
 */
export async function checkCanPreview(context: UIContext, filePath: string): Promise<boolean> {
  try {
    const uri = fileUri.getUriFromPath(filePath);
    const hostContext = context.getHostContext();
    if (!hostContext) {
      console.error('无法获取HostContext');
      return false;
    }
    return await filePreview.canPreview(hostContext, uri);
  } catch (err) {
    console.error(`检查文件是否可预览失败 ${filePath}:`, err);
    return false;
  }
}

/**
 * 打开文件预览
 */
export async function openFilePreview(context: UIContext, fileItem: FileItem): Promise<void> {
  try {
    const uri = fileUri.getUriFromPath(fileItem.path);
    const hostContext = context.getHostContext();
    if (!hostContext) {
      console.error('无法获取HostContext');
      throw new Error('无法获取HostContext');
    }
    const previewInfo: filePreview.PreviewInfo = {
      title: fileItem.name,
      uri: uri,
      mimeType: fileItem.mimeType || 'application/octet-stream',
    };
    
    await filePreview.openPreview(hostContext, previewInfo);
  } catch (err) {
    console.error(`打开文件预览失败 ${fileItem.path}:`, err);
    throw new Error(`打开文件预览失败: ${JSON.stringify(err)}`);
  }
}

/**
 * 获取父目录路径
 */
export function getParentDirectory(path: string): string | undefined {
  // 移除末尾的斜杠
  const normalizedPath = path.endsWith('/') ? path.slice(0, -1) : path;
  const lastSlashIndex = normalizedPath.lastIndexOf('/');
  
  if (lastSlashIndex === -1) {
    // 已经是根目录
    return undefined;
  }
  
  return normalizedPath.substring(0, lastSlashIndex) || '/';
}

/**
 * 格式化文件大小
 */
export function formatFileSize(bytes: number): string {
  if (bytes === 0) return '0 B';
  
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  const k = 1024;
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + units[i];
}

/**
 * 格式化时间戳
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