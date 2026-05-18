/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.
 */

import { FileListView } from '../components/FileListView';
import { filePreview } from '@kit.PreviewKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';

@Entry
@Component
struct Index {
  private fileName: string = 'preview_info.txt';

  build() {
    Row() {
      Column({ space: 20 }) {
        // 文件列表浏览模块
        FileListView()
          .layoutWeight(1)
          .width('100%')
          .height('100%')
        
        // 原有预览功能保留，作为示例
        Divider()
          .strokeWidth(1)
          .color('#E5E5E5')
          .margin({ top: 20, bottom: 20 })
        
        Text('原有预览功能示例')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ bottom: 12 })
        
        Row({ space: 12 }) {
          Button($r('app.string.PreviewFile'))
            .layoutWeight(1)
            .height(44)
            .onClick(async() => {
              try {
                let context = this.getUIContext().getHostContext();
                if (context === undefined) {
                  return;
                }
                let fileDir = context.filesDir; // Get the sandbox path
                let filePath = fileDir + '/' + this.fileName;
                let file: fs.File = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE); // create file
                let uri = fileUri.getUriFromPath(filePath); // get uri
                let str: string = "hello, world";
                let writeLen = fs.writeSync(file.fd, str); // Write to the file
                console.info("write data to file succeed and size is:" + writeLen);
                fs.closeSync(file);
                let result = await filePreview.canPreview(context, uri); // Check whether the URI can be previewed
                if (result) {
                  let previewInfo: filePreview.PreviewInfo = {
                    title: this.fileName,
                    uri: uri,
                    mimeType: 'text/plain'
                  }
                  filePreview.openPreview(context, previewInfo); // Open File Preview
                } else {
                  this.getUIContext().getPromptAction().showToast({
                    // File cannot be previewed.
                    message: 'File cannot be previewed.'
                  });
                }
              } catch (err) {
                console.error('openPreview error');
              }
            })
          
          Button($r('app.string.PreviewFolder'))
            .layoutWeight(1)
            .height(44)
            .onClick(async() => {
              try {
                let context = this.getUIContext().getHostContext();
                if (context === undefined) {
                  return;
                }
                let fileDir = context.filesDir; // Get the sandbox path
                let folderUri = fileUri.getUriFromPath(fileDir); // get uri
                let filePath = fileDir + '/' + this.fileName;
                let file = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE); // create file
                let str: string = "hello, world";
                let writeLen = fs.writeSync(file.fd, str); // Write to the file
                console.info("write data to file succeed and size is:" + writeLen);
                fs.closeSync(file);
                let result = await filePreview.canPreview(context, folderUri); // Check whether the URI can be previewed
                if (result) {
                  let previewInfo: filePreview.PreviewInfo = {
                    title: 'file',
                    uri: folderUri,
                    mimeType: ''
                  }
                  filePreview.openPreview(context, previewInfo); // Open File Preview
                } else {
                  this.getUIContext().getPromptAction().showToast({
                    // File cannot be previewed.
                    message: 'File cannot be previewed.'
                  });
                }
              } catch (err) {
                console.error('openPreview Folder error');
              }
            })
        }
        .width('100%')
        .margin({ bottom: 20 })
      }
      .width('100%')
      .padding(20)
    }
    .height('100%')
  }
}