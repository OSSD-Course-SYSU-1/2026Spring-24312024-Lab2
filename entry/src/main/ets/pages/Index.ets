/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import { textRecognition } from '@kit.CoreVisionKit'
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { LengthMetrics } from '@kit.ArkUI';

@Entry
@Component
struct Index {
  private imageSource: image.ImageSource | undefined = undefined;
  @State chooseImage: PixelMap | undefined = undefined;
  @State dataValues: string = '';

  build() {
    Column() {
      Row() {
        Image(this.chooseImage)
          .objectFit(ImageFit.Contain)
      }
      .height('50%')
      .margin({
        bottom: LengthMetrics.vp(24)
      })

      Row() {
        Scroll() {
          Text(this.dataValues)
            .copyOption(CopyOptions.LocalDevice)
            .margin(10)
            .width('90%')
        }
        .margin(10)
        .width('90%')
        .backgroundColor('rgba(0, 0, 0, 0.05)')
        .borderRadius(16)
        .height('100%') // Sets the height of the Scroll component.
      }
      .height('30%')
      .margin({
        bottom: LengthMetrics.vp(12)
      })

      Button('Select image')
        .onClick(() => {
          // Pull up the gallery.
          this.selectImage()
        })
        .width('80%')
        .margin({
          bottom: LengthMetrics.vp(12)
        })

      Button('Start recognition')
        .fontColor(Color.White)
        .alignSelf(ItemAlign.Center)
        .width('80%')
        .margin({
          bottom: LengthMetrics.vp(16)
        })
        .onClick(async () => {
          this.textRecognitionTest();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.End)
  }

  private async textRecognitionTest() {
    if (!this.chooseImage) {
      return;
    }
    let visionInfo: textRecognition.VisionInfo = {
      pixelMap: this.chooseImage
    };
    let textConfiguration: textRecognition.TextRecognitionConfiguration = {
      isDirectionDetectionSupported: false
    };
    // Call the OCR API.
    try {
      let recognitionResult = await textRecognition.recognizeText(visionInfo, textConfiguration);
      let recognitionString = recognitionResult.value;
      this.dataValues = recognitionString;
      hilog.info(0x0000, 'OCRDemo', `Succeeded in recognizing text：${recognitionString}`);
    } catch (error) {
      hilog.error(0x0000, 'OCRDemo', "recognizeText error: " + JSON.stringify(error));
    }

    if(this.chooseImage && this.imageSource) {
      this.chooseImage.release();
      this.imageSource.release();
    }
  }

  async aboutToAppear(): Promise<void> {
    const initResult = await textRecognition.init();
    hilog.info(0x0000, 'OCRDemo', `OCR service initialization result:${initResult}`);
  }

  async aboutToDisappear(): Promise<void> {
    await textRecognition.release();
    hilog.info(0x0000, 'OCRDemo', 'OCR service released successfully');
  }

  private async selectImage() {
    let uri = await this.openPhoto();
    if (uri === undefined) {
      hilog.error(0x0000, 'OCRDemo', "Failed to get uri.");
      return;
    }
    this.loadImage(uri);
  }

  private openPhoto(): Promise<string> {
    return new Promise<string>((resolve, reject) => {
      let photoPicker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      photoPicker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      }).then((res: photoAccessHelper.PhotoSelectResult) => {
        resolve(res.photoUris[0]);
      }).catch((err: BusinessError) => {
        hilog.error(0x0000, 'OCRDemo', `Failed to get photo image uri. code：${err.code}，message：${err.message}`);
        reject('');
      })
    })
  }

  private loadImage(name: string) {
    setTimeout(async () => {
      try {
        let fileSource = await fileIo.open(name, fileIo.OpenMode.READ_ONLY);
        this.imageSource = image.createImageSource(fileSource.fd);
        this.chooseImage = await this.imageSource.createPixelMap();
      } catch (error) {
        hilog.error(0x0000, 'OCRDemo', "fileIo.open error: " + JSON.stringify(error));
      }
    }, 100)
  }
}