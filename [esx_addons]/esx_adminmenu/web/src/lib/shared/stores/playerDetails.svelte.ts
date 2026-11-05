import type { Player } from "../../tabs/players/types/player";
import { currentPage } from "./navigation.svelte";

export const playerDetails = $state<{ player: Player | null; page: string }>({
    player: null,
    page: "",
});

export function showPlayerDetails(player: Player) {
    playerDetails.player = player;
    playerDetails.page = currentPage.value;
}
