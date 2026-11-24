import { Recognition } from './Models';

export interface DraftSuggestion {
  title: string;
  description: string;
}

export function suggestNotice(recognition: Recognition, kind: string): DraftSuggestion {
  const verb = kind === 'lost' ? '寻找' : '拾到';
  const object = recognition.object.trim();
  const features = recognition.features.map((feature: string) => feature.trim()).filter((feature: string) => feature.length > 0);
  return {
    title: (verb + object).slice(0, 36),
    description: features.length ? (verb + '一件' + object + '，可见外观：' +
      features.join('、') + '。').slice(0, 300) : ''
  };
}
