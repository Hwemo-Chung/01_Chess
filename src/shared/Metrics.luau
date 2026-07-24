-- Pure session metrics for MVP measurement hooks (PRD §3.2).
-- restart-after-loss, rounds/session, and durable counters live here;
-- D1/D7 needs calendar login data (profile.stats + external analytics later).
local Metrics = {}
Metrics.__index = Metrics

export type SessionMetrics = {
	sessionStartedAt: number,
	runsStarted: number,
	runsEnded: number,
	restartsAfterLoss: number,
	roundsThisSession: number,
	lastRunLevel: number,
	lastRunRounds: number,
	events: { { name: string, at: number, payload: any } },
}

function Metrics.new(clock: () -> number)
	return setmetatable({
		_clock = clock,
		sessionStartedAt = clock(),
		runsStarted = 0,
		runsEnded = 0,
		restartsAfterLoss = 0,
		roundsThisSession = 0,
		lastRunLevel = 0,
		lastRunRounds = 0,
		events = {},
	}, Metrics)
end

function Metrics._emit(self, name: string, payload: any)
	table.insert(self.events, {
		name = name,
		at = self._clock(),
		payload = payload or {},
	})
end

function Metrics.recordRunStart(self)
	self.runsStarted += 1
	self:_emit("run_start", { runsStarted = self.runsStarted })
end

function Metrics.recordRound(self)
	self.roundsThisSession += 1
	self.lastRunRounds += 1
	self:_emit("round", { roundsThisSession = self.roundsThisSession })
end

function Metrics.recordRunEnd(self, level: number, reason: string)
	self.runsEnded += 1
	self.lastRunLevel = level
	self:_emit("run_end", {
		level = level,
		reason = reason,
		rounds = self.lastRunRounds,
		runsEnded = self.runsEnded,
	})
	self.lastRunRounds = 0
end

function Metrics.recordRestartAfterLoss(self)
	self.restartsAfterLoss += 1
	self:_emit("restart_after_loss", {
		restartsAfterLoss = self.restartsAfterLoss,
		runsEnded = self.runsEnded,
	})
end

function Metrics.restartAfterLossRate(self): number
	if self.runsEnded <= 0 then
		return 0
	end
	return self.restartsAfterLoss / self.runsEnded
end

function Metrics.roundsPerSession(self): number
	return self.roundsThisSession
end

function Metrics.snapshot(self): SessionMetrics
	return {
		sessionStartedAt = self.sessionStartedAt,
		runsStarted = self.runsStarted,
		runsEnded = self.runsEnded,
		restartsAfterLoss = self.restartsAfterLoss,
		roundsThisSession = self.roundsThisSession,
		lastRunLevel = self.lastRunLevel,
		lastRunRounds = self.lastRunRounds,
		restartAfterLossRate = self:restartAfterLossRate(),
		events = table.clone(self.events),
	}
end

return Metrics
