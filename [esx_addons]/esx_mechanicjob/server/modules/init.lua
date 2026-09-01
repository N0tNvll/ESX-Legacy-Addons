ESXMechanicJob = {
	PlayerWorkStates = {},
	PlayersNPCJobs = {},
	LastNPCJobReward = {},
	RateLimits = {}
}

function ESXMechanicJob.clearPlayerState(source)
	ESXMechanicJob.PlayerWorkStates[source] = nil
	ESXMechanicJob.PlayersNPCJobs[source] = nil
	ESXMechanicJob.LastNPCJobReward[source] = nil
	ESXMechanicJob.RateLimits[source] = nil
end

AddEventHandler('playerDropped', function()
	ESXMechanicJob.clearPlayerState(source)
end)
