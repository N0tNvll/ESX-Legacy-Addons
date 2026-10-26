/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

import { translations } from "$lib/shared/stores/translations.svelte";

type NuiWindow = Window & {
	invokeNative?: unknown;
};

export const isChromium = (): boolean => typeof (window as NuiWindow).invokeNative === "function";

export const t = (key: string | null | undefined, fallback?: string): string => {
	if (!key) return fallback ?? "";

	return translations.values[key] ?? fallback ?? key;
};

export const copyToClipboardChromium = async (text: string): Promise<boolean> => {
	if (!document.body || typeof text !== "string" || !text) return false;

	const previousFocus = document.activeElement;
	let copyHandled = false;
	const onCopy = (event: ClipboardEvent) => {
		if (!event.clipboardData) return;
		event.clipboardData.setData("text/plain", text);
		event.preventDefault();
		copyHandled = true;
	};

	const textarea = document.createElement("textarea");
	textarea.value = text;

	textarea.style.position = "fixed";
	textarea.style.top = "0";
	textarea.style.left = "0";
	textarea.style.width = "1px";
	textarea.style.height = "1px";
	textarea.style.opacity = "0";
	textarea.style.pointerEvents = "none";
	textarea.setAttribute("aria-hidden", "true");

	document.body.appendChild(textarea);
	document.addEventListener("copy", onCopy);

	textarea.focus({ preventScroll: true });
	textarea.select();
	textarea.setSelectionRange(0, textarea.value.length);

	try {
		const copied = document.execCommand("copy");
		return copied || copyHandled;
	} catch {
		return false;
	} finally {
		document.removeEventListener("copy", onCopy);
		textarea.remove();
		if (previousFocus instanceof HTMLElement && previousFocus.isConnected) {
			previousFocus.focus({ preventScroll: true });
		}
	}
};
