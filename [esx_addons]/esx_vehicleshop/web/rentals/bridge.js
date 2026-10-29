'use strict';

const rentalFrame = document.getElementById('timed-rentals');
const rentalMessages = new Map();
let rentalFrameReady = false;

window.addEventListener('message', (event) => {
    if (event.source === rentalFrame.contentWindow) {
        if (event.data?.type === 'timedRental:ready') {
            rentalFrameReady = true;

            for (const message of rentalMessages.values()) {
                rentalFrame.contentWindow.postMessage(message, window.location.origin);
            }

            rentalMessages.clear();
        }

        return;
    }

    const message = event.data;

    if (!['rental:open', 'rental:close', 'rental:contract'].includes(message?.action)) {
        return;
    }

    if (message.action === 'rental:open') {
        rentalFrame.style.pointerEvents = 'auto';
    } else if (message.action === 'rental:close') {
        rentalFrame.style.pointerEvents = 'none';
    }

    if (rentalFrameReady) {
        rentalFrame.contentWindow.postMessage(message, window.location.origin);
    } else {
        rentalMessages.delete(message.action);
        rentalMessages.set(message.action, message);
    }
});
