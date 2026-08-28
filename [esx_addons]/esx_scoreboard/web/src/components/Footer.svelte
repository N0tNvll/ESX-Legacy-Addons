<script>
  let { activities } = $props()

  function getActivityIcon(type) {
    const icons = {
      robbery: "💰",
      heist: "🏦",
      drug: "💊",
      race: "🏎️",
      hostage: "🚫",
      shootout: "🔫"
    }
    return icons[type.toLowerCase()] || "⚡"
  }
</script>

<footer class="scoreboard-footer">
  <div class="footer-left">
    <span class="footer-label">Active Events</span>
    {#if activities.length === 0}
      <span class="no-events">No active events</span>
    {:else}
      <div class="activity-scroll-wrapper">
        <div class="activity-list">
          {#each activities as activity}
            <div class="activity-item">
              <span class="activity-icon">{getActivityIcon(activity.type)}</span>
              <span class="activity-name">{activity.label}</span>
              {#if activity.location}
                <span class="activity-loc">@ {activity.location}</span>
              {/if}
            </div>
          {/each}
        </div>
      </div>
    {/if}
  </div>

  <div class="footer-right">
    <div class="key-hint">
      <kbd>ESC</kbd>
      <span>Close</span>
    </div>
    <div class="key-hint">
      <kbd>↑↓</kbd>
      <span>Scroll</span>
    </div>
    <div class="key-hint">
      <kbd>Click</kbd>
      <span>Sort</span>
    </div>
  </div>
</footer>

<style>
  .scoreboard-footer {
    display: grid;
    grid-template-columns: 1fr auto;
    align-items: center;
    gap: 16px;
    padding: 12px 24px;
    background: var(--dark-color);
    border-top: 1px solid var(--mid-color);
    border-radius: 0 0 12px 12px;
    min-height: 56px;
  }

  .footer-left {
    display: flex;
    align-items: center;
    gap: 12px;
    min-width: 0;
    overflow: visible;
  }

  .footer-label {
    font-size: 11px;
    font-weight: 600;
    color: var(--light-color);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    white-space: nowrap;
    flex-shrink: 0;
  }

  .no-events {
    font-size: 12px;
    color: var(--mid-color);
    font-style: italic;
    white-space: nowrap;
  }

  .activity-scroll-wrapper {
    flex: 1;
    min-width: 0;
    overflow-x: auto;
    overflow-y: hidden;
    -webkit-overflow-scrolling: touch;
    scrollbar-width: thin;
    scrollbar-color: var(--mid-color) transparent;
    padding-bottom: 4px;
    mask-image: linear-gradient(to right, black 90%, transparent 100%);
    -webkit-mask-image: linear-gradient(to right, black 90%, transparent 100%);
  }

  .activity-scroll-wrapper::-webkit-scrollbar {
    height: 4px;
  }

  .activity-scroll-wrapper::-webkit-scrollbar-track {
    background: transparent;
  }

  .activity-scroll-wrapper::-webkit-scrollbar-thumb {
    background: var(--mid-color);
    border-radius: 2px;
  }

  .activity-list {
    display: flex;
    align-items: center;
    gap: 8px;
    width: max-content;
  }

  .activity-item {
    display: flex;
    align-items: center;
    gap: 5px;
    padding: 5px 12px;
    background: rgba(251, 155, 4, 0.1);
    border: 1px solid rgba(251, 155, 4, 0.25);
    border-radius: 8px;
    font-size: 12px;
    color: var(--lightest-color);
    white-space: nowrap;
    flex-shrink: 0;
    animation: slideIn 0.3s ease;
  }

  .activity-icon {
    font-size: 13px;
  }

  .activity-name {
    font-weight: 500;
  }

  .activity-loc {
    color: var(--light-color);
    font-size: 11px;
  }

  .footer-right {
    display: flex;
    align-items: center;
    gap: 12px;
    flex-shrink: 0;
  }

  .key-hint {
    display: flex;
    align-items: center;
    gap: 5px;
  }

  .key-hint kbd {
    padding: 2px 7px;
    background: var(--mid-color);
    border: 1px solid var(--light-color);
    border-radius: 4px;
    font-size: 10px;
    font-weight: 600;
    color: var(--lightest-color);
    font-family: "Poppins", sans-serif;
    white-space: nowrap;
  }

  .key-hint span {
    font-size: 10px;
    color: var(--light-color);
    white-space: nowrap;
  }

  @keyframes slideIn {
    from {
      opacity: 0;
      transform: translateX(-10px);
    }
    to {
      opacity: 1;
      transform: translateX(0);
    }
  }
</style>