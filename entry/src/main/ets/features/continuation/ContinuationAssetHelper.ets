/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.
 *
 * 自由流转 - 文件资产迁移辅助类
 *
 * 对于图片、文档等文件类数据，需要先将其转换为资产 commonType.Asset 类型，
 * 再封装到分布式数据对象中进行迁移。
 *
 * 执行流程（Step B：文件与媒体资产迁移）：
 *   1. 将文件写入分布式文件目录 context.distributedFilesDir 下
 *   2. 获取文件状态（ctime, mtime, size）构建 Asset 对象
 *   3. 将 Asset 对象作为分布式数据对象的根属性
 *   4. 随分布式数据对象激活并持久化
 *
 * 约束限制：
 *   - 仅支持迁移分布式文件目录下的文件
 *   - 非分布式文件目录下的文件需先复制或移动到分布式文件目录
 *   - API version 20 之前不支持资产类型数组，多文件需每个作为根属性
 *   - 对端需创建各属性为空字符串的 Asset 对象
 */

import { commonType } from '@kit.ArkData';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = '[ContinuationAssetHelper]';
const DOMAIN: number = 0x0000;

/**
 * 文件资产信息接口（扩展的 Asset 信息）
 */
export interface AssetFileInfo {
  /** 原始文件路径 */
  originalPath: string;
  /** 分布式目录下的文件路径 */
  distributedPath: string;
  /** 分布式目录下的文件 URI */
  distributedUri: string;
  /** 资产对象 */
  asset: commonType.Asset;
}

/**
 * 文件资产迁移辅助类
 */
export class ContinuationAssetHelper {
  /**
   * 将文件复制到分布式文件目录并创建 Asset 对象
   *
   * @param distributedDir 分布式文件目录路径（context.distributedFilesDir）
   * @param sourceFilePath 源文件路径
   * @param fileName 目标文件名（可选，默认使用源文件名）
   * @returns AssetFileInfo 包含资产路径和 Asset 对象
   */
  public static copyFileToDistributedDir(
    distributedDir: string,
    sourceFilePath: string,
    fileName?: string
  ): AssetFileInfo | null {
    try {
      // 提取文件名
      const srcFileName = fileName || sourceFilePath.split('/').pop() || 'unknown_file';
      const distributedPath = `${distributedDir}/${srcFileName}`;

      hilog.info(DOMAIN, TAG,
        `Copying file: ${sourceFilePath} -> ${distributedPath}`);

      // 打开源文件
      const srcFile = fs.openSync(sourceFilePath, fs.OpenMode.READ_ONLY);

      // 在分布式目录下创建目标文件
      const destFile = fs.openSync(
        distributedPath,
        fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE
      );

      // 复制文件内容
      const bufferSize = 4096;
      let buf = new ArrayBuffer(bufferSize);
      let readSize = 0;
      let readLen = fs.readSync(srcFile.fd, buf, { offset: readSize });

      while (readLen > 0) {
        readSize += readLen;
        fs.writeSync(destFile.fd, buf);
        readLen = fs.readSync(srcFile.fd, buf, { offset: readSize });
      }

      // 关闭文件句柄
      fs.closeSync(srcFile);
      fs.closeSync(destFile);

      // 获取文件状态信息
      const stat = fs.statSync(distributedPath);
      const distributedUri = fileUri.getUriFromPath(distributedPath);

      // 构建 Asset 对象
      const asset: commonType.Asset = {
        name: srcFileName,
        uri: distributedUri,
        path: distributedPath,
        createTime: stat.ctime.toString(),
        modifyTime: stat.mtime.toString(),
        size: stat.size.toString()
      };

      hilog.info(DOMAIN, TAG,
        `File copied successfully: ${srcFileName}, size: ${stat.size}`);

      return {
        originalPath: sourceFilePath,
        distributedPath: distributedPath,
        distributedUri: distributedUri,
        asset: asset
      };

    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, TAG,
        `Failed to copy file to distributed dir: ${err.message}`);
      return null;
    }
  }

  /**
   * 将多个文件批量复制到分布式文件目录
   *
   * @param distributedDir 分布式文件目录路径
   * @param sourceFilePaths 源文件路径数组
   * @returns AssetFileInfo 数组
   */
  public static copyFilesToDistributedDir(
    distributedDir: string,
    sourceFilePaths: string[]
  ): AssetFileInfo[] {
    const results: AssetFileInfo[] = [];

    for (const sourcePath of sourceFilePaths) {
      const result = this.copyFileToDistributedDir(distributedDir, sourcePath);
      if (result) {
        results.push(result);
      }
    }

    hilog.info(DOMAIN, TAG,
      `Batch copy complete: ${results.length}/${sourceFilePaths.length} files copied`);

    return results;
  }

  /**
   * 创建空的 Asset 对象（对端恢复时使用）
   * 所有属性必须为空字符串，而非 undefined，否则会导致数据恢复失败
   */
  public static createEmptyAsset(): commonType.Asset {
    return {
      name: '',
      uri: '',
      path: '',
      createTime: '',
      modifyTime: '',
      size: ''
    };
  }

  /**
   * 将 Asset 对象封装为数据对象属性
   * 对于多个文件，每个文件作为独立的根属性
   *
   * @param sourceObject 源数据对象
   * @param assets Asset 文件信息数组
   * @returns 带有资产属性的新对象
   */
  public static wrapAssetsIntoObject(
    sourceObject: Record<string, Object>,
    assets: AssetFileInfo[]
  ): Record<string, Object> {
    const wrapped = { ...sourceObject };

    // 将每个资产作为数据对象的根属性
    for (let i = 0; i < assets.length; i++) {
      wrapped[`attachment_${i}`] = assets[i].asset;
    }

    return wrapped;
  }

  /**
   * 从 Asset 属性中提取文件信息（对端恢复用）
   *
   * @param attachment Asset 对象
   * @param distributedDir 分布式文件目录
   * @returns 文件路径信息
   */
  public static extractAssetFileInfo(
    attachment: commonType.Asset,
    distributedDir: string
  ): { fileName: string; distributedPath: string; fileUri: string } | null {
    try {
      const fileName = attachment.name;
      if (!fileName || fileName === '') {
        hilog.warn(DOMAIN, TAG, 'Empty asset name, skipping');
        return null;
      }

      const distributedPath = `${distributedDir}/${fileName}`;
      const uri = fileUri.getUriFromPath(distributedPath);

      return {
        fileName: fileName,
        distributedPath: distributedPath,
        fileUri: uri
      };
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, TAG,
        `Failed to extract asset file info: ${err.message}`);
      return null;
    }
  }

  /**
   * 检查分布式文件是否存在
   */
  public static isDistributedFileExists(distributedDir: string, fileName: string): boolean {
    try {
      const filePath = `${distributedDir}/${fileName}`;
      fs.accessSync(filePath);
      return true;
    } catch (_error) {
      return false;
    }
  }

  /**
   * 从分布式文件目录读取文件并复制到目标目录
   */
  public static restoreFileFromDistributed(
    distributedDir: string,
    fileName: string,
    destinationDir: string
  ): string | null {
    try {
      const sourcePath = `${distributedDir}/${fileName}`;
      const destPath = `${destinationDir}/${fileName}`;

      if (!this.isDistributedFileExists(distributedDir, fileName)) {
        hilog.warn(DOMAIN, TAG,
          `Distributed file not found: ${fileName}`);
        return null;
      }

      // 打开源文件
      const srcFile = fs.openSync(sourcePath, fs.OpenMode.READ_ONLY);

      // 创建目标文件
      const destFile = fs.openSync(
        destPath,
        fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE
      );

      // 复制内容
      const bufferSize = 4096;
      let buf = new ArrayBuffer(bufferSize);
      let readSize = 0;
      let readLen = fs.readSync(srcFile.fd, buf, { offset: readSize });

      while (readLen > 0) {
        readSize += readLen;
        fs.writeSync(destFile.fd, buf);
        readLen = fs.readSync(srcFile.fd, buf, { offset: readSize });
      }

      fs.closeSync(srcFile);
      fs.closeSync(destFile);

      hilog.info(DOMAIN, TAG,
        `File restored from distributed: ${fileName} -> ${destPath}`);

      return destPath;

    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, TAG,
        `Failed to restore file from distributed: ${err.message}`);
      return null;
    }
  }
}
