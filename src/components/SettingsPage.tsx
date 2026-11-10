import { useEffect, useRef, useState, type FormEvent } from 'react';
import { entranceDestination } from '../lib/entrance-link';

export function SettingsPage() {
  const [baseUrl, setBaseUrl] = useState(() => window.location.protocol === 'https:' ? window.location.origin : '');
  const [verified, setVerified] = useState(false);
  const [busy, setBusy] = useState(false);
  const [png, setPng] = useState('');
  const [message, setMessage] = useState('');
  const generation = useRef(0);
  const mounted = useRef(false);
  const inFlight = useRef(false);

  let destination = '';
  let validationMessage = '';
  if (baseUrl.trim()) {
    try {
      destination = entranceDestination(baseUrl.trim());
    } catch {
      validationMessage = 'Enter a public HTTPS base URL without credentials, query parameters, or a fragment.';
    }
  }

  useEffect(() => {
    mounted.current = true;
    return () => { mounted.current = false; };
  }, []);

  function resetPreview() {
    ++generation.current;
    setPng('');
    setMessage('');
  }

  async function generate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (inFlight.current || !destination || !verified) return;
    inFlight.current = true;
    const ticket = ++generation.current;
    setBusy(true);
    setPng('');
    setMessage('');
    try {
      const { toDataURL } = await import('qrcode');
      const image = await toDataURL(destination, {
        type: 'image/png', margin: 4, errorCorrectionLevel: 'M', width: 640,
      });
      if (!mounted.current || ticket !== generation.current) return;
      setPng(image);
      setMessage('Entrance QR image generated. Scan the preview on a phone and check the displayed destination before printing.');
    } catch {
      if (mounted.current && ticket === generation.current) setMessage('The QR image could not be generated. Please try again.');
    } finally {
      inFlight.current = false;
      if (mounted.current && ticket === generation.current) setBusy(false);
    }
  }

  function download() {
    if (!png || !verified || !destination) return;
    const link = document.createElement('a');
    link.href = png;
    link.download = 'gymforce-entrance.png';
    link.click();
  }

  async function copyDestination() {
    if (!destination) return;
    const ticket = generation.current;
    try {
      await navigator.clipboard.writeText(destination);
      if (mounted.current && ticket === generation.current) setMessage('Public entrance URL copied.');
    } catch {
      if (mounted.current && ticket === generation.current) setMessage('Copy is unavailable. Select the displayed entrance URL and copy it manually.');
    }
  }

  return (
    <section className="plans-module" aria-label="Entrance QR settings">
      <div className="plans-toolbar"><div><strong>Permanent entrance QR</strong><p>Create a printable PNG for the public entrance page.</p></div></div>
      <div className="members-table-card purchase-form-card">
        <div className="members-table-heading"><div><h2>Public entrance destination</h2><p>Use the permanent HTTPS address on the gym's chosen hosting provider. A free provider address is sufficient.</p></div></div>
        <form className="purchase-form" onSubmit={generate}>
          <label className="member-form-field">Public HTTPS base URL
            <input type="url" value={baseUrl} placeholder="https://your-gym.example" required maxLength={2048} autoComplete="off" spellCheck={false} disabled={busy} onChange={(event) => {
              resetPreview();
              setVerified(false);
              setBaseUrl(event.target.value);
            }} />
          </label>
          {validationMessage && <p className="members-error" role="alert">{validationMessage}</p>}
          {destination && <div>
            <label className="member-form-field">Exact QR destination<input value={destination} readOnly autoComplete="off" spellCheck={false} onFocus={(event) => event.currentTarget.select()} /></label>
            <button type="button" className="secondary-button" onClick={() => void copyDestination()}>Copy entrance URL</button>
          </div>}
          <label className="payment-evidence-attestation"><input type="checkbox" checked={verified} disabled={busy || !destination} required onChange={(event) => {
            resetPreview();
            setVerified(event.target.checked);
          }} /><span>I verified that the displayed destination is the gym's permanent published entrance URL.</span></label>
          <div className="member-modal-actions"><button type="submit" className="primary-button" disabled={busy || !destination || !verified}>{busy ? 'Generating QR image...' : 'Generate entrance QR (PNG)'}</button></div>
        </form>
        {message && <p className="feedback" role="status" aria-live="polite">{message}</p>}
        {png && <section aria-label="Generated entrance QR preview">
          <img src={png} alt={`Entrance QR code for ${destination}`} width={320} height={320} style={{ maxWidth: '100%', height: 'auto' }} />
          <div className="member-modal-actions"><button type="button" className="primary-button" disabled={!verified || busy} onClick={download}>Download entrance QR (PNG)</button></div>
        </section>}
      </div>
      <p className="members-footnote">The QR image contains only the displayed public entrance URL. Keep that address stable after printing. The image is generated locally; downloading it does not publish a website or enable check-in services.</p>
    </section>
  );
}
