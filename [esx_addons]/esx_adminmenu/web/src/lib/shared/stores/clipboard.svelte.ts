/* SPDX-License-Identifier: GPL-3.0-only */

class ClipboardState {
	visible = $state(false);
	text = $state("");
	requestId = $state<number | undefined>(undefined);

	open(text: string, requestId?: number) {
		if (typeof text !== "string" || !text || text.length > 4096) return;
		this.text = text;
		this.requestId = requestId;
		this.visible = true;
	}

	close(requestId?: number) {
		if (requestId !== undefined && requestId !== this.requestId) return;
		this.visible = false;
		this.text = "";
		this.requestId = undefined;
	}
}

export const clipboard = new ClipboardState();
