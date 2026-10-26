local count = 0

local function test(name, callback)
    local ok, err = pcall(callback)

    assert(ok, name .. ': ' .. tostring(err))
    count = count + 1
    print('PASS ' .. name)
end

local function loadIn(env, file)
    assert(load(SOURCES[file], '@' .. file, 't', env))()
end

local function fixture(server)
    local e = setmetatable({}, { __index = _G })

    e.time, e.active = 100000, false
    e.tasks, e.messages, e.notifications = {}, {}, {}
    e.callbacks, e.handlers, e.commands, e.exportsList = {}, {}, {}, {}
    e.startCalls, e.saveCalls, e.discardCalls, e.editorCalls = 0, 0, 0, 0
    e.feedHiddenFrames = 0
    e.ThefeedHideThisFrame = function()
        e.feedHiddenFrames = e.feedHiddenFrames + 1
    end
    e.convars, e.logs = {}, {}
    e.GetConvar = function(name, default)
        return e.convars[name] or default
    end
    e.print = function(message)
        e.logs[#e.logs + 1] = message
    end
    e.GetGameBuildNumber = function()
        return 3258
    end
    e.GetGameTimer = function()
        return e.time
    end
    e.GetCurrentResourceName = function()
        return 'esx_rockstareditor'
    end
    e.CreateThread = function(callback)
        e.tasks[#e.tasks + 1] = { co = coroutine.create(callback), wake = e.time }
    end
    e.SetTimeout = function(delay, callback)
        e.tasks[#e.tasks + 1] = { co = coroutine.create(callback), wake = e.time + delay }
    end
    e.Wait = coroutine.yield
    e.step = function(ms)
        e.time = e.time + (ms or 0)

        for _, task in ipairs(e.tasks) do
            if coroutine.status(task.co) ~= 'dead' and task.wake <= e.time then
                local ok, delay = coroutine.resume(task.co)

                assert(ok, delay)
                task.wake = e.time + (delay or 0)
            end
        end
    end
    e.AddEventHandler = function(name, callback)
        e.handlers[name] = callback
    end
    e.RegisterCommand = function(name, callback)
        e.commands[name] = callback
    end
    e.RegisterKeyMapping = function(command, _, _, key)
        assert(command == 'rockstar' and key == '')
    end
    e.RegisterNUICallback = function(name, callback)
        e.callbacks[name] = callback
    end
    e.exports = function(name, callback)
        e.exportsList[name] = callback
    end
    e.SetNuiFocus = function(keyboard, mouse)
        assert(keyboard == mouse)
        e.focused = keyboard
    end
    e.IsNuiFocused = function()
        return e.focused == true
    end
    e.IsPauseMenuActive = function()
        return e.paused == true
    end
    e.SendNUIMessage = function(message)
        e.messages[#e.messages + 1] = message
    end
    e.IsScreenFadedOut = function()
        return e.faded == true
    end
    e.DoScreenFadeIn = function()
        e.faded = false
    end
    e.IsRecording = function()
        if e.numericRecording then
            return e.active and 1 or 0
        end

        return e.active
    end
    e.StartRecording = function(mode)
        assert(mode == 1)
        e.startCalls = e.startCalls + 1

        if e.startDelay then
            e.SetTimeout(e.startDelay, function()
                e.active = true
            end)
        elseif not e.failStart then
            e.active = true
        end
    end
    e.StopRecordingAndSaveClip = function()
        e.saveCalls = e.saveCalls + 1

        if not e.failStop then
            e.active = false
        end
    end
    e.StopRecordingAndDiscardClip = function()
        e.discardCalls = e.discardCalls + 1
        e.active = false
    end
    e.ActivateRockstarEditor = function(mode)
        assert(mode == 0 and not e.focused and not e.active)
        e.editorCalls = e.editorCalls + 1
    end
    e.Locales = {}
    loadIn(e, 'config.lua')
    loadIn(e, 'locales/en.lua')
    loadIn(e, 'locales/es.lua')
    e.Translate = function(key, ...)
        return (e.Locales[e.Config.Locale][key] or e.Locales.en[key] or key):format(...)
    end
    e.player = {
        getGroup = function()
            return e.group or 'user'
        end,
    }
    e.ESX = {
        PlayerLoaded = true,
        GetPlayerFromId = function()
            return not e.noPlayer and e.player or nil
        end,
        ShowNotification = function(message)
            e.notifications[#e.notifications + 1] = message
        end,
    }
    e.IsPlayerAceAllowed = function()
        return e.ace == true
    end
    e.xLib = {
        colors = {
            getESXTheme = function()
                return { primaryColor = '#FB9B04' }
            end,
        },
        rateLimiter = function()
            return {
                consume = function()
                    return not e.limited
                end,
            }
        end,
        callback = {
            register = function(name, callback)
                e.authorize = callback
            end,
            await = function(name, _, action)
                assert(name == 'esx_rockstareditor:authorize')

                if e.accessDelay then
                    e.Wait(e.accessDelay)
                end

                if e.accessError then
                    error('Callback unavailable')
                end

                return e.authorize(1, action)
            end,
        },
    }

    loadIn(e, 'server/main.lua')

    if not server then
        loadIn(e, 'client/recording.lua')
        loadIn(e, 'client/main.lua')
    end

    e.responses = {}
    e.action = function(action, confirmed)
        e.callbacks.action({ action = action, confirmed = confirmed }, function(result)
            e.responses[#e.responses + 1] = result
        end)
        e.step(0)
    end
    e.open = function()
        e.commands.rockstar()
        e.step(0)
    end
    e.last = function()
        return e.responses[#e.responses]
    end
    return e
end

test('public access still requires a loaded ESX player and a valid action', function()
    local e = fixture(true)

    assert(e.authorize(1, 'open').ok)
    e.noPlayer = true
    assert(not e.authorize(1, 'start').ok)
    assert(e.authorize(1, {}).reason == 'invalid_action')
    assert(e.authorize(1, 'delete_all_clips').reason == 'invalid_action')
end)

test('restricted access accepts configured ESX groups or the ACE permission', function()
    local e = fixture(true)

    e.Config.RestrictAccess = true
    assert(not e.authorize(1, 'open').ok)
    e.group = 'admin'
    assert(e.authorize(1, 'open').ok)
    e.group, e.ace = 'user', true
    assert(e.authorize(1, 'start').ok)
    e.limited = true
    assert(e.authorize(1, 'start').reason == 'busy')
end)

test('server replay policy blocks starting and opening the editor but allows saving', function()
    for _, setting in ipairs({ 'true', '1' }) do
        local e = fixture()

        e.convars.sv_disableClientReplays = setting
        e.open()
        assert(e.focused)
        e.action('start')
        assert(not e.last().ok and e.last().message == e.Translate('replays_disabled'))
        assert(e.startCalls == 0)
        e.action('editor', true)
        assert(not e.last().ok and e.editorCalls == 0)
        e.active = true
        e.action('save')
        assert(e.last().ok and e.saveCalls == 1)
        assert(e.authorize(1, 'status').replaysDisabled)
    end
end)

test('a false replay policy allows recording and is reported by diagnostics', function()
    local e = fixture()

    e.convars.sv_disableClientReplays = 'false'
    e.commands.rockstarstatus()
    e.step(0)
    assert(e.logs[1]:find('serverReplaysDisabled=false', 1, true))
    assert(e.logs[1]:find('gameBuild=3258', 1, true))
    assert(not e.active and not e.focused and e.startCalls == 0)
    e.open()
    e.action('start')
    assert(e.last().ok and e.startCalls == 1)
end)

test('diagnostics require the configured access and never interrupt a recording', function()
    local e = fixture()

    e.Config.RestrictAccess, e.active = true, true
    e.commands.rockstarstatus()
    e.step(0)
    assert(#e.logs == 0 and e.active)
    e.group = 'admin'
    e.commands.rockstarstatus()
    e.step(0)
    assert(#e.logs == 3 and e.active)
    assert(e.startCalls == 0 and e.saveCalls == 0 and e.discardCalls == 0)
end)

test(
    'a native exception is retained instead of being replaced by a generic storage error',
    function()
        local e = fixture()

        e.StartRecording = function()
            error('native invocation rejected')
        end
        e.open()
        e.action('start')
        assert(not e.last().ok and e.focused and not e.active)
        assert(e.last().message:find('/rockstarstatus', 1, true))
        assert(e.logs[3]:find('native invocation rejected', 1, true))
    end
)

test('recording-state native errors are visible in diagnostics', function()
    local e = fixture()

    e.IsRecording = function()
        error('recording state unavailable')
    end
    e.commands.rockstarstatus()
    e.step(0)
    assert(e.logs[1]:find('recording state unavailable', 1, true))
    assert(e.startCalls == 0 and e.saveCalls == 0)
end)

test('opening sends the shared theme, locale and real recording state', function()
    local e = fixture()

    e.Config.Locale = 'es'
    e.open()

    local message = e.messages[#e.messages]

    assert(e.focused and message.action == 'open')
    assert(message.theme.primaryColor == '#FB9B04')
    assert(message.locale.ui_start == 'Iniciar grabación')
    assert(message.command == '/rockstar' and not message.state.recording)
end)

test('both menu commands toggle the menu without creating extra loops', function()
    local e = fixture()

    e.open()
    e.commands.rockstareditor()
    assert(not e.focused)
    e.open()
    assert(e.focused)
end)

test('existing NUI focus, the pause menu and logout block opening', function()
    for _, kind in ipairs({ 'focus', 'pause', 'logout' }) do
        local e = fixture()

        e.focused = kind == 'focus'
        e.paused = kind == 'pause'
        e.ESX.PlayerLoaded = kind ~= 'logout'
        e.open()
        assert(#e.messages == 0)
    end
end)

test('denied access and transport errors leave NUI focus released', function()
    for _, kind in ipairs({ 'denied', 'error' }) do
        local e = fixture()

        e.Config.RestrictAccess = true
        e.accessError = kind == 'error'
        e.open()
        assert(not e.focused and #e.notifications == 1)
    end
end)

test('timed out or cancelled authorization cannot reopen the menu later', function()
    for _, cancel in ipairs({ false, true }) do
        local e = fixture()

        e.accessDelay = 6000
        e.open()

        if cancel then
            e.exportsList.CloseMenu()
        end

        e.step(5000)
        e.step(1000)
        assert(not e.focused)
    end
end)

test('recording starts in manual mode and closing the menu keeps it running', function()
    local e = fixture()

    e.open()
    e.action('start')
    assert(e.last().ok and e.active and e.startCalls == 1 and not e.focused)
    e.step(1500)
    assert(e.Recorder.State().elapsed == 1500)
    e.open()
    e.action('save')
    assert(e.last().ok and not e.active and e.saveCalls == 1)
end)

test('numeric native results support starting, the timer, saving and discarding', function()
    for _, action in ipairs({ 'save', 'discard' }) do
        local e = fixture()

        e.numericRecording = true
        assert(e.Recorder.State().recording == false)
        e.open()
        e.action('start')
        e.step(2000)
        assert(e.last() and e.last().ok and e.active and not e.focused)

        local state = e.Recorder.State()

        assert(state.recording == true and state.elapsed == 2000 and not state.external)
        e.open()
        e.action(action, true)
        assert(e.last().ok and not e.active)
        assert(e.last().state.recording == false and e.last().state.elapsed == false)
        assert(e.saveCalls + e.discardCalls == 1)
    end
end)

test(
    'numeric external recordings block duplicate starts and the editor and survive cleanup',
    function()
        local e = fixture()

        e.numericRecording, e.active = true, true
        local state = e.Recorder.State()

        assert(state.recording == true and state.external and state.elapsed == false)
        e.open()
        e.action('start')
        assert(not e.last().ok and e.startCalls == 0)
        e.action('editor', true)
        assert(not e.last().ok and e.editorCalls == 0)
        e.Recorder.Cleanup()
        assert(e.active and e.saveCalls == 0)
    end
)

test('logout and resource stop preserve owned footage with numeric native results', function()
    for _, event in ipairs({ 'esx:onPlayerLogout', 'onResourceStop' }) do
        local e = fixture()

        e.numericRecording = true
        e.open()
        e.action('start')
        e.step(2000)
        assert(e.last() and e.last().ok)
        e.handlers[event]('esx_rockstareditor')
        assert(not e.active and not e.focused and e.saveCalls == 1)
    end
end)

test('invalid native results cannot be treated as an active recording', function()
    local e = fixture()

    for _, result in ipairs({ '1', 2, {} }) do
        e.IsRecording = function()
            return result
        end
        assert(e.Recorder.IsRecording() == false)
    end
    e.IsRecording = function() end
    assert(e.Recorder.IsRecording() == false)
end)

test('only active takes can be saved or discarded and confirmation is required', function()
    local e = fixture()

    e.open()
    e.action('save')
    assert(not e.last().ok and e.saveCalls == 0)
    e.active = true
    e.action('discard')
    assert(not e.last().ok and e.discardCalls == 0)
    e.action('discard', true)
    assert(e.last().ok and e.discardCalls == 1 and not e.active)
end)

test('permissions are checked again before every recording action', function()
    local e = fixture()

    e.Config.RestrictAccess, e.group = true, 'admin'
    e.open()
    e.group = 'user'
    e.action('start')
    assert(not e.last().ok and e.startCalls == 0)
end)

test('closing during authorization replies once and never executes stale actions', function()
    local e = fixture()

    e.open()
    e.accessDelay = 1000
    e.action('start')
    e.exportsList.CloseMenu()
    e.step(1000)
    assert(#e.responses == 1 and not e.last().ok and e.startCalls == 0)
end)

test('duplicate requests cannot start overlapping native operations', function()
    local e = fixture()

    e.open()
    e.startDelay = 500
    e.action('start')
    e.action('start')
    assert(not e.last().ok and e.startCalls == 1)
    e.step(500)
    e.step(50)
    assert(e.active and e.startCalls == 1)
end)

test('unsupported natives and failed recording starts report a failure', function()
    local e = fixture()

    e.StartRecording = false
    assert(not e.Recorder.State().available)
    e.open()
    e.action('start')
    assert(not e.last().ok)

    local failed = fixture()

    failed.failStart = true
    failed.open()
    failed.action('start')
    failed.step(2000)
    assert(not failed.last().ok and not failed.active and failed.focused)
    assert(failed.logs[3]:find('IsRecording() stayed false for 2000 ms', 1, true))
end)

test('failed stop does not falsely report a saved clip', function()
    local e = fixture()

    e.open()
    e.active, e.failStop = true, true
    e.action('save')
    e.step(2000)
    assert(not e.last().ok and e.active)
end)

test('external recordings have no invented duration and are left alone on cleanup', function()
    local e = fixture()

    e.active = true

    local state = e.Recorder.State()

    assert(state.recording and state.external and state.elapsed == false)
    e.Recorder.Cleanup()
    assert(e.active and e.saveCalls == 0)
end)

test('resource stop and logout request a save for this resource recording', function()
    for _, event in ipairs({ 'onResourceStop', 'esx:onPlayerLogout' }) do
        local e = fixture()

        e.open()
        e.action('start')
        e.handlers[event]('esx_rockstareditor')
        assert(not e.focused and not e.active and e.saveCalls == 1)
    end
end)

test(
    'logout during an asynchronous start preserves footage instead of reviving the menu',
    function()
        local e = fixture()

        e.open()
        e.startDelay = 500
        e.action('start')
        e.step(500)
        e.ESX.PlayerLoaded = false
        e.handlers['esx:onPlayerLogout']()
        e.step(50)
        assert(not e.active and not e.focused and e.saveCalls == 1)
    end
)

test('logout before a delayed native acknowledgement still saves the take', function()
    local e = fixture()

    e.open()
    e.startDelay = 500
    e.action('start')
    e.ESX.PlayerLoaded = false
    e.handlers['esx:onPlayerLogout']()
    e.step(250)
    e.step(250)
    e.step(50)
    assert(not e.active and not e.focused and e.saveCalls == 1)
end)

test('editor is unavailable when the recording state native is missing', function()
    local e = fixture()

    e.IsRecording = false
    assert(not e.Recorder.State().editorAvailable)
    e.open()
    e.action('editor', true)
    assert(not e.last().ok and e.editorCalls == 0)
end)

test('editor opening requires confirmation and a finished recording', function()
    local e = fixture()

    e.open()
    e.action('editor')
    assert(not e.last().ok and e.editorCalls == 0)
    e.active = true
    e.action('editor', true)
    assert(not e.last().ok and e.editorCalls == 0)
    e.active, e.faded = false, true
    e.action('editor', true)
    e.step(150)
    assert(e.editorCalls == 1 and not e.focused and not e.faded)
end)

test('a recording started during the editor transition prevents opening', function()
    local e = fixture()

    e.open()
    e.action('editor', true)
    e.active = true
    e.step(150)
    assert(e.editorCalls == 0)
end)

test('malformed or hidden-menu actions never execute natives', function()
    local e = fixture()

    e.action('start')
    e.open()
    e.action('unknown')
    e.callbacks.action(false, function(result)
        assert(not result.ok)
    end)
    assert(e.startCalls == 0 and e.saveCalls == 0 and e.editorCalls == 0)
end)

test('native recording notifications remain visible by default', function()
    local e = fixture()

    assert(e.Config.HideGameFeedWhileRecording == false)
    e.active = true
    e.step(0)
    e.step(500)
    assert(e.feedHiddenFrames == 0 and e.active)
end)

test('native feed is hidden only during recording and restored after it stops', function()
    local e = fixture()

    e.Config.HideGameFeedWhileRecording = true
    e.numericRecording = true
    e.step(0)
    assert(e.feedHiddenFrames == 0)
    e.active = true
    e.step(500)
    e.step(16)
    assert(e.feedHiddenFrames == 2)
    e.active = false
    e.step(16)
    e.step(500)
    assert(e.feedHiddenFrames == 2)
    assert(e.startCalls + e.saveCalls + e.discardCalls == 0)
end)

test(
    'native feed stays visible when disabled, without the REC replacement or after logout',
    function()
        for _, condition in ipairs({ 'config', 'indicator', 'logout', 'stop' }) do
            local e = fixture()

            e.Config.HideGameFeedWhileRecording = true
            e.active = true
            if condition == 'config' then
                e.Config.HideGameFeedWhileRecording = false
            elseif condition == 'indicator' then
                e.Config.ShowRecordingIndicator = false
            elseif condition == 'logout' then
                e.ESX.PlayerLoaded = false
                e.handlers['esx:onPlayerLogout']()
            else
                e.handlers.onResourceStop('esx_rockstareditor')
            end
            e.step(0)
            e.step(500)
            assert(e.feedHiddenFrames == 0 and e.active)
        end
    end
)

test('both translations expose the same keys', function()
    local e = fixture(true)

    for key in pairs(e.Locales.en) do
        assert(type(e.Locales.es[key]) == 'string', key)
    end

    for key in pairs(e.Locales.es) do
        assert(type(e.Locales.en[key]) == 'string', key)
    end
end)

print(('TOTAL %d Rockstar Editor tests passed'):format(count))
