const resourceName = typeof GetParentResourceName === "function" ? GetParentResourceName() : "esx_scoreboard"
const app = document.getElementById("app")

const state = {
  visible: false,
  loading: false,
  players: [],
  jobs: [],
  activities: [],
  info: {
    serverName: "ESX Server",
    maxPlayers: 64,
    uptime: 0,
    logoUrl: ""
  },
  totalPlayers: 0,
  page: 1,
  pageSize: 50,
  total: 0,
  totalPages: 1,
  search: "",
  sortBy: "serverId",
  sortAsc: true,
  paging: {
    defaultPageSize: 50,
    maxPageSize: 100
  }
}

let searchTimer = 0

function post(name, data = {}) {
  return fetch(`https://${resourceName}/${name}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json; charset=UTF-8"
    },
    body: JSON.stringify(data)
  })
}

function asText(value, fallback = "") {
  if (typeof value !== "string") {
    return fallback
  }

  const text = value.replace(/[\u0000-\u001f\u007f]/g, "").trim()
  return text.length > 0 ? text : fallback
}

function asNumber(value, fallback = 0) {
  const number = Number(value)
  return Number.isFinite(number) ? number : fallback
}

function safeHex(value, fallback = "#6B7280") {
  return /^#[0-9a-f]{6}$/i.test(value || "") ? value : fallback
}

function safeUrl(value) {
  const url = asText(value, "")
  return /^https:\/\//i.test(url) ? url : ""
}

function normalizePlayer(player) {
  const job = asText(player?.job, "unemployed")

  return {
    serverId: Math.max(0, Math.floor(asNumber(player?.serverId, 0))),
    name: asText(player?.name, "Unknown").slice(0, 64),
    job,
    jobLabel: asText(player?.jobLabel, job).slice(0, 64),
    jobGrade: asText(player?.jobGrade, "").slice(0, 64),
    ping: Math.max(0, Math.floor(asNumber(player?.ping, 0))),
    activity: asText(player?.activity, "")
  }
}

function normalizeJob(job) {
  const name = asText(job?.name, "unemployed")
  return {
    name,
    label: asText(job?.label, name).slice(0, 64),
    count: Math.max(0, Math.floor(asNumber(job?.count, 0))),
    color: safeHex(job?.color)
  }
}

function normalizeActivity(activity) {
  return {
    id: Math.floor(asNumber(activity?.id, 0)),
    type: asText(activity?.type, "activity").slice(0, 50),
    label: asText(activity?.label, "Activity").slice(0, 100),
    location: asText(activity?.location, "").slice(0, 100),
    players: Array.isArray(activity?.players) ? activity.players.slice(0, 16) : []
  }
}

function ingestSummary(summary) {
  if (!summary || typeof summary !== "object") {
    return
  }

  state.totalPlayers = Math.max(0, Math.floor(asNumber(summary.totalPlayers, state.totalPlayers)))
  state.jobs = Array.isArray(summary.jobs) ? summary.jobs.map(normalizeJob) : state.jobs
  state.activities = Array.isArray(summary.activities) ? summary.activities.map(normalizeActivity) : state.activities

  if (summary.info && typeof summary.info === "object") {
    state.info = {
      serverName: asText(summary.info.serverName, state.info.serverName).slice(0, 80),
      maxPlayers: Math.max(1, Math.floor(asNumber(summary.info.maxPlayers, state.info.maxPlayers))),
      uptime: Math.max(0, Math.floor(asNumber(summary.info.uptime, state.info.uptime))),
      logoUrl: safeUrl(summary.info.logoUrl)
    }
  }

  if (summary.paging && typeof summary.paging === "object") {
    const maxPageSize = Math.max(10, Math.min(100, Math.floor(asNumber(summary.paging.maxPageSize, 100))))
    const defaultPageSize = Math.max(10, Math.min(maxPageSize, Math.floor(asNumber(summary.paging.defaultPageSize, 50))))
    state.paging = { defaultPageSize, maxPageSize }
    state.pageSize = Math.min(state.pageSize || defaultPageSize, maxPageSize)
  }
}

function ingestPage(page) {
  if (!page || typeof page !== "object") {
    return
  }

  state.players = Array.isArray(page.players) ? page.players.map(normalizePlayer) : []
  state.page = Math.max(1, Math.floor(asNumber(page.page, 1)))
  state.pageSize = Math.max(10, Math.min(state.paging.maxPageSize, Math.floor(asNumber(page.pageSize, state.pageSize))))
  state.total = Math.max(0, Math.floor(asNumber(page.total, state.players.length)))
  state.totalPages = Math.max(1, Math.floor(asNumber(page.totalPages, 1)))
  state.search = asText(page.search, state.search).slice(0, 48)
  state.sortBy = asText(page.sortBy, state.sortBy)
  state.sortAsc = page.sortAsc === true
  state.loading = false
}

function ingestLegacyPayload(data) {
  ingestSummary({
    totalPlayers: Array.isArray(data.players) ? data.players.length : 0,
    jobs: data.jobs,
    activities: data.activities,
    info: data.info
  })

  ingestPage({
    players: data.players,
    page: 1,
    pageSize: Array.isArray(data.players) ? data.players.length : state.pageSize,
    total: Array.isArray(data.players) ? data.players.length : 0,
    totalPages: 1,
    search: "",
    sortBy: "serverId",
    sortAsc: true
  })
}

function requestPage(overrides = {}) {
  const pageSize = Math.max(10, Math.min(state.paging.maxPageSize, Math.floor(asNumber(overrides.pageSize, state.pageSize))))
  const payload = {
    page: Math.max(1, Math.floor(asNumber(overrides.page, state.page))),
    pageSize,
    search: asText(overrides.search ?? state.search, "").slice(0, 48),
    sortBy: asText(overrides.sortBy ?? state.sortBy, "serverId"),
    sortAsc: overrides.sortAsc ?? state.sortAsc
  }

  if (!window.invokeNative) {
    buildLocalPage(payload)
    render()
    return
  }

  state.loading = true
  post("requestPlayersPage", payload).catch(() => {
    state.loading = false
    render()
  })
}

function buildLocalPage(payload) {
  const source = mockData.players.map(normalizePlayer)
  const search = asText(payload.search, "").toLowerCase()
  const filtered = source.filter((player) => {
    if (!search) return true
    return String(player.serverId).includes(search)
      || player.name.toLowerCase().includes(search)
      || player.job.toLowerCase().includes(search)
      || player.jobLabel.toLowerCase().includes(search)
  })

  filtered.sort((a, b) => {
    let av = a[payload.sortBy]
    let bv = b[payload.sortBy]
    if (typeof av === "string") av = av.toLowerCase()
    if (typeof bv === "string") bv = bv.toLowerCase()
    if (av === bv) return a.serverId - b.serverId
    return payload.sortAsc ? (av > bv ? 1 : -1) : (av < bv ? 1 : -1)
  })

  const totalPages = Math.max(1, Math.ceil(filtered.length / payload.pageSize))
  const page = Math.min(payload.page, totalPages)
  const start = (page - 1) * payload.pageSize

  ingestPage({
    players: filtered.slice(start, start + payload.pageSize),
    page,
    pageSize: payload.pageSize,
    total: filtered.length,
    totalPages,
    search: payload.search,
    sortBy: payload.sortBy,
    sortAsc: payload.sortAsc
  })
}

function formatUptime(seconds) {
  const total = Math.max(0, Math.floor(seconds))
  const hours = Math.floor(total / 3600)
  const minutes = Math.floor((total % 3600) / 60)
  if (hours > 0) {
    return `${hours}h ${minutes}m`
  }
  return `${minutes}m`
}

function el(tag, className, text) {
  const node = document.createElement(tag)
  if (className) node.className = className
  if (text !== undefined) node.textContent = text
  return node
}

function button(className, text, onClick, disabled = false) {
  const node = el("button", className, text)
  node.type = "button"
  node.disabled = disabled
  node.addEventListener("click", onClick)
  return node
}

function renderHeader() {
  const header = el("header", "scoreboard-header")
  const left = el("div", "server-title")
  const logoUrl = safeUrl(state.info.logoUrl)

  if (logoUrl) {
    const logo = el("img", "server-logo")
    logo.src = logoUrl
    logo.alt = ""
    left.appendChild(logo)
  } else {
    left.appendChild(el("div", "server-mark", "ESX"))
  }

  const text = el("div")
  text.appendChild(el("h1", null, state.info.serverName))
  text.appendChild(el("p", null, `${state.totalPlayers}/${state.info.maxPlayers} players online - uptime ${formatUptime(state.info.uptime)}`))
  left.appendChild(text)

  const close = button("icon-button", "X", () => {
    if (window.invokeNative) {
      post("closeScoreboard").catch(() => {})
    } else {
      state.visible = false
      render()
    }
  })
  close.setAttribute("aria-label", "Close scoreboard")

  header.appendChild(left)
  header.appendChild(close)
  return header
}

function renderJobs() {
  const section = el("section", "job-strip")

  if (state.jobs.length === 0) {
    section.appendChild(el("span", "muted", "No active jobs"))
    return section
  }

  for (const job of state.jobs) {
    const item = el("div", "job-count")
    item.style.setProperty("--job-color", job.color)
    item.appendChild(el("span", "job-dot"))
    item.appendChild(el("strong", null, String(job.count)))
    item.appendChild(el("span", null, job.label))
    section.appendChild(item)
  }

  return section
}

function sortButton(label, field) {
  const active = state.sortBy === field
  const text = active ? `${label} ${state.sortAsc ? "ASC" : "DESC"}` : label
  return button(active ? "sort-button active" : "sort-button", text, () => {
    const sortAsc = state.sortBy === field ? !state.sortAsc : true
    requestPage({ page: 1, sortBy: field, sortAsc })
  })
}

function renderToolbar() {
  const toolbar = el("section", "table-toolbar")
  const search = el("input", "search-input")
  search.type = "search"
  search.maxLength = 48
  search.placeholder = "Search ID, name or job"
  search.value = state.search
  search.addEventListener("input", () => {
    state.search = search.value.slice(0, 48)
    window.clearTimeout(searchTimer)
    searchTimer = window.setTimeout(() => {
      requestPage({ page: 1, search: state.search })
    }, 350)
  })

  const pageSize = el("select", "page-size")
  const sizes = [25, 50, 100].filter((size) => size <= state.paging.maxPageSize)
  if (!sizes.includes(state.pageSize)) {
    sizes.unshift(state.pageSize)
  }
  for (const size of sizes) {
    const option = el("option", null, `${size} rows`)
    option.value = String(size)
    option.selected = size === state.pageSize
    pageSize.appendChild(option)
  }
  pageSize.addEventListener("change", () => {
    requestPage({ page: 1, pageSize: Number(pageSize.value) })
  })

  const sortControls = el("div", "sort-controls")
  sortControls.appendChild(sortButton("ID", "serverId"))
  sortControls.appendChild(sortButton("Name", "name"))
  sortControls.appendChild(sortButton("Job", "job"))
  sortControls.appendChild(sortButton("Ping", "ping"))

  toolbar.appendChild(search)
  toolbar.appendChild(pageSize)
  toolbar.appendChild(sortControls)
  return toolbar
}

function renderPlayers() {
  const section = el("section", "player-panel")
  section.appendChild(renderToolbar())

  const table = el("div", "player-table")
  const header = el("div", "player-row table-head")
  for (const label of ["ID", "Name", "Job", "Grade", "Ping", "Activity"]) {
    header.appendChild(el("span", null, label))
  }
  table.appendChild(header)

  if (state.players.length === 0) {
    const empty = el("div", "empty-state", state.loading ? "Loading players..." : "No players found")
    table.appendChild(empty)
  } else {
    for (const player of state.players) {
      const row = el("div", "player-row")
      row.appendChild(el("span", "server-id", String(player.serverId)))
      row.appendChild(el("span", "player-name", player.name))

      const job = el("span", "job-badge", player.jobLabel)
      const jobConfig = state.jobs.find((item) => item.name === player.job)
      job.style.setProperty("--job-color", jobConfig ? jobConfig.color : "#6B7280")
      row.appendChild(job)

      row.appendChild(el("span", "muted", player.jobGrade || "-"))

      const ping = el("span", player.ping >= 150 ? "ping high" : player.ping >= 90 ? "ping warn" : "ping", `${player.ping} ms`)
      row.appendChild(ping)
      row.appendChild(el("span", "muted", player.activity || "-"))
      table.appendChild(row)
    }
  }

  const pager = el("div", "pager")
  pager.appendChild(button("pager-button", "Prev", () => requestPage({ page: state.page - 1 }), state.page <= 1))
  pager.appendChild(el("span", "pager-text", `Page ${state.page}/${state.totalPages} - ${state.total} results`))
  pager.appendChild(button("pager-button", "Next", () => requestPage({ page: state.page + 1 }), state.page >= state.totalPages))

  section.appendChild(table)
  section.appendChild(pager)
  return section
}

function renderActivities() {
  const section = el("aside", "activity-panel")
  section.appendChild(el("h2", null, "Activities"))

  if (state.activities.length === 0) {
    section.appendChild(el("p", "muted", "No active activities"))
    return section
  }

  for (const activity of state.activities) {
    const item = el("div", "activity-item")
    item.appendChild(el("strong", null, activity.label))
    item.appendChild(el("span", null, activity.location || activity.type))
    if (activity.players.length > 0) {
      item.appendChild(el("small", null, `${activity.players.length} players`))
    }
    section.appendChild(item)
  }

  return section
}

function render() {
  document.body.classList.toggle("scoreboard-visible", state.visible)
  app.replaceChildren()

  if (!state.visible) {
    return
  }

  const shell = el("main", "scoreboard-shell")
  shell.appendChild(renderHeader())
  shell.appendChild(renderJobs())

  const grid = el("div", "content-grid")
  grid.appendChild(renderPlayers())
  grid.appendChild(renderActivities())
  shell.appendChild(grid)

  app.appendChild(shell)
}

function applyTheme(data) {
  const root = document.documentElement
  const colors = {
    "--primary-color": data.primaryColor,
    "--secondary-color": data.secondaryColor,
    "--background-color": data.backgroundColor,
    "--accent-color": data.accentColor
  }

  for (const [key, value] of Object.entries(colors)) {
    if (safeHex(value, "") !== "") {
      root.style.setProperty(key, value)
    }
  }

  if (safeUrl(data.logoUrl)) {
    state.info.logoUrl = safeUrl(data.logoUrl)
    render()
  }
}

window.addEventListener("message", (event) => {
  const data = event.data
  if (!data || typeof data !== "object") {
    return
  }

  switch (data.type) {
    case "show":
      state.visible = true
      render()
      break
    case "hide":
      state.visible = false
      state.loading = false
      render()
      break
    case "updateSummary":
      ingestSummary(data.summary)
      render()
      break
    case "updatePage":
      ingestPage(data.page)
      render()
      break
    case "updateActivities":
      state.activities = Array.isArray(data.activities) ? data.activities.map(normalizeActivity) : []
      render()
      break
    case "updateAll":
      ingestLegacyPayload(data)
      render()
      break
    case "updateTheme":
      applyTheme(data)
      break
    default:
      break
  }
})

window.addEventListener("keyup", (event) => {
  if (event.key !== "Escape" || !state.visible) {
    return
  }

  event.preventDefault()
  if (window.invokeNative) {
    post("closeScoreboard").catch(() => {})
  } else {
    state.visible = false
    render()
  }
})

const mockData = {
  players: [
    { serverId: 1, name: "John_Doe", job: "police", jobLabel: "Police", jobGrade: "Sergeant", ping: 24 },
    { serverId: 2, name: "Jane_Smith", job: "ambulance", jobLabel: "EMS", jobGrade: "Paramedic", ping: 45 },
    { serverId: 3, name: "Mike_Ross", job: "mechanic", jobLabel: "Mechanic", jobGrade: "Expert", ping: 112 },
    { serverId: 4, name: "Sarah_Connor", job: "police", jobLabel: "Police", jobGrade: "Officer", ping: 34 },
    { serverId: 5, name: "Tony_Stark", job: "unemployed", jobLabel: "Civilian", jobGrade: "", ping: 78 },
    { serverId: 6, name: "Bruce_Wayne", job: "police", jobLabel: "Police", jobGrade: "Chief", ping: 12 }
  ],
  jobs: [
    { name: "police", label: "Police", count: 3, color: "#3B82F6" },
    { name: "ambulance", label: "EMS", count: 1, color: "#EF4444" },
    { name: "mechanic", label: "Mechanic", count: 1, color: "#F59E0B" },
    { name: "unemployed", label: "Civilian", count: 1, color: "#6B7280" }
  ],
  activities: [
    { id: 1, type: "robbery", label: "Fleeca Bank", location: "Legion Square", players: [1, 4] }
  ],
  info: {
    serverName: "ESX Development Server",
    maxPlayers: 2048,
    uptime: 3665,
    logoUrl: ""
  }
}

document.addEventListener("DOMContentLoaded", () => {
  if (window.invokeNative) {
    post("nuiReady").catch(() => {})
    return
  }

  state.visible = true
  ingestSummary({
    totalPlayers: mockData.players.length,
    jobs: mockData.jobs,
    activities: mockData.activities,
    info: mockData.info
  })
  buildLocalPage({ page: 1, pageSize: 50, search: "", sortBy: "serverId", sortAsc: true })
  render()
})
