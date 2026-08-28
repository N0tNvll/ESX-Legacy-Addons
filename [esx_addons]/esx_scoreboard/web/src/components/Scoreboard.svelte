<script>
  import { scoreboardStore, filteredPlayers, setSortBy } from "../stores/scoreboard.js"
  import Header from "./Header.svelte"
  import SearchBar from "./SearchBar.svelte"
  import PlayerRow from "./PlayerRow.svelte"
  import Footer from "./Footer.svelte"

  const columns = [
    { key: "serverId", label: "ID" },
    { key: "name", label: "Name" },
    { key: "job", label: "Job" },
    { key: "ping", label: "Ping" }
  ]

  function handleSort(key) {
    setSortBy(key)
  }

  function getSortIndicator(currentSortBy, currentSortAsc, key) {
    if (currentSortBy !== key) return "↕"
    return currentSortAsc ? "↑" : "↓"
  }
</script>

{#if $scoreboardStore.visible}
  <div class="scoreboard-overlay">
    <div class="scoreboard-container">
      <Header
        serverName={$scoreboardStore.serverName}
        maxPlayers={$scoreboardStore.maxPlayers}
        uptime={$scoreboardStore.uptime}
        logoUrl={$scoreboardStore.logoUrl}
      />
      <SearchBar jobs={$scoreboardStore.jobs} />

      <div class="table-header">
        {#each columns as col}
          <button
            class="col-header"
            class:active={$scoreboardStore.sortBy === col.key}
            onclick={() => handleSort(col.key)}
          >
            {col.label}
            <span class="sort-icon">{getSortIndicator($scoreboardStore.sortBy, $scoreboardStore.sortAsc, col.key)}</span>
          </button>
        {/each}
      </div>

      <div class="players-list">
        {#if $filteredPlayers.length === 0}
          <div class="empty-state">
            <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="var(--light-color)" stroke-width="1.5">
              <circle cx="11" cy="11" r="8"></circle>
              <path d="m21 21-4.3-4.3"></path>
            </svg>
            <p>No players found</p>
          </div>
        {:else}
          {#each $filteredPlayers as player, index (player.serverId)}
            <PlayerRow
              serverId={player.serverId}
              name={player.name}
              job={player.job}
              jobGrade={player.jobGrade}
              group={player.group}
              ping={player.ping}
              {index}
            />
          {/each}
        {/if}
      </div>

      <Footer activities={$scoreboardStore.activities} />
    </div>
  </div>
{/if}

<style>
  .scoreboard-overlay {
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(0, 0, 0, 0.6);
    z-index: 9999;
    animation: fadeIn 0.2s ease;
  }

  .scoreboard-container {
    width: 860px;
    max-width: 95vw;
    max-height: 85vh;
    display: flex;
    flex-direction: column;
    background: var(--background-color);
    border-radius: 12px;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
    overflow: hidden;
    animation: slideUp 0.3s ease;
  }

  .table-header {
    display: grid;
    grid-template-columns: 60px 1fr 220px 80px;
    align-items: center;
    padding: 10px 20px;
    background: var(--darkest-color);
    border-bottom: 2px solid var(--mid-color);
  }

  .col-header {
    display: flex;
    align-items: center;
    gap: 4px;
    background: none;
    border: none;
    color: var(--light-color);
    font-family: "Poppins", sans-serif;
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    padding: 4px 0;
    cursor: pointer;
    transition: color 0.2s ease;
  }

  .col-header:hover {
    color: var(--lightest-color);
  }

  .col-header.active {
    color: var(--brand-color);
  }

  .sort-icon {
    font-size: 10px;
    opacity: 0.6;
  }

  .col-header.active .sort-icon {
    opacity: 1;
  }

  .players-list {
    flex: 1;
    overflow-y: auto;
    max-height: 50vh;
    min-height: 200px;
  }

  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 12px;
    padding: 60px 20px;
    color: var(--light-color);
  }

  .empty-state p {
    font-size: 14px;
  }

  @keyframes fadeIn {
    from { opacity: 0; }
    to { opacity: 1; }
  }

  @keyframes slideUp {
    from {
      opacity: 0;
      transform: translateY(20px) scale(0.98);
    }
    to {
      opacity: 1;
      transform: translateY(0) scale(1);
    }
  }
</style>