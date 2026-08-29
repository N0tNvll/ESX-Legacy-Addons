<script>
  import JobBadge from "./JobBadge.svelte"

  let { serverId, name, job, jobGrade, group, ping, index } = $props()

  function getPingColor(pingValue) {
    if (pingValue < 60) return "#10B981"
    if (pingValue < 120) return "#FBBF24"
    return "#EF4444"
  }

  function getGroupInfo(groupName) {
    const groups = {
      admin: { label: "Admin", color: "#EF4444" },
      mod: { label: "Mod", color: "#F59E0B" },
      supporter: { label: "Supp", color: "#3B82F6" },
      user: { label: "Player", color: "var(--light-color)" }
    }
    return groups[groupName.toLowerCase()] || groups.user
  }

  const groupInfo = $derived(getGroupInfo(group))
  const pingColor = $derived(getPingColor(ping))
  const isEven = $derived(index % 2 === 0)
</script>

<div class="player-row" class:even={isEven}>
  <div class="col id">
    <span class="id-badge">{serverId}</span>
  </div>

  <div class="col name">
    <span class="player-name">{name}</span>
    {#if group.toLowerCase() !== "user"}
      <span class="group-tag" style="color: {groupInfo.color}">{groupInfo.label}</span>
    {/if}
  </div>

  <div class="col job">
    <JobBadge {job} {jobGrade} />
  </div>

  <div class="col ping">
    <div class="ping-indicator">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={pingColor} stroke-width="2">
        <path d="M22 12h-4l-3 9L9 3l-3 9H2"></path>
      </svg>
      <span class="ping-value" style="color: {pingColor}">{ping}ms</span>
    </div>
  </div>
</div>

<style>
  .player-row {
    display: grid;
    grid-template-columns: 60px 1fr 220px 80px;
    align-items: center;
    padding: 10px 20px;
    background: var(--dark-color);
    border-bottom: 1px solid var(--mid-color);
    transition: background 0.15s ease;
  }

  .player-row.even {
    background: rgba(37, 37, 37, 0.6);
  }

  .player-row:hover {
    background: var(--mid-color);
  }

  .col {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .col.id {
    justify-content: flex-start;
  }

  .col.name {
    min-width: 0;
  }

  .col.job {
    justify-content: flex-start;
  }

  .col.ping {
    justify-content: flex-start;
    min-width: 70px;
  }

  .id-badge {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 32px;
    padding: 2px 8px;
    background: var(--mid-color);
    border-radius: 6px;
    font-size: 12px;
    font-weight: 600;
    color: var(--lightest-color);
  }

  .player-name {
    font-size: 14px;
    font-weight: 500;
    color: var(--lightest-color);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .group-tag {
    font-size: 10px;
    font-weight: 600;
    padding: 1px 6px;
    background: rgba(255, 255, 255, 0.08);
    border-radius: 4px;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    white-space: nowrap;
    flex-shrink: 0;
  }

  .ping-indicator {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .ping-value {
    font-size: 12px;
    font-weight: 600;
  }
</style>