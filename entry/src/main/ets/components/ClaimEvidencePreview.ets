import { common } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { Api } from '../service/Api';
import { Colors } from './Common';

@ComponentV2
export struct ClaimEvidencePreview {
  @Param claimId: string = '';
  @Param mediaType: string = '';
  @Local previewUri: string = '';
  @Local failed: boolean = false;
  private active: boolean = true;
  private cachePath: string = '';

  aboutToAppear(): void { this.load(); }

  aboutToDisappear(): void {
    this.active = false;
    this.removeFromCache();
  }

  removeFromCache(): void {
    if (!this.cachePath) { return; }
    try { fileIo.unlinkSync(this.cachePath); } catch (_) {}
    this.cachePath = '';
  }

  async load(): Promise<void> {
    this.failed = false;
    this.previewUri = '';
    this.removeFromCache();
    try {
      const bytes = await Api.claimEvidence(this.claimId);
      if (!this.active) { return; }
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const suffix = this.mediaType === 'video' ? '.mp4' : '.jpg';
      this.cachePath = context.cacheDir + '/claim-evidence-' + this.claimId + '-' + Date.now() + suffix;
      const file = fileIo.openSync(this.cachePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      try {
        if (fileIo.writeSync(file.fd, bytes) !== bytes.byteLength) { throw new Error('核对附件读取不完整'); }
      } finally { fileIo.closeSync(file); }
      this.previewUri = fileUri.getUriFromPath(this.cachePath);
    } catch (error) {
      this.removeFromCache();
      if (this.active) { this.failed = true; }
    }
  }

  build() {
    Column({ space: 6 }) {
      if (this.failed) {
        Text('核对附件暂时无法打开').fontSize(12).fontColor(Colors.muted)
        Button('重新加载附件').constraintSize({ minHeight: 36 }).fontSize(12).fontColor(Colors.green)
          .backgroundColor(Colors.surface).onClick(() => { this.load(); })
      } else if (!this.previewUri.length) {
        Text('正在加载核对附件…').fontSize(12).fontColor(Colors.muted)
      } else if (this.mediaType === 'video') {
        Video({ src: this.previewUri }).width('100%').height(190).controls(true).autoPlay(false)
          .onError(() => { this.failed = true; })
      } else {
        Image(this.previewUri).width('100%').height(190).objectFit(ImageFit.Contain)
          .accessibilityText('核对图片').onError(() => { this.failed = true; })
      }
    }.width('100%').padding(8).backgroundColor(Colors.paper).borderRadius(10)
  }
}
