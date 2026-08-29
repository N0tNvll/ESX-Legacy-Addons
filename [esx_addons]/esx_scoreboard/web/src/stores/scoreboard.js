import { writable, derived } from "svelte/store"

/**
 * @typedef {Object} PlayerData
 * @property {number} serverId
 * @property {string} name
 * @property {string} job
 * @property {string} jobGrade
 * @property {string} group
 * @property {number} ping
 * @property {string|null} activity
 */

/**
 * @typedef {Object} JobCount
 * @property {string} name
 * @property {string} label
 * @property {number} count
 * @property {string} color
 */

/**
 * @typedef {Object} ActivityData
 * @property {string} type
 * @property {string} label
 * @property {string} location
 * @property {number} startTime
 */

/**
 * @typedef {Object} ScoreboardState
 * @property {boolean} visible
 * @property {PlayerData[]} players
 * @property {JobCount[]} jobs
 * @property {ActivityData[]} activities
 * @property {string} searchQuery
 * @property {string} sortBy
 * @property {boolean} sortAsc
 * @property {string} serverName
 * @property {number} maxPlayers
 * @property {number} uptime
 * @property {string} logoUrl
 */

/** @type {ScoreboardState} */
const initialState = {
  visible: false,
  players: [],
  jobs: [],
  activities: [],
  searchQuery: "",
  sortBy: "serverId",
  sortAsc: true,
  serverName: "ESX Server",
  maxPlayers: 128,
  uptime: 0,
  logoUrl: ""
}

/**
 * List of valid columns that can be used for sorting.
 * @type {string[]}
 */
const VALID_COLUMNS = ["serverId", "name", "job", "ping"]

/**
 * Core writable store holding the full scoreboard state.
 * @type {import("svelte/store").Writable<ScoreboardState>}
 */
export const scoreboardStore = writable(initialState)

/**
 * Derived store that returns the player list filtered by search query
 * and sorted by the current sort column/direction.
 * Re-computes whenever players, searchQuery, sortBy, or sortAsc change.
 * @type {import("svelte/store").Readable<PlayerData[]>}
 */
export const filteredPlayers = derived(scoreboardStore, ($state) => {
  let players = [...$state.players]

  const query = $state.searchQuery.trim().toLowerCase()
  if (query) {
    players = players.filter((p) =>
      p.name.toLowerCase().includes(query) ||
      p.job.toLowerCase().includes(query) ||
      String(p.serverId).includes(query)
    )
  }

  players.sort((a, b) => {
    let valA = a[$state.sortBy]
    let valB = b[$state.sortBy]

    if (typeof valA === "string") {
      valA = valA.toLowerCase()
      valB = valB.toLowerCase()
    }

    if (valA < valB) return $state.sortAsc ? -1 : 1
    if (valA > valB) return $state.sortAsc ? 1 : -1
    return 0
  })

  return players
})

/**
 * Derived store exposing the total number of connected players.
 * @type {import("svelte/store").Readable<number>}
 */
export const totalPlayers = derived(scoreboardStore, ($state) => $state.players.length)

/**
 * Derived store exposing the count of currently active activities/events.
 * @type {import("svelte/store").Readable<number>}
 */
export const activeActivityCount = derived(scoreboardStore, ($state) => $state.activities.length)

/**
 * Update scoreboard visibility.
 * @param {boolean} visible
 */
export function setVisible(visible) {
  scoreboardStore.update((s) => ({ ...s, visible }))
}

/**
 * Update the full players list.
 * @param {PlayerData[]} players
 */
export function setPlayers(players) {
  scoreboardStore.update((s) => ({ ...s, players }))
}

/**
 * Update the job counts list.
 * @param {JobCount[]} jobs
 */
export function setJobs(jobs) {
  scoreboardStore.update((s) => ({ ...s, jobs }))
}

/**
 * Update the active activities list.
 * @param {ActivityData[]} activities
 */
export function setActivities(activities) {
  scoreboardStore.update((s) => ({ ...s, activities }))
}

/**
 * Set the current search query used to filter the player list.
 * @param {string} query
 */
export function setSearchQuery(query) {
  scoreboardStore.update((s) => ({ ...s, searchQuery: query }))
}

/**
 * Set the sort column. Toggles sort direction if the same column is selected again.
 * @param {string} column
 */
export function setSortBy(column) {
  if (!VALID_COLUMNS.includes(column)) return
  scoreboardStore.update((s) => ({
    ...s,
    sortBy: column,
    sortAsc: s.sortBy === column ? !s.sortAsc : true
  }))
}

/**
 * Update server info fields (name, max players, uptime, logo).
 * Only overwrites keys present in the passed object; preserves existing values for missing keys.
 * @param {Object} info
 * @param {string} [info.serverName]
 * @param {number} [info.maxPlayers]
 * @param {number} [info.uptime]
 * @param {string} [info.logoUrl]
 */
export function setServerInfo(info) {
  scoreboardStore.update((s) => ({
    ...s,
    serverName: info.serverName ?? s.serverName,
    maxPlayers: info.maxPlayers ?? s.maxPlayers,
    uptime: info.uptime ?? s.uptime,
    logoUrl: info.logoUrl ?? s.logoUrl
  }))
}

/**
 * Batch-ingest a full server payload in a single store update.
 * Use this when receiving a consolidated data packet from the server
 * to avoid triggering multiple separate store writes.
 * @param {Object} data
 * @param {PlayerData[]} [data.players]
 * @param {JobCount[]} [data.jobs]
 * @param {ActivityData[]} [data.activities]
 * @param {Object} [data.info]
 * @param {string} [data.info.serverName]
 * @param {number} [data.info.maxPlayers]
 * @param {number} [data.info.uptime]
 * @param {string} [data.info.logoUrl]
 */
export function ingestServerPayload(data) {
  scoreboardStore.update((s) => ({
    ...s,
    ...(data.players && { players: data.players }),
    ...(data.jobs && { jobs: data.jobs }),
    ...(data.activities && { activities: data.activities }),
    ...(data.info && {
      serverName: data.info.serverName ?? s.serverName,
      maxPlayers: data.info.maxPlayers ?? s.maxPlayers,
      uptime: data.info.uptime ?? s.uptime,
      logoUrl: data.info.logoUrl ?? s.logoUrl
    })
  }))
}