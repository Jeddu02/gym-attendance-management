import { useEffect, useState } from 'react';

/** Mounted only inside the verified Owner view. No forced activation or reload. */
export function OwnerUpdateNotice() {
  const [available, setAvailable] = useState(false);
  const [instructions, setInstructions] = useState(false);

  useEffect(() => {
    if (!('serviceWorker' in navigator)) return;
    let active = true;
    let registration: ServiceWorkerRegistration | undefined;
    let installing: ServiceWorker | null = null;
    const inspect = () => {
      if (active) setAvailable(Boolean(registration?.waiting));
    };
    const watchInstalling = () => {
      installing?.removeEventListener('statechange', inspect);
      installing = registration?.installing ?? null;
      installing?.addEventListener('statechange', inspect);
      inspect();
    };
    void navigator.serviceWorker.ready.then((ready) => {
      if (!active) return;
      registration = ready;
      ready.addEventListener('updatefound', watchInstalling);
      watchInstalling();
    }).catch(() => { /* Update discovery must not block gym operations. */ });
    window.addEventListener('focus', inspect);
    return () => {
      active = false;
      window.removeEventListener('focus', inspect);
      registration?.removeEventListener('updatefound', watchInstalling);
      installing?.removeEventListener('statechange', inspect);
    };
  }, []);

  if (!available) return null;
  return (
    <aside className="feedback" role="status" aria-label="Application update available">
      <p>A GYMFORCE update is ready. Your current work will not be reloaded.</p>
      <button type="button" aria-expanded={instructions} onClick={() => setInstructions(value => !value)}>How to apply safely</button>
      {instructions && <p>Finish or resolve pending operations first. Then close every GYMFORCE tab and installed app window on this device and reopen the app. The browser applies the waiting update after all current app windows close. Do not close an active or uncertain payment, check-in or PIN request just to update.</p>}
    </aside>
  );
}
