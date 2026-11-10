import { lazy, StrictMode, Suspense } from 'react';
import { createRoot } from 'react-dom/client';
import { PinSetupPage } from './components/PinSetupPage';
import { EntrancePage } from './components/EntrancePage';
import './style.css';

// eslint-disable-next-line react-refresh/only-export-components -- Application entrypoint is not a reusable component module.
const OwnerApp = lazy(() => import('./App').then((module) => ({ default: module.App })));

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    {window.location.pathname.replace(/\/+$/, '') === '/pin-setup' ? (
      <PinSetupPage purpose="enrollment" />
    ) : window.location.pathname.replace(/\/+$/, '') === '/pin-reset' ? (
      <PinSetupPage purpose="reset" />
    ) : window.location.pathname.replace(/\/+$/, '') === '/entrance' ? (
      <EntrancePage />
    ) : <Suspense fallback={<main className="login-page"><p role="status">Loading GYMFORCE…</p></main>}><OwnerApp /></Suspense>}
  </StrictMode>,
);
