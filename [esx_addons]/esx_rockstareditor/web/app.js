/* SPDX-License-Identifier: GPL-3.0-only */
(() => {
  'use strict';

  const $ = (id) => document.getElementById(id);
  const native = typeof GetParentResourceName === 'function';
  const preview = !native && new URLSearchParams(location.search).get('preview') === '1';
  const fallback = {};
  document.querySelectorAll('[data-text]').forEach((node) => {
    fallback[node.dataset.text] = node.textContent;
  });
  Object.assign(fallback, {
    ui_standby: 'STANDBY',
    ui_ready: 'Ready for your next take', ui_recording: 'Recording in progress',
    ui_unavailable: 'Recording unavailable', ui_external: 'Started outside this menu',
    ui_ready_hint: 'Set the scene. Start recording. Make it yours.',
    ui_recording_hint: 'Close this menu to keep filming. Come back to save your take.',
    ui_confirm_discard: 'Discard this take?',
    ui_confirm_discard_text: 'The current recording will be stopped without saving. Saved clips are unaffected.',
    ui_confirm_editor: 'Leave for the editor?',
    ui_confirm_editor_text: 'You will leave this server session to open Rockstar Editor. Save your current take first.',
    ui_confirm_delete: 'Discard recording', ui_confirm_open: 'Leave & open editor',
    ui_request_failed: 'Something went wrong. Please try again.',
    ui_preview_saved: 'Preview: clip save requested.',
    ui_preview_discarded: 'Preview: recording discarded.',
    ui_preview_editor: 'Preview: Rockstar Editor would open here.',
  });
  const state = {
    open: false,
    busy: false,
    confirmation: null,
    epoch: 0,
    locale: {},
    recording: false,
    available: true,
    editorAvailable: true,
    elapsed: false,
    external: false,
    showIndicator: true,
  };
  let previewStarted = 0;
  let previousFocus;

  const t = (key) => state.locale[key] || fallback[key] || key;
  const timecode = () => {
    if (state.recording && (state.external || state.elapsed === false)) return '—:—';
    const seconds = Math.max(0, Math.floor(Number(state.elapsed || 0) / 1000));
    return `${String(Math.floor(seconds / 60)).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`;
  };

  function notify(message, error = false) {
    $('message').textContent = String(message || '');
    $('message').classList.toggle('error', error);
    $('message').hidden = !message;
  }

  function configure(data) {
    if (data.locale && typeof data.locale === 'object') {
      state.locale = data.locale;
      document.documentElement.lang = typeof data.language === 'string' ? data.language : 'en';
      document.querySelectorAll('[data-text]').forEach((node) => { node.textContent = t(node.dataset.text); });
      document.querySelectorAll('[data-label]').forEach((node) => { node.setAttribute('aria-label', t(node.dataset.label)); });
    }
    const theme = data.theme;
    if (theme && typeof theme === 'object') {
      for (const [variable, field] of Object.entries({ '--brand': 'primaryColor', '--base': 'backgroundColor', '--panel': 'secondaryColor', '--raised': 'accentColor' })) {
        if (typeof theme[field] === 'string' && /^#[0-9a-f]{3,8}$/i.test(theme[field])) {
          document.documentElement.style.setProperty(variable, theme[field]);
        }
      }
    }
  }

  function update(data) {
    const incoming = data.state;
    if (incoming && typeof incoming === 'object') {
      for (const key of ['recording', 'available', 'editorAvailable', 'external']) {
        if (typeof incoming[key] === 'boolean') state[key] = incoming[key];
      }
      state.elapsed = typeof incoming.elapsed === 'number' && Number.isFinite(incoming.elapsed) ? incoming.elapsed : false;
    }
    if (typeof data.showIndicator === 'boolean') state.showIndicator = data.showIndicator;
    render();
  }

  function render() {
    $('menu').hidden = !state.open;
    $('menu').classList.toggle('is-recording', state.recording);
    $('timecode').textContent = timecode();
    $('indicator-time').textContent = timecode();
    $('recording-indicator').hidden = !state.recording || !state.showIndicator || state.open;
    $('status-label').textContent = state.recording ? 'REC' : state.available ? t('ui_standby') : '—';
    $('status-title').textContent = t(!state.available ? 'ui_unavailable' : state.recording ? 'ui_recording' : 'ui_ready');
    $('capture-hint').textContent = t(state.recording ? state.external ? 'ui_external' : 'ui_recording_hint' : 'ui_ready_hint');
    $('start').disabled = state.busy || !state.available || state.recording;
    $('save').disabled = state.busy || !state.available || !state.recording;
    $('discard').disabled = $('save').disabled;
    $('editor').disabled = state.busy || !state.editorAvailable || state.recording;
    $('confirm').disabled = state.busy;
    $('menu').setAttribute('aria-busy', String(state.busy));
  }

  function dismissConfirmation() {
    state.confirmation = null;
    $('confirmation').hidden = true;
    $('workspace').inert = false;
    if (state.open && previousFocus?.isConnected) previousFocus.focus();
  }

  function confirmAction(action) {
    previousFocus = document.activeElement;
    state.confirmation = action;
    $('confirm-title').textContent = t(action === 'discard' ? 'ui_confirm_discard' : 'ui_confirm_editor');
    $('confirm-text').textContent = t(action === 'discard' ? 'ui_confirm_discard_text' : 'ui_confirm_editor_text');
    $('confirm').textContent = t(action === 'discard' ? 'ui_confirm_delete' : 'ui_confirm_open');
    $('confirm').classList.toggle('danger', action === 'discard');
    $('confirm-icon').querySelector('use').setAttribute('href', action === 'discard' ? '#icon-trash' : '#icon-edit');
    $('workspace').inert = true;
    $('confirmation').hidden = false;
    $('cancel-confirm').focus();
  }

  function closeLocal() {
    state.epoch += 1;
    state.open = false;
    state.busy = false;
    dismissConfirmation();
    notify('');
    render();
  }

  async function request(endpoint, payload = {}) {
    if (!native) return { ok: true };
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 9000);
    try {
      const response = await fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(payload),
        signal: controller.signal,
      });
      if (!response.ok) throw new Error('NUI request failed');
      return await response.json();
    } finally {
      clearTimeout(timeout);
    }
  }

  async function closeMenu() {
    closeLocal();
    try { await request('close'); } catch { /* Local closure remains immediate. */ }
  }

  function simulate(action) {
    if (action === 'start') {
      previewStarted = performance.now();
      return { ok: true, state: { recording: true, external: false, elapsed: 0 } };
    }
    if (action === 'editor') return { ok: true, message: t('ui_preview_editor') };
    return { ok: true, message: t(action === 'save' ? 'ui_preview_saved' : 'ui_preview_discarded'), state: { recording: false, external: false, elapsed: false } };
  }

  async function perform(action, confirmed = false) {
    if (state.busy || !state.open) return;
    const epoch = state.epoch;
    state.busy = true;
    notify('');
    render();
    try {
      const result = preview ? simulate(action) : await request('action', { action, confirmed });
      if (epoch !== state.epoch || !state.open) return;
      dismissConfirmation();
      if (result.state) update(result);
      if (result.message) notify(result.message, !result.ok);
      else if (!result.ok) notify(t('ui_request_failed'), true);
    } catch {
      if (epoch === state.epoch && state.open) {
        dismissConfirmation();
        notify(t('ui_request_failed'), true);
      }
    } finally {
      if (epoch === state.epoch) {
        state.busy = false;
        render();
      }
    }
  }

  document.querySelectorAll('[data-action]').forEach((button) => {
    button.addEventListener('click', () => {
      if (button.disabled) return;
      const action = button.dataset.action;
      if (action === 'discard' || action === 'editor') confirmAction(action);
      else void perform(action);
    });
  });
  $('close').addEventListener('click', () => void closeMenu());
  $('cancel-confirm').addEventListener('click', dismissConfirmation);
  $('confirm').addEventListener('click', () => {
    if (state.confirmation) void perform(state.confirmation, true);
  });

  document.addEventListener('keydown', (event) => {
    if (!state.open) return;
    if (event.key === 'Escape') {
      event.preventDefault();
      if (state.confirmation && !state.busy) dismissConfirmation();
      else void closeMenu();
    }
    if (event.key === 'Tab') {
      const container = state.confirmation ? $('confirmation') : $('menu');
      const controls = [...container.querySelectorAll('button:not(:disabled)')].filter((node) => node.offsetParent !== null && !node.closest('[inert]'));
      const first = controls[0];
      const last = controls.at(-1);
      if (event.shiftKey && (document.activeElement === first || !controls.includes(document.activeElement))) {
        event.preventDefault(); last?.focus();
      } else if (!event.shiftKey && (document.activeElement === last || !controls.includes(document.activeElement))) {
        event.preventDefault(); first?.focus();
      }
    }
  });

  window.addEventListener('message', ({ data }) => {
    if (!data || typeof data !== 'object') return;
    if (data.action === 'open') {
      state.epoch += 1;
      state.open = true;
      state.busy = false;
      configure(data);
      dismissConfirmation();
      notify('');
      update(data);
      $('menu').focus();
    } else if (data.action === 'state') update(data);
    else if (data.action === 'close') closeLocal();
    else if (data.action === 'reset') {
      state.recording = false;
      state.elapsed = false;
      closeLocal();
    }
  });

  if (preview) {
    state.open = true;
    render();
    setInterval(() => {
      if (state.recording) { state.elapsed = performance.now() - previewStarted; render(); }
    }, 500);
  }
})();
