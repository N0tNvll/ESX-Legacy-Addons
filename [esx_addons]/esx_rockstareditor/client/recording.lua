-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Recorder = {}

local startedAt
local owned = false
local operating = false
local generation = 0
local lastStart = 'not_attempted'

local function elapsed(since)
    return (GetGameTimer() - since) % 4294967296
end

function Recorder.IsRecording()
    if type(IsRecording) ~= 'function' then
        return false
    end

    local ok, active = pcall(IsRecording)

    -- Some client builds return BOOL natives as 1/0 instead of Lua booleans.
    return ok and (active == true or active == 1)
end

function Recorder.State()
    local active = Recorder.IsRecording()

    if not active and not operating then
        startedAt, owned = nil, false
    end

    return {
        available = type(StartRecording) == 'function'
            and type(StopRecordingAndSaveClip) == 'function'
            and type(StopRecordingAndDiscardClip) == 'function'
            and type(IsRecording) == 'function',
        editorAvailable = type(ActivateRockstarEditor) == 'function'
            and type(IsRecording) == 'function',
        recording = active,
        elapsed = active and startedAt and elapsed(startedAt) or false,
        external = active and not owned,
    }
end

local function diagnosticValue(native)
    if type(native) ~= 'function' then
        return 'unavailable'
    end

    local ok, value = pcall(native)

    return ok and tostring(value) or ('native_error: ' .. tostring(value))
end

function Recorder.Diagnostics(serverReplaysDisabled)
    local state = Recorder.State()

    print(
        ('[esx_rockstareditor] serverReplaysDisabled=%s available=%s recording=%s gameBuild=%s nativeRecording=%s'):format(
            tostring(serverReplaysDisabled),
            tostring(state.available),
            tostring(state.recording),
            diagnosticValue(GetGameBuildNumber),
            diagnosticValue(IsRecording)
        )
    )
    print(
        ('[esx_rockstareditor] paused=%s nuiFocused=%s replayMode=%s replayMemLimit=%s'):format(
            diagnosticValue(IsPauseMenuActive),
            diagnosticValue(IsNuiFocused),
            GetConvar('profile_replayMode', 'unknown'),
            GetConvar('profile_replayMemLimit', 'unknown')
        )
    )
    print('[esx_rockstareditor] lastStart=' .. lastStart)
end

local function waitForRecording(expected)
    local since = GetGameTimer()

    while Recorder.IsRecording() ~= expected and elapsed(since) < 2000 do
        Wait(50)
    end

    return Recorder.IsRecording() == expected
end

function Recorder.Run(action)
    if operating then
        return false, 'busy'
    end

    local state = Recorder.State()
    local current = generation

    if not state.available then
        return false, 'unavailable'
    end

    if action == 'start' then
        if state.recording then
            return false, 'already_recording'
        end

        operating = true

        local since = GetGameTimer()
        local ok, nativeError = pcall(StartRecording, 1)
        local active = ok and waitForRecording(true)

        operating = false

        if generation ~= current then
            if active then
                pcall(StopRecordingAndSaveClip)
            end

            return false, 'cancelled'
        end

        if not active then
            lastStart = ok
                    and 'StartRecording(1) returned, but IsRecording() stayed false for 2000 ms.'
                or ('StartRecording(1) raised an error: ' .. tostring(nativeError))
            Recorder.Diagnostics('unknown')
            return false, 'start_failed'
        end

        lastStart = 'recording_started'
        startedAt, owned = since, true
        return true, 'recording_started'
    end

    if action ~= 'save' and action ~= 'discard' then
        return false, 'invalid_action'
    end

    if not state.recording then
        return false, 'not_recording'
    end

    operating = true

    local stop = action == 'save' and StopRecordingAndSaveClip or StopRecordingAndDiscardClip
    local ok = pcall(stop)
    local stopped = ok and waitForRecording(false)

    operating = false

    if not stopped then
        return false, 'stop_failed'
    end

    startedAt, owned = nil, false
    return true, action == 'save' and 'save_requested' or 'recording_discarded'
end

function Recorder.Cleanup()
    generation = generation + 1

    -- Preserve this resource's pending footage; never stop an external recording.
    if owned and not operating and Recorder.IsRecording() then
        pcall(StopRecordingAndSaveClip)
    end

    startedAt, owned = nil, false
end
