// The expression runs in the official Codex renderer through Electron CDP.
(async (write, timeoutMs) => {
    const until = Date.now() + timeoutMs;
    let client;
    do {
        const root = globalThis.__STATSIG__;
        client = root?.firstInstance ?? root?.instance?.();
        if (client?.loadingStatus === 'Ready') break;
        await new Promise(resolve => setTimeout(resolve, 200));
    } while (Date.now() < until);
    if (client?.loadingStatus !== 'Ready' || typeof client.dataAdapter?._getCacheKey !== 'function') {
        throw new Error('Statsig did not become ready or has an unsupported cache adapter.');
    }

    const context = client.getContext();
    const cacheKey = client.dataAdapter._getCacheKey(context.user);
    if (typeof cacheKey !== 'string' || !cacheKey.startsWith('statsig.cached.evaluations.')) {
        throw new Error('Unrecognized Statsig cache key.');
    }

    const cacheText = localStorage.getItem(cacheKey);
    const wrapper = cacheText === null ? null : JSON.parse(cacheText);
    if (cacheText !== null && (!wrapper || typeof wrapper !== 'object' || Array.isArray(wrapper))) {
        throw new Error('Invalid existing Statsig cache record.');
    }
    const stringData = typeof wrapper?.data === 'string';
    let payload = wrapper ? (stringData ? JSON.parse(wrapper.data) : wrapper.data) : null;
    if (write && cacheText === null) {
        if (context.values?.has_updates === true) {
            payload = JSON.parse(JSON.stringify(context.values));
        } else {
            // The upstream bootstrap format is used only for a missing current key.
            payload = {
                has_updates: true,
                response_format: 'init-v2',
                time: Date.now(),
                feature_gates: {},
                dynamic_configs: {},
                layer_configs: { '72216192': { v: '0', r: 'usegoodai-codex-zh', s: [], is_device_based: true } },
                values: { '0': { enable_i18n: true, locale_source: 'IDE' } },
                param_stores: {},
                sdk_flags: {},
                exposures: {}
            };
        }
    }
    if (!payload || typeof payload.layer_configs !== 'object' || payload.layer_configs === null) {
        throw new Error('No supported Statsig evaluations are available for the current client.');
    }

    const knownLayers = ['72216192', '4269166702'].filter(key =>
        Object.prototype.hasOwnProperty.call(payload.layer_configs, key));
    if (knownLayers.length !== 1) {
        throw new Error('The localization layer could not be identified unambiguously.');
    }
    const layerKey = knownLayers[0];
    const layer = payload.layer_configs[layerKey];
    if (!layer || typeof layer !== 'object' || Array.isArray(layer)) {
        throw new Error('Unsupported localization layer.');
    }

    const value = layer.v !== undefined ? payload.values?.[String(layer.v)] : (layer.value ?? layer);
    if (!value || typeof value.enable_i18n !== 'boolean') {
        throw new Error('The localization flag is missing or invalid.');
    }

    if (write && (!wrapper || value.enable_i18n !== true)) {
        if (layer.v !== undefined && value.enable_i18n !== true) {
            // Layer value slots can be shared with unrelated evaluations.
            let index = 0;
            while (Object.prototype.hasOwnProperty.call(payload.values, String(index))) index += 1;
            payload.values[String(index)] = { ...value, enable_i18n: true };
            layer.v = String(index);
        } else {
            value.enable_i18n = true;
        }
        const record = wrapper ?? {
            source: 'Bootstrap',
            receivedAt: Date.now(),
            stableID: context.stableID ?? null,
            fullUserHash: null
        };
        record.data = wrapper && !stringData ? payload : JSON.stringify(payload);
        localStorage.setItem(cacheKey, JSON.stringify(record));
    }

    const live = client.getLayer?.('72216192', { disableExposureLog: true })?.get('enable_i18n', null);
    return { enabled: write || value.enable_i18n === true, liveEnabled: live === true };
})
