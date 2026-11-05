<!--
  SPDX-License-Identifier: GPL-3.0-only
  Copyright (C) 2022-2026 ESX Framework
-->

<script lang="ts">
    import { t } from "$lib/shared/util/util";
    import "./Actions.css";
    import ContextMenu from "./ContextMenu.svelte";
    import { onDestroy } from "svelte";
    import type { Player } from "../types/player";
    import { formatName, formatMoney, formatLastVisited, formatPlayTime, formatPosition } from "../../../shared/util/formatter";
    import { copyToClipboardChromium } from "$lib/shared/util/util";

    const { player, onClose } = $props<{
        player: Player;
        onClose: () => void;
    }>();

    let copiedText = $state<string | null>(null);
    let copyTimeout: number | null = null;

    async function copyToClipboard(text: string) {
        const copied = await copyToClipboardChromium(text);
        copiedText = copied
            ? t("copied_to_clipboard", "Copied to clipboard")
            : t("copy_failed", "Could not copy the text. Please try again.");

        if (copyTimeout) clearTimeout(copyTimeout);
        copyTimeout = window.setTimeout(() => {
            copiedText = null;
        }, 1000);
    }
    onDestroy(() => {
        if (copyTimeout !== null) {
            clearTimeout(copyTimeout);
        }
    });
</script>

{#if player}
    <section class="player-detail" aria-label={t("player_information")}>
        <div class="detail-header">
            <button class="detail-back" onclick={onClose}>&larr; {t("back")}</button>
            <div class="detail-title">
                <h2>{formatName(player.name)}</h2>
                <span>{t("player_information")}</span>
            </div>
            {#if player.status === "online"}
                <span class="online-badge">
                    <span class="online-dot"></span>
                    <span>{t("online")}</span>
                </span>
            {:else}
                <span class="offline-badge">
                    <span class="offline-dot"></span>
                    <span>{t("offline")}</span>
                </span>
            {/if}
        </div>
        <div class="detail-body">
            <div class="detail-content">
                {#if player.status === "online"}
                    {@render InfoRow({ label: t("id"), value: player.id })}
                {/if}
                {#if player.identifier}
                    {@render InfoRow({ label: t("identifier"), value: player.identifier })}
                {/if}
                {#if player.ip}
                    {@render InfoRow({ label: t("ip_address"), value: player.ip })}
                {/if}
                {#if player.status === "online"}
                    {@render InfoRow({ label: t("routing_bucket"), value: player.routing_bucket ?? 0 })}
                    {@render InfoRow({ label: t("radio_channel"), value: player.radio_channel ?? 0 })}
                {/if}
                {#if player.char_identifier}
                    {@render InfoRow({ label: t("char_identifier"), value: player.char_identifier })}
                {/if}
                {@render InfoRow({ label: t("name"), value: formatName(player.name) })}
                {@render InfoRow({
                    label: t("gender"),
                    value: player.gender === "m" ? t("male") : t("female"),
                })}

                {@render InfoRow({ label: t("job"), value: player.job ?? "Unknown" })}
                {@render InfoRow({ label: t("job_grade"), value: player.job_grade ?? "Unknown" })}

                {@render InfoRow({ label: t("money"), value: `$${formatMoney(player.cash)}` })}
                {@render InfoRow({ label: t("bank_money"), value: `$${formatMoney(player.bank)}` })}
                {@render InfoRow({ label: t("black_money"), value: `$${formatMoney(player.alt_money)}` })}

                {#if player.status === "online"}
                    {@render InfoRow({ label: t("position"), value: formatPosition(player.position) })}
                    {@render InfoRow({ label: t("health"), value: player.health })}
                    {@render InfoRow({ label: t("armor"), value: player.armor })}
                {/if}

                {@render InfoRow({ label: t("play_time"), value: formatPlayTime(player.play_time) })}
                {@render InfoRow({ label: t("last_visited"), value: formatLastVisited(player.last_join) })}

                {#if player.identifiers && Object.keys(player.identifiers).length > 0}
                    <div class="info-section-title">{t("identifiers")}</div>
                    {#each Object.entries(player.identifiers) as [key, identifier]}
                        {@render InfoRow({ label: key, value: String(identifier) })}
                    {/each}
                {/if}

                {#if copiedText}
                    <div class="clipboard-feedback">
                        <svg clip-rule="evenodd" fill-rule="evenodd" stroke-linejoin="round" stroke-miterlimit="2" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                            <path
                                d="m6 19v2c0 .621.52 1 1 1h2v-1.5h-1.5v-1.5zm7.5 3h-3.5v-1.5h3.5zm4.5 0h-3.5v-1.5h3.5zm4-3h-1.5v1.5h-1.5v1.5h2c.478 0 1-.379 1-1zm-1.5-1v-3.363h1.5v3.363zm0-4.363v-3.637h1.5v3.637zm-13-3.637v3.637h-1.5v-3.637zm11.5-4v1.5h1.5v1.5h1.5v-2c0-.478-.379-1-1-1zm-10 0h-2c-.62 0-1 .519-1 1v2h1.5v-1.5h1.5zm4.5 1.5h-3.5v-1.5h3.5zm3-1.5v-2.5h-13v13h2.5v-1.863h1.5v3.363h-4.5c-.48 0-1-.379-1-1v-14c0-.481.38-1 1-1h14c.621 0 1 .522 1 1v4.5h-3.5v-1.5z"
                                fill-rule="nonzero"
                            />
                        </svg>
                        {copiedText}
                    </div>
                {/if}
            </div>
            <aside class="detail-actions" aria-label={t("quick_actions")}>
                <h3>{t("quick_actions")}</h3>
                <ContextMenu
                    open={true}
                    embedded={true}
                    type="player"
                    value={player}
                    onClose={() => {}}
                />
            </aside>
        </div>
    </section>
{/if}

{#snippet InfoRow({ label, value }: { label: string; value: string | number | null | undefined })}
    {@const displayValue = value ?? "-"}
    <div class="info-row" role="button" tabindex="0" onclick={() => value != null && copyToClipboard(String(value))} onkeydown={(e) => e.key === "Enter" && value != null && copyToClipboard(String(value))}>
        <span class="info-label">{label}</span>
        <span class="info-value">{displayValue}</span>
    </div>
{/snippet}

<style>
    .player-detail {
        display: flex;
        flex-direction: column;
        height: 100%;
        min-height: 0;
        overflow: hidden;
    }

    .detail-header {
        display: flex;
        align-items: center;
        gap: 1.5vh;
        padding-bottom: 1.8vh;
        border-bottom: 0.1vh solid #333;
    }

    .detail-back {
        background: #252525;
        color: #f2f2f2;
        border: 0.1vh solid #444;
        border-radius: 0.5vh;
        padding: 0.8vh 1.4vh;
        font: inherit;
        cursor: pointer;
    }

    .detail-back:hover {
        border-color: #fb9b04;
        color: #fb9b04;
    }

    .detail-title {
        flex: 1;
        min-width: 0;
    }

    .detail-title h2 {
        margin: 0;
        font-size: 2.2vh;
        overflow-wrap: anywhere;
    }

    .detail-title > span {
        color: #9a9a9a;
        font-size: 1.2vh;
    }

    .detail-body {
        display: grid;
        grid-template-columns: minmax(0, 1fr) 25vh;
        gap: 1.6vh;
        flex: 1;
        min-height: 0;
        overflow: hidden;
    }

    .detail-actions {
        min-height: 0;
        overflow-y: auto;
        padding: 1.8vh 0;
    }

    .detail-actions h3 {
        margin: 0 0 1vh;
        font-size: 1.3vh;
        color: #9a9a9a;
    }

    .detail-content {
        overflow-y: auto;
        min-height: 0;
        display: grid;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        align-content: start;
        gap: 0.8vh 1.6vh;
        padding: 1.8vh 0.6vh 1.8vh 0;
        font-size: 1.3vh;
    }

    .info-row {
        flex-direction: column;
        gap: 0.6vh;
        padding: 1.2vh;
        min-width: 0;
        background: #202020;
        border: 0.1vh solid #303030;
    }

    .info-label {
        margin-right: 0;
        min-width: 0;
    }

    .info-value {
        max-width: 100%;
        overflow-wrap: anywhere;
    }

    .info-section-title,
    .clipboard-feedback {
        grid-column: 1 / -1;
    }

    @media (max-width: 900px) {
        .detail-body {
            grid-template-columns: minmax(0, 1fr) 21vh;
        }

        .detail-content {
            grid-template-columns: minmax(0, 1fr);
        }
    }
</style>
