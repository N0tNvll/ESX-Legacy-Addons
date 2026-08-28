<script>
  let { job, jobGrade = "" } = $props()

  const jobColors = {
    police: "#3B82F6",
    ambulance: "#EF4444",
    mechanic: "#F59E0B",
    taxi: "#FBBF24",
    realtor: "#10B981",
    cardealer: "#8B5CF6",
    banker: "#06B6D4",
    unemployed: "#6B7280",
    offpolice: "#1E40AF",
    offambulance: "#991B1B"
  }

  const displayName = $derived(job.charAt(0).toUpperCase() + job.slice(1))
  const color = $derived(jobColors[job.toLowerCase()] || "#FB9B04")
</script>

<span class="job-badge" style="background-color: {color}20; color: {color}; border: 1px solid {color}40;">
  {displayName}
  {#if jobGrade}
    <span class="grade">- {jobGrade}</span>
  {/if}
</span>

<style>
  .job-badge {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 2px 10px;
    border-radius: 12px;
    font-size: 12px;
    font-weight: 500;
    white-space: nowrap;
  }

  .grade {
    opacity: 0.8;
    font-size: 11px;
  }
</style>