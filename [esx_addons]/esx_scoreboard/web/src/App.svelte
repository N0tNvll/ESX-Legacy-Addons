<script>
  import Scoreboard from "./components/Scoreboard.svelte"
  import { ingestServerPayload, setVisible } from "./stores/scoreboard.js"
  const mockData = {
    players: [
      { serverId: 1, name: "John_Doe", job: "police", jobGrade: "Sergeant", group: "admin", ping: 24, activity: "robbery" },
      { serverId: 2, name: "Jane_Smith", job: "ambulance", jobGrade: "Paramedic", group: "owner", ping: 45, activity: null },
      { serverId: 3, name: "Mike_Ross", job: "mechanic", jobGrade: "Expert", group: "user", ping: 112, activity: "race" },
      { serverId: 4, name: "Sarah_Connor", job: "police", jobGrade: "Officer", group: "user", ping: 34, activity: null },
      { serverId: 5, name: "Tony_Stark", job: "unemployed", jobGrade: "", group: "owner", ping: 78, activity: "heist" },
      { serverId: 6, name: "Bruce_Wayne", job: "police", jobGrade: "Chief", group: "admin", ping: 12, activity: null },
      { serverId: 7, name: "Clark_Kent", job: "realtor", jobGrade: "Senior", group: "user", ping: 56, activity: null },
      { serverId: 8, name: "Peter_Parker", job: "taxi", jobGrade: "Driver", group: "user", ping: 89, activity: "drug" },
      { serverId: 9, name: "Wade_Wilson", job: "cardealer", jobGrade: "Manager", group: "superadmin", ping: 67, activity: null },
      { serverId: 10, name: "Logan_Howlett", job: "banker", jobGrade: "Executive", group: "user", ping: 41, activity: "hostage" },
      { serverId: 11, name: "Diana_Prince", job: "ambulance", jobGrade: "Doctor", group: "admin", ping: 29, activity: null },
      { serverId: 12, name: "Barry_Allen", job: "mechanic", jobGrade: "Junior", group: "user", ping: 155, activity: "shootout" }
    ],
    jobs: [
      { name: "police", label: "Police", count: 3, color: "#3B82F6" },
      { name: "ambulance", label: "EMS", count: 2, color: "#EF4444" },
      { name: "mechanic", label: "Mechanic", count: 2, color: "#F59E0B" },
      { name: "taxi", label: "Taxi", count: 1, color: "#FBBF24" },
      { name: "realtor", label: "Realtor", count: 1, color: "#10B981" },
      { name: "cardealer", label: "Car Dealer", count: 1, color: "#8B5CF6" },
      { name: "banker", label: "Banker", count: 1, color: "#06B6D4" },
      { name: "unemployed", label: "Civilian", count: 1, color: "#6B7280" }
    ],
    activities: [
      { type: "robbery", label: "Fleeca Bank", location: "Legion Square" },
      { type: "heist", label: "Pacific Standard", location: "Downtown" },
      { type: "race", label: "Street Race", location: "Vinewood Hills" },
      { type: "drug", label: "Drug Deal", location: "Sandy Shores" },
      { type: "hostage", label: "Hostage Situation", location: "Paleto Bay" },
      { type: "shootout", label: "Gang Shootout", location: "Grove Street" }
    ],
    info: {
      serverName: "ESX Development Server",
      maxPlayers: 128,
      uptime: 3665,
      logoUrl: ""
    }
  }

  function loadMockData() {
    ingestServerPayload(mockData)
    setVisible(true)
  }

  /**
   * Handle Escape key to close scoreboard
   * Using keyup is more reliable in FiveM NUI than keydown
   * @param {KeyboardEvent} e
   */
  function handleKeyup(e) {
    if (e.key === "Escape") {
      e.preventDefault()
      e.stopPropagation()
      if (window.invokeNative) {
        fetch("https://esx_scoreboard/closeScoreboard", { method: "POST" })
      } else {
        setVisible(false)
      }
    }
  }

  $effect(() => {
    function handleNuiMessage(event) {
      const data = event.data

      switch (data.type) {
        case "show":
          setVisible(true)
          break
        case "hide":
          setVisible(false)
          break
        case "updateAll":
          ingestServerPayload(data)
          break
        case "updateTheme":
          {
            const root = document.documentElement
            if (data.primaryColor) root.style.setProperty("--primary-color", data.primaryColor)
            if (data.secondaryColor) root.style.setProperty("--secondary-color", data.secondaryColor)
            if (data.backgroundColor) root.style.setProperty("--background-color", data.backgroundColor)
            if (data.accentColor) root.style.setProperty("--accent-color", data.accentColor)
            if (data.logoUrl && /^https?:\/\//.test(data.logoUrl)) {
              root.style.setProperty("--logo-url", `url(${data.logoUrl})`)
            }
          }
          break
      }
    }

    window.addEventListener("message", handleNuiMessage)
    window.addEventListener("keyup", handleKeyup)

    if (!window.invokeNative) {
      console.log("[ESX Scoreboard] Browser mode detected — loading mock data")
      loadMockData()
    } else {
      fetch("https://esx_scoreboard/nuiReady", { method: "POST" }).catch(() => {})
    }

    return () => {
      window.removeEventListener("message", handleNuiMessage)
      window.removeEventListener("keyup", handleKeyup)
    }
  })
</script>

<Scoreboard />