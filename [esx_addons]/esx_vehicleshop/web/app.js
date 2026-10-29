/* One interface for every dealership. Financial authority stays on the server. */
'use strict';
const $ = (id) => document.getElementById(id);
const dictionaries = {
    es: {
        catalog: 'Catálogo',
        stock: 'Stock',
        rentals: 'Alquileres',
        sales: 'Ventas',
        manage: 'Gestión',
        orders: 'Mis operaciones',
        refresh: 'Actualizar',
        search: 'Buscar vehículo…',
        all: 'Todas las categorías',
        preview: 'Ver modelo',
        buy: 'Comprar',
        sell: 'Ofrecer venta',
        rent: 'Ofrecer alquiler',
        procure: 'Comprar stock',
        supplier: 'Devolver al proveedor',
        confirm: 'Confirmar',
        cancel: 'Cancelar',
        method: 'Método de pago',
        money: 'Efectivo',
        bank: 'Banco',
        society: 'Sociedad',
        unlimited: 'Disponible',
        units: 'unidades',
        license: 'Licencia',
        grade: 'Grado mínimo',
        empty: 'No hay registros.',
        success: 'Operación completada.',
        offered: 'Oferta enviada al comprador. Debe aceptarla y pagar.',
        target: 'ID del comprador cercano',
        amount: 'Cantidad',
        deposit: 'Ingresar',
        withdraw: 'Retirar',
        employees: 'Empleados',
        inventory: 'Inventario',
        invoice: 'Facturar',
        balance: 'Saldo de la empresa',
        status: 'Comprobar estado',
        pending: 'Operación pendiente de confirmar. Comprueba su estado antes de repetirla.',
        failed: 'La operación no se completó. Puedes volver a intentarlo desde el catálogo.',
        quoted: 'Sin confirmar',
        processing: 'Procesando',
        complete: 'Completada',
        next: 'Siguiente',
        previous: 'Anterior',
        daily: 'al día',
        plate: 'Matrícula',
        vehicle: 'Vehículo',
        client: 'Cliente',
        seller: 'Vendedor',
        date: 'Fecha',
        price: 'Precio',
        stockWaiting: 'Pendiente de retirar el vehículo anterior',
        stored:
            'El vehículo queda registrado y disponible en su garaje si la ' +
            'entrega no se ha ' +
            'realizado.',
        help: 'ESC para cerrar · Los precios y permisos se validan al confirmar.',
        return: 'Devolver alquiler',
        resale: 'Vender vehículo',
        items: 'Objetos',
        count: 'Unidades',
        shop: 'Tienda',
        player: 'Jugador',
        getLicense: 'Adquirir licencia',
        unconfirmed: 'No se ha confirmado el resultado. Comprueba el estado de la operación.',
        operation_failed: 'No se pudo completar la operación.',
        not_ready: 'El concesionario se está preparando.',
        not_allowed: 'No tienes permiso.',
        insufficient_funds: 'Saldo insuficiente.',
        out_of_stock: 'No quedan unidades disponibles.',
        license_required: 'Necesitas la licencia indicada.',
        quote_changed: 'La oferta ha cambiado. Actualiza el catálogo.',
        purchase_invalidated: 'Ya no cumples los requisitos o no estás cerca de la tienda.',
        order_expired: 'La oferta ha caducado.',
        busy: 'Espera un momento antes de repetir la operación.',
        transaction_failed: 'La operación no se completó; no se ha confirmado ningún cobro.',
        buyer_unavailable: 'El comprador debe estar cerca.',
        rented_vehicle: 'Un vehículo alquilado no se puede vender.',
        not_owned: 'El vehículo no te pertenece.',
        vehicle_required: 'Debes conducir el vehículo.',
        order_pending: 'Ya tienes una operación en curso. Consulta su estado.',
        society_unavailable: 'La cuenta de empresa no está disponible.',
        seller_unavailable: 'El vendedor ya no está disponible.',
        rentals_unavailable: 'El servicio de alquileres no está disponible.',
        license_unavailable: 'La licencia no está disponible en este momento.',
        not_near_shop: 'Debes estar cerca del concesionario.',
        employee_required: 'Esta operación requiere un empleado autorizado.',
        boss_required: 'Esta operación requiere un jefe autorizado.',
        session_closing: 'La sesión está cerrándose. Vuelve a entrar antes de continuar.',
        invalid_account: 'Selecciona un método de pago válido.',
        rentConfirm: 'Aceptar alquiler',
    },
    en: {
        catalog: 'Catalog',
        stock: 'Stock',
        rentals: 'Rentals',
        sales: 'Sales',
        manage: 'Management',
        orders: 'My orders',
        refresh: 'Refresh',
        search: 'Search vehicles…',
        all: 'All categories',
        preview: 'Preview',
        buy: 'Buy',
        sell: 'Offer sale',
        rent: 'Offer rental',
        procure: 'Purchase stock',
        supplier: 'Return to supplier',
        confirm: 'Confirm',
        cancel: 'Cancel',
        method: 'Payment method',
        money: 'Cash',
        bank: 'Bank',
        society: 'Company',
        unlimited: 'Available',
        units: 'units',
        license: 'License',
        grade: 'Minimum grade',
        empty: 'No records.',
        success: 'Operation completed.',
        offered: 'Offer sent. The buyer must accept and pay.',
        target: 'Nearby buyer ID',
        amount: 'Amount',
        deposit: 'Deposit',
        withdraw: 'Withdraw',
        employees: 'Employees',
        inventory: 'Inventory',
        invoice: 'Invoice',
        balance: 'Company balance',
        status: 'Check status',
        pending: 'Result pending. Check this order before trying again.',
        failed: 'The operation did not complete. You can try again from the catalog.',
        quoted: 'Unconfirmed',
        processing: 'Processing',
        complete: 'Complete',
        next: 'Next',
        previous: 'Previous',
        daily: 'per day',
        plate: 'Plate',
        vehicle: 'Vehicle',
        client: 'Customer',
        seller: 'Seller',
        date: 'Date',
        price: 'Price',
        stockWaiting: 'Waiting for the previous vehicle to be removed',
        stored:
            'The vehicle is registered and remains available in its garage ' +
            'if delivery could not ' +
            'finish.',
        help: 'ESC to close · Prices and permissions are checked on confirmation.',
        return: 'Return rental',
        resale: 'Sell vehicle',
        items: 'Items',
        count: 'Units',
        shop: 'Shop',
        player: 'Player',
        getLicense: 'Buy license',
        unconfirmed: 'Result unconfirmed. Check the order status.',
        operation_failed: 'The operation could not be completed.',
        not_ready: 'The dealership is preparing.',
        not_allowed: 'Access denied.',
        insufficient_funds: 'Insufficient funds.',
        out_of_stock: 'Out of stock.',
        license_required: 'The indicated license is required.',
        quote_changed: 'The offer changed. Refresh the catalog.',
        purchase_invalidated: 'You no longer meet the requirements or are too far away.',
        order_expired: 'The offer expired.',
        busy: 'Please wait before trying again.',
        transaction_failed: 'The operation did not complete; no charge was confirmed.',
        buyer_unavailable: 'The buyer must be nearby.',
        rented_vehicle: 'A rented vehicle cannot be sold.',
        not_owned: 'You do not own this vehicle.',
        vehicle_required: 'You must be driving the vehicle.',
        order_pending: 'You already have an order in progress. Check its status.',
        society_unavailable: 'The company account is unavailable.',
        seller_unavailable: 'The seller is no longer available.',
        rentals_unavailable: 'The rental service is unavailable.',
        license_unavailable: 'The license is currently unavailable.',
        not_near_shop: 'You must be near the dealership.',
        employee_required: 'This action requires an authorized employee.',
        boss_required: 'This action requires an authorized boss.',
        session_closing: 'Your session is closing. Log in again to continue.',
        invalid_account: 'Select a valid payment method.',
        rentConfirm: 'Accept rental',
    },
};
let lang = 'es',
    snapshot = null,
    tab = 'catalog',
    quote = null,
    pending = null,
    busy = false,
    generation = 0,
    search = '',
    category = '',
    target = '',
    page = 1;
const t = (key) => dictionaries[lang][key] || dictionaries[lang].operation_failed;
const money = (value) => '$' + new Intl.NumberFormat(lang).format(Number(value) || 0);

function node(tag, text, cls) {
    const n = document.createElement(tag);

    if (text !== undefined) {
        n.textContent = String(text);
    }

    if (cls) {
        n.className = cls;
    }

    return n;
}

function button(text, action, cls) {
    const b = node('button', text, cls);

    b.type = 'button';
    b.onclick = action;
    return b;
}

function notice(message) {
    $('notice').textContent = message;
    $('notice').hidden = !message;
}

async function rpc(name, data = {}) {
    try {
        const r = await fetch(`https://${GetParentResourceName()}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        });

        return await r.json();
    } catch {
        return { success: false, error: 'unconfirmed' };
    }
}

async function refresh() {
    const g = generation;
    const r = await rpc('refresh', { page });

    if (g !== generation) {
        return;
    }

    if (r.success) {
        snapshot = r.data;
        render();
    } else {
        notice(t(r.error));
    }
}

function close() {
    generation++;
    snapshot = null;
    quote = null;
    $('shop').hidden = true;

    if ($('checkout').open) {
        $('checkout').close();
    }

    rpc('close');
}

function table(headers, rows) {
    if (!rows.length) {
        return node('p', t('empty'), 'empty');
    }

    const el = node('table'),
        head = node('tr');

    headers.forEach((h) => head.append(node('th', t(h))));
    el.append(head);

    for (const row of rows) {
        const tr = node('tr');

        for (const cell of row) {
            const td = node('td');

            td.append(
                cell instanceof Node ? cell : document.createTextNode(String(cell ?? '')),
            );
            tr.append(td);
        }

        el.append(tr);
    }

    return el;
}

async function requestQuote(data) {
    if (busy || pending) {
        notice(t('pending'));

        if (pending) {
            await checkStatus(pending);
        }

        return;
    }

    busy = true;

    const g = generation;
    const r = await rpc('quote', data);

    if (g !== generation) {
        return;
    }

    busy = false;

    if (!r.success) {
        notice(t(r.error));
        return;
    }

    if (r.data.offered) {
        notice(t('offered'));
        return;
    }

    showQuote(r.data);
}

function showQuote(value) {
    if (!snapshot) {
        return;
    }

    if (value.error) {
        notice(t(value.error));
        return;
    }

    quote = value;
    $('confirmTitle').textContent =
        value.kind === 'rent'
            ? t('rentConfirm')
            : t(
                    value.kind === 'purchase'
                        ? 'buy'
                        : value.kind === 'stock'
                        ? 'procure'
                        : value.kind === 'provider'
                            ? 'supplier'
                            : value.kind === 'license'
                            ? 'getLicense'
                            : value.kind,
                );
    $('summary').textContent = [
        value.name || value.model || '',
        money(value.amount),
        value.rentPrice ? `${money(value.rentPrice)} ${t('daily')}` : '',
        value.plate || '',
    ]
        .filter(Boolean)
        .join(' · ');
    $('method').replaceChildren();

    for (const method of value.paymentMethods || snapshot.shop.paymentMethods) {
        const option = node('option', t(method));

        option.value = method;
        $('method').append(option);
    }

    $('methodLabel').textContent = t('method');
    $('cancel').textContent = t('cancel');
    $('confirm').textContent = t('confirm');
    $('checkStatus').textContent = t('status');
    $('confirm').disabled = !!pending;
    $('checkStatus').hidden = !pending;
    $('checkoutError').textContent = pending ? t('pending') : '';

    if (!$('checkout').open) {
        $('checkout').showModal();
    }
}

async function execute() {
    if (busy || pending || !quote) {
        return;
    }

    busy = true;
    pending = quote.id;
    $('confirm').disabled = true;
    $('cancel').disabled = true;

    const g = generation;
    const r = await rpc('execute', { id: quote.id, account: $('method').value });

    if (g !== generation) {
        return;
    }

    busy = false;

    $('cancel').disabled = false;

    if (r.success && r.data.complete) {
        pending = null;
        $('checkout').close();
        notice(
            t('success') +
                (r.data.kind === 'purchase' || r.data.kind === 'rent'
                    ? ' ' + t('stored')
                    : ''),
        );
        await refresh();
        return;
    }

    if (r.error === 'unconfirmed') {
        showPending();
        return;
    }

    await checkStatus(pending);

    if (g !== generation) {
        return;
    }

    if (pending) {
        $('checkoutError').textContent = t(r.error);
        $('checkStatus').hidden = false;
    } else {
        $('checkoutError').textContent = t(r.error);
        $('confirm').disabled = true;
    }
}

function showPending() {
    $('checkoutError').textContent = t('pending');
    $('checkStatus').hidden = false;
    $('confirm').disabled = true;
    notice(t('pending'));
}

async function checkStatus(id) {
    if (!id) {
        return;
    }

    const g = generation;
    const r = await rpc('status', { id });

    if (g !== generation) {
        return;
    }

    if (!r.success) {
        notice(t(r.error));
        return;
    }

    if (r.data.complete) {
        pending = null;

        if ($('checkout').open) {
            $('checkout').close();
        }

        notice(t('success'));
        await refresh();
    } else if (r.data.state === 'failed' || r.data.expired) {
        pending = null;
        notice(t('failed'));
        $('checkoutError').textContent = t('failed');
        $('confirm').disabled = true;
    } else if (r.data.state === 'quoted') {
        pending = null;
        notice(t('quoted'));

        if (quote && quote.id === id) {
            $('confirm').disabled = false;
            $('checkStatus').hidden = true;
        }
    } else {
        pending = id;
        notice(t('pending'));

        if ($('checkout').open) {
            showPending();
        }
    }
}

function catalog(root) {
    const tools = node('div', undefined, 'toolbar'),
        input = node('input');

    input.placeholder = t('search');
    input.value = search;
    input.oninput = () => {
        search = input.value;
        drawCards();
    };

    const select = node('select');
    const all = node('option', t('all'));

    all.value = '';
    select.append(all);

    for (const c of [...new Set(snapshot.vehicles.map((v) => v.category))].sort()) {
        const op = node('option', c);

        op.value = c;
        select.append(op);
    }

    select.value = category;
    select.onchange = () => {
        category = select.value;
        drawCards();
    };
    tools.append(input, select);
    root.append(tools);

    if (snapshot.shop.employee && snapshot.shop.mode === 'managed') {
        const row = node('div', undefined, 'form-row'),
            id = node('input');

        id.type = 'number';
        id.min = '1';
        id.placeholder = t('target');
        id.value = target;
        id.oninput = () => {
            target = id.value;
        };
        row.append(id);
        root.append(row);
    }

    const cards = node('div', undefined, 'grid');

    root.append(cards);

    function drawCards() {
        cards.replaceChildren();

        for (const v of snapshot.vehicles.filter(
            (v) =>
                (!category || v.category === category) &&
                `${v.name} ${v.model}`.toLowerCase().includes(search.toLowerCase()),
        )) {
            const card = node('article', undefined, 'card');

            card.append(
                node('h3', v.name),
                node('div', v.model, 'muted'),
                node('div', money(v.price), 'price'),
                node(
                    'span',
                    v.stock < 0 ? t('unlimited') : `${v.stock} ${t('units')}`,
                    'badge',
                ),
            );

            if (v.license) {
                card.append(node('div', `${t('license')}: ${v.license}`, 'muted'));
            }

            if (v.minGrade) {
                card.append(node('div', `${t('grade')}: ${v.minGrade}`, 'muted'));
            }

            const actions = node('div', undefined, 'actions');

            actions.append(
                button(t('preview'), async () => {
                    const r = await rpc('preview', { model: v.model });

                    if (!r.success) {
                        notice(t(r.error));
                    }
                }),
            );

            if (snapshot.shop.mode !== 'managed' || snapshot.shop.employee) {
                const b = button(
                    t(snapshot.shop.mode === 'managed' ? 'sell' : 'buy'),
                    () =>
                        requestQuote({
                            kind: 'purchase',
                            model: v.model,
                            targetId: Number(target),
                        }),
                    'primary',
                );

                b.disabled = v.stock === 0;
                actions.append(b);
            }

            if (snapshot.shop.employee) {
                actions.append(
                    button(t('procure'), () =>
                        requestQuote({ kind: 'stock', model: v.model }),
                    ),
                );

                if (snapshot.shop.rentals) {
                    const b = button(t('rent'), () =>
                        requestQuote({
                            kind: 'rent',
                            model: v.model,
                            targetId: Number(target),
                        }),
                    );

                    b.disabled = v.stock === 0;
                    actions.append(b);
                }
            }

            card.append(actions);
            cards.append(card);
        }

        if (!cards.children.length) {
            cards.append(node('p', t('empty'), 'empty'));
        }
    }

    drawCards();

    if (snapshot.shop.licensePrice) {
        root.append(
            button(`${t('getLicense')} · ${money(snapshot.shop.licensePrice)}`, () =>
                requestQuote({ kind: 'license' }),
            ),
        );
    }
}

function paging(root) {
    const actions = node('div', undefined, 'actions');
    const prev = button(t('previous'), () => {
        page = Math.max(1, page - 1);
        refresh();
    });

    prev.disabled = page <= 1;

    const next = button(t('next'), () => {
        page++;
        refresh();
    });

    next.disabled = !snapshot[tab + 'More'];
    actions.append(prev, node('span', page), next);
    root.append(actions);
}

function render() {
    if (!snapshot) {
        return;
    }

    const shop = snapshot.shop;

    $('title').textContent = shop.name;

    const logo = $('logo');

    logo.hidden = !shop.logo;

    if (shop.logo) {
        logo.src = shop.logo;
    } else {
        logo.removeAttribute('src');
    }

    logo.onerror = () => {
        logo.hidden = true;
    };
    document.documentElement.style.setProperty(
        '--accent',
        /^#[a-f\d]{6}$/i.test(shop.color || '') ? shop.color : '#ffac00',
    );
    $('refresh').textContent = t('refresh');
    $('help').textContent = t('help');
    $('tabs').replaceChildren();

    const tabs = [
        'catalog',
        ...(shop.employee ? ['stock', 'rentals', 'sales', 'manage'] : []),
        'orders',
    ];

    if (!tabs.includes(tab)) {
        tab = 'catalog';
    }

    for (const key of tabs) {
        $('tabs').append(
            button(
                t(key),
                () => {
                    tab = key;
                    page = 1;
                    render();
                    refresh();
                },
                key === tab ? 'active' : '',
            ),
        );
    }

    const root = $('content');

    root.replaceChildren();

    if (tab === 'catalog') {
        catalog(root);
    }

    if (tab === 'stock') {
        root.append(
            table(
                ['vehicle', 'price', 'stock'],
                (snapshot.stock || []).map((s) => [
                    s.vehicle,
                    money(s.price),
                    s.available === 1
                        ? button(t('supplier'), () =>
                                requestQuote({ kind: 'provider', stockId: s.id }),
                            )
                        : t('stockWaiting'),
                ]),
            ),
        );
        paging(root);
    }

    if (tab === 'rentals') {
        root.append(
            table(
                ['vehicle', 'plate', 'client', 'price'],
                (snapshot.rentals || []).map((r) => [
                    r.vehicle,
                    r.plate,
                    r.player_name,
                    `${money(r.rent_price)} ${t('daily')}`,
                ]),
            ),
        );
        paging(root);
    }

    if (tab === 'sales') {
        root.append(
            table(
                ['vehicle', 'plate', 'client', 'seller', 'date'],
                (snapshot.sales || []).map((s) => [
                    s.model,
                    s.plate,
                    s.client,
                    s.soldby,
                    String(s.date),
                ]),
            ),
        );
        paging(root);
    }

    if (tab === 'orders') {
        root.append(
            table(
                ['vehicle', 'plate', 'price', 'status'],
                (snapshot.orders || []).map((o) => [
                    o.model,
                    o.plate,
                    money(o.amount),
                    button(t(o.state), () => checkStatus(o.id)),
                ]),
            ),
        );
    }

    if (tab === 'manage') {
        if (shop.boss) {
            const section = node('div', undefined, 'section');

            section.append(node('h3', `${t('balance')}: ${money(snapshot.societyBalance)}`));

            const row = node('div', undefined, 'form-row'),
                input = node('input');

            input.type = 'number';
            input.min = '1';
            input.placeholder = t('amount');
            row.append(
                input,
                button(t('deposit'), () =>
                    requestQuote({ kind: 'deposit', amount: Number(input.value) }),
                ),
                button(t('withdraw'), () =>
                    requestQuote({ kind: 'withdraw', amount: Number(input.value) }),
                ),
            );
            section.append(
                row,
                button(t('employees'), () => rpc('employees')),
            );
            root.append(section);
        }

        root.append(button(t('inventory'), openInventory));

        if (shop.billingAccount) {
            const row = node('div', undefined, 'form-row'),
                input = node('input');

            input.type = 'number';
            input.min = '1';
            input.placeholder = t('amount');
            row.append(
                input,
                button(t('invoice'), async () => {
                    const r = await rpc('invoice', { amount: Number(input.value) });

                    notice(t(r.success ? 'success' : r.error));
                }),
            );
            root.append(row);
        }
    }
}

async function openInventory() {
    const g = generation,
        r = await rpc('inventory');

    if (g !== generation) {
        return;
    }

    if (!r.success) {
        notice(t(r.error));
        return;
    }

    if (r.data.ox) {
        return;
    }

    const root = $('content');

    root.replaceChildren(node('h2', t('items')));

    const society = r.data.society || [],
        player = r.data.player || [];
    const rows = (
        Array.isArray(player)
            ? player
            : Object.entries(player).map(([name, count]) => ({ name, count }))
    )
        .filter((i) => i.count > 0)
        .map((i) => ({ ...i, deposit: true }))
        .concat(society.map((i) => ({ ...i, deposit: false })));

    root.append(
        table(
            ['items', 'count', 'shop'],
            rows.map((i) => {
                const row = node('div', undefined, 'form-row'),
                    n = node('input');

                n.type = 'number';
                n.min = '1';
                n.max = i.count;
                n.value = '1';
                row.append(
                    n,
                    button(t(i.deposit ? 'deposit' : 'withdraw'), async () => {
                        const r = await rpc('moveInventory', {
                            item: i.name,
                            count: Number(n.value),
                            deposit: i.deposit,
                        });

                        if (r.success) {
                            openInventory();
                        } else {
                            notice(t(r.error));
                        }
                    }),
                );
                return [i.label || i.name, i.count, row];
            }),
        ),
    );
}

window.addEventListener('message', (event) => {
    const { type, data } = event.data || {};

    if (type === 'close') {
        generation++;
        snapshot = null;
        $('shop').hidden = true;

        if ($('checkout').open) {
            $('checkout').close();
        }
    }

    if (type === 'open') {
        generation++;

        if ($('checkout').open) {
            $('checkout').close();
        }

        busy = false;
        $('cancel').disabled = false;
        lang = data.locale?.startsWith('es') ? 'es' : 'en';
        snapshot = data.snapshot;
        pending = data.pending;
        quote = null;
        tab = 'catalog';
        search = '';
        category = '';
        page = 1;
        notice(pending ? t('pending') : '');
        $('shop').hidden = false;
        render();

        if (pending) {
            checkStatus(pending);
        }
    }

    if (type === 'quote') {
        showQuote(data);
    }
});
$('close').onclick = close;
$('refresh').onclick = refresh;
$('confirm').onclick = execute;
$('checkStatus').onclick = () => checkStatus(pending || quote?.id);
$('checkout').addEventListener('cancel', (e) => {
    if (busy) {
        e.preventDefault();
    }
});
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !$('checkout').open) {
        close();
    }
});
