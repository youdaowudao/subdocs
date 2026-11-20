(() => {
    const text = document.body?.innerText || '';
    const buttons = Array.from(document.querySelectorAll('button')).filter(b => b.getClientRects().length);
    let action = null;
    const skip = buttons.find(b => /^(Skip|跳过)$/.test(b.innerText.trim()) && !b.disabled);
    const next = buttons.find(b => /^(Continue|继续)$/.test(b.innerText.trim()) && !b.disabled);
    const go = buttons.find(b => /^(Go to ChatGPT|Continue to ChatGPT|前往 ChatGPT|进入 ChatGPT)$/.test(b.innerText.trim()) && !b.disabled);
    if (go) { action = go.innerText; go.click(); }
    else if (/What kind of work|你从事什么工作|按你的工作方式|哪一项最能描述你的工作/.test(text)) {
        if (skip) { action = skip.innerText; skip.click(); }
        else {
            const input = Array.from(document.querySelectorAll('input')).find(x => /engineering/i.test(x.value));
            const label = Array.from(document.querySelectorAll('label,[role="radio"],[role="option"]')).find(x => /^(工程|Engineering)$/.test(x.innerText.trim()));
            if (input && !input.checked) { action = '选择工程'; input.click(); }
            else if (label && !input?.checked) { action = '选择工程'; label.click(); }
            else if (next) { action = next.innerText; next.click(); }
        }
    } else if (skip) { action = skip.innerText; skip.click(); }
    else if (next) { action = next.innerText; next.click(); }
    const editors = Array.from(document.querySelectorAll('textarea,[contenteditable="true"]')).filter(x => x.getClientRects().length);
    const onboarding = /Welcome to ChatGPT desktop|欢迎使用 ChatGPT 桌面版|What kind of work|你从事什么工作|哪一项最能描述/.test(text);
    return JSON.stringify({done: !onboarding && editors.length > 0, text: text.slice(0, 3500), action,
        buttons: buttons.map(b => ({text: b.innerText, label: b.getAttribute('aria-label'), testid: b.getAttribute('data-testid')})),
        inputs: Array.from(document.querySelectorAll('input,textarea,[contenteditable="true"]')).map(x => ({tag: x.tagName, type: x.type, value: x.value, checked: x.checked, parent: x.parentElement?.innerText?.slice(0,250), role: x.getAttribute('role'), placeholder: x.getAttribute('placeholder'), label: x.getAttribute('aria-label'), testid: x.getAttribute('data-testid')}))});
})()
