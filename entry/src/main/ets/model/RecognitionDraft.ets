import { Recognition } from './Models';

export interface DraftSuggestion {
  title: string;
  description: string;
}

export function suggestFoundNotice(recognition: Recognition): DraftSuggestion {
  const features = recognition.features.map((feature: string) => feature.trim()).filter((feature: string) => feature.length > 0);
  return {
    title: ('拾到' + recognition.object.trim()).slice(0, 36),
    description: features.length ? ('拾到一件' + recognition.object.trim() + '，可见外观：' +
      features.join('、') + '。').slice(0, 300) : ''
  };
}
