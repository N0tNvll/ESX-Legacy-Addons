<!-- SPDX-License-Identifier: GPL-3.0-only -->
<script lang="ts">
	import { tick } from "svelte";
	import { clipboard } from "../stores/clipboard.svelte";
	import { copyToClipboardChromium, t } from "../util/util";
	import { fetchNui } from "../nui/fetchNUI";

	let field: HTMLTextAreaElement | undefined = $state();
	let copyButton: HTMLButtonElement | undefined = $state();
	let closeButton: HTMLButtonElement | undefined = $state();
	let busy = $state(false);
	let failed = $state(false);

	$effect(() => {
		if (!clipboard.visible) return;
		const id = clipboard.requestId;
		busy = false;
		failed = false;
		void tick().then(() => {
			if (clipboard.visible && clipboard.requestId === id) {
				field?.focus();
				field?.select();
			}
		});
	});

	async function complete(success: boolean) {
		if (busy || !clipboard.visible) return;
		const id = clipboard.requestId;
		if (id === undefined) {
			clipboard.close();
			return;
		}
		busy = true;
		const response = await fetchNui("clipboardResult", { requestId: id, success, cancelled: !success });
		if (response !== null) clipboard.close(id);
		else if (clipboard.requestId === id) {
			busy = false;
			failed = true;
		}
	}

	async function copy() {
		if (busy) return;
		const id = clipboard.requestId;
		const success = await copyToClipboardChromium(clipboard.text);
		if (!clipboard.visible || clipboard.requestId !== id) return;
		if (success) void complete(true);
		else {
			failed = true;
			field?.focus();
			field?.select();
		}
	}

	function handleKeyDown(event: KeyboardEvent) {
		if (!clipboard.visible) return;
		event.stopImmediatePropagation();
		if (event.key === "Escape") {
			event.preventDefault();
			void complete(false);
		} else if (event.key === "Tab") {
			event.preventDefault();
			const controls = [field, copyButton, closeButton].filter(
				(element): element is HTMLTextAreaElement | HTMLButtonElement => !!element && !element.disabled,
			);
			const index = controls.indexOf(document.activeElement as HTMLTextAreaElement);
			const next = (index + (event.shiftKey ? -1 : 1) + controls.length) % controls.length;
			controls[next]?.focus();
		}
	}

	$effect(() => {
		window.addEventListener("keydown", handleKeyDown, true);
		return () => window.removeEventListener("keydown", handleKeyDown, true);
	});
</script>

{#if clipboard.visible}
	<div class="clipboard-overlay">
		<div class="clipboard-card" role="dialog" aria-modal="true" aria-labelledby="clipboard-title" aria-describedby="clipboard-hint" tabindex="-1">
			<header>
				<span class="clipboard-brand">ESX</span>
				<button class="clipboard-close" aria-label={t("close", "Close")} disabled={busy} onclick={() => complete(false)}>×</button>
			</header>
			<h2 id="clipboard-title">{t("clipboard_title", "Copy coordinates or text")}</h2>
			<p id="clipboard-hint">{t("clipboard_hint", "Press Ctrl+C to copy the selected text, or use the Copy button.")}</p>
			<textarea
				bind:this={field}
				value={clipboard.text}
				readonly
				spellcheck="false"
				aria-label={t("clipboard_text", "Text to copy")}
				oncopy={() => { void complete(true); }}
			></textarea>
			{#if failed}
				<p class="clipboard-error" role="status">{t("clipboard_manual", "Click the text, press Ctrl+A, then Ctrl+C. You can also find it in F8.")}</p>
			{/if}
			<footer>
				<button bind:this={closeButton} disabled={busy} onclick={() => complete(false)}>{t("close", "Close")}</button>
				<button bind:this={copyButton} class="clipboard-copy" disabled={busy} onclick={copy}>{t("clipboard_copy", "Copy")}</button>
			</footer>
		</div>
	</div>
{/if}

<style>
	.clipboard-overlay { position: fixed; inset: 0; z-index: 10000; display: grid; place-items: center; padding: 24px; background: #0006; box-sizing: border-box; }
	.clipboard-card { width: min(520px, 100%); max-height: calc(100vh - 48px); overflow: auto; box-sizing: border-box; padding: 25px; border: 1px solid #383838; border-radius: 10px; background: #161616; color: #f2f2f2; font-family: inherit; }
	header { display: flex; align-items: center; justify-content: space-between; }
	.clipboard-brand { color: #fb9b04; font-size: 18px; font-weight: 700; }
	.clipboard-close { border: 0; background: transparent; color: #969696; font-size: 25px; padding: 0 5px; }
	h2 { margin: 18px 0 10px; font-size: 19px; font-weight: 600; }
	p { margin: 0 0 18px; color: #969696; font-size: 12px; line-height: 1.7; }
	textarea { box-sizing: border-box; display: block; width: 100%; min-height: 85px; max-height: 220px; resize: vertical; padding: 15px; border: 1px solid #383838; border-radius: 6px; background: #252525; color: #f2f2f2; font: 13px/1.6 monospace; user-select: text; }
	textarea:focus { outline: 1px solid #fb9b04; border-color: #fb9b04; }
	textarea::selection { background: #fb9b04; color: #161616; }
	.clipboard-error { color: #f3b469; margin-top: 12px; }
	footer { display: flex; justify-content: flex-end; gap: 10px; margin-top: 20px; }
	footer button { padding: 10px 18px; border: 1px solid #383838; border-radius: 6px; background: #252525; color: #f2f2f2; font: inherit; font-size: 12px; }
	footer .clipboard-copy { background: #fb9b04; border-color: #fb9b04; color: #161616; font-weight: 600; }
	button { cursor: pointer; }
	button:disabled { opacity: .5; cursor: default; }
	button:focus-visible { outline: 2px solid #fb9b04; outline-offset: 3px; }
</style>
