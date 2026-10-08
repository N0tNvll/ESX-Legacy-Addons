/* SPDX-License-Identifier: GPL-3.0-only */
/* Copyright (C) 2022-2026 ESX Framework */

(() => {
    const element = (id) => document.getElementById(id);
    const app = element('app');
    const state = {
        data: null,
        model: null,
        plan: null,
        account: null,
        filter: 'all',
        busy: false,
        lease: null,
        leaseDeadline: 0,
        labels: {},
    };
    let messageTimer;
    let synchronized = false;

    const label = (key) => state.labels[key] || key;
    const currency = (value) => {
        try {
            return new Intl.NumberFormat(state.data?.locale || undefined, {
                style: 'currency',
                currency: state.data?.currency || 'USD',
                maximumFractionDigits: 0,
            }).format(value);
        } catch {
            return `$${Number(value).toLocaleString()}`;
        }
    };

    function theme(values = {}) {
        const properties = {
            primaryColor: '--primary',
            secondaryColor: '--secondary',
            backgroundColor: '--background',
            accentColor: '--accent',
        };

        for (const [key, property] of Object.entries(properties)) {
            if (/^#[\da-f]{3,8}$/i.test(values[key] || '')) {
                document.documentElement.style.setProperty(property, values[key]);
                if (key === 'primaryColor' && /^#[\da-f]{6}$/i.test(values[key])) {
                    const rgb = values[key]
                        .slice(1)
                        .match(/.{2}/g)
                        .map((value) => parseInt(value, 16));
                    document.documentElement.style.setProperty('--primary-rgb', rgb.join(', '));
                }
            }
        }
    }

    function text(id, value) {
        element(id).textContent = value ?? '';
    }

    function image(node, value) {
        node.hidden = !value;
        node.onerror = () => {
            node.hidden = true;
        };
        node.src = /^[\w-]+\.webp$/.test(value || '') ? `assets/${value}` : '';
    }

    function button(className, onClick) {
        const node = document.createElement('button');
        node.type = 'button';
        node.className = className;
        node.addEventListener('click', onClick);
        return node;
    }

    function child(parent, tag, className, content) {
        const node = document.createElement(tag);
        node.className = className;
        node.textContent = content ?? '';
        parent.append(node);
        return node;
    }

    function toast(message) {
        text('message', message);
        element('message').classList.remove('hidden');
        clearTimeout(messageTimer);
        messageTimer = setTimeout(() => element('message').classList.add('hidden'), 6000);
    }

    async function request(action, data = {}) {
        if (state.busy) return;
        state.busy = true;
        renderSelection();

        try {
            const resource = window.GetParentResourceName?.() || 'esx_vehiclerental';
            const result = await fetch(`https://${resource}/${action}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify(data),
            });
            const response = await result.json();
            if (!response.ok) toast(response.message || label('choose'));
            return response;
        } catch {
            toast(label('choose'));
        } finally {
            state.busy = false;
            renderSelection();
        }
    }

    function renderFilters() {
        const categories = [
            'all',
            ...new Set(state.data.vehicles.map((vehicle) => vehicle.category)),
        ];
        const container = element('filters');
        container.replaceChildren();

        for (const category of categories) {
            const node = button(`filter${state.filter === category ? ' active' : ''}`, () => {
                state.filter = category;
                renderFilters();
                renderFleet();
            });
            node.textContent = label(category);
            node.setAttribute('aria-pressed', String(state.filter === category));
            container.append(node);
        }
    }

    function renderFleet() {
        if (!state.data) return;
        const query = element('search').value.trim().toLowerCase();
        const vehicles = state.data.vehicles.filter(
            (vehicle) =>
                (state.filter === 'all' || vehicle.category === state.filter) &&
                vehicle.label.toLowerCase().includes(query),
        );
        const container = element('vehicles');
        container.replaceChildren();
        element('empty').classList.toggle('hidden', vehicles.length > 0);

        for (const vehicle of vehicles) {
            const card = button(
                `vehicle-card${vehicle.model === state.model ? ' selected' : ''}`,
                () => {
                    if (state.busy) return;
                    state.model = vehicle.model;
                    renderFleet();
                    renderSelection();
                },
            );
            card.setAttribute('aria-pressed', String(vehicle.model === state.model));
            child(card, 'span', 'vehicle-category', label(vehicle.category));
            const photo = child(card, 'img', 'vehicle-image');
            photo.alt = vehicle.label;
            image(photo, vehicle.image);
            child(card, 'span', 'vehicle-name', vehicle.label);
            const meta = child(card, 'div', 'vehicle-meta');
            child(meta, 'span', '', `${vehicle.seats} ${label('seats')}`);
            child(meta, 'strong', '', currency(vehicle.prices[state.plan] || 0));
            container.append(card);
        }
    }

    function renderSelection() {
        if (!state.data) return;
        element('selection-panel').classList.toggle('hidden', !!state.lease);
        element('active-panel').classList.toggle('hidden', !state.lease);

        if (state.lease) {
            text('active-title', label('active'));
            text('active-name', state.lease.label);
            text('active-plate', state.lease.plate);
            text('active-location', state.lease.branchLabel);
            text('remaining-label', label('remaining'));
            text('return-hint', label('return_hint'));
            text(
                'collect',
                state.busy ? label('pending') : label(state.lease.inUse ? 'in_use' : 'collect'),
            );
            element('collect').disabled =
                state.busy ||
                state.lease.inUse ||
                state.lease.branch !== state.data.branch.id ||
                remaining() <= 0;
            return;
        }

        const vehicle = state.data.vehicles.find((entry) => entry.model === state.model);
        image(element('selected-image'), vehicle?.image);
        text('selected-category', vehicle ? label(vehicle.category) : '');
        text('selected-name', vehicle?.label || label('choose'));
        text('total', currency(vehicle?.prices[state.plan] || 0));
        text('rent-label', state.busy ? label('pending') : label('rent'));
        element('rent').classList.toggle('is-loading', state.busy);
        element('rent').setAttribute('aria-busy', String(state.busy));
        const price = vehicle?.prices[state.plan];
        element('rent').disabled =
            state.busy || !price || (state.data.balances[state.account] || 0) < price;

        const plans = element('plans');
        plans.replaceChildren();

        for (const plan of state.data.plans) {
            const node = button(`plan${plan.id === state.plan ? ' active' : ''}`, () => {
                if (state.busy) return;
                state.plan = plan.id;
                renderFleet();
                renderSelection();
            });
            child(node, 'strong', '', plan.minutes);
            child(node, 'span', '', label('minutes'));
            node.setAttribute('aria-pressed', String(plan.id === state.plan));
            plans.append(node);
        }

        const accounts = element('accounts');
        accounts.replaceChildren();

        for (const account of state.data.accounts) {
            const node = button(`account${account === state.account ? ' active' : ''}`, () => {
                if (state.busy) return;
                state.account = account;
                renderSelection();
            });
            child(node, 'span', '', label(account === 'money' ? 'cash' : 'bank'));
            child(node, 'strong', '', currency(state.data.balances[account] || 0));
            node.setAttribute('aria-pressed', String(account === state.account));
            accounts.append(node);
        }
    }

    function setLease(lease) {
        state.lease = lease || null;
        state.leaseDeadline = performance.now() + Math.max(0, lease?.remaining || 0) * 1000;
        element('hud').classList.toggle('hidden', !lease);

        if (lease) {
            text('hud-label', label('active'));
            text('hud-model', lease.label);
            text('hud-plate', lease.plate);
        }

        updateClock();
        renderSelection();
    }

    function remaining() {
        return Math.max(0, Math.ceil((state.leaseDeadline - performance.now()) / 1000));
    }

    function updateClock() {
        const seconds = remaining();
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        const format =
            hours > 0
                ? `${hours}:${String(minutes).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`
                : `${minutes}:${String(seconds % 60).padStart(2, '0')}`;
        text('remaining', format);
        text('hud-time', format);
        if (state.lease && seconds <= 0) element('collect').disabled = true;
    }

    function open(data) {
        synchronized = true;
        state.data = data;
        document.documentElement.lang = data.locale || 'en';
        state.labels = data.labels || {};
        state.model = data.vehicles[0]?.model;
        state.plan = data.plans[0]?.id;
        state.account = data.accounts[0];
        state.filter = 'all';
        state.busy = false;
        theme(data.theme);
        element('search').value = '';
        element('search').placeholder = label('search');
        element('search').setAttribute('aria-label', label('search'));
        element('close').setAttribute('aria-label', label('close'));
        text('branch', data.branch.label);

        for (const [id, key] of Object.entries({
            'brand-title': 'rental_title',
            'contract-section-label': 'contract_section',
            'duration-label': 'duration',
            'payment-label': 'payment',
            'total-label': 'total',
            terms: 'terms',
            empty: 'empty',
        })) {
            text(id, label(key));
        }

        app.classList.remove('hidden');
        app.setAttribute('aria-hidden', 'false');
        element('message').classList.add('hidden');
        setLease(data.lease);
        renderFilters();
        renderFleet();
    }

    function close() {
        app.classList.add('hidden');
        app.setAttribute('aria-hidden', 'true');
    }

    window.addEventListener('message', ({ data }) => {
        if (!data || typeof data !== 'object') return;
        if (data.action === 'rental:open' && data.data) open(data.data);
        if (data.action === 'rental:close') close();
        if (data.action === 'rental:contract') {
            synchronized = true;
            state.labels = data.labels || state.labels;
            theme(data.theme);
            setLease(data.lease);
        }
    });

    element('search').addEventListener('input', renderFleet);
    element('close').addEventListener('click', () => {
        if (!state.busy) request('rental:close');
    });
    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape' && !app.classList.contains('hidden') && !state.busy) {
            event.preventDefault();
            request('rental:close');
        }
    });
    element('rent').addEventListener('click', () =>
        request('rental:rent', { vehicle: state.model, plan: state.plan, account: state.account }),
    );
    element('collect').addEventListener('click', () => request('rental:collect'));
    setInterval(updateClock, 1000);

    const resource = window.GetParentResourceName?.() || 'esx_vehiclerental';
    fetch(`https://${resource}/rental:ready`, {
        method: 'POST',
        body: '{}',
        headers: { 'Content-Type': 'application/json' },
    })
        .then((response) => response.json())
        .then((response) => {
            if (!response.ok || synchronized) return;
            state.labels = response.labels || state.labels;
            theme(response.theme);
            setLease(response.lease);
        })
        .catch(() => {});
})();
