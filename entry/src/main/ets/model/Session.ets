// Fixed fictional roles make both sides of the workflow demonstrable. This is not login.
export class Session {
  static actor: string = 'demo-user';
  static displayName(): string { return Session.actor === 'demo-user' ? '校园体验同学' : (Session.actor === 'peer-01' ? '互助体验同学' : '志愿体验同学'); }
}
