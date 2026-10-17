<script lang="ts">
  import { Clock } from 'lucide-svelte';
  import backgroundImage from '../assets/background.webp';
  import pumpkinImage from '../assets/pumpkin.webp';
  interface Props { visible?: boolean; current?: number; total?: number; timeRemaining?: number }
  let { visible = false, current = 0, total = 0, timeRemaining = 0 }: Props = $props();
  const progress = $derived(total > 0 ? Math.min(100, Math.max(0, current / total * 100)) : 0);
  const displayTime = $derived.by(() => {
    const seconds = Math.max(0, Math.floor(timeRemaining / 1000));
    return Math.floor(seconds / 60) + ':' + (seconds % 60).toString().padStart(2, '0');
  });
</script>

{#if visible}
  <div class="trick-or-treat-hud">
    <div class="hud-card">
      <!-- Background image layer -->
      <img src={backgroundImage} alt="" class="hud-card__background" />

      <!-- Pumpkin overlay (right side) -->
      <img src={pumpkinImage} alt="" class="hud-card__pumpkin" />

      <!-- Content layer -->
      <div class="hud-card__content">
        <!-- Header with Halloween font -->
        <div class="hud-header">
          <h3 class="hud-title">Trick or Treat!</h3>
        </div>

        <!-- Progress bar section -->
        <div class="progress-section">
          <div class="progress-bar-container">
            <div class="progress-bar">
              <div class="progress-fill" style="width: {progress}%"></div>
            </div>
          </div>

          <!-- Progress text (X / Y houses) -->
          <div class="progress-text">{current} / {total} houses</div>
        </div>

        <!-- Timer section -->
        <div class="timer-section">
          <Clock class="timer-icon" size={18} strokeWidth={2} />
          <span class="timer-text">Time Left: {displayTime}</span>
        </div>
      </div>
    </div>
  </div>
{/if}

<style>
  .trick-or-treat-hud {
    position: fixed;
    top: var(--space-xl);
    left: var(--space-xl);
    z-index: var(--z-fixed);
    animation: slideIn 400ms ease-out;
  }

  .hud-card {
    position: relative;
    border-radius: var(--radius-lg);
    padding: var(--space-lg);
    min-width: 18.75rem;
    overflow: hidden;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.4);
  }

  /* Background image layer (z-index: 1) */
  .hud-card__background {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    width: 120%;
    height: 120%;
    object-fit: cover;
    filter: brightness(0.7);
    z-index: 1;
    pointer-events: none;
  }

  /* Pumpkin overlay (z-index: 2) */
  .hud-card__pumpkin {
    position: absolute;
    right: 0;
    top: 50%;
    transform: translateY(-50%);
    height: 85%;
    z-index: 2;
    pointer-events: none;
    animation: pumpkinGlow 2s ease-in-out infinite;
  }

  /* Content layer (z-index: 3) */
  .hud-card__content {
    position: relative;
    z-index: 3;
    max-width: 70%;
  }

  .hud-header {
    margin-bottom: var(--space-lg);
  }

  .hud-title {
    color: var(--color-brand);
    font-size: var(--font-size-h3);
    font-family: var(--font-family-halloween);
    font-weight: var(--font-weight-bold);
    margin: 0;
    letter-spacing: 0.02em;
    text-shadow: 0 2px 8px rgba(0, 0, 0, 0.6);
  }

  .progress-section {
    margin-bottom: var(--space-md);
  }

  .progress-bar-container {
    background: rgba(255, 255, 255, 0.08);
    height: 0.625rem;
    border-radius: var(--radius-sm);
    overflow: hidden;
    margin-bottom: var(--space-sm);
    border: 1px solid rgba(var(--color-brand-rgb), 0.2);
  }

  .progress-bar {
    width: 100%;
    height: 100%;
    position: relative;
  }

  .progress-fill {
    background: linear-gradient(90deg, rgba(var(--color-brand-rgb), 0.6), var(--color-brand));
    height: 100%;
    transition: width var(--transition-base) cubic-bezier(0.34, 1.56, 0.64, 1);
    box-shadow: 0 0 15px rgba(var(--color-brand-rgb), 0.8), inset 0 0 10px rgba(255, 255, 255, 0.2);
  }

  .progress-text {
    color: var(--color-lightest);
    font-size: var(--font-size-small);
    font-weight: 300;
  }

  .timer-section {
    display: flex;
    align-items: center;
    gap: var(--space-sm);
    color: var(--color-brand);
    font-size: var(--font-size-small);
  }

  :global(.timer-icon) {
    color: var(--color-brand);
    animation: pulse 1s ease-in-out infinite;
  }

  .timer-text {
    font-weight: var(--font-weight-medium);
    color: var(--color-lightest);
  }

  @keyframes slideIn {
    from {
      opacity: 0;
      transform: translateX(-1.25rem);
    }
    to {
      opacity: 1;
      transform: translateX(0);
    }
  }

  @keyframes pumpkinGlow {
    0%, 100% {
      filter: brightness(1.1) saturate(1.2);
    }
    50% {
      filter: brightness(1.4) saturate(1.6);
    }
  }

  @keyframes pulse {
    0%, 100% {
      transform: scale(1);
    }
    50% {
      transform: scale(1.15);
    }
  }
</style>
