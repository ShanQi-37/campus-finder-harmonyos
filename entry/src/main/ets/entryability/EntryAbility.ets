import { UIAbility, ConfigurationConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
export default class EntryAbility extends UIAbility {
  onWindowStageCreate(stage: window.WindowStage): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    stage.loadContent('pages/Index');
  }
}
