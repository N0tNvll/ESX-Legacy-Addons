<!--
  @component WeaponDetails
  Displays the selected weapon preview and purchase action
-->
<script lang="ts">
  import { shopStore } from '@stores/shopStore.svelte';
  import { fetchNui } from '@utils/nui';
  import { NUI_EVENTS } from '@/types/nui';
  import WeaponImage from './WeaponImage.svelte';

  let item = $derived(shopStore.selectedItem);
  let categoryLabel = $derived(
    item
      ? (shopStore.categories.find((category) => category.id === item.category)?.label ?? item.category)
      : ''
  );

  /**
   * Purchases the currently selected weapon
   */
  async function buyWeapon(): Promise<void> {
    if (!item || shopStore.buying) {
      return;
    }

    shopStore.buying = true;
    await fetchNui(NUI_EVENTS.BUY_WEAPON, {
      weaponName: item.name
    });
    shopStore.buying = false;
  }
</script>

<div class="details">
  {#if item}
    <div class="preview">
      <WeaponImage name={item.name} image={item.image} alt={item.label} />
    </div>
    <div class="meta">
      <div class="name">{item.label}</div>
      <div class="category">{categoryLabel}</div>
    </div>
    <div class="price">${item.price.toLocaleString()}</div>
    <button class="buy" disabled={shopStore.buying} onclick={buyWeapon}>
      {shopStore.locales.buy}
    </button>
  {:else}
    <div class="empty">{shopStore.locales.noWeaponSelected}</div>
  {/if}
</div>

<style>
  .details {
    width: 100%;
    flex: 1;
    min-height: 0;
    display: grid;
    grid-template-columns: minmax(0, 1fr) auto;
    grid-template-rows: minmax(13rem, 1fr) auto 2.65rem;
    overflow: hidden;
    margin: 0.75rem 0.75rem 1rem 0;
    padding: 0.85rem;
    gap: 0.75rem;
    background: rgba(var(--lightest-color-rgb), 0.035);
    border: 1px solid rgba(var(--lightest-color-rgb), 0.08);
    border-radius: 0.35rem;
  }

  .preview {
    --weapon-image-width: auto;
    --weapon-image-max-width: 13rem;
    --weapon-image-max-height: 56%;
    position: relative;
    grid-column: 1 / -1;
    min-height: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background:
      linear-gradient(180deg, rgba(var(--lightest-color-rgb), 0.06), rgba(var(--lightest-color-rgb), 0.025)),
      repeating-linear-gradient(90deg, transparent 0, transparent 2.8rem, rgba(var(--lightest-color-rgb), 0.025) 2.85rem),
      repeating-linear-gradient(0deg, transparent 0, transparent 2.8rem, rgba(var(--lightest-color-rgb), 0.02) 2.85rem);
    border: 1px solid rgba(var(--lightest-color-rgb), 0.08);
    border-radius: 0.25rem;
    padding: 1.5rem;
    overflow: hidden;
  }

  .preview::after {
    content: '';
    position: absolute;
    left: 13%;
    right: 13%;
    bottom: 16%;
    height: 0.12rem;
    background: linear-gradient(90deg, transparent, rgba(var(--brand-color-rgb), 0.72), transparent);
    box-shadow: 0 0 1rem rgba(var(--brand-color-rgb), 0.2);
  }

  .meta {
    grid-column: 1;
    align-self: center;
    min-width: 0;
    border-left: 0.18rem solid var(--brand-color);
    padding-left: 0.65rem;
  }

  .name {
    font-size: 1.12rem;
    font-weight: 700;
    line-height: 1.1;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .category {
    display: inline-flex;
    margin-top: 0.35rem;
    padding: 0.18rem 0.42rem;
    background: rgba(var(--lightest-color-rgb), 0.08);
    border-radius: 0.2rem;
    font-size: 0.75rem;
    color: var(--light-color);
    text-transform: uppercase;
  }

  .price {
    grid-column: 2;
    grid-row: 2;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    align-self: flex-start;
    min-width: 4.7rem;
    min-height: 2.25rem;
    margin-top: 0;
    padding: 0.25rem 0.65rem;
    background: rgba(var(--brand-color-rgb), 0.16);
    border: 1px solid rgba(var(--brand-color-rgb), 0.25);
    border-radius: 0.25rem;
    font-size: 1.18rem;
    font-weight: 700;
    color: var(--brand-color);
  }

  .buy {
    grid-column: 1 / -1;
    grid-row: 3;
    margin-top: 0;
    border: none;
    border-radius: 0.25rem;
    background: var(--brand-color);
    color: var(--darkest-color);
    font-family: var(--font-family);
    font-weight: 700;
    font-size: 0.95rem;
    padding: 0.7rem 0.5rem;
    cursor: pointer;
    transition: filter 0.2s ease, transform 0.2s ease;
  }

  .buy:disabled {
    opacity: 0.55;
    cursor: default;
  }

  .buy:not(:disabled):hover {
    filter: brightness(1.08);
    transform: translateY(-0.05rem);
  }

  .empty {
    grid-column: 1 / -1;
    grid-row: 1 / -1;
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    text-align: center;
    color: var(--light-color);
    font-size: 0.9rem;
    padding: 1rem;
  }
</style>
