import test from 'node:test';
import assert from 'node:assert/strict';
import QRCode from 'qrcode';
import { entranceDestination } from '../src/lib/entrance-link.ts';

test('entrance QR encodes exactly the HTTPS public entrance address', async () => {
  const destination = entranceDestination(' https://EXAMPLE.com/entrance/ ');
  assert.equal(destination, 'https://example.com/entrance');
  assert.equal(entranceDestination('https://example.com'), destination);
  const png = await QRCode.toDataURL(destination, { margin: 4, errorCorrectionLevel: 'M', width: 640 });
  assert.ok(png.startsWith('data:image/png;base64,'));
  assert.equal(Buffer.from(png.split(',')[1], 'base64').subarray(1, 4).toString(), 'PNG');
});

test('entrance QR rejects credentials, private paths, query data and fragments', () => {
  for (const input of ['http://example.com', 'javascript:alert(1)', 'https://owner:secret@example.com',
    'https://example.com/pin-setup', 'https://example.com/?member=1', 'https://example.com/#token=secret', '/entrance']) {
    assert.throws(() => entranceDestination(input));
  }
});
