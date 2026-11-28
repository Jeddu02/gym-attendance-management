import { useEffect, useRef, useState } from 'react';

type WidgetApi = {
  render: (container: HTMLElement, options: { sitekey: string; action: string; callback: (token: string) => void;
    'expired-callback': () => void; 'error-callback': () => void; 'timeout-callback': () => void; 'response-field': boolean }) => string;
  remove: (id: string) => void;
};
const scriptUrl = 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';
const api = () => (window as Window & { turnstile?: WidgetApi }).turnstile;
let loading: Promise<WidgetApi> | undefined;
function load(): Promise<WidgetApi> {
  const existing = api();
  if (existing) return Promise.resolve(existing);
  if (!loading) loading = new Promise<WidgetApi>((resolve, reject) => {
    const script = document.createElement('script');
    script.src = scriptUrl;
    script.async = true;
    const timer = window.setTimeout(fail, 15000);
    function fail() { window.clearTimeout(timer); script.remove(); reject(new Error('Security check unavailable')); }
    script.onerror = fail;
    script.onload = () => {
      window.clearTimeout(timer);
      const ready = api();
      if (ready) resolve(ready); else fail();
    };
    document.head.append(script);
  }).catch((error: unknown) => { loading = undefined; throw error; });
  return loading;
}
export function TurnstileChallenge({siteKey, onToken}: {siteKey: string; onToken: (token: string) => void}) {
  const element = useRef<HTMLDivElement>(null);
  const [attempt, setAttempt] = useState(0);
  const [failed, setFailed] = useState(false);
  useEffect(() => {
    let active = true;
    let widget: string | undefined;
    let instance: WidgetApi | undefined;
    onToken('');
    void load().then((ready) => {
      if (!active || !element.current) return;
      instance = ready;
      widget = ready.render(element.current, {
        sitekey: siteKey, action: 'member_checkin', 'response-field': false,
        callback: (token) => { if (active) {setFailed(false); onToken(token);} },
        'expired-callback': () => { if (active) onToken(''); },
        'error-callback': () => { if (active) {onToken(''); setFailed(true);} },
        'timeout-callback': () => { if (active) {onToken(''); setFailed(true);} },
      });
    }).catch(() => { if (active) {onToken(''); setFailed(true);} });
    return () => { active = false; if (widget !== undefined) instance?.remove(widget); onToken(''); };
  }, [siteKey, onToken, attempt]);
  return <div className="field"><div ref={element}/>{failed && <><p role="status">Security check unavailable. Retry or ask the Owner.</p><button className="secondary-button" type="button" onClick={() => {setFailed(false); setAttempt(n => n+1);}}>Retry security check</button></>}</div>;
}
