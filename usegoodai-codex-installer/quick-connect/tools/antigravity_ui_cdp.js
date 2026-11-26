'use strict';
// Test-only browser automation against the real Electron-rendered App.
// The debugging endpoint is bound to loopback, used only with a fake Key,
// and the script interacts with the visible composer, not internal APIs.
const fs = require('node:fs');
const path = require('node:path');
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
const port = Number(process.env.AGY_TEST_CDP_PORT);
const evidence = process.env.AGY_TEST_EVIDENCE;
if (!port || !evidence || typeof WebSocket === 'undefined') process.exit(2);

async function connectPage() {
  for (let i = 0; i < 90; i++) {
    try {
      const targets = await (await fetch('http://127.0.0.1:' + port + '/json/list')).json();
      const page = targets.find(t => t.type === 'page' &&
        /^https?:\/\/(127\.0\.0\.1|localhost)(:|\/)/.test(t.url) &&
        t.webSocketDebuggerUrl);
      if (page) {
        const ws = new WebSocket(page.webSocketDebuggerUrl);
        await new Promise((resolve, reject) => {
          ws.addEventListener('open', resolve, { once: true });
          ws.addEventListener('error', reject, { once: true });
        });
        return ws;
      }
    } catch (_) { /* The App is still starting. */ }
    await pause(1000);
  }
  throw new Error('No real App renderer was available for the local test.');
}
async function main() {
  const ws = await connectPage();
  let nextId = 0;
  const pending = new Map();
  ws.addEventListener('message', event => {
    const message = JSON.parse(String(event.data));
    const p = pending.get(message.id);
    if (!p) return;
    pending.delete(message.id);
    if (message.error) p.reject(new Error('CDP command failed'));
    else p.resolve(message.result);
  });
  function call(method, params = {}) {
    const id = ++nextId;
    return new Promise((resolve, reject) => {
      pending.set(id, {resolve, reject});
      ws.send(JSON.stringify({id, method, params}));
      setTimeout(() => { if (pending.delete(id)) reject(new Error('CDP command timed out')); }, 10000).unref();
    });
  }
  async function evaluate(expression) {
    const result = await call('Runtime.evaluate', {expression, returnByValue: true});
    return result.result?.value;
  }
  async function screenshot(filename) {
    const shot = await call('Page.captureScreenshot', {format:'png', captureBeyondViewport:false});
    fs.writeFileSync(path.join(evidence,filename), Buffer.from(shot.data,'base64'));
  }
  try {
    let composer;
    for (let i = 0; i < 90; i++) {
      composer = await evaluate(`(() => {
        const els = Array.from(document.querySelectorAll('textarea,[contenteditable="true"],[role="textbox"]'));
        const visible = els.map(el => ({el, r:el.getBoundingClientRect()}))
          .filter(({r})=>r.width>100 && r.height>15 && r.bottom>innerHeight/2 && r.right>innerWidth/3 && r.top<innerHeight)
          .sort((a,b)=>b.r.bottom-a.r.bottom);
        if (!visible.length) return null;
        const r=visible[0].r;
        return {x:r.left + Math.min(50, r.width/2), y:r.top+r.height/2};
      })()`);
      if (composer) break;
      await pause(1000);
    }
    if (!composer) throw new Error('The actual App composer did not become visible.');
    await screenshot('renderer-before.png');
    await call('Input.dispatchMouseEvent',{type:'mousePressed',button:'left',clickCount:1,...composer});
    await call('Input.dispatchMouseEvent',{type:'mouseReleased',button:'left',clickCount:1,...composer});
    await call('Input.insertText',{text:'test'});
    await call('Input.dispatchKeyEvent',{type:'keyDown',key:'Enter',code:'Enter',windowsVirtualKeyCode:13,nativeVirtualKeyCode:13});
    await call('Input.dispatchKeyEvent',{type:'keyUp',key:'Enter',code:'Enter',windowsVirtualKeyCode:13,nativeVirtualKeyCode:13});
    let replied = false;
    for (let i=0;i<45;i++) {
      if (await evaluate("document.body.innerText.includes('UseGoodAI native desktop test passed')")) {replied=true;break;}
      await pause(1000);
    }
    await screenshot('renderer-after.png');
    if (!replied) throw new Error('No mock response was shown in the actual renderer.');
    console.log('Actual Antigravity renderer: test submitted and mock reply visible.');
  } finally { ws.close(); }
}
main().catch(err => {console.error(err.message);process.exitCode=1;});
