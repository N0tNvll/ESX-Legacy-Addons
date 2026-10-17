interface GhostState {
    choiceVisible: boolean;
    choiceDuration: number;
    jumpscareDuration: number;
    hudVisible: boolean;
    jumpscareVisible: boolean;
    maxDuration: number;
    exitKey: string;
    scareKey: string;
    forced: boolean;
    soundVolume: number;
}

class GhostManager {
    state = $state<GhostState>({
        choiceVisible: false,
        choiceDuration: 30000,
        jumpscareDuration: 3000,
        hudVisible: false,
        jumpscareVisible: false,
        maxDuration: 600000,
        exitKey: 'X',
        scareKey: 'E',
        forced: false,
        soundVolume: 0.8
    });

    showChoice(forced: boolean = false, duration: number = 30000) {
        this.state.choiceVisible = true;
        this.state.forced = forced;
        this.state.choiceDuration = duration;
    }

    hideChoice() {
        this.state.choiceVisible = false;
    }

    showHUD(maxDuration: number, exitKey: string = 'X', scareKey: string = 'E') {
        this.state.hudVisible = true;
        this.state.maxDuration = maxDuration;
        this.state.exitKey = exitKey;
        this.state.scareKey = scareKey;
    }

    hideHUD() {
        this.state.hudVisible = false;
    }

    triggerJumpscare(soundVolume: number = 0.8, duration: number = 3000) {
        this.state.jumpscareVisible = true;
        this.state.soundVolume = soundVolume;
        this.state.jumpscareDuration = duration;
    }

    hideJumpscare() {
        this.state.jumpscareVisible = false;
    }
}

export const ghostManager = new GhostManager();
