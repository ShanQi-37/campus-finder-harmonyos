import { common } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { camera, cameraPicker } from '@kit.CameraKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';

async function readMedia(uri: string, video: boolean): Promise<ArrayBuffer> {
  const file = await fileIo.open(uri, fileIo.OpenMode.READ_ONLY);
  try {
    const size = (await fileIo.stat(file.fd)).size;
    if (size <= 0) { throw new Error('没有读到媒体内容，请重新选择'); }
    if (video) {
      if (size > 24 * 1024 * 1024) { throw new Error('视频超过 24 MB，请选择或录制更小的视频'); }
      const data = new ArrayBuffer(size);
      let offset = 0;
      while (offset < size) {
        const chunk = new ArrayBuffer(Math.min(65536, size - offset));
        const read = await fileIo.read(file.fd, chunk);
        if (read <= 0) { throw new Error('视频读取不完整，请重试'); }
        new Uint8Array(data).set(new Uint8Array(chunk, 0, read), offset);
        offset += read;
      }
      return data;
    }
    const source = image.createImageSource(file.fd);
    try {
      const info = await source.getImageInfo();
      const ratio = Math.min(1, 1200 / Math.max(info.size.width, info.size.height));
      const pixels = await source.createPixelMap({
        desiredSize: { width: Math.max(1, Math.round(info.size.width * ratio)),
          height: Math.max(1, Math.round(info.size.height * ratio)) }
      });
      const packer = image.createImagePacker();
      try {
        return await packer.packing(pixels, { format: 'image/jpeg', quality: 85 });
      } finally {
        await pixels.release();
        await packer.release();
      }
    } finally {
      await source.release();
    }
  } finally {
    await fileIo.close(file);
  }
}

export class MediaPicker {
  static async choose(context: common.UIAbilityContext, video: boolean, fromAlbum: boolean): Promise<ArrayBuffer | null> {
    if (fromAlbum) {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = video
        ? photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE
        : photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const result: photoAccessHelper.PhotoSelectResult | null | undefined =
        await new photoAccessHelper.PhotoViewPicker().select(options);
      const uri = result?.photoUris?.[0];
      return uri ? await readMedia(uri, video) : null;
    }
    const output = context.cacheDir + '/campus-capture-' + Date.now() + (video ? '.mp4' : '.jpg');
    const file = await fileIo.open(output, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
    await fileIo.close(file);
    try {
      const result: cameraPicker.PickerResult | null | undefined = await cameraPicker.pick(context,
        [video ? cameraPicker.PickerMediaType.VIDEO : cameraPicker.PickerMediaType.PHOTO],
        { cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK, saveUri: fileUri.getUriFromPath(output),
          videoDuration: 15 });
      if (!result || result.resultCode !== 0) { return null; }
      return await readMedia(output, video);
    } finally {
      await fileIo.unlink(output);
    }
  }
}
