import { UIAbility, ConfigurationConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
export default class EntryAbility extends UIAbility {
  onWindowStageCreate(stage: window.WindowStage): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      stage.loadContent('pages/Index', (error) => {
        if (error.code) { hilog.error(0, 'CampusFinder', 'Page load failed: %{public}s', JSON.stringify(error)); }
      });
    } catch (error) { hilog.error(0, 'CampusFinder', 'Ability initialization failed: %{public}s', JSON.stringify(error)); }
  }
}
