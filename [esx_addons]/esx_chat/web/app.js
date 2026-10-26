(() => {
    'use strict';

    const shell = document.getElementById('chatShell');
    const messageList = document.getElementById('messages');
    const form = document.getElementById('chatForm');
    const input = document.getElementById('chatInput');
    const commandPanel = document.getElementById('commandPanel');
    const commandRows = document.getElementById('commandRows');
    const emojiButton = document.getElementById('emojiButton');
    const emojiPicker = document.getElementById('emojiPicker');
    const emojiCategories = document.getElementById('emojiCategories');
    const emojiGrid = document.getElementById('emojiGrid');
    const rpPanel = document.getElementById('rpPanel');
    const rpCommandList = document.getElementById('rpCommandList');
    const modeButtons = [...document.querySelectorAll('.mode-tab[data-mode]')];
    const displayButton = document.getElementById('displayButton');
    const sendButton = document.getElementById('sendButton');

    const DISPLAY_MODES = ['always', 'onMessage', 'hidden'];
    const DEFAULT_LOCALE = {
        ui_placeholder_ooc: 'Out of character message...',
        ui_placeholder_rp: 'Choose an RP command or type /...',
        ui_placeholder_job: 'Message your job...',
        ui_placeholder_pm: 'Player ID and message...',
        ui_send: 'Send message',
        ui_display_always: 'Always visible',
        ui_display_onMessage: 'Visible on new messages',
        ui_display_hidden: 'Hidden'
    };

    const DEFAULT_RP_COMMANDS = [
        { name: '/me', description: 'Perform an action' },
        { name: '/do', description: 'Describe the surroundings' },
        { name: '/environment', description: 'Describe the environment' },
        { name: '/dice', description: 'Roll a die' },
        { name: '/try', description: 'Try an action' }
    ];

    const EMOJI_CATEGORIES = [
        { id: 'smileys', label: 'Smileys', icon: '😀', emojis: ['😀','😃','😄','😁','😆','😅','😂','🤣','😊','🙂','🙃','😉','😍','🥰','😘','😎','🤓','🥳','😏','😒','😔','😢','😭','😡','🤬','😱','😴','🤔','🫡','🤯'] },
        { id: 'people', label: 'People', icon: '👋', emojis: ['👋','🤚','🖐️','✋','🖖','👌','🤌','🤏','✌️','🤞','🫰','🤟','🤘','🤙','👈','👉','👆','👇','☝️','👍','👎','✊','👊','🤛','🤜','👏','🙌','🫶','🙏','💪'] },
        { id: 'hearts', label: 'Hearts', icon: '❤️', emojis: ['❤️','🧡','💛','💚','💙','💜','🖤','🤍','🤎','💔','❤️‍🔥','❤️‍🩹','💕','💞','💓','💗','💖','💘','💝','💟','❣️','💋','✨','⭐','🌟'] },
        { id: 'food', label: 'Food', icon: '🍔', emojis: ['🍎','🍓','🍉','🍌','🍕','🍔','🍟','🌭','🌮','🌯','🍗','🥩','🍿','🍩','🍪','🎂','🍫','☕','🥤','🧃','🍺','🍻','🥂','🍷','🍸'] },
        { id: 'activities', label: 'Activities', icon: '🎮', emojis: ['⚽','🏀','🏈','⚾','🎾','🏐','🎱','🏆','🥇','🎮','🕹️','🎲','🎯','🎸','🎵','🎧','🎤','🎬','🚗','🏍️','🚁','✈️','🚀','🔥','💨'] },
        { id: 'symbols', label: 'Symbols', icon: '✅', emojis: ['✅','❌','⚠️','❗','❓','💯','💥','💢','💤','♻️','🔞','🔒','🔓','🔑','📍','📌','📢','💬','💭','🆘','🆗','🆒','🆕','✔️','➕','➖','➡️','⬅️','⬆️','⬇️'] }
    ];

    const state = {
        open: false,
        mode: 'ooc',
        maxVisibleMessages: 5,
        keepMessages: 100,
        maxMessageLength: 280,
        autoHideAfter: 12000,
        history: [],
        historyIndex: 0,
        baseCommands: [
            ...DEFAULT_RP_COMMANDS,
            { name: '/ooc', description: 'Out of character chat' },
            { name: '/job', description: 'Message players with the same job' },
            { name: '/pm [id]', description: 'Private message' },
            { name: '/report', description: 'Report a player' },
            { name: '/help', description: 'Show all commands' }
        ],
        rpCommands: [...DEFAULT_RP_COMMANDS],
        suggestions: new Map(),
        emojiCategory: 'smileys',
        hideTimer: null,
        displayMode: 'onMessage',
        locale: { ...DEFAULT_LOCALE }
    };

    const t = (key) => state.locale[key] || DEFAULT_LOCALE[key] || key;

    function applyLocale(strings) {
        if (strings && typeof strings === 'object') {
            state.locale = { ...DEFAULT_LOCALE, ...strings };
        }

        for (const element of document.querySelectorAll('[data-i18n]')) {
            const value = state.locale[element.dataset.i18n];
            if (value) element.textContent = value;
        }

        sendButton.setAttribute('aria-label', t('ui_send'));
        updateDisplayButton();
        setPlaceholder();
    }

    const HEX_COLOR = /^#([0-9a-f]{3}|[0-9a-f]{6})$/i;

    function hexToRgb(value) {
        if (typeof value !== 'string' || !HEX_COLOR.test(value.trim())) return null;
        let hex = value.trim().slice(1);
        if (hex.length === 3) hex = hex.split('').map((c) => c + c).join('');
        const number = parseInt(hex, 16);
        return `${(number >> 16) & 255}, ${(number >> 8) & 255}, ${number & 255}`;
    }

    function applyTheme(theme) {
        if (!theme || typeof theme !== 'object') return;
        const root = document.documentElement.style;
        const map = {
            primaryColor: '--primary-rgb',
            backgroundColor: '--bg-rgb',
            secondaryColor: '--secondary-rgb',
            accentColor: '--accent-rgb'
        };

        for (const [key, variable] of Object.entries(map)) {
            const rgb = hexToRgb(theme[key]);
            if (!rgb) continue;
            root.setProperty(variable, rgb);
            if (key === 'primaryColor') root.setProperty('--primary', theme[key].trim());
        }
    }

    function updateDisplayButton() {
        const label = t(`ui_display_${state.displayMode}`);
        displayButton.title = label;
        displayButton.setAttribute('aria-label', label);
    }

    function updateVisibility() {
        const cards = messageList.children;
        const hiddenCount = state.open ? 0 : Math.max(0, cards.length - state.maxVisibleMessages);

        for (let i = 0; i < cards.length; i += 1) {
            cards[i].classList.toggle('is-overflow', i < hiddenCount);
        }

        shell.dataset.display = state.displayMode;

        if (state.open) {
            messageList.style.opacity = '1';
            messageList.scrollTop = messageList.scrollHeight;
        }
    }

    function setDisplayMode(mode) {
        if (!DISPLAY_MODES.includes(mode)) return;
        state.displayMode = mode;
        updateDisplayButton();
        updateVisibility();
        resetHideTimer();
    }

    const iconForType = (message) => {
        if (message.icon) {
            const known = new Set(['system', 'discord', 'user', 'message', 'user-plus']);
            if (known.has(message.icon)) return message.icon;
        }

        switch (message.type) {
            case 'system': return 'system';
            case 'pm': return 'message';
            case 'me':
            case 'do':
            case 'environment':
            case 'dice':
            case 'try': return 'user-plus';
            case 'anonymous': return 'discord';
            default: return 'user';
        }
    };

    const post = async (endpoint, data = {}) => {
        applyLocale();
    updateVisibility();

    if (typeof GetParentResourceName !== 'function') {
            return { ok: true };
        }

        try {
            const response = await fetch(`https://${GetParentResourceName()}/${endpoint}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify(data)
            });

            if (!response.ok) return { ok: false };
            return await response.json();
        } catch (_) {
            return { ok: false };
        }
    };

    const makeSvg = (icon) => {
        const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
        const use = document.createElementNS('http://www.w3.org/2000/svg', 'use');
        use.setAttribute('href', `#i-${icon}`);
        svg.appendChild(use);
        return svg;
    };

    const colorCodeMap = {
        '0': '#ffffff',
        '1': '#e74c3c',
        '2': '#2ecc71',
        '3': '#f1c40f',
        '4': '#3498db',
        '5': '#00bcd4',
        '6': '#9b59b6',
        '7': '#ffffff',
        '8': '#ff7f00',
        '9': '#9e9e9e'
    };

    function appendSafeColoredText(parent, value, rgbColor) {
        const text = String(value ?? '');
        let currentColor = Array.isArray(rgbColor) && rgbColor.length >= 3
            ? `rgb(${Number(rgbColor[0]) || 255}, ${Number(rgbColor[1]) || 255}, ${Number(rgbColor[2]) || 255})`
            : null;

        const tokens = text.split(/(\^[0-9])/g);
        let buffer = '';

        const flush = () => {
            if (!buffer) return;
            const span = document.createElement('span');
            span.textContent = buffer;
            if (currentColor) span.style.color = currentColor;
            parent.appendChild(span);
            buffer = '';
        };

        for (const token of tokens) {
            if (/^\^[0-9]$/.test(token)) {
                flush();
                currentColor = colorCodeMap[token[1]] || currentColor;
            } else {
                buffer += token;
            }
        }
        flush();
    }

    const nowTime = () => new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: false });

    function resetHideTimer() {
        if (state.hideTimer) window.clearTimeout(state.hideTimer);
        state.hideTimer = null;

        if (state.displayMode === 'hidden' && !state.open) {
            messageList.style.opacity = '0';
            return;
        }

        messageList.style.opacity = '1';
        if (!state.open && state.displayMode === 'onMessage' && state.autoHideAfter > 0) {
            state.hideTimer = window.setTimeout(() => {
                messageList.style.opacity = '0';
            }, state.autoHideAfter);
        }
    }

    function appendMessage(raw) {
        const message = raw && typeof raw === 'object' ? raw : { type: 'system', title: 'SYSTEM', text: String(raw ?? '') };
        const type = String(message.type || 'global').toLowerCase().replace(/[^a-z0-9_-]/g, '');
        const card = document.createElement('article');
        card.className = `message-card type-${type}`;

        const icon = document.createElement('div');
        icon.className = 'message-icon';
        icon.appendChild(makeSvg(iconForType(message)));

        const copy = document.createElement('div');
        copy.className = 'message-copy';

        const title = document.createElement('div');
        title.className = 'message-title';
        appendSafeColoredText(title, message.title || (type === 'system' ? 'SYSTEM' : ''), message.color);

        const text = document.createElement('div');
        text.className = 'message-text';
        appendSafeColoredText(text, message.text || '', message.color);

        const time = document.createElement('time');
        time.className = 'message-time';
        time.textContent = message.time || nowTime();

        copy.append(title, text);
        card.append(icon, copy, time);
        messageList.appendChild(card);

        while (messageList.children.length > state.keepMessages) {
            messageList.firstElementChild?.remove();
        }

        updateVisibility();
        resetHideTimer();
    }

    function mergedCommands() {
        const map = new Map();
        for (const command of state.baseCommands) {
            map.set(String(command.name), command);
        }
        for (const [name, suggestion] of state.suggestions) {
            map.set(name, {
                name,
                description: suggestion.description || suggestion.help || ''
            });
        }
        return [...map.values()];
    }

    function commandPrefix(commandName) {
        const raw = String(commandName || '').trim();
        const base = raw.split(/\s+/)[0];
        return base === '/dice' ? base : `${base} `;
    }

    function insertCommand(commandName) {
        input.value = commandPrefix(commandName);
        input.focus();
        input.setSelectionRange(input.value.length, input.value.length);
        rpPanel.classList.remove('is-visible');
        closeEmojiPicker();
        renderCommands();
    }

    function renderCommands() {
        const query = input.value.trim().toLowerCase();
        const hasSlash = query.startsWith('/');

        if (!hasSlash) {
            commandRows.replaceChildren();
            commandPanel.classList.remove('is-visible');
            return;
        }

        const filter = query.split(/\s/)[0];
        const all = mergedCommands();
        const shown = all.filter((command) => String(command.name).toLowerCase().startsWith(filter));

        commandRows.replaceChildren();

        for (const command of shown.slice(0, 8)) {
            const row = document.createElement('button');
            row.type = 'button';
            row.className = 'command-row';
            row.addEventListener('click', () => insertCommand(command.name));

            const name = document.createElement('div');
            name.className = 'command-name';
            name.textContent = command.name;

            const description = document.createElement('div');
            description.className = 'command-description';
            description.textContent = command.description || '';

            row.append(name, description);
            commandRows.appendChild(row);
        }

        const shouldShow = state.open && shown.length > 0;
        commandPanel.classList.toggle('is-visible', shouldShow);
        if (shouldShow) {
            closeEmojiPicker();
            rpPanel.classList.remove('is-visible');
        }
    }

    function renderRPCommands() {
        rpCommandList.replaceChildren();

        for (const command of state.rpCommands) {
            const button = document.createElement('button');
            button.type = 'button';
            button.className = 'rp-command';
            button.title = command.description || command.name;
            button.textContent = String(command.name || '').split(/\s+/)[0];
            button.addEventListener('click', () => insertCommand(command.name));
            rpCommandList.appendChild(button);
        }
    }

    function setMode(mode, toggleRP = false) {
        const wasRP = state.mode === 'rp';
        state.mode = mode;

        for (const button of modeButtons) {
            button.classList.toggle('is-active', button.dataset.mode === mode);
        }

        setPlaceholder();

        if (mode === 'rp') {
            const shouldShow = toggleRP && wasRP ? !rpPanel.classList.contains('is-visible') : true;
            rpPanel.classList.toggle('is-visible', shouldShow);
            closeEmojiPicker();
        } else {
            rpPanel.classList.remove('is-visible');
        }

        input.focus();
    }

    function setPlaceholder() {
        const key = `ui_placeholder_${state.mode}`;
        input.placeholder = t(state.locale[key] || DEFAULT_LOCALE[key] ? key : 'ui_placeholder_ooc');
    }

    function renderEmojiCategories() {
        emojiCategories.replaceChildren();
        for (const category of EMOJI_CATEGORIES) {
            const button = document.createElement('button');
            button.type = 'button';
            button.className = 'emoji-category';
            button.classList.toggle('is-active', category.id === state.emojiCategory);
            button.title = category.label;
            button.setAttribute('aria-label', category.label);
            button.textContent = category.icon;
            button.addEventListener('click', () => {
                state.emojiCategory = category.id;
                renderEmojiCategories();
                renderEmojiGrid();
            });
            emojiCategories.appendChild(button);
        }
    }

    function insertEmoji(emoji) {
        const start = input.selectionStart ?? input.value.length;
        const end = input.selectionEnd ?? input.value.length;
        input.setRangeText(emoji, start, end, 'end');
        input.focus();
        renderCommands();
    }

    function renderEmojiGrid() {
        const category = EMOJI_CATEGORIES.find((item) => item.id === state.emojiCategory) || EMOJI_CATEGORIES[0];
        emojiGrid.replaceChildren();

        for (const emoji of category.emojis) {
            const button = document.createElement('button');
            button.type = 'button';
            button.className = 'emoji-item';
            button.textContent = emoji;
            button.addEventListener('click', () => insertEmoji(emoji));
            emojiGrid.appendChild(button);
        }
    }

    function openEmojiPicker() {
        rpPanel.classList.remove('is-visible');
        commandPanel.classList.remove('is-visible');
        emojiPicker.classList.add('is-visible');
        emojiButton.setAttribute('aria-expanded', 'true');
        renderEmojiCategories();
        renderEmojiGrid();
    }

    function closeEmojiPicker() {
        emojiPicker.classList.remove('is-visible');
        emojiButton.setAttribute('aria-expanded', 'false');
    }

    function openChat() {
        state.open = true;
        shell.classList.add('is-open');
        updateVisibility();
        state.historyIndex = state.history.length;
        commandPanel.classList.remove('is-visible');
        closeEmojiPicker();
        renderRPCommands();
        window.setTimeout(() => input.focus(), 0);
    }

    function closeChat(notify = false) {
        state.open = false;
        shell.classList.remove('is-open');
        commandPanel.classList.remove('is-visible');
        rpPanel.classList.remove('is-visible');
        closeEmojiPicker();
        input.value = '';
        if (notify) post('close');
        updateVisibility();
        resetHideTimer();
    }

    async function submit() {
        const text = input.value.trim();
        if (!text) return;

        state.history.push(text);
        if (state.history.length > 50) state.history.shift();
        state.historyIndex = state.history.length;

        input.value = '';
        commandPanel.classList.remove('is-visible');
        rpPanel.classList.remove('is-visible');
        closeEmojiPicker();
        await post('submit', { text, mode: state.mode });
    }

    form.addEventListener('submit', (event) => {
        event.preventDefault();
        submit();
    });

    modeButtons.forEach((button) => button.addEventListener('click', () => setMode(button.dataset.mode, true)));

    displayButton.addEventListener('click', async () => {
        const index = DISPLAY_MODES.indexOf(state.displayMode);
        const fallback = DISPLAY_MODES[(index + 1) % DISPLAY_MODES.length];
        const response = await post('cycleDisplayMode');
        setDisplayMode(response && DISPLAY_MODES.includes(response.mode) ? response.mode : fallback);
        input.focus();
    });

    emojiButton.addEventListener('click', () => {
        if (emojiPicker.classList.contains('is-visible')) {
            closeEmojiPicker();
            input.focus();
        } else {
            openEmojiPicker();
        }
    });

    input.addEventListener('input', () => {
        renderCommands();
        if (input.value.trim().startsWith('/')) {
            rpPanel.classList.remove('is-visible');
        }
    });

    input.addEventListener('keydown', (event) => {
        if (event.key === 'Escape') {
            event.preventDefault();
            if (emojiPicker.classList.contains('is-visible')) {
                closeEmojiPicker();
                input.focus();
                return;
            }
            if (rpPanel.classList.contains('is-visible')) {
                rpPanel.classList.remove('is-visible');
                input.focus();
                return;
            }
            closeChat(true);
            return;
        }

        if (event.key === 'ArrowUp') {
            if (!state.history.length) return;
            event.preventDefault();
            state.historyIndex = Math.max(0, state.historyIndex - 1);
            input.value = state.history[state.historyIndex] || '';
            input.setSelectionRange(input.value.length, input.value.length);
            renderCommands();
        } else if (event.key === 'ArrowDown') {
            if (!state.history.length) return;
            event.preventDefault();
            state.historyIndex = Math.min(state.history.length, state.historyIndex + 1);
            input.value = state.historyIndex >= state.history.length ? '' : state.history[state.historyIndex];
            input.setSelectionRange(input.value.length, input.value.length);
            renderCommands();
        }
    });

    document.addEventListener('pointerdown', (event) => {
        if (!state.open || !emojiPicker.classList.contains('is-visible')) return;
        if (emojiPicker.contains(event.target) || emojiButton.contains(event.target)) return;
        closeEmojiPicker();
    });

    window.addEventListener('message', (event) => {
        const data = event.data || {};

        switch (data.action) {
            case 'init': {
                const config = data.config || {};
                if (Number.isFinite(config.maxVisibleMessages)) state.maxVisibleMessages = Math.max(1, config.maxVisibleMessages);
                if (Number.isFinite(config.keepMessages)) state.keepMessages = Math.max(state.maxVisibleMessages, config.keepMessages);
                if (Number.isFinite(config.autoHideAfter)) state.autoHideAfter = Math.max(0, config.autoHideAfter);
                if (Number.isFinite(config.maxMessageLength)) {
                    state.maxMessageLength = Math.max(1, config.maxMessageLength);
                    input.maxLength = state.maxMessageLength;
                }
                state.baseCommands = Array.isArray(config.commands) ? config.commands : [];
                if (Array.isArray(config.rpCommands)) state.rpCommands = config.rpCommands;
                applyTheme(config.theme);
                applyLocale(config.locale);
                if (DISPLAY_MODES.includes(config.displayMode)) setDisplayMode(config.displayMode);
                renderRPCommands();
                renderCommands();
                break;
            }
            case 'displayMode':
                setDisplayMode(data.mode);
                break;
            case 'message':
                appendMessage(data.message);
                break;
            case 'open':
                openChat();
                break;
            case 'close':
                closeChat(false);
                break;
            case 'clear':
                messageList.replaceChildren();
                break;
            case 'suggestion:add': {
                const suggestion = data.suggestion || {};
                if (suggestion.name) state.suggestions.set(String(suggestion.name), suggestion);
                renderCommands();
                break;
            }
            case 'suggestion:remove':
                if (data.name) state.suggestions.delete(String(data.name));
                renderCommands();
                break;
            default:
                break;
        }
    });

    if (typeof GetParentResourceName !== 'function') {
        document.body.classList.add('preview');
        state.autoHideAfter = 0;
        openChat();
        const preview = [
            { type: 'system', title: 'SYSTEM', text: 'The chat has been cleared.', time: '23:45', icon: 'system' },
            { type: 'ooc', title: 'OOC | Anonymous', text: 'This is a message example', time: '23:45', icon: 'discord' },
            { type: 'me', title: 'Tommy Champion', text: 'looks around the rooftop.', time: '23:45', icon: 'user-plus' },
            { type: 'job', title: 'POLICE | Tommy Champion', text: 'Unit available for a call.', time: '23:45', icon: 'user' },
            { type: 'pm', title: '[PM] Arthur James → You', text: 'hi :D', time: '23:45', icon: 'message' }
        ];
        preview.forEach(appendMessage);
    } else {
        post('ready');
    }
})();
