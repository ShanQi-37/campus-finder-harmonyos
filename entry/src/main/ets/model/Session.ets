export interface LoginSession {
  token: string;
  actor: string;
  displayName: string;
}

export class Session {
  static actor: string = '';
  static token: string = '';
  static displayName: string = '';
  static onExpired: () => void = () => {};

  static start(session: LoginSession): void {
    Session.actor = session.actor;
    Session.token = session.token;
    Session.displayName = session.displayName;
  }

  static clear(): void {
    Session.actor = '';
    Session.token = '';
    Session.displayName = '';
  }

  static expire(token: string): void {
    if (token.length && token === Session.token) { Session.onExpired(); }
  }
}
