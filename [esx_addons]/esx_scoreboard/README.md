# ESX Scoreboard

A modern, responsive scoreboard resource for **ESX Legacy** built with **Svelte** and **Vite**. Provides real-time player listings with job indicators, activity badges, and instant search.

![ESX Scoreboard](https://img.shields.io/badge/ESX-Legacy-orange)
![Svelte](https://img.shields.io/badge/Svelte-4.0-ff3e00?logo=svelte)
![Vite](https://img.shields.io/badge/Vite-5.0-646cff?logo=vite)

---

## Features

- **Modern UI** — Clean, responsive design with CSS variable theming
- **Real-time Search** — Filter players by name, job, or server ID instantly
- **Job Badges** — Visual indicators for player occupations
- **Activity Tracking** — See what players are currently doing
- **Lightweight** — Optimized Svelte build delivered via Vite
- **Easy Theming** — Customize colors via CSS variables without touching components
- **ESX Native** — Built specifically for ESX Legacy framework integration

---

## Preview

> *Add a screenshot or GIF showing the scoreboard UI in-game*

---

## Installation

### 1. Download & Extract

Download the latest release and place the `esx_scoreboard` folder into your server's `resources/` directory.

```
server/
└── resources/
    └── esx_scoreboard/
        ├── build/
        ├── src/
        ├── fxmanifest.lua
        └── ...
```

### 2. Build the UI (Development)

If you're modifying the source, you'll need Node.js 18+:

```bash
cd esx_scoreboard/web/
npm install
npm run build
```

For development with hot-reload:

```bash
npm run dev
```

---

## Configuration

### Keybind

The scoreboard is toggled via a **configurable keybind** (default: `Z`).

Players can rebind this in their FiveM settings under **Settings → Keybinds → FiveM**.

To change the default key, edit `config/main.lua`:

---

## Usage

### Opening the Scoreboard

Press your bound key (default: `Z`) to toggle the scoreboard on/off.

### Search

Type in the search bar to filter players by:
- **Player name**
- **Job label** (e.g., "Police", "Ambulance")
- **Server ID**

---

## API & Events

### Client → NUI

The scoreboard listens for the following NUI messages:

| Action | Description | Payload |
|--------|-------------|---------|
| `toggleVisibility` | Show/hide the scoreboard | — |
| `setPlayers` | Update the full player list | `{ players: Array<Player> }` |
| `updatePlayer` | Update a single player's data | `{ player: Player }` |
| `setJobCounts` | Update aggregated job statistics | `{ jobs: Record<string, number> }` |

#### Player Object Structure

```typescript
interface Player {
  id: number;        // Server ID
  name: string;      // Character name
  job: string;       // Job label
  jobGrade: string;  // Job grade label
  activity?: string; // Current activity (optional)
  ping?: number;     // Network ping (optional)
}
```

---

## Project Structure

```
esx_scoreboard/
├── web/
    ├── build/                  # Compiled Svelte app (served by FiveM)
    │   ├── index.html
    │   └── assets/
├── src/
│   ├── components/         # Svelte UI components
│   │   ├── Header.svelte
│   │   ├── Footer.svelte
│   │   ├── PlayerRow.svelte
│   │   ├── ActivityBadge.svelte
│   │   ├── JobBadge.svelte
│   │   └── SearchBar.svelte
│   ├── stores/
│   │   └── scoreboard.js   # Svelte store for state management
│   ├── styles/
│   │   └── variables.css   # CSS custom properties
│   ├── App.svelte
│   └── main.js
├── package.json
├── vite.config.js
├── svelte.config.js
├── client/
├── ├── modules/  
│   └── main.lua            # Client-side Lua logic
├── server/
│   └── main.lua            # Server-side Lua logic
└── fxmanifest.lua          # FiveM resource manifest

```

---

## Development

### Prerequisites

- [Node.js](https://nodejs.org/) 18+ with npm
- [FiveM](https://fivem.net/) server with ESX Legacy installed

### Setup

```bash
# Clone into your resources directory
cd resources/esx_scoreboard

# Install dependencies
npm install

# Start development server
npm run dev
```

### Build for Production

```bash
npm run build
```

The compiled files will be output to `dist/` and served by FiveM via `fxmanifest.lua`.

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/amazing-feature`)
3. Commit your changes using [Conventional Commits](https://www.conventionalcommits.org/)
4. Push to the branch (`git push origin feat/amazing-feature`)
5. Open a Pull Request

---

## License

This project is licensed under the MIT License — see the ESX Framework repository for details.

---

## Credits

- Built for [ESX Legacy](https://github.com/esx-framework/esx-legacy)
- UI powered by [Svelte](https://svelte.dev/) and [Vite](https://vitejs.dev/)
- Original concept by the ESX community

---

## Support

For issues, questions, or contributions related specifically to this scoreboard resource, please open an issue in the [ESX-Legacy-Addons](https://github.com/esx-framework/ESX-Legacy-Addons) repository.
