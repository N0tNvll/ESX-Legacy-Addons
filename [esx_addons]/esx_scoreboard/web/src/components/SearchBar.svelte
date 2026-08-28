<script>
  import { setSearchQuery } from "../stores/scoreboard.js"

  let { jobs } = $props()

  let searchValue = $state("")

  function handleInput(e) {
    searchValue = e.target.value
    setSearchQuery(searchValue)
  }

  function clearSearch() {
    searchValue = ""
    setSearchQuery("")
  }
</script>

<div class="search-bar">
  <div class="search-input-wrapper">
    <svg class="search-icon" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
      <circle cx="11" cy="11" r="8"></circle>
      <path d="m21 21-4.3-4.3"></path>
    </svg>
    <input
      type="text"
      class="search-input"
      placeholder="Search players by name, job, or ID..."
      value={searchValue}
      oninput={handleInput}
    />
    {#if searchValue}
      <button class="clear-btn" onclick={clearSearch} aria-label="Clear search">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M18 6 6 18"></path>
          <path d="m6 6 12 12"></path>
        </svg>
      </button>
    {/if}
  </div>

  <div class="job-filters">
    {#each jobs.slice(0, 6) as job}
      <span class="job-pill">
        {job.label} <strong>{job.count}</strong>
      </span>
    {/each}
  </div>
</div>

<style>
  .search-bar {
    padding: 14px 28px;
    background: var(--darkest-color);
    border-bottom: 1px solid var(--mid-color);
  }

  .search-input-wrapper {
    position: relative;
    display: flex;
    align-items: center;
  }

  .search-icon {
    position: absolute;
    left: 14px;
    color: var(--light-color);
    pointer-events: none;
  }

  .search-input {
    width: 100%;
    padding: 10px 14px 10px 42px;
    background: var(--dark-color);
    border: 1px solid var(--mid-color);
    border-radius: 8px;
    color: var(--lightest-color);
    font-family: "Poppins", sans-serif;
    font-size: 14px;
    outline: none;
    transition: border-color 0.2s ease;
  }

  .search-input::placeholder {
    color: var(--light-color);
  }

  .search-input:focus {
    border-color: var(--brand-color);
  }

  .clear-btn {
    position: absolute;
    right: 10px;
    background: none;
    border: none;
    color: var(--light-color);
    cursor: pointer;
    padding: 4px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 4px;
    transition: color 0.2s ease;
  }

  .clear-btn:hover {
    color: var(--lightest-color);
  }

  .job-filters {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-top: 10px;
  }

  .job-pill {
    padding: 3px 10px;
    background: var(--dark-color);
    border: 1px solid var(--mid-color);
    border-radius: 12px;
    font-size: 11px;
    color: var(--light-color);
    font-weight: 400;
  }

  .job-pill strong {
    color: var(--brand-color);
    margin-left: 4px;
  }
</style>