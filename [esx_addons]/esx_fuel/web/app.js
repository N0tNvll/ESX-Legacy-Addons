(() => {
    'use strict';

    const $ = (id) => document.getElementById(id);
    const pump = $('pump');
    const filling = $('filling');
    const grades = $('grades');
    const slider = $('slider');
    const confirmButton = $('confirm');
    const quantityControls = [$('minus'), $('plus'), slider, $('fillUp')];
    const accountButtons = [...document.querySelectorAll('.account[data-account]')];

    const GRADE_COLORS = {
        regular: 'var(--grade-regular)',
        plus: 'var(--grade-plus)',
        premium: 'var(--grade-premium)',
        diesel: 'var(--grade-diesel)',
        electric: 'var(--grade-electric)'
    };

    const state = {
        vehicle: null,
        fuels: [],
        fuel: null,
        liters: 0,
        maxLiters: 0,
        wallet: { money: 0, bank: 0 },
        accounts: ['money', 'bank'],
        account: 'bank',
        locale: {},
        target: 0,
        unit: 'L',
        stock: null
    };

    const t = (key, fallback) => state.locale[key] || fallback || key;
    const money = (value) => `$${Math.round(value).toLocaleString('en-US')}`;

    const post = async (endpoint, data = {}) => {
        if (typeof GetParentResourceName !== 'function') return { ok: true };

        try {
            const response = await fetch(`https://${GetParentResourceName()}/${endpoint}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify(data)
            });
            return response.ok ? await response.json() : { ok: false };
        } catch (_) {
            return { ok: false };
        }
    };

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
        const map = { primaryColor: '--primary-rgb', backgroundColor: '--bg-rgb', secondaryColor: '--secondary-rgb', accentColor: '--accent-rgb' };

        for (const [key, variable] of Object.entries(map)) {
            const rgb = hexToRgb(theme[key]);
            if (!rgb) continue;
            root.setProperty(variable, rgb);
            if (key === 'primaryColor') root.setProperty('--primary', theme[key].trim());
        }
    }

    function applyLocale(strings) {
        if (strings && typeof strings === 'object') state.locale = strings;
        for (const element of document.querySelectorAll('[data-i18n]')) {
            const value = state.locale[element.dataset.i18n];
            if (value) element.textContent = value;
        }
    }

    function balance(account) {
        return Number(state.wallet[account]) || 0;
    }

    function total() {
        return state.fuel ? Math.ceil(state.liters * state.fuel.price - 1e-9) : 0;
    }

    function render() {
        const vehicle = state.vehicle;
        if (!vehicle) return;

        $('targetLabel').textContent = vehicle.can ? t('ui_jerrycan', 'JERRY CAN') : t('ui_vehicle_type', 'VEHICLE TAKES');
        $('vehicleKind').textContent = vehicle.can ? '' : t(`ui_kind_${vehicle.kind}`, vehicle.kind);
        $('vehicleLiters').textContent = `${vehicle.liters.toFixed(1)} / ${Math.round(vehicle.capacity)} ${state.unit}`;
        $('stockField').hidden = typeof state.stock !== 'number';
        $('stock').textContent = `${Math.floor(state.stock || 0)} L`;
        $('gaugeFill').style.width = `${Math.min(100, (vehicle.liters / vehicle.capacity) * 100)}%`;
        $('pricePerLiter').textContent = state.fuel ? `$${state.fuel.price.toFixed(2)}` : '-';
        $('quantity').textContent = `${vehicle.can ? state.liters.toFixed(1) : state.liters} ${state.unit}`;
        $('total').textContent = money(total());
        $('bank').textContent = money(balance('bank'));
        $('cash').textContent = money(balance('money'));

        slider.max = String(state.maxLiters);
        slider.value = String(state.liters);

        for (const button of accountButtons) {
            const allowed = state.accounts.includes(button.dataset.account);
            button.hidden = !allowed;
            button.classList.toggle('is-active', button.dataset.account === state.account);
        }

        for (const button of grades.children) {
            button.classList.toggle('is-active', state.fuel && button.dataset.fuel === state.fuel.name);
        }

        for (const control of quantityControls) control.disabled = vehicle.can;

        confirmButton.disabled = state.liters < (vehicle.can ? 0.5 : 1) || total() > balance(state.account);
    }

    function setLiters(value) {
        if (state.vehicle && state.vehicle.can) return;
        state.liters = Math.max(0, Math.min(state.maxLiters, Math.round(Number(value) || 0)));
        render();
    }

    function renderGrades() {
        grades.replaceChildren();

        for (const fuel of state.fuels) {
            const button = document.createElement('button');
            button.type = 'button';
            button.className = 'grade';
            button.dataset.fuel = fuel.name;
            button.style.setProperty('--grade-color', GRADE_COLORS[fuel.name] || 'var(--primary)');

            const badge = document.createElement('span');
            badge.className = 'badge';
            badge.textContent = fuel.kind === 'diesel' ? 'D' : fuel.kind === 'electric' ? 'EV' : String(fuel.octane || '');

            const label = document.createElement('span');
            label.textContent = fuel.label || fuel.name;

            button.append(badge, label);
            button.addEventListener('click', () => {
                state.fuel = fuel;
                render();
            });
            grades.appendChild(button);
        }
    }

    function open(data) {
        state.vehicle = data.vehicle;
        state.fuels = Array.isArray(data.fuels) ? data.fuels : [];
        state.wallet = data.wallet || { money: 0, bank: 0 };
        state.accounts = Array.isArray(data.accounts) && data.accounts.length ? data.accounts : ['money', 'bank'];
        state.fuel = state.fuels.find((fuel) => fuel.kind === data.vehicle.kind) || state.fuels[0] || null;
        state.unit = data.vehicle.unit || 'L';
        state.stock = typeof data.stock === 'number' ? data.stock : null;
        const space = data.vehicle.capacity - data.vehicle.liters;
        state.maxLiters = data.vehicle.can
            ? Math.max(0, space)
            : Math.max(0, Math.min(Number(data.maxLiters) || 0, Math.floor(space), state.stock === null ? Infinity : Math.floor(state.stock)));
        state.liters = state.maxLiters;
        state.account = state.accounts.find((account) => balance(account) >= total()) || state.accounts[0];

        applyTheme(data.theme);
        applyLocale(data.locale);
        renderGrades();
        render();
        pump.hidden = false;
    }

    function close(notify) {
        pump.hidden = true;
        if (notify) post('close');
    }

    $('minus').addEventListener('click', () => setLiters(state.liters - 1));
    $('plus').addEventListener('click', () => setLiters(state.liters + 1));
    $('fillUp').addEventListener('click', () => setLiters(state.maxLiters));
    slider.addEventListener('input', () => setLiters(slider.value));
    $('cancel').addEventListener('click', () => close(true));

    for (const button of accountButtons) {
        button.addEventListener('click', () => {
            state.account = button.dataset.account;
            render();
        });
    }

    confirmButton.addEventListener('click', () => {
        if (confirmButton.disabled || !state.fuel) return;
        pump.hidden = true;
        post('confirm', { fuel: state.fuel.name, liters: state.liters, account: state.account });
    });

    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape' && !pump.hidden) close(true);
    });

    window.addEventListener('message', (event) => {
        const data = event.data || {};

        switch (data.action) {
            case 'open':
                open(data);
                break;
            case 'close':
                pump.hidden = true;
                break;
            case 'filling':
                state.target = Number(data.target) || 0;
                state.unit = data.unit || state.unit;
                $('fillLiters').textContent = `0.0 / ${state.target} ${state.unit}`;
                $('fillPrice').textContent = money(Number(data.price) || 0);
                $('fillGauge').style.width = '0%';
                filling.hidden = false;
                break;
            case 'progress': {
                const delivered = Number(data.delivered) || 0;
                $('fillLiters').textContent = `${delivered.toFixed(1)} / ${state.target} ${state.unit}`;
                $('fillGauge').style.width = `${state.target ? Math.min(100, (delivered / state.target) * 100) : 0}%`;
                break;
            }
            case 'done':
                filling.hidden = true;
                break;
            default:
                break;
        }
    });

    if (typeof GetParentResourceName !== 'function') {
        document.body.classList.add('preview');
        open({
            vehicle: { kind: 'petrol', capacity: 65, liters: 18.4 },
            fuels: [
                { name: 'regular', kind: 'petrol', octane: 87, price: 1.55, label: 'Regular' },
                { name: 'plus', kind: 'petrol', octane: 89, price: 1.7, label: 'Plus' },
                { name: 'premium', kind: 'petrol', octane: 91, price: 1.9, label: 'Premium' },
                { name: 'diesel', kind: 'diesel', price: 1.6, label: 'Diesel' }
            ],
            wallet: { money: 211.5, bank: 9604.5 },
            accounts: ['money', 'bank'],
            maxLiters: 200
        });
    }
})();
