--[[

   ▄▄▄▄███▄▄▄▄      ▄████████     ███         ███             ▄████████  ▄████████    ▄████████  ▄█     ▄███████▄     ███        ▄████████    ▄████████ 
 ▄██▀▀▀███▀▀▀██▄   ███    ███ ▀█████████▄ ▀█████████▄        ███    ███ ███    ███   ███    ███ ███    ███    ███ ▀█████████▄   ███    ███   ███    ███ 
 ███   ███   ███   ███    ███    ▀███▀▀██    ▀███▀▀██        ███    █▀  ███    █▀    ███    ███ ███▌   ███    ███    ▀███▀▀██   ███    █▀    ███    ███ 
 ███   ███   ███   ███    ███     ███   ▀     ███   ▀        ███        ███         ▄███▄▄▄▄██▀ ███▌   ███    ███     ███   ▀  ▄███▄▄▄      ▄███▄▄▄▄██▀ 
 ███   ███   ███ ▀███████████     ███         ███          ▀███████████ ███        ▀▀███▀▀▀▀▀   ███▌ ▀█████████▀      ███     ▀▀███▀▀▀     ▀▀███▀▀▀▀▀   
 ███   ███   ███   ███    ███     ███         ███                   ███ ███    █▄  ▀███████████ ███    ███            ███       ███    █▄  ▀███████████ 
 ███   ███   ███   ███    ███     ███         ███             ▄█    ███ ███    ███   ███    ███ ███    ███            ███       ███    ███   ███    ███ 
  ▀█   ███   █▀    ███    █▀     ▄████▀      ▄████▀         ▄████████▀  ████████▀    ███    ███ █▀    ▄████▀         ▄████▀     ██████████   ███    ███ 
                                                                                     ███    ███                                              ███    ███
	-> Discord: @eo_mtzsz
	-> Portfolio: https://discord.gg/GWU5pJJTpD
	-> Roblox Creator / Experienced Programmer / Team Coordinator & Tech Lead / Dev
]]

local RunService         = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local CollectionService  = game:GetService("CollectionService")
local HttpService        = game:GetService("HttpService")
local Players            = game:GetService("Players")
local Debris             = game:GetService("Debris")

local _rng   = Random.new()
local _clock = os.clock

local function guid()        return HttpService:GenerateGUID(false) end
local function clamp(v,a,b)  return math.max(a, math.min(b, v)) end
local function rng()         return _rng:NextNumber() end
local function rngi(a,b)     return _rng:NextInteger(a, b) end
local function rngR(a,b)     return a + _rng:NextNumber()*(b-a) end
local function now()         return _clock() end

local function Root(m)  return m and m:FindFirstChild("HumanoidRootPart") end
local function Hum(m)   return m and m:FindFirstChildOfClass("Humanoid")  end
local function VelOf(m) local r = Root(m); return r and r.AssemblyLinearVelocity or Vector3.zero end

local function Alive(m)
	if not m or not m.Parent then return false end
	local h = Hum(m)
	return h ~= nil and h.Health > 0
end

local function HPRatio(m)
	local h = Hum(m)
	return (h and h.MaxHealth > 0) and (h.Health / h.MaxHealth) or 0
end

local function deepCopy(t, seen)
	if type(t) ~= "table" then return t end
	seen = seen or {}
	if seen[t] then return seen[t] end
	local c = setmetatable({}, getmetatable(t))
	seen[t] = c
	for k, v in pairs(t) do c[deepCopy(k, seen)] = deepCopy(v, seen) end
	return c
end

local function mergeInto(base, over)
	if not over then return base end
	for k, v in pairs(over) do
		if type(v) == "table" and type(base[k]) == "table" then
			mergeInto(base[k], v)
		else
			base[k] = v
		end
	end
	return base
end

local function fireList(list, ...)
	for i = 1, #list do
		local ok, err = pcall(list[i], ...)
		if not ok then warn("[AIFrame] " .. tostring(err)) end
	end
end

local function applyImpulse(root, vel, tenacity)
	local mag = vel.Magnitude * (1 - clamp((tenacity or 0) * 0.5, 0, 0.85))
	if mag < 0.01 then return end
	local att = Instance.new("Attachment")
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0    = att
	lv.VectorVelocity = vel.Unit * mag
	lv.MaxForce       = math.huge
	lv.RelativeTo     = Enum.ActuatorRelativeTo.World
	lv.Parent         = root
	task.delay(0.1, function()
		if lv  and lv.Parent  then lv:Destroy()  end
		if att and att.Parent then att:Destroy() end
	end)
end

local S = {
	IDLE     = "Idle",
	PATROL   = "Patrol",
	ALERT    = "Alert",
	CHASE    = "Chase",
	COMBAT   = "Combat",
	FLEE     = "Flee",
	SEARCH   = "Search",
	GUARD    = "Guard",
	STUNNED  = "Stunned",
	DEAD     = "Dead",
	RAGDOLL  = "Ragdoll",
	CHANNEL  = "Channeling",
	AMBUSH   = "Ambush",
	REGROUP  = "Regroup",
	ESCORT   = "Escort",
	HUNT     = "Hunt",
}

local LOD = { FULL = 0, MED = 1, LOW = 2, SLEEP = 3 }

local STATUS_DEFS = {
	Burning   = { dur=3.5, tick=0.5,  dmg=4,   slow=nil, stun=false, stacks=3, maxStacks=3,
		interactions = {
			Wet    = function(a) a.def=STATUS_DEFS.Shocked; a.remaining=1.5; a.stacks=2 end,
			Frozen = function(a) a.stacks=math.max(1,a.stacks-1); a.remaining=0.5 end,
			Oiled  = function(a) a.stacks=a.def.maxStacks; a.remaining=a.remaining*2 end,
		}},
	Frozen    = { dur=2.2, tick=nil,  dmg=nil, slow=0,    stun=true,  stacks=1, maxStacks=1,
		interactions = {
			Burning = function(a) a.remaining=0; a.stacks=0 end,
			Shocked = function(a) a.remaining=a.remaining*1.5 end,
		}},
	Shocked   = { dur=1.8, tick=0.3,  dmg=2.5, slow=0.70, stun=false, stacks=2, maxStacks=3,
		interactions = {
			Wet = function(a) a.dmgMult=(a.dmgMult or 1)*1.40; a.remaining=a.remaining*1.25 end,
		}},
	Wet       = { dur=5.0, tick=nil,  dmg=nil, slow=nil,  stun=false, stacks=1, maxStacks=1 },
	Poisoned  = { dur=6.0, tick=1.0,  dmg=3,   slow=nil,  stun=false, stacks=5, maxStacks=5 },
	Bleeding  = { dur=7.0, tick=0.8,  dmg=5,   slow=nil,  stun=false, stacks=5, maxStacks=5,
		interactions = {
			Poisoned = function(a) a.dmg=(a.dmg or 5)*1.3 end,
		}},
	Oiled     = { dur=8.0, tick=nil,  dmg=nil, slow=0.80, stun=false, stacks=1, maxStacks=1 },
	Cursed    = { dur=5.0, tick=nil,  dmg=nil, slow=nil,  stun=false, stacks=1, maxStacks=1 },
	Marked    = { dur=6.0, tick=nil,  dmg=nil, slow=nil,  stun=false, stacks=1, maxStacks=1 },
	Silenced  = { dur=3.0, tick=nil,  dmg=nil, slow=nil,  stun=false, silence=true, stacks=1, maxStacks=1 },
	Rooted    = { dur=2.5, tick=nil,  dmg=nil, slow=0,    stun=false, root=true, stacks=1, maxStacks=1 },
	Stunned   = { dur=1.2, tick=nil,  dmg=nil, slow=0,    stun=true,  stacks=1, maxStacks=1 },
	Slowed    = { dur=3.0, tick=nil,  dmg=nil, slow=0.50, stun=false, stacks=1, maxStacks=1 },
	Weakened  = { dur=4.0, tick=nil,  dmg=nil, slow=nil,  stun=false, stacks=1, maxStacks=1 },
	Broken    = { dur=4.0, tick=nil,  dmg=nil, slow=nil,  stun=false, stacks=1, maxStacks=1 },
	Terrified = { dur=3.0, tick=nil,  dmg=nil, slow=nil,  stun=false, stacks=1, maxStacks=1,
		onApply  = function(r) r.cfg.Personality.Courage=math.max(0,r.cfg.Personality.Courage-0.5) end,
		onRemove = function(r) r.cfg.Personality.Courage=math.min(1,r.cfg.Personality.Courage+0.5) end,
	},
	Empowered = { dur=5.0, tick=nil,  dmg=nil, slow=nil,  stun=false, stacks=1, maxStacks=1,
		onApply  = function(r) r.cfg.BaseDamage=(r.cfg.BaseDamage or 15)*1.5 end,
		onRemove = function(r) r.cfg.BaseDamage=(r.cfg.BaseDamage or 15)/1.5 end,
	},
	Taunted   = { dur=4.0, tick=nil,  dmg=nil, slow=nil,  stun=false, stacks=1, maxStacks=1 },
	Confused  = { dur=2.5, tick=nil,  dmg=nil, slow=0.60, stun=false, stacks=1, maxStacks=1 },
	Ignited   = { dur=2.0, tick=0.25, dmg=6,   slow=nil,  stun=false, stacks=1, maxStacks=1 },
}

local DEFAULT_CFG = {
	Type            = "Enemy",
	Level           = 1,
	Faction         = "Default",
	BehaviourPreset = "Aggressive",
	CombatStyle     = "Balanced",

	Personality = {
		Aggression   = 0.5,
		Courage      = 0.5,
		Intelligence = 0.5,
		Loyalty      = 0.5,
		Patience     = 0.5,
		Cruelty      = 0.3,
		Curiosity    = 0.4,
	},

	Emotion = {
		Fear   = 0.0,
		Rage   = 0.0,
		Stress = 0.0,
		Morale = 1.0,
	},

	VisionRange     = 80,
	VisionAngle     = 120,
	HearingRange    = 50,
	NightMul        = 0.5,
	UseTaggedCovers = true,
	VisionLODFull   = 80,
	VisionLODMed    = 140,

	TerritoryRadius      = 100,
	TerritoryReturnSpeed = 14,
	TerritoryAlertRadius = 60,

	AttackRange  = 6,
	BaseDamage   = 15,
	DamageJitter = 0.20,
	AttackRate   = 1.20,
	FleeHealth   = 0.15,
	ElementType  = "Physical",
	ComboName    = nil,
	CritChance   = 0.08,
	CritMult     = 1.75,

	MoveSpeed    = 16,
	SprintSpeed  = 24,
	SprintThresh = 0.60,
	AgentRadius  = 2,
	AgentHeight  = 5,
	WaypointSize = 4,

	MaxMana    = 100,
	ManaRegen  = 5,
	MaxShield  = 0,
	Shield     = 0,

	LOD_High = 60,
	LOD_Med  = 130,
	LOD_Low  = 220,

	PerceptionRate  = 0.14,
	DecisionRate    = 0.10,
	PathfindRate    = 0.44,
	MemoryDecayRate = 5.0,
	TacticalRate    = 0.26,
	ThreatDecayRate = 3.0,
	EmotionRate     = 1.0,
	PredictionSteps = 6,

	Tenacity = 0,
	Armor    = 0,

	Sounds = {
		Footstep = nil,
		Attack   = nil,
		Hurt     = nil,
		Death    = nil,
		Alert    = nil,
		Ability  = nil,
	},

	Goal        = nil,
	GoalPayload = nil,

	SchedulerBucket = nil,

	CombatEngine = nil,
	StateMachine = nil,
}

local PRESETS = {
	Aggressive = { Personality={Aggression=0.92,Courage=0.80,Patience=0.15}, FleeHealth=0.08, CombatStyle="Aggressive" },
	Defensive  = { Personality={Aggression=0.28,Courage=0.55,Patience=0.82}, FleeHealth=0.35, CombatStyle="Defensive"  },
	Patrol     = { Personality={Aggression=0.38,Courage=0.50,Patience=0.72} },
	Guard      = { Personality={Aggression=0.60,Courage=0.97,Patience=0.92}, TerritoryRadius=28 },
	Passive    = { Personality={Aggression=0.00,Courage=0.12,Patience=1.00}, FleeHealth=0.65 },
	Berserk    = { Personality={Aggression=1.00,Courage=1.00,Patience=0.00,Cruelty=1.0}, FleeHealth=0.0, SprintThresh=1.0, CombatStyle="HitAndRun" },
	Sniper     = { Personality={Aggression=0.68,Courage=0.38,Intelligence=0.97,Patience=0.93}, AttackRange=58, AttackRate=2.6, SprintThresh=0.0, CombatStyle="Sniper" },
	Coward     = { Personality={Aggression=0.04,Courage=0.04,Patience=0.18}, FleeHealth=0.60 },
	Ambusher   = { Personality={Aggression=0.88,Courage=0.62,Intelligence=0.82,Patience=0.97}, VisionAngle=50 },
	Tank       = { Personality={Aggression=0.55,Courage=1.00,Intelligence=0.40,Patience=0.70}, Armor=40, FleeHealth=0.0, AttackRate=1.8, CombatStyle="Defensive" },
	Support    = { Personality={Aggression=0.25,Courage=0.70,Intelligence=0.90,Loyalty=0.95}, AttackRange=30 },
	Berserker  = { Personality={Aggression=1.00,Courage=1.00,Cruelty=1.00}, AttackRate=0.45, FleeHealth=0.0 },
	HitAndRun  = { Personality={Aggression=0.80,Courage=0.55,Intelligence=0.80,Patience=0.60}, CombatStyle="HitAndRun" },
}

local MODIFIERS = {
	Berserk   = { _p={Aggression=1.0,Courage=1.0,Cruelty=1.0},   FleeHealth=0.0, AttackRate=0.5 },
	Coward    = { _p={Aggression=0.0,Courage=0.0},                FleeHealth=0.95 },
	Sniper    = { AttackRange=58, AttackRate=2.5, _p={Intelligence=0.97,Patience=0.95} },
	Guardian  = { _p={Courage=1.0,Loyalty=1.0},                   TerritoryRadius=18 },
	Frenzied  = { _p={Aggression=1.0,Patience=0.0},               AttackRate=0.38 },
	Enraged   = { _p={Aggression=1.0,Courage=1.0,Intelligence=0.25,Cruelty=1.0}, AttackRate=0.42 },
	Empowered = { _p={Aggression=0.90,Intelligence=0.85},          AttackRate=0.70 },
	Weakened  = { _p={Aggression=0.15,Courage=0.25} },
}

local COMBAT_STYLES = {
	Aggressive = { burstMax=3, keepDist=0,  preferCover=false, hitAndRun=false },
	Defensive  = { burstMax=1, keepDist=4,  preferCover=true,  hitAndRun=false },
	Sniper     = { burstMax=1, keepDist=45, preferCover=true,  hitAndRun=false },
	HitAndRun  = { burstMax=2, keepDist=8,  preferCover=false, hitAndRun=true  },
	Balanced   = { burstMax=2, keepDist=2,  preferCover=false, hitAndRun=false },
	Flanker    = { burstMax=2, keepDist=0,  preferCover=false, hitAndRun=false },
}

local GOAL_DEFS = {
	DefendArea = { state=S.GUARD   },
	HuntEnemy  = { state=S.HUNT    },
	Patrol     = { state=S.PATROL  },
	Escort     = { state=S.ESCORT  },
	Idle       = { state=S.IDLE    },
	FleeAlways = { state=S.FLEE    },
}

local STUCK_TIMEOUT  = 2.2
local STUCK_DELTA    = 1.2
local ARRIVE_R       = 3.2
local MAX_RECOMP     = 4
local COVER_CANDIDATES = 16
local COVER_RECHECK    = 5.0
local SQUAD_ORDER_INTERVAL = 4.0

local function newRecord(model, cfg)
	local r = Root(model)
	local p = r and r.Position or Vector3.zero
	return {
		id              = guid(),
		model           = model,
		cfg             = cfg,
		state           = S.IDLE,
		prevState       = nil,
		stateAge        = 0,
		target          = nil,
		secondaryTarget = nil,
		escortTarget    = nil,
		spawnPos        = p,
		spawnCF         = r and r.CFrame or CFrame.new(),
		alive           = true,
		lod             = LOD.FULL,
		bucket          = 0,

		t_percep      = 0,
		t_decide      = 0,
		t_path        = 0,
		t_memory      = 0,
		t_tactical    = 0,
		t_threatDecay = 0,
		t_emotion     = 0,
		t_world       = 0,
		t_predict     = 0,
		t_sound       = 0,

		percep = {
			visible        = {},
			audible        = {},
			closestModel   = nil,
			closestDist    = math.huge,
			alertLevel     = 0,
			dmgSource      = nil,
			dmgTime        = 0,
			dmgAmount      = 0,
			lastHeardPos   = nil,
			lastHeardTime  = 0,
			worldEvents    = {},
		},

		memory = {
			LastEnemy      = nil,
			LastEnemyPos   = nil,
			LastEnemyTime  = 0,
			LastEnemyHP    = nil,
			PatrolRing     = {},
			PatrolRingIdx  = 0,
			DangerZones    = {},
			InterestPoints = {},
			CustomFacts    = {},
			KnownEnemies   = {},
			ReplayLog      = {},
		},

		threat = {},

		combat = {
			atkTimer    = 0,
			dodgeTimer  = 0,
			blockTimer  = 0,
			reactTimer  = 0,
			burstCount  = 0,
			burstTimer  = 0,
			blocking    = false,
			lastAtkTime = 0,
			inCombat    = false,
			hitsDealt   = 0,
			hitsTaken   = 0,
			dmgDealt    = 0,
			dmgTaken    = 0,
			parryWindow = 0,
			styleTimer  = 0,
		},

		movement = {
			path        = nil,
			waypoints   = {},
			wpIdx       = 1,
			dest        = nil,
			lastPos     = nil,
			stuckTimer  = 0,
			stuckCheck  = 0,
			recomputes  = 0,
			status      = "idle",
			patrolTimer = 0,
			sprinting   = false,
			_blockConn  = nil,
			avoidVec    = Vector3.zero,
			avoidTimer  = 0,
		},

		tactical = {
			mode         = "Rush",
			flankTimer   = 0,
			flankSide    = 1,
			lastBackup   = 0,
			coverPos     = nil,
			coverScore   = 0,
			coverTimer   = 0,
			lastRetreat  = 0,
			circleAngle  = 0,
			circleDir    = 1,
			hitRunPhase  = "attack",
			hitRunTimer  = 0,
		},

		territory = {
			center      = p,
			radius      = cfg.TerritoryRadius,
			alertRadius = cfg.TerritoryAlertRadius,
			returning   = false,
			patrolPts   = {},
		},

		ability = {
			defs      = {},
			cooldowns = {},
			mana      = cfg.MaxMana,
			casting   = nil,
			castTimer = 0,
		},

		squad = {
			squadId   = nil,
			role      = "Soldier",
			formSlot  = 0,
			pingTimer = 0,
		},

		shield = {
			current    = cfg.Shield or 0,
			max        = cfg.MaxShield or 0,
			regenTimer = 0,
		},

		prediction = {
			history      = {},
			predictedPos = nil,
			predictedVel = nil,
			accuracy     = 0,
		},

		emotion = deepCopy(cfg.Emotion),

		learning = {
			targetHist     = {},
			playerPatterns = {},
			wins           = 0,
			losses         = 0,
			combatCount    = 0,
			dmgDealt       = 0,
			dmgTaken       = 0,
		},

		btree = {
			root       = nil,
			lastResult = nil,
			blackboard = {},
		},

		goal = {
			current = cfg.Goal,
			payload = cfg.GoalPayload,
			stack   = {},
		},

		statusEffects = {},
		modifiers     = {},
		custom        = {},

		_deathConn = nil,
		_remConn   = nil,
		_hpConn    = nil,
		_gridKey   = nil,
	}
end

local AIFrame   = {}
AIFrame.__index = AIFrame

local CALLBACK_EVENTS = {
	"OnStateChange", "OnNPCDied", "OnNPCRegistered", "OnTargetFound", "OnTargetLost",
	"OnAttack", "OnAbilityUsed", "OnSquadEvent", "OnThreatAdded", "OnThreatExpired",
	"OnShieldBroken", "OnStatusApplied", "OnStatusRemoved", "OnStatusInteract",
	"OnParry", "OnDodge", "OnCombatStart", "OnCombatEnd", "OnTerritoryBreach",
	"OnInterestFound", "OnCoverTaken", "OnCoverLost", "OnSquadOrder", "OnGoalChanged",
	"OnWorldEvent", "OnEmotionChanged", "OnSoundEmitted", "OnPrediction",
}

function AIFrame.new(options)
	options = options or {}
	local self = setmetatable({}, AIFrame)

	self._registry    = {}
	self._list        = {}
	self._squads      = {}
	self._ce          = options.CombatEngine or nil
	self._debug       = options.Debug or false
	self._paused      = false
	self._tick        = 0
	self._dayNight    = 1.0
	self._worldEvents = {}
	self._modules     = {}

	self._scheduler = {
		bucketCount   = options.SchedulerBuckets or 4,
		currentBucket = 0,
		buckets       = {},
	}
	for i = 1, self._scheduler.bucketCount do
		self._scheduler.buckets[i] = {}
	end

	self._rayBudget  = { perFrame = options.MaxRaysPerFrame or 60, used = 0 }
	self._pathCache  = {}
	self._pathCacheN = 0

	self._spatialGrid = {}
	self._gridSize    = options.GridSize or 32

	self._replayEnabled = options.ReplayDebug or false

	self._callbacks = {}
	for _, name in ipairs(CALLBACK_EVENTS) do
		self._callbacks[name] = {}
	end

	self._prof = {
		npc=0, fps=0, avgMs=0, peakMs=0,
		_acc=0, _n=0, _st=0, _sc=0,
		perceptionCalls=0, pathfindCalls=0, decisionCalls=0,
		raycastsThisFrame=0, raycastsTotal=0,
		pathCacheHits=0, spatialQueries=0,
	}

	self._rayPool = {}

	if not options.ManualUpdate then
		self._conn = RunService.Heartbeat:Connect(function(dt)
			self:Update(dt)
		end)
	end

	if self._ce then
		self._ce:On("OnDamage", function(target, source, info)
			self:_onCEDamage(target, source, info)
		end)
		self._ce:On("OnKill", function(target, killer)
			local rec = self._registry[killer]
			if rec then self:_learningOnKill(rec, target) end
		end)
	end

	return self
end

function AIFrame:_onCEDamage(target, source, info)
	local rec = self._registry[target]
	if not rec or not source then return end
	local dmg = info and info.Final or 0

	rec.percep.dmgSource = source
	rec.percep.dmgTime   = now()
	rec.percep.dmgAmount = dmg
	rec.combat.dmgTaken  = rec.combat.dmgTaken + dmg
	rec.combat.hitsTaken = rec.combat.hitsTaken + 1
	rec.learning.dmgTaken = rec.learning.dmgTaken + dmg

	self:_addThreatRaw(rec, source, dmg * 2.2, "damage")
	rec.emotion.Stress = math.min(1, rec.emotion.Stress + dmg * 0.01)

	local sh = rec.shield
	if sh.current > 0 then
		sh.current    = math.max(0, sh.current - dmg)
		sh.regenTimer = 4.5
		if sh.current == 0 then
			fireList(self._callbacks.OnShieldBroken, rec, source)
		end
	end

	if rec.state == S.IDLE or rec.state == S.PATROL then
		self:_setState(rec, S.ALERT, "dmg_wake")
		self:_setTarget(rec, source)
	end
	self:_emitSound(rec, "Hurt")
end

function AIFrame:_getRayParams(model)
	if not self._rayPool[model] then
		local rp = RaycastParams.new()
		rp.FilterDescendantsInstances = {model}
		rp.FilterType = Enum.RaycastFilterType.Exclude
		self._rayPool[model] = rp
	end
	return self._rayPool[model]
end

function AIFrame:_raycast(origin, dir, rp)
	if self._rayBudget.used >= self._rayBudget.perFrame then return nil end
	self._rayBudget.used         += 1
	self._prof.raycastsThisFrame += 1
	self._prof.raycastsTotal     += 1
	return workspace:Raycast(origin, dir, rp)
end

function AIFrame:_gridKey(pos)
	local g = self._gridSize
	return math.floor(pos.X/g) .. "|" .. math.floor(pos.Z/g)
end

function AIFrame:_updateSpatialGrid(rec)
	local root = Root(rec.model)
	if not root then return end
	local oldKey = rec._gridKey
	local newKey = self:_gridKey(root.Position)
	if oldKey == newKey then return end

	if oldKey then
		local cell = self._spatialGrid[oldKey]
		if cell then
			for i = #cell, 1, -1 do
				if cell[i] == rec.model then table.remove(cell, i); break end
			end
		end
	end

	local cell = self._spatialGrid[newKey]
	if not cell then
		cell = {}
		self._spatialGrid[newKey] = cell
	end
	cell[#cell+1] = rec.model
	rec._gridKey  = newKey
end

function AIFrame:_getNearbyModels(pos, radius)
	local g      = self._gridSize
	local cells  = math.ceil(radius / g) + 1
	local cx     = math.floor(pos.X / g)
	local cz     = math.floor(pos.Z / g)
	local result = {}
	local seen   = {}
	for dx = -cells, cells do
		for dz = -cells, cells do
			local cell = self._spatialGrid[(cx+dx) .. "|" .. (cz+dz)]
			if cell then
				for _, m in ipairs(cell) do
					if not seen[m] then
						seen[m]           = true
						result[#result+1] = m
					end
				end
			end
		end
	end
	self._prof.spatialQueries += 1
	return result
end

function AIFrame:RegisterNPC(model, userCfg)
	assert(model and model:IsA("Model"), "[AIFrame] model must be a Model")
	if self._registry[model] then return self end

	local cfg = deepCopy(DEFAULT_CFG)
	mergeInto(cfg, PRESETS[(userCfg and userCfg.BehaviourPreset) or cfg.BehaviourPreset] or {})
	mergeInto(cfg, userCfg or {})

	local rec  = newRecord(model, cfg)
	local sch  = self._scheduler
	local slot = cfg.SchedulerBucket or ((#self._list) % sch.bucketCount) + 1
	slot = math.max(1, math.min(sch.bucketCount, slot))
	rec.bucket = slot
	local bucket = sch.buckets[slot]
	bucket[#bucket+1] = model

	self._registry[model]     = rec
	self._list[#self._list+1] = model
	self._prof.npc           += 1

	local h = Hum(model)
	if h then
		h.WalkSpeed    = cfg.MoveSpeed
		rec._deathConn = h.Died:Connect(function() self:_onDeath(rec) end)
		rec._hpConn    = h:GetPropertyChangedSignal("Health"):Connect(function()
			if rec.alive and h.Health <= 0 then self:_onDeath(rec) end
		end)
	end

	rec._remConn = model.AncestryChanged:Connect(function()
		if not model.Parent then self:UnregisterNPC(model) end
	end)

	self:_updateSpatialGrid(rec)
	CollectionService:AddTag(model, "AIFrameRegistered")
	fireList(self._callbacks.OnNPCRegistered, rec)
	return self
end

function AIFrame:UnregisterNPC(model)
	local rec = self._registry[model]
	if not rec then return end

	if rec._deathConn then rec._deathConn:Disconnect(); rec._deathConn = nil end
	if rec._remConn   then rec._remConn:Disconnect();   rec._remConn   = nil end
	if rec._hpConn    then rec._hpConn:Disconnect();    rec._hpConn    = nil end
	if rec.movement._blockConn then
		rec.movement._blockConn:Disconnect()
		rec.movement._blockConn = nil
	end

	local bucket = self._scheduler.buckets[rec.bucket]
	if bucket then
		for i = #bucket, 1, -1 do
			if bucket[i] == model then table.remove(bucket, i); break end
		end
	end

	if rec._gridKey then
		local cell = self._spatialGrid[rec._gridKey]
		if cell then
			for i = #cell, 1, -1 do
				if cell[i] == model then table.remove(cell, i); break end
			end
		end
	end

	local bb = model:FindFirstChild("_AI_DBG")
	if bb then bb:Destroy() end

	self._registry[model] = nil
	self._rayPool[model]  = nil

	for i, m in ipairs(self._list) do
		if m == model then table.remove(self._list, i); break end
	end

	self._prof.npc = math.max(0, self._prof.npc - 1)
	if model.Parent then CollectionService:RemoveTag(model, "AIFrameRegistered") end
end

function AIFrame:GetRecord(model)    return self._registry[model] end
function AIFrame:IsRegistered(model) return self._registry[model] ~= nil end

function AIFrame:GetAllRecords()
	local out = {}
	for _, m in ipairs(self._list) do
		local r = self._registry[m]
		if r then out[#out+1] = r end
	end
	return out
end

function AIFrame:Query(fn)
	local out = {}
	for _, m in ipairs(self._list) do
		local r = self._registry[m]
		if r and fn(r) then out[#out+1] = r end
	end
	return out
end

function AIFrame:Update(dt)
	if self._paused then return end

	local t0 = now()
	self._tick += 1
	self._rayBudget.used         = 0
	self._prof.raycastsThisFrame = 0

	local sch = self._scheduler
	sch.currentBucket = (sch.currentBucket % sch.bucketCount) + 1
	local activeBucket = sch.buckets[sch.currentBucket]

	local doLOD  = (self._tick % 15 == 0)
	local doGrid = (self._tick % 5  == 0)

	for _, model in ipairs(activeBucket) do
		local rec = self._registry[model]
		if not rec or not rec.alive then continue end

		if doLOD  then self:_updateLOD(rec)        end
		if doGrid then self:_updateSpatialGrid(rec) end
		if rec.lod == LOD.SLEEP then continue end

		local scaledDt = dt * sch.bucketCount
		rec.stateAge += scaledDt

		self:_tickStatusEffects(rec, dt)
		self:_tickShield(rec, dt)

		rec.t_percep += scaledDt
		if rec.t_percep >= rec.cfg.PerceptionRate then
			rec.t_percep = 0
			self:_runPerception(rec)
			self._prof.perceptionCalls += 1
		end

		rec.t_threatDecay += scaledDt
		if rec.t_threatDecay >= rec.cfg.ThreatDecayRate then
			rec.t_threatDecay = 0
			self:_decayThreat(rec)
		end

		rec.t_emotion += scaledDt
		if rec.t_emotion >= rec.cfg.EmotionRate then
			rec.t_emotion = 0
			self:_tickEmotion(rec)
		end

		rec.t_decide += scaledDt
		if rec.t_decide >= rec.cfg.DecisionRate then
			rec.t_decide = 0
			if rec.btree.root then
				self:_evalBTree(rec)
			else
				self:_runDecision(rec)
			end
			self._prof.decisionCalls += 1
		end

		rec.t_path += scaledDt
		if rec.t_path >= rec.cfg.PathfindRate then
			rec.t_path = 0
			self:_runMovement(rec)
			self._prof.pathfindCalls += 1
		end

		self:_stepPath(rec, dt)

		if rec.lod <= LOD.MED then
			rec.t_tactical += scaledDt
			if rec.t_tactical >= rec.cfg.TacticalRate then
				rec.t_tactical = 0
				self:_runTactical(rec)
			end
			rec.t_predict += scaledDt
			if rec.t_predict >= 0.20 then
				rec.t_predict = 0
				self:_updatePrediction(rec)
			end
		end

		self:_runCombatAI(rec, dt)
		self:_tickAbilities(rec, dt)
		self:_updateSprinting(rec)
		self:_applyAvoidance(rec, dt)
		self:_tickSquadOrders(rec, dt)
		self:_checkTerritory(rec)
		self:_updateMemoryFromPercep(rec)
		self:_tickGoal(rec, dt)

		rec.t_sound += scaledDt
		if rec.t_sound >= 0.5 and rec.movement.sprinting then
			rec.t_sound = 0
			self:_emitSound(rec, "Footstep")
		end

		rec.t_memory += scaledDt
		if rec.t_memory >= rec.cfg.MemoryDecayRate then
			rec.t_memory = 0
			self:_runMemoryDecay(rec)
		end

		rec.t_world += scaledDt
		if rec.t_world >= 0.25 then
			rec.t_world = 0
			self:_processWorldEvents(rec)
		end

		if self._debug then self:_updateDebugLabel(rec) end
	end

	self:_updateSquadCommanders(dt)

	local ms = (now() - t0) * 1000
	local p  = self._prof
	p._acc += ms
	p._n   += 1
	if ms > p.peakMs then p.peakMs = ms end
	p._st += dt
	p._sc += 1
	if p._st >= 1 then
		p.fps   = p._sc
		p.avgMs = p._n > 0 and (p._acc / p._n) or 0
		p._st=0; p._sc=0; p._acc=0; p._n=0
	end
end

function AIFrame:_updateLOD(rec)
	local r = Root(rec.model)
	if not r then rec.lod = LOD.SLEEP; return end
	local pos     = r.Position
	local nearest = math.huge
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local pr   = char and Root(char)
		if pr then
			local d = (pr.Position - pos).Magnitude
			if d < nearest then nearest = d end
		end
	end
	local cfg = rec.cfg
	if     nearest <= cfg.LOD_High then rec.lod = LOD.FULL
	elseif nearest <= cfg.LOD_Med  then rec.lod = LOD.MED
	elseif nearest <= cfg.LOD_Low  then rec.lod = LOD.LOW
	else                                rec.lod = LOD.SLEEP
	end
end

function AIFrame:_setState(rec, new, reason)
	if rec.state == new then return end
	local old    = rec.state
	rec.prevState = old
	rec.state     = new
	rec.stateAge  = 0

	if new == S.COMBAT and old ~= S.COMBAT then
		rec.combat.inCombat = true
		fireList(self._callbacks.OnCombatStart, rec)
	elseif old == S.COMBAT and new ~= S.COMBAT then
		rec.combat.inCombat = false
		rec.combat.blocking = false
		fireList(self._callbacks.OnCombatEnd, rec)
	end

	if self._replayEnabled then
		local log = rec.memory.ReplayLog
		log[#log+1] = { t=now(), from=old, to=new, reason=reason or "" }
		if #log > 200 then table.remove(log, 1) end
	end

	local sm = rec.cfg.StateMachine
	if sm and sm._states and sm._states[new] then
		pcall(sm.forceTransition, sm, new)
	end

	fireList(self._callbacks.OnStateChange, rec, old, new, reason)
end

function AIFrame:SetState(m,s,r)  local rec=self._registry[m]; if rec then self:_setState(rec,s,r) end end
function AIFrame:GetState(m)      local r=self._registry[m]; return r and r.state end
function AIFrame:IsInState(m,s)   local r=self._registry[m]; return r ~= nil and r.state == s end

function AIFrame:_setTarget(rec, new)
	local old = rec.target
	if old == new then return end
	rec.target = new
	if new  and not old then fireList(self._callbacks.OnTargetFound, rec, new) end
	if not new and old  then fireList(self._callbacks.OnTargetLost,  rec, old) end
end

function AIFrame:SetTarget(m,t)  local r=self._registry[m]; if r then self:_setTarget(r,t) end end
function AIFrame:GetTarget(m)    local r=self._registry[m]; return r and r.target end
function AIFrame:ClearTarget(m)  self:SetTarget(m, nil) end

function AIFrame:_addThreatRaw(rec, source, amount, reason)
	if not source then return end
	local t = rec.threat[source]
	if not t then
		t = { amount=0, lastHit=now(), decayRate=1.0, locked=false, sources={} }
		rec.threat[source] = t
	end
	t.amount  = t.amount + amount
	t.lastHit = now()
	if reason then t.sources[reason] = (t.sources[reason] or 0) + amount end
	self:_refreshHighestThreat(rec)
	fireList(self._callbacks.OnThreatAdded, rec, source, amount, reason)
end

function AIFrame:AddThreat(model, source, amount, reason)
	local rec = self._registry[model]
	if rec then self:_addThreatRaw(rec, source, amount or 10, reason or "manual") end
end

function AIFrame:RemoveThreat(model, source)
	local rec = self._registry[model]
	if not rec then return end
	rec.threat[source] = nil
	self:_refreshHighestThreat(rec)
end

function AIFrame:SetThreat(model, source, amount)
	local rec = self._registry[model]
	if not rec then return end
	if not rec.threat[source] then
		rec.threat[source] = { amount=0, lastHit=now(), decayRate=1.0, locked=false, sources={} }
	end
	rec.threat[source].amount = amount
	self:_refreshHighestThreat(rec)
end

function AIFrame:LockThreat(model, source, locked)
	local rec = self._registry[model]
	if rec and rec.threat[source] then rec.threat[source].locked = locked ~= false end
end

function AIFrame:SetThreatDecayRate(model, source, rate)
	local rec = self._registry[model]
	if rec and rec.threat[source] then rec.threat[source].decayRate = math.max(0, rate) end
end

function AIFrame:ClearThreat(model)
	local rec = self._registry[model]
	if not rec then return end
	rec.threat = {}
	self:_setTarget(rec, nil)
end

function AIFrame:GetThreatTable(model)
	local rec = self._registry[model]
	if not rec then return {} end
	local out = {}
	for src, t in pairs(rec.threat) do
		out[src] = { amount=t.amount, lastHit=t.lastHit, locked=t.locked, sources=deepCopy(t.sources) }
	end
	return out
end

function AIFrame:GetTopThreats(model, n)
	local rec = self._registry[model]
	if not rec then return {} end
	local list = {}
	for src, t in pairs(rec.threat) do
		if typeof(src) == "Instance" and Alive(src) then
			list[#list+1] = { source=src, amount=t.amount, locked=t.locked }
		end
	end
	table.sort(list, function(a, b) return a.amount > b.amount end)
	local out = {}
	for i = 1, math.min(n or 3, #list) do out[i] = list[i] end
	return out
end

function AIFrame:ShareThreat(fromModel, toModel, factor)
	local from = self._registry[fromModel]
	local to   = self._registry[toModel]
	if not from or not to then return end
	factor = factor or 0.5
	for src, t in pairs(from.threat) do
		if typeof(src) == "Instance" then
			self:_addThreatRaw(to, src, t.amount * factor, "shared")
		end
	end
end

function AIFrame:_decayThreat(rec)
	local toRemove = nil
	local n = now()
	for src, t in pairs(rec.threat) do
		if t.locked then continue end
		local age   = n - t.lastHit
		local decay = t.decayRate * (1 + age * 0.08)
		t.amount    = math.max(0, t.amount - decay)
		if t.amount == 0 then
			if not toRemove then toRemove = {} end
			toRemove[#toRemove+1] = src
			fireList(self._callbacks.OnThreatExpired, rec, src)
		end
	end
	if toRemove then
		for _, src in ipairs(toRemove) do rec.threat[src] = nil end
		self:_refreshHighestThreat(rec)
	end
end

function AIFrame:_refreshHighestThreat(rec)
	local bestSrc, bestAmt = nil, -1
	for src, t in pairs(rec.threat) do
		if t.amount > bestAmt and typeof(src) == "Instance" and Alive(src) then
			bestSrc = src; bestAmt = t.amount
		end
	end
	if bestSrc then self:_setTarget(rec, bestSrc) end
end

function AIFrame:_scanModelForPercep(rec, char, isPlayer, pos, look, vRange, halfA, hRange, useRaycast, visible, audible)
	local cr = Root(char)
	if not cr then return nil, nil end
	local h = Hum(char)
	if not h or h.Health <= 0 then return nil, nil end
	if self._registry[char] and self._registry[char].modifiers.Stealth then return nil, nil end

	local delta = cr.Position - pos
	local dist  = delta.Magnitude
	local bestM, bestD = nil, math.huge

	if dist <= hRange then
		local vol = h.MoveDirection.Magnitude > 0.05 and 1.0 or 0.25
		audible[#audible+1] = { model=char, dist=dist, volume=vol }
		self:_addThreatRaw(rec, char, vol * 0.5, "heard")
		rec.percep.lastHeardPos  = cr.Position
		rec.percep.lastHeardTime = now()
		self:_propagateSound(pos, char, vol * 10, hRange * 0.5)
	end

	if dist <= vRange then
		local angle = math.acos(clamp(look:Dot(delta.Unit), -1, 1))
		if angle <= halfA then
			if useRaycast then
				local result = self:_raycast(pos, delta.Unit * dist, self:_getRayParams(rec.model))
				local hitM   = result and result.Instance:FindFirstAncestorOfClass("Model")
				if result and hitM ~= char then
					return nil, nil
				end
			end
			visible[#visible+1] = { model=char, dist=dist, angle=math.deg(angle), isPlayer=isPlayer }
			if dist < bestD then bestM=char; bestD=dist end
		end
	end

	return bestM, bestD
end

function AIFrame:_runPerception(rec)
	local npcRoot = Root(rec.model)
	if not npcRoot then return end

	local pos    = npcRoot.Position + Vector3.new(0, 1.6, 0)
	local look   = npcRoot.CFrame.LookVector
	local cfg    = rec.cfg
	local halfA  = math.rad(cfg.VisionAngle * 0.5)
	local hRange = cfg.HearingRange

	local useRaycast = rec.lod == LOD.FULL
	local vRange     = useRaycast
		and (cfg.VisionRange * self._dayNight)
		or  (cfg.VisionLODMed or cfg.VisionRange * 0.6)

	local visible = {}
	local audible = {}
	local bestM, bestD = nil, math.huge

	local nearby = self:_getNearbyModels(npcRoot.Position, math.max(vRange, hRange))

	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		if char then
			local m, d = self:_scanModelForPercep(rec, char, true, pos, look, vRange, halfA, hRange, useRaycast, visible, audible)
			if m and d < bestD then bestM=m; bestD=d end
		end
	end

	for _, om in ipairs(nearby) do
		if om == rec.model then continue end
		local other = self._registry[om]
		if not other or other.cfg.Faction == cfg.Faction or not other.alive then continue end
		local m, d = self:_scanModelForPercep(rec, om, false, pos, look, vRange, halfA, hRange, useRaycast, visible, audible)
		if m and d < bestD then bestM=m; bestD=d end
	end

	local alertLevel = 0
	if #visible > 0 then
		alertLevel = 2
	elseif #audible > 0 then
		alertLevel = 1
	elseif rec.percep.dmgTime > 0 and (now()-rec.percep.dmgTime) < 5 then
		alertLevel = 2
	end

	local per        = rec.percep
	per.visible      = visible
	per.audible      = audible
	per.closestModel = bestM
	per.closestDist  = bestD < math.huge and bestD or nil
	per.alertLevel   = alertLevel
end

function AIFrame:_propagateSound(fromPos, source, threat, radius)
	local srcFaction = self._registry[source] and self._registry[source].cfg.Faction or ""
	for _, om in ipairs(self:_getNearbyModels(fromPos, radius)) do
		local other = self._registry[om]
		if not other or not other.alive or other.cfg.Faction == srcFaction then continue end
		self:_addThreatRaw(other, source, threat * 0.25, "sound_prop")
	end
end

function AIFrame:_updateMemoryFromPercep(rec)
	local per = rec.percep
	local mem = rec.memory
	if not per.closestModel then return end

	local n  = now()
	local tr = Root(per.closestModel)
	mem.LastEnemy     = per.closestModel
	mem.LastEnemyPos  = tr and tr.Position or mem.LastEnemyPos
	mem.LastEnemyTime = n
	local eh = Hum(per.closestModel)
	mem.LastEnemyHP = eh and eh.Health or nil

	local ke = mem.KnownEnemies
	for _, e in ipairs(ke) do
		if e.model == per.closestModel then
			e.lastPos=mem.LastEnemyPos; e.lastHp=mem.LastEnemyHP; e.ts=n
			return
		end
	end
	ke[#ke+1] = { model=per.closestModel, lastPos=mem.LastEnemyPos, lastHp=mem.LastEnemyHP, ts=n }
	if #ke > 10 then table.remove(ke, 1) end
end

function AIFrame:_runMemoryDecay(rec)
	local mem = rec.memory
	local n   = now()

	if mem.LastEnemyTime > 0 and (n-mem.LastEnemyTime) > 18 then
		mem.LastEnemy=nil; mem.LastEnemyPos=nil; mem.LastEnemyTime=0
	end

	local dz = mem.DangerZones
	for i = #dz, 1, -1 do
		if (n-dz[i].ts) > 90 then table.remove(dz, i) end
	end

	local ip = mem.InterestPoints
	for i = #ip, 1, -1 do
		if (n-ip[i].ts) > 20 then table.remove(ip, i) end
	end

	local ke = mem.KnownEnemies
	for i = #ke, 1, -1 do
		if (n-ke[i].ts) > 30 then table.remove(ke, i) end
	end

	for key, entry in pairs(self._pathCache) do
		if (n - entry.ts) > 30 then
			self._pathCache[key] = nil
			self._pathCacheN    -= 1
		end
	end
end

function AIFrame:RememberFact(model, key, value)
	local rec = self._registry[model]
	if rec then rec.memory.CustomFacts[key] = {value=value, ts=now()} end
end

function AIFrame:RecallFact(model, key, maxAge)
	local rec = self._registry[model]
	if not rec then return nil end
	local f = rec.memory.CustomFacts[key]
	if not f then return nil end
	if maxAge and (now()-f.ts) > maxAge then return nil end
	return f.value
end

function AIFrame:AddInterestPoint(model, position, interest, radius)
	local rec = self._registry[model]
	if not rec then return end
	local ip = rec.memory.InterestPoints
	for _, pt in ipairs(ip) do
		if (pt.pos-position).Magnitude < (radius or 8) then
			pt.interest=math.max(pt.interest, interest or 1); pt.ts=now(); return
		end
	end
	ip[#ip+1] = { pos=position, interest=interest or 1, radius=radius or 8, ts=now() }
	if #ip > 12 then
		table.sort(ip, function(a,b) return a.interest > b.interest end)
		table.remove(ip)
	end
	fireList(self._callbacks.OnInterestFound, rec, position, interest)
end

function AIFrame:AddDangerZone(model, position, radius, severity)
	local rec = self._registry[model]
	if not rec then return end
	local dz = rec.memory.DangerZones
	for _, z in ipairs(dz) do
		if (z.pos-position).Magnitude < (radius or 10) then
			z.score += severity or 1; z.ts=now(); return
		end
	end
	dz[#dz+1] = { pos=position, radius=radius or 10, score=severity or 1, ts=now() }
	if #dz > 20 then
		table.sort(dz, function(a,b) return a.score > b.score end)
		while #dz > 20 do table.remove(dz) end
	end
end

function AIFrame:IsInDangerZone(model, position)
	local rec = self._registry[model]
	if not rec then return false end
	for _, z in ipairs(rec.memory.DangerZones) do
		if (z.pos-position).Magnitude <= z.radius then return true, z.score end
	end
	return false
end

function AIFrame:_tickEmotion(rec)
	local em  = rec.emotion
	local cfg = rec.cfg
	local hp  = HPRatio(rec.model)

	local hasAlly = false
	if rec.squad.squadId then
		local sq = self._squads[rec.squad.squadId]
		if sq then
			for _, mr in ipairs(sq.members) do
				if mr.alive and mr ~= rec then hasAlly=true; break end
			end
		end
	end

	local function lerpEmo(a, target) return clamp(a + (target-a)*0.08, 0, 1) end

	local prevFear = em.Fear
	em.Fear   = lerpEmo(em.Fear,   clamp((1-hp)*0.8 + (rec.percep.alertLevel>0 and 0.1 or 0), 0, 1))
	em.Rage   = lerpEmo(em.Rage,   clamp((rec.combat.dmgTaken / math.max(100, rec.combat.dmgTaken+1)) * 1.2, 0, 1))
	em.Stress = lerpEmo(em.Stress, clamp(em.Stress * 0.95, 0, 1))
	em.Morale = lerpEmo(em.Morale, clamp(hp*0.5 + (hasAlly and 0.3 or 0) + 0.2, 0, 1))

	if em.Fear > 0.85 and prevFear <= 0.85 then
		rec.cfg.FleeHealth = math.min(0.9, rec.cfg.FleeHealth + 0.10)
		fireList(self._callbacks.OnEmotionChanged, rec, "Fear", em.Fear)
	end
	if em.Rage > 0.80 then
		rec.cfg.Personality.Aggression = math.min(1, rec.cfg.Personality.Aggression + 0.02)
	end
	if em.Morale < 0.25 then
		rec.cfg.Personality.Courage = math.max(0, rec.cfg.Personality.Courage - 0.01)
	end
end

function AIFrame:_runDecision(rec)
	if not rec.alive then return end
	if rec.state == S.STUNNED or rec.state == S.CHANNEL then return end

	local goal = rec.goal.current
	if goal then
		local gDef = GOAL_DEFS[goal]
		if gDef and rec.state ~= gDef.state then
			self:_setState(rec, gDef.state, "goal_"..goal)
		end
		return
	end

	local cfg  = rec.cfg
	local pers = cfg.Personality
	local em   = rec.emotion
	local hp   = HPRatio(rec.model)
	local per  = rec.percep
	local seen = per.closestModel
	local dist = per.closestDist or math.huge
	local n    = now()

	if hp <= (cfg.FleeHealth + em.Fear * 0.15) and pers.Courage < (0.6 - em.Fear * 0.2) then
		if rec.state ~= S.FLEE then self:_setState(rec, S.FLEE, "hp_critical") end
		return
	end

	if rec.statusEffects.Terrified or rec.statusEffects.Confused then
		if rec.state ~= S.FLEE then self:_setState(rec, S.FLEE, "status_flee") end
		return
	end

	if per.dmgTime > 0 and (n-per.dmgTime) < 1.8 and per.dmgSource then
		if rec.state == S.IDLE or rec.state == S.PATROL or rec.state == S.GUARD then
			self:_setTarget(rec, per.dmgSource)
			self:_setState(rec, S.ALERT, "dmg_interrupt")
			return
		end
	end

	if not seen and per.lastHeardTime > 0 and (n-per.lastHeardTime) < 3
		and rec.state == S.PATROL and pers.Intelligence > 0.35 then
		self:AddInterestPoint(rec.model, per.lastHeardPos, 0.8, 10)
		self:_setState(rec, S.ALERT, "heard_noise")
		return
	end

	if seen then
		self:_setTarget(rec, seen)
		local eDist = dist
		if rec.prediction.predictedPos then
			local pRoot = Root(seen)
			if pRoot then
				eDist = dist - (pRoot.Position - rec.prediction.predictedPos).Magnitude * 0.3
			end
		end
		if eDist <= cfg.AttackRange then
			if rec.state ~= S.COMBAT then self:_setState(rec, S.COMBAT, "in_range") end
		elseif eDist <= cfg.AttackRange * 2.8 then
			if rec.state ~= S.CHASE and rec.state ~= S.COMBAT then
				self:_setState(rec, S.CHASE, "close_approach")
			end
		elseif pers.Aggression > 0.50 then
			if rec.state ~= S.CHASE then self:_setState(rec, S.CHASE, "spotted") end
		elseif rec.state ~= S.ALERT then
			self:_setState(rec, S.ALERT, "spotted_cautious")
		end
	else
		if rec.target and not Alive(rec.target) then
			self:_setTarget(rec, nil); self:ClearThreat(rec.model)
		end
		if rec.target then
			local window = 5 + pers.Patience * 14 + em.Rage * 5
			if rec.memory.LastEnemyPos and rec.stateAge < window then
				if rec.state ~= S.SEARCH then self:_setState(rec, S.SEARCH, "lost_sight") end
			else
				self:_setTarget(rec, nil); self:ClearThreat(rec.model)
				if #rec.memory.InterestPoints > 0 then
					self:_setState(rec, S.ALERT, "investigate_interest")
				elseif rec.state ~= S.PATROL then
					self:_setState(rec, S.PATROL, "threat_gone")
				end
			end
		elseif rec.state ~= S.PATROL and rec.state ~= S.IDLE and rec.state ~= S.GUARD then
			self:_setState(rec, S.IDLE, "no_threat")
		end
	end
end

function AIFrame:_pathCacheKey(from, to, r)
	local g = 8
	local function q(v) return math.floor(v/g) end
	return q(from.X)..","..q(from.Z).."|"..q(to.X)..","..q(to.Z).."|"..(r or 2)
end

function AIFrame:_computePath(rec, dest)
	if not dest then return false end
	local root = Root(rec.model)
	if not root then return false end
	local mov = rec.movement

	if mov._blockConn then mov._blockConn:Disconnect(); mov._blockConn=nil end

	local inDanger, score = self:IsInDangerZone(rec.model, dest)
	if inDanger and score and score > 2 then
		dest = dest + Vector3.new(rngR(-9,9), 0, rngR(-9,9))
	end

	local cacheKey = self:_pathCacheKey(root.Position, dest, rec.cfg.AgentRadius)
	local cached   = self._pathCache[cacheKey]
	if cached and (now()-cached.ts) < 8 then
		mov.path       = nil
		mov.waypoints  = cached.waypoints
		mov.wpIdx      = 2
		mov.dest       = dest
		mov.recomputes = 0
		mov.status     = "following"
		mov.lastPos    = root.Position
		mov.stuckTimer = 0
		self._prof.pathCacheHits += 1
		return true
	end

	local cfg  = rec.cfg
	local path = PathfindingService:CreatePath({
		AgentRadius     = cfg.AgentRadius,
		AgentHeight     = cfg.AgentHeight,
		AgentCanJump    = true,
		AgentCanClimb   = true,
		WaypointSpacing = cfg.WaypointSize,
		Costs           = { Water=4, Lava=1000 },
	})

	local ok = pcall(path.ComputeAsync, path, root.Position, dest)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		mov.status = "failed"; return false
	end

	local wps = path:GetWaypoints()
	self._pathCache[cacheKey] = { waypoints=wps, ts=now() }
	self._pathCacheN += 1
	if self._pathCacheN > 200 then
		local oldest, oldKey = math.huge, nil
		for k, v in pairs(self._pathCache) do
			if v.ts < oldest then oldest=v.ts; oldKey=k end
		end
		if oldKey then self._pathCache[oldKey]=nil; self._pathCacheN -= 1 end
	end

	mov.path       = path
	mov.waypoints  = wps
	mov.wpIdx      = 2
	mov.dest       = dest
	mov.recomputes = 0
	mov.status     = "following"
	mov.lastPos    = root.Position
	mov.stuckTimer = 0

	mov._blockConn = path.Blocked:Connect(function(bi)
		if bi >= mov.wpIdx then
			self._pathCache[cacheKey] = nil
			self._pathCacheN          = math.max(0, self._pathCacheN-1)
			if mov.recomputes < MAX_RECOMP then
				mov.recomputes += 1
				self:_computePath(rec, mov.dest)
			else
				mov.status = "failed"
			end
		end
	end)
	return true
end

function AIFrame:_stepPath(rec, dt)
	local mov  = rec.movement
	local root = Root(rec.model)
	local hum  = Hum(rec.model)
	if not root or not hum or mov.status ~= "following" then return end

	local wps = mov.waypoints
	if not wps or mov.wpIdx > #wps then mov.status="arrived"; return end

	local wp   = wps[mov.wpIdx]
	local pos  = root.Position
	local dist = (wp.Position - pos).Magnitude

	if dist <= ARRIVE_R then
		mov.wpIdx += 1
		if mov.wpIdx > #wps then mov.status="arrived"; return end
		wp = wps[mov.wpIdx]
	end

	if wp.Action == Enum.PathWaypointAction.Jump then
		if hum:GetState() ~= Enum.HumanoidStateType.Jumping then
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end

	hum:MoveTo(wp.Position + mov.avoidVec)

	mov.stuckCheck = (mov.stuckCheck or 0) + dt
	if mov.stuckCheck >= 0.5 then
		mov.stuckCheck = 0
		local lp = mov.lastPos
		if lp and (pos-lp).Magnitude < STUCK_DELTA then
			mov.stuckTimer += 0.5
			if mov.stuckTimer >= STUCK_TIMEOUT then
				mov.status = "stuck"
				self:_recoverStuck(rec)
			end
		else
			mov.lastPos    = pos
			mov.stuckTimer = 0
		end
	end
end

function AIFrame:_recoverStuck(rec)
	local mov  = rec.movement
	local hum  = Hum(rec.model)
	local root = Root(rec.model)
	if not hum or not root then return end
	hum:ChangeState(Enum.HumanoidStateType.Jumping)
	task.delay(0.45, function()
		if not rec or mov.status ~= "stuck" then return end
		local side = root.CFrame.RightVector * (rng() > 0.5 and 1 or -1)
		hum:MoveTo(root.Position + side * 6)
		task.delay(0.65, function()
			if not rec or not mov.dest then mov.status="idle"; return end
			if mov.recomputes < MAX_RECOMP then
				mov.recomputes += 1
				self:_computePath(rec, mov.dest)
			else
				mov.status = "failed"
			end
		end)
	end)
end

function AIFrame:_runMovement(rec)
	local hum  = Hum(rec.model)
	local root = Root(rec.model)
	if not hum or not root then return end

	local st  = rec.state
	local mov = rec.movement

	if st == S.CHASE or st == S.COMBAT then
		local tr = rec.target and Root(rec.target)
		if tr then
			local dest = rec.prediction.predictedPos or tr.Position
			local dd   = mov.dest and (mov.dest-dest).Magnitude or math.huge
			if dd > 3.5 or mov.status == "failed" or mov.status == "idle" then
				self:_computePath(rec, dest)
			end
		end

	elseif st == S.FLEE then
		local tr = rec.target and Root(rec.target)
		if tr then
			local away = root.Position - tr.Position
			if away.Magnitude < 0.01 then away=Vector3.new(rng(),0,rng()) end
			local fleeDest = root.Position + away.Unit*35 + Vector3.new(rngR(-6,6),0,rngR(-6,6))
			if mov.status ~= "following" or (mov.dest and (mov.dest-fleeDest).Magnitude > 10) then
				self:_computePath(rec, fleeDest)
			end
		end

	elseif st == S.SEARCH then
		local ip = rec.memory.InterestPoints
		if #ip > 0 then
			local best = ip[1]
			for _, pt in ipairs(ip) do if pt.interest > best.interest then best=pt end end
			if mov.status ~= "following" then self:_computePath(rec, best.pos) end
		elseif rec.memory.LastEnemyPos and mov.status ~= "following" then
			self:_computePath(rec, rec.memory.LastEnemyPos)
		end

	elseif st == S.PATROL then
		if mov.status == "arrived" or mov.status == "idle" or mov.status == "failed" then
			mov.patrolTimer -= rec.cfg.PathfindRate
			if mov.patrolTimer <= 0 then
				local dest = self:_pickPatrolDest(rec)
				self:_logPatrolPos(rec, dest)
				self:_computePath(rec, dest)
				mov.patrolTimer = rngR(4, 10)
			end
		end

	elseif st == S.ESCORT then
		local et = rec.escortTarget and Root(rec.escortTarget)
		if et then
			local dd = mov.dest and (mov.dest-et.Position).Magnitude or math.huge
			if dd > 5 then
				self:_computePath(rec, et.Position + Vector3.new(rngR(-4,4),0,rngR(-4,4)))
			end
		end

	elseif st == S.HUNT then
		local bestE, bestS = nil, -math.huge
		for _, e in ipairs(rec.memory.KnownEnemies) do
			if (now()-e.ts) < 20 then
				local s = (e.lastHp or 100) * -1 + (now()-e.ts) * -2
				if s > bestS then bestS=s; bestE=e end
			end
		end
		if bestE and bestE.lastPos and mov.status ~= "following" then
			self:_computePath(rec, bestE.lastPos)
		end

	elseif st == S.GUARD then
		local fromSpawn = (root.Position-rec.spawnPos).Magnitude
		if fromSpawn > 3 and (mov.status == "idle" or mov.status == "arrived" or mov.status == "failed") then
			self:_computePath(rec, rec.spawnPos)
		end

	elseif st == S.IDLE then
		if mov.status ~= "idle" then mov.status="idle"; hum:MoveTo(root.Position) end
	end
end

function AIFrame:_pickPatrolDest(rec)
	local pts = rec.territory.patrolPts
	if #pts > 0 then return pts[rngi(1,#pts)] end
	local base = rec.spawnPos
	local r    = rec.cfg.TerritoryRadius * 0.55
	local best, bestScore = nil, -math.huge
	for _ = 1, 7 do
		local c     = base + Vector3.new(rngR(-r,r), 0, rngR(-r,r))
		local vis   = self:_hasVisitedPatrol(rec, c)
		local dng   = self:IsInDangerZone(rec.model, c)
		local score = (vis and -1 or 1) + (dng and -2 or 0) + rng()*0.4
		if score > bestScore then bestScore=score; best=c end
	end
	return best or base
end

function AIFrame:_logPatrolPos(rec, pos)
	local mem = rec.memory
	local idx = (mem.PatrolRingIdx % 10) + 1
	mem.PatrolRing[idx] = pos
	mem.PatrolRingIdx   = idx
end

function AIFrame:_hasVisitedPatrol(rec, pos)
	for _, p in ipairs(rec.memory.PatrolRing) do
		if p and (p-pos).Magnitude < 9 then return true end
	end
	return false
end

function AIFrame:_updateSprinting(rec)
	local hum = Hum(rec.model)
	if not hum then return end
	local cfg  = rec.cfg
	local hp   = HPRatio(rec.model)
	local want = (rec.state == S.CHASE and hp > cfg.SprintThresh and cfg.Personality.Aggression > 0.45)
		or rec.state == S.FLEE
	if want ~= rec.movement.sprinting then
		rec.movement.sprinting = want
		hum.WalkSpeed = want and cfg.SprintSpeed or cfg.MoveSpeed
	end
end

function AIFrame:_applyAvoidance(rec, dt)
	local mov = rec.movement
	mov.avoidTimer = (mov.avoidTimer or 0) - dt
	if mov.avoidTimer > 0 then return end
	mov.avoidTimer = 0.28
	local root = Root(rec.model)
	if not root then return end

	local pos   = root.Position
	local avoid = Vector3.zero
	local count = 0

	for _, om in ipairs(self:_getNearbyModels(pos, 5)) do
		if om == rec.model then continue end
		local or2 = Root(om)
		if not or2 then continue end
		local d = (or2.Position - pos).Magnitude
		if d < 3.5 and d > 0.01 then
			avoid = avoid + (pos - or2.Position).Unit * ((3.5-d)/3.5)
			count += 1
		end
	end
	mov.avoidVec = count > 0 and Vector3.new(avoid.X/count, 0, avoid.Z/count)*1.8 or Vector3.zero
end

function AIFrame:AddPatrolPoint(model, position)
	local rec = self._registry[model]
	if rec then rec.territory.patrolPts[#rec.territory.patrolPts+1] = position end
end

function AIFrame:_updatePrediction(rec)
	if not rec.target then rec.prediction.predictedPos=nil; return end
	local tr = Root(rec.target)
	if not tr then return end

	local pred = rec.prediction
	local hist = pred.history
	hist[#hist+1] = { pos=tr.Position, vel=VelOf(rec.target), t=now() }
	if #hist > rec.cfg.PredictionSteps then table.remove(hist, 1) end
	if #hist < 2 then pred.predictedPos=tr.Position; return end

	local avgVel = Vector3.zero
	for i = 2, #hist do
		local dt2 = hist[i].t - hist[i-1].t
		if dt2 > 0 then avgVel = avgVel + (hist[i].pos - hist[i-1].pos) / dt2 end
	end
	avgVel = avgVel / (#hist - 1)

	local myRoot  = Root(rec.model)
	local myPos   = myRoot and myRoot.Position or tr.Position
	local travelT = (myPos - tr.Position).Magnitude / math.max(rec.cfg.SprintSpeed, 1)

	local pat = rec.learning.playerPatterns[rec.target]
	local acc = pat and math.min(1.0, #pat / 10) or 0.5

	pred.predictedPos = tr.Position + avgVel * travelT * acc
	pred.predictedVel = avgVel
	pred.accuracy     = acc

	if not pat then
		rec.learning.playerPatterns[rec.target] = {}
		pat = rec.learning.playerPatterns[rec.target]
	end
	pat[#pat+1] = { pos=tr.Position, vel=VelOf(rec.target), t=now() }
	if #pat > 30 then table.remove(pat, 1) end

	fireList(self._callbacks.OnPrediction, rec, pred.predictedPos, pred.accuracy)
end

function AIFrame:_scoreCoverPoint(rec, candidate, enemyPos)
	local myRoot = Root(rec.model)
	if not myRoot then return -math.huge end
	local score = 0

	local losResult = self:_raycast(
		candidate + Vector3.new(0,1,0),
		(enemyPos - candidate).Unit * (enemyPos-candidate).Magnitude,
		self:_getRayParams(rec.model))
	score += losResult and 10 or 2

	local dist = (candidate - myRoot.Position).Magnitude
	score += math.max(0, 8 - dist*0.3)

	local inDanger, ds = self:IsInDangerZone(rec.model, candidate)
	score += inDanger and (-5 - (ds or 0)) or 3

	for _, om in ipairs(self:_getNearbyModels(candidate, 5)) do
		if om == rec.model then continue end
		local other = self._registry[om]
		if other and other.tactical.coverPos and
			(other.tactical.coverPos - candidate).Magnitude < 4 then
			score -= 3
		end
	end

	if rec.cfg.UseTaggedCovers then
		for _, cover in ipairs(CollectionService:GetTagged("Cover")) do
			if (cover.Position - candidate).Magnitude < 4 then score += 5; break end
		end
	end

	return score + rng()*1.5
end

function AIFrame:FindCover(model, enemyPos, maxRadius)
	local rec  = self._registry[model]
	local root = Root(model)
	if not rec or not root then return nil end
	enemyPos  = enemyPos or (rec.target and Root(rec.target) and Root(rec.target).Position)
	if not enemyPos then return nil end
	maxRadius = maxRadius or 28

	local pos  = root.Position
	local best, bestScore = nil, -math.huge

	if rec.cfg.UseTaggedCovers then
		for _, cover in ipairs(CollectionService:GetTagged("Cover")) do
			if (cover.Position - pos).Magnitude <= maxRadius then
				local s = self:_scoreCoverPoint(rec, cover.Position, enemyPos) + 5
				if s > bestScore then bestScore=s; best=cover.Position end
			end
		end
	end

	for _ = 1, COVER_CANDIDATES do
		local a = rng() * math.pi * 2
		local r = rngR(4, maxRadius)
		local c = pos + Vector3.new(math.cos(a)*r, 0, math.sin(a)*r)
		local s = self:_scoreCoverPoint(rec, c, enemyPos)
		if s > bestScore then bestScore=s; best=c end
	end

	if best and bestScore > 3 then
		rec.tactical.coverPos   = best
		rec.tactical.coverScore = bestScore
		fireList(self._callbacks.OnCoverTaken, rec, best, bestScore)
		return best, bestScore
	end
	return nil
end

function AIFrame:LeaveCover(model)
	local rec = self._registry[model]
	if not rec then return end
	local prev = rec.tactical.coverPos
	rec.tactical.coverPos=nil; rec.tactical.coverScore=0; rec.tactical.coverTimer=0
	if prev then fireList(self._callbacks.OnCoverLost, rec, prev) end
end

function AIFrame:_runTactical(rec)
	if rec.state ~= S.COMBAT and rec.state ~= S.CHASE then return end
	local target = rec.target
	local root   = Root(rec.model)
	local tr     = target and Root(target)
	if not root or not tr then return end

	local cfg   = rec.cfg
	local pers  = cfg.Personality
	local intel = pers.Intelligence
	local hp    = HPRatio(rec.model)
	local dist  = (root.Position - tr.Position).Magnitude
	local tac   = rec.tactical
	local style = COMBAT_STYLES[cfg.CombatStyle] or COMBAT_STYLES.Balanced
	local em    = rec.emotion
	local n     = now()

	if hp < 0.35 and intel > 0.45 and (n-tac.lastBackup) > 22 then
		self:CallForHelp(rec.model, 75)
		tac.lastBackup = n
	end

	if hp < 0.20 and pers.Courage < (0.55 - em.Fear*0.2) then
		tac.mode = "Retreat"
	elseif style.hitAndRun then
		tac.mode = "HitAndRun"
	elseif style.preferCover and (intel > 0.5 or em.Stress > 0.5) then
		local cv, cvScore = self:FindCover(rec.model, tr.Position)
		if cv and cvScore > 5 then tac.mode="Cover"
		elseif style.keepDist > 0 then tac.mode="Kite"
		else tac.mode="Rush" end
	elseif intel > 0.72 and rng() < 0.20 then
		tac.mode = rng() > 0.45 and "Flank" or "Circle"
	elseif style.keepDist > 0 then
		tac.mode = "Kite"
	else
		tac.mode = "Rush"
	end

	if tac.mode == "HitAndRun" then
		if tac.hitRunPhase == "attack" then
			if dist <= cfg.AttackRange then
				tac.hitRunTimer = (tac.hitRunTimer or 0) + cfg.TacticalRate
				if tac.hitRunTimer >= rngR(1.5, 3.0) then
					tac.hitRunPhase="run"; tac.hitRunTimer=0
				end
			else
				self:_computePath(rec, tr.Position)
			end
		else
			local away = (root.Position - tr.Position).Unit
			self:_computePath(rec, root.Position + away*16 + Vector3.new(rngR(-5,5),0,rngR(-5,5)))
			tac.hitRunTimer = (tac.hitRunTimer or 0) + cfg.TacticalRate
			if tac.hitRunTimer >= rngR(2.0, 3.5) then
				tac.hitRunPhase="attack"; tac.hitRunTimer=0
			end
		end

	elseif tac.mode == "Flank" then
		tac.flankTimer -= cfg.TacticalRate
		if tac.flankTimer <= 0 then
			tac.flankSide=-tac.flankSide; tac.flankTimer=rngR(1.8,3.5)
		end
		local toT  = (tr.Position - root.Position).Unit
		local perp = Vector3.new(-toT.Z, 0, toT.X) * tac.flankSide
		self:_computePath(rec, tr.Position + perp*13 - toT*4)

	elseif tac.mode == "Circle" then
		tac.circleAngle = (tac.circleAngle + tac.circleDir*cfg.TacticalRate*55) % 360
		if rng() < 0.05 then tac.circleDir = -tac.circleDir end
		local a = math.rad(tac.circleAngle)
		self:_computePath(rec, tr.Position + Vector3.new(math.cos(a), 0, math.sin(a))*cfg.AttackRange*0.92)

	elseif tac.mode == "Kite" then
		local ideal = (style.keepDist > 0 and style.keepDist or cfg.AttackRange) * 0.85
		if dist < ideal - 3 then
			local away = (root.Position - tr.Position).Unit
			self:_computePath(rec, root.Position + away*14)
		elseif dist > ideal + 6 then
			if rec.state ~= S.CHASE then self:_setState(rec, S.CHASE, "kite_close") end
		end

	elseif tac.mode == "Cover" then
		local cv = tac.coverPos
		tac.coverTimer = (tac.coverTimer or 0) + cfg.TacticalRate
		if cv then
			if rec.movement.status ~= "following" then self:_computePath(rec, cv) end
			if tac.coverTimer > COVER_RECHECK then
				tac.coverTimer = 0
				local newCV, newScore = self:FindCover(rec.model, tr.Position)
				if newCV and newScore > tac.coverScore + 3 then
					tac.coverPos=newCV; tac.coverScore=newScore
				end
			end
		else
			tac.mode = "Rush"
		end

	elseif tac.mode == "Retreat" then
		if (n-tac.lastRetreat) > 3 then
			tac.lastRetreat=n
			self:_setState(rec, S.FLEE, "tactical_retreat")
		end

	else
		if rec.state ~= S.CHASE and rec.state ~= S.COMBAT then
			self:_setState(rec, S.CHASE, "rush")
		end
	end
end

function AIFrame:_runCombatAI(rec, dt)
	if rec.state ~= S.COMBAT then
		if rec.combat.inCombat then
			rec.combat.inCombat=false; rec.combat.blocking=false
		end
		return
	end

	local c     = rec.combat
	local cfg   = rec.cfg
	local pers  = cfg.Personality
	local style = COMBAT_STYLES[cfg.CombatStyle] or COMBAT_STYLES.Balanced
	c.inCombat    = true
	c.atkTimer   += dt
	c.dodgeTimer += dt
	c.blockTimer += dt
	c.reactTimer += dt
	c.burstTimer += dt
	c.styleTimer += dt

	local target = rec.target
	if not target or not Alive(target) then
		self:_setTarget(rec, nil)
		self:_setState(rec, S.SEARCH, "target_died")
		return
	end

	local root = Root(rec.model)
	local tr   = Root(target)
	if not root or not tr then return end
	local dist = (root.Position - tr.Position).Magnitude

	if c.styleTimer >= rngR(4,8) then
		c.styleTimer = 0
		local plog = rec.learning.playerPatterns[target]
		if not plog then
			plog = {}
			rec.learning.playerPatterns[target] = plog
		end
		plog[#plog+1] = { pos=tr.Position, vel=VelOf(target), t=now() }
		if #plog > 30 then table.remove(plog, 1) end
	end

	local blockCd = 3.2 - pers.Courage*1.4
	if c.blockTimer >= blockCd and pers.Courage > 0.48 then
		local recentHit = rec.percep.dmgTime > 0 and (now()-rec.percep.dmgTime) < 0.28
		if recentHit and rng() < pers.Courage*0.55 then
			self:Block(rec.model, 0.5+pers.Courage*0.4, 0.65+pers.Courage*0.18)
			c.blockTimer = 0
		end
	end

	local dodgeCd = 2.6 - pers.Intelligence*1.1
	if c.dodgeTimer >= dodgeCd then
		local recentHit = rec.percep.dmgTime > 0 and (now()-rec.percep.dmgTime) < 0.32
		if recentHit and rng() < pers.Intelligence*0.50 then
			self:Dodge(rec.model); c.dodgeTimer=0
		end
	end

	local rate = (cfg.AttackRate or (1.6 - pers.Aggression*0.9)) * (1 - rec.emotion.Rage*0.25)
	if c.atkTimer >= rate and dist <= cfg.AttackRange then
		local burstMax = style.burstMax + math.floor(pers.Aggression*1.5)
		if c.burstCount < burstMax and c.burstTimer < 0.38 then
			self:_doAttack(rec, target); c.burstCount+=1; c.atkTimer=rate*0.22
		else
			self:_doAttack(rec, target); c.atkTimer=0; c.burstCount=0; c.burstTimer=0
		end
	end

	if c.reactTimer >= 1.4 and pers.Intelligence > 0.55 then
		c.reactTimer = 0
		self:_autoUseAbility(rec, target)
	end
end

function AIFrame:_doAttack(rec, target)
	local ce = rec.cfg.CombatEngine or self._ce
	local c  = rec.combat
	c.lastAtkTime = now()

	local rawDmg = (rec.cfg.BaseDamage or 15)
		* (1 + rngR(-rec.cfg.DamageJitter, rec.cfg.DamageJitter))
		* (1 + (rec.cfg.Level-1)*0.06)
		* (1 + rec.emotion.Rage*0.30)

	if rec.statusEffects.Weakened or rec.statusEffects.Broken then rawDmg = rawDmg*0.60 end
	local isCrit = rng() < rec.cfg.CritChance
	if isCrit then rawDmg = rawDmg*rec.cfg.CritMult end

	if ce then
		local comboName = rec.cfg.ComboName
		if comboName and ce._combos and ce._combos[comboName] then
			ce:TriggerCombo(rec.model, comboName)
		else
			local info = ce:Damage(rec.model, target, rawDmg,
				rec.cfg.ElementType or "Physical", {IsBlockable=true, NoCrit=true})
			if info then
				c.dmgDealt            = c.dmgDealt + info.Final
				c.hitsDealt           = c.hitsDealt + 1
				rec.learning.dmgDealt = rec.learning.dmgDealt + info.Final
				fireList(self._callbacks.OnAttack, rec, target, info.Final, isCrit)
			end
		end
	else
		local hum = Hum(target)
		if hum then
			hum:TakeDamage(rawDmg)
			c.dmgDealt            = c.dmgDealt + rawDmg
			c.hitsDealt           = c.hitsDealt + 1
			rec.learning.dmgDealt = rec.learning.dmgDealt + rawDmg
			fireList(self._callbacks.OnAttack, rec, target, rawDmg, isCrit)
		end
	end
	self:_emitSound(rec, "Attack")
end

function AIFrame:_checkTerritory(rec)
	local root = Root(rec.model)
	if not root then return end
	local ter = rec.territory
	local pos = root.Position
	local inT = (pos-ter.center).Magnitude <= ter.radius

	if not inT and (rec.state == S.CHASE or rec.state == S.COMBAT) then
		local tr = rec.target and Root(rec.target)
		if tr and (tr.Position-ter.center).Magnitude > ter.radius then
			self:_setTarget(rec, nil); self:ClearThreat(rec.model)
			self:_setState(rec, S.PATROL, "left_territory")
			ter.returning = true
			local hum = Hum(rec.model)
			if hum then hum.WalkSpeed = rec.cfg.TerritoryReturnSpeed end
			fireList(self._callbacks.OnTerritoryBreach, rec)
		end
	end

	if ter.returning and inT then
		ter.returning = false
		local hum = Hum(rec.model)
		if hum then hum.WalkSpeed = rec.cfg.MoveSpeed end
	end
end

function AIFrame:SetTerritory(model, center, radius, alertRadius)
	local rec = self._registry[model]
	if not rec then return end
	rec.territory.center      = center
	rec.territory.radius      = radius or rec.cfg.TerritoryRadius
	rec.territory.alertRadius = alertRadius or rec.cfg.TerritoryAlertRadius
end

function AIFrame:_tickShield(rec, dt)
	local sh = rec.shield
	if sh.max <= 0 then return end
	sh.regenTimer = math.max(0, sh.regenTimer - dt)
	if sh.regenTimer == 0 and sh.current < sh.max then
		sh.current = math.min(sh.max, sh.current + 5*dt)
	end
end

function AIFrame:RestoreShield(model, amount)
	local rec = self._registry[model]
	if not rec then return end
	rec.shield.current = math.min(rec.shield.max, rec.shield.current + (amount or rec.shield.max))
end

local GLOBAL_ABILITIES = {}

function AIFrame:RegisterAbility(def)
	assert(type(def.Name) == "string", "[AIFrame] ability needs Name")
	GLOBAL_ABILITIES[def.Name] = def
end

function AIFrame:RegisterAbilityForNPC(model, def)
	assert(type(def.Name) == "string", "[AIFrame] ability needs Name")
	local rec = self._registry[model]
	if not rec then return end
	rec.ability.defs[def.Name]      = def
	rec.ability.cooldowns[def.Name] = 0
end

function AIFrame:UseAbility(model, name, target)
	local rec = self._registry[model]
	if not rec then return false end
	if rec.statusEffects.Silenced then return false end
	local def = rec.ability.defs[name] or GLOBAL_ABILITIES[name]
	if not def then return false end
	if (rec.ability.cooldowns[name] or 0) > 0 then return false end
	if (def.ManaCost or 0) > rec.ability.mana then return false end

	rec.ability.mana -= (def.ManaCost or 0)
	rec.ability.cooldowns[name] = def.Cooldown or 5

	if def.CastTime and def.CastTime > 0 then
		rec.ability.casting   = name
		rec.ability.castTimer = def.CastTime
		self:_setState(rec, S.CHANNEL, "cast_"..name)
		task.delay(def.CastTime, function()
			if not rec or not rec.alive or rec.ability.casting ~= name then return end
			rec.ability.casting = nil
			if def.OnUse then pcall(def.OnUse, model, target, self) end
			fireList(self._callbacks.OnAbilityUsed, rec, name, target)
			if rec.state == S.CHANNEL then self:_setState(rec, S.COMBAT, "cast_done") end
		end)
	else
		if def.OnUse then pcall(def.OnUse, model, target, self) end
		fireList(self._callbacks.OnAbilityUsed, rec, name, target)
	end
	self:_emitSound(rec, "Ability")
	return true
end

function AIFrame:_autoUseAbility(rec, target)
	local root = Root(rec.model)
	local tr   = target and Root(target)
	if not root or not tr then return end
	local dist = (root.Position-tr.Position).Magnitude
	local hp   = HPRatio(rec.model)

	local allDefs = {}
	for n, d in pairs(rec.ability.defs)  do allDefs[n]=d end
	for n, d in pairs(GLOBAL_ABILITIES)  do if not allDefs[n] then allDefs[n]=d end end

	local best, bestP = nil, -1
	for name, def in pairs(allDefs) do
		if (rec.ability.cooldowns[name] or 0) > 0 then continue end
		if (def.ManaCost or 0) > rec.ability.mana  then continue end
		if dist < (def.MinRange or 0) or dist > (def.MaxRange or 9999) then continue end
		if hp < (def.MinHP or 0) or hp > (def.MaxHP or 1) then continue end
		local p = (def.Priority or 1) + rng()*0.12
		if p > bestP then best=name; bestP=p end
	end
	if best then self:UseAbility(rec.model, best, target) end
end

function AIFrame:_tickAbilities(rec, dt)
	local ab = rec.ability
	for name, cd in pairs(ab.cooldowns) do
		if cd > 0 then ab.cooldowns[name] = math.max(0, cd-dt) end
	end
	ab.mana = math.min(rec.cfg.MaxMana, ab.mana + rec.cfg.ManaRegen*dt)
	if ab.casting and ab.castTimer > 0 then
		ab.castTimer -= dt
		if ab.castTimer <= 0 then ab.casting=nil; ab.castTimer=0 end
	end
end

function AIFrame:ApplyStatus(model, statusName, source, overrides)
	local rec = self._registry[model]
	if not rec or not rec.alive then return false end
	local def = STATUS_DEFS[statusName]
	if not def then return false end

	local existing = rec.statusEffects[statusName]
	if existing then
		existing.stacks    = math.min(def.maxStacks or 1, existing.stacks+1)
		existing.remaining = math.max(existing.remaining, (overrides and overrides.duration) or def.dur)
		return true
	end

	local hum   = Hum(model)
	local entry = {
		name      = statusName,
		def       = def,
		remaining = (overrides and overrides.duration) or def.dur,
		tickTimer = 0,
		stacks    = 1,
		source    = source,
		dmg       = def.dmg,
		dmgMult   = 1,
	}
	rec.statusEffects[statusName] = entry

	for otherName, otherEntry in pairs(rec.statusEffects) do
		if otherName == statusName then continue end
		if def.interactions and def.interactions[otherName] then
			def.interactions[otherName](entry, otherEntry)
			fireList(self._callbacks.OnStatusInteract, rec, statusName, otherName)
		end
		if otherEntry.def.interactions and otherEntry.def.interactions[statusName] then
			otherEntry.def.interactions[statusName](otherEntry, entry)
			fireList(self._callbacks.OnStatusInteract, rec, otherName, statusName)
		end
	end

	if def.slow ~= nil and hum then hum.WalkSpeed = rec.cfg.MoveSpeed * def.slow end
	if def.root and hum then hum.WalkSpeed = 0 end
	if def.stun and hum then
		hum.WalkSpeed=0; hum.JumpPower=0
		self:_setState(rec, S.STUNNED, "status_stun")
	end
	if def.onApply then pcall(def.onApply, rec, source) end
	fireList(self._callbacks.OnStatusApplied, rec, statusName, source)
	return true
end

function AIFrame:RemoveStatus(model, statusName)
	local rec = self._registry[model]
	if not rec then return end
	local entry = rec.statusEffects[statusName]
	if not entry then return end
	rec.statusEffects[statusName] = nil
	local def = entry.def
	local hum = Hum(model)

	if def.slow ~= nil and hum then
		local mult = 1
		for _, e in pairs(rec.statusEffects) do
			if e.def.slow ~= nil then mult = mult * e.def.slow end
		end
		hum.WalkSpeed = rec.cfg.MoveSpeed * mult
	end

	if def.stun and rec.state == S.STUNNED then
		local stillStunned = false
		for _, e in pairs(rec.statusEffects) do if e.def.stun then stillStunned=true; break end end
		if not stillStunned then
			if hum then hum.WalkSpeed=rec.cfg.MoveSpeed; hum.JumpPower=50 end
			self:_setState(rec, S.IDLE, "stun_expired")
		end
	end

	if def.onRemove then pcall(def.onRemove, rec) end
	fireList(self._callbacks.OnStatusRemoved, rec, statusName)
end

function AIFrame:HasStatus(model, s) local r=self._registry[model]; return r ~= nil and r.statusEffects[s] ~= nil end
function AIFrame:GetStatusStacks(model, s)
	local r=self._registry[model]; if not r then return 0 end
	local e=r.statusEffects[s]; return e and e.stacks or 0
end

function AIFrame:_tickStatusEffects(rec, dt)
	local toRemove = nil
	for name, entry in pairs(rec.statusEffects) do
		entry.remaining -= dt
		if entry.def.tick then
			entry.tickTimer = (entry.tickTimer or 0) + dt
			if entry.tickTimer >= entry.def.tick then
				entry.tickTimer -= entry.def.tick
				local dmg = entry.dmg and (entry.dmg * entry.stacks * (entry.dmgMult or 1)) or 0
				if dmg > 0 then
					local ce = rec.cfg.CombatEngine or self._ce
					if ce and ce._registry and ce._registry[rec.model] then
						ce:Damage(entry.source, rec.model, dmg, nil, {NoCrit=true, BypassIFrames=true})
					else
						local h = Hum(rec.model)
						if h then h:TakeDamage(dmg) end
					end
				end
				if entry.def.onTick then pcall(entry.def.onTick, rec, entry.stacks) end
			end
		end
		if entry.remaining <= 0 or entry.stacks <= 0 then
			if not toRemove then toRemove={} end
			toRemove[#toRemove+1] = name
		end
	end
	if toRemove then
		for _, name in ipairs(toRemove) do self:RemoveStatus(rec.model, name) end
	end
end

function AIFrame:BroadcastWorldEvent(eventName, position, radius, payload)
	local we = { name=eventName, pos=position, radius=radius or 50, payload=payload, ts=now() }
	self._worldEvents[#self._worldEvents+1] = we
	if #self._worldEvents > 50 then table.remove(self._worldEvents, 1) end
	fireList(self._callbacks.OnWorldEvent, we)
end

function AIFrame:_processWorldEvents(rec)
	local root = Root(rec.model)
	if not root then return end
	local pos = root.Position
	local n   = now()
	for _, we in ipairs(self._worldEvents) do
		if (n-we.ts) > 5 or not we.pos then continue end
		if (we.pos-pos).Magnitude > we.radius then continue end
		local wn = we.name
		if wn == "Explosion" then
			self:_addThreatRaw(rec, we.payload, 35, "explosion")
			self:AddInterestPoint(rec.model, we.pos, 1.0, 12)
			rec.emotion.Stress = math.min(1, rec.emotion.Stress + 0.3)
			if rec.state == S.IDLE or rec.state == S.PATROL then
				self:_setState(rec, S.ALERT, "explosion_heard")
			end
		elseif wn == "AllyDeath" then
			rec.emotion.Fear   = math.min(1, rec.emotion.Fear   + 0.25)
			rec.emotion.Morale = math.max(0, rec.emotion.Morale - 0.30)
		elseif wn == "DoorOpened" or wn == "ObjectMoved" then
			self:AddInterestPoint(rec.model, we.pos, 0.7, 8)
			if rec.state == S.IDLE or rec.state == S.PATROL then
				self:_setState(rec, S.ALERT, "world_event")
			end
		elseif wn == "GunShot" then
			self:AddInterestPoint(rec.model, we.pos, 0.9, 10)
			self:_addThreatRaw(rec, we.payload, 15, "gunshot")
		end
		rec.percep.worldEvents[#rec.percep.worldEvents+1] = we
		if #rec.percep.worldEvents > 5 then table.remove(rec.percep.worldEvents, 1) end
	end
end

function AIFrame:SetGoal(model, goalName, payload)
	local rec = self._registry[model]
	if not rec then return end
	local prev = rec.goal.current
	rec.goal.current = goalName
	rec.goal.payload = payload
	if goalName == "Escort" and payload then rec.escortTarget = payload end
	if goalName and GOAL_DEFS[goalName] then
		self:_setState(rec, GOAL_DEFS[goalName].state, "goal_"..goalName)
	end
	fireList(self._callbacks.OnGoalChanged, rec, prev, goalName, payload)
end

function AIFrame:PushGoal(model, goalName, payload)
	local rec = self._registry[model]
	if not rec then return end
	rec.goal.stack[#rec.goal.stack+1] = { goal=rec.goal.current, payload=rec.goal.payload }
	self:SetGoal(model, goalName, payload)
end

function AIFrame:PopGoal(model)
	local rec = self._registry[model]
	if not rec then return end
	local prev = table.remove(rec.goal.stack)
	self:SetGoal(model, prev and prev.goal, prev and prev.payload)
end

function AIFrame:_tickGoal(rec, dt)
	if rec.goal.current == "Escort" then
		if not rec.escortTarget or not Alive(rec.escortTarget) then
			self:PopGoal(rec.model)
		end
	elseif rec.goal.current == "HuntEnemy" then
		if #rec.memory.KnownEnemies == 0 then rec.state = S.PATROL end
	end
end

local BT = {}
BT.__index = BT
function BT.Selector(children)      return { type="Selector",  children=children } end
function BT.Sequence(children)      return { type="Sequence",  children=children } end
function BT.Condition(fn)           return { type="Condition", fn=fn }             end
function BT.Action(fn)              return { type="Action",    fn=fn }             end
function BT.Inverter(child)         return { type="Inverter",  child=child }       end
function BT.Repeater(child, n)      return { type="Repeater",  child=child, times=n or -1, count=0 } end
function BT.Wait(seconds)           return { type="Wait",      duration=seconds, elapsed=0 }          end
function BT.Cooldown(s, child)      return { type="Cooldown",  duration=s, child=child, next=0 }      end
function BT.Random(children, weights)
	return { type="Random", children=children, weights=weights }
end
AIFrame.BT = BT

function AIFrame:SetBehaviorTree(model, rootNode)
	local rec = self._registry[model]
	if not rec then return end
	rec.btree.root       = rootNode
	rec.btree.blackboard = {}
end

function AIFrame:_evalBTree(rec)
	if not rec.btree.root then return end
	rec.btree.lastResult = self:_evalNode(rec, rec.btree.root)
end

function AIFrame:_evalNode(rec, node)
	if not node then return false end

	if node.type == "Selector" then
		for _, child in ipairs(node.children) do
			if self:_evalNode(rec, child) then return true end
		end
		return false

	elseif node.type == "Sequence" then
		for _, child in ipairs(node.children) do
			if not self:_evalNode(rec, child) then return false end
		end
		return true

	elseif node.type == "Condition" then
		local ok, result = pcall(node.fn, rec, self)
		return ok and result == true

	elseif node.type == "Action" then
		local ok, result = pcall(node.fn, rec, self)
		return ok and result ~= false

	elseif node.type == "Inverter" then
		return not self:_evalNode(rec, node.child)

	elseif node.type == "Repeater" then
		if node.times > 0 and node.count >= node.times then
			node.count=0; return true
		end
		local r = self:_evalNode(rec, node.child)
		node.count += 1
		return r

	elseif node.type == "Wait" then
		node.elapsed = (node.elapsed or 0) + rec.cfg.DecisionRate
		if node.elapsed >= node.duration then
			node.elapsed=0; return true
		end
		return false

	elseif node.type == "Cooldown" then
		if now() < node.next then return false end
		local r = self:_evalNode(rec, node.child)
		if r then node.next = now() + node.duration end
		return r

	elseif node.type == "Random" then
		if node.weights then
			local total = 0
			for _, w in ipairs(node.weights) do total += w end
			local roll = rng() * total
			local acc  = 0
			for i, w in ipairs(node.weights) do
				acc += w
				if roll <= acc then return self:_evalNode(rec, node.children[i]) end
			end
		else
			return self:_evalNode(rec, node.children[rngi(1, #node.children)])
		end
		return false
	end

	return false
end

function AIFrame:RegisterModule(name, module)
	assert(type(name)   == "string", "[AIFrame] module name must be string")
	assert(type(module) == "table",  "[AIFrame] module must be table")
	self._modules[name] = module
	if module.Init then pcall(module.Init, self) end
end

function AIFrame:GetModule(name)
	return self._modules[name]
end

function AIFrame:_emitSound(rec, soundType)
	local soundId = rec.cfg.Sounds and rec.cfg.Sounds[soundType]
	if not soundId then return end
	local root = Root(rec.model)
	if not root then return end

	local snd = root:FindFirstChild("_AI_SND_"..soundType)
	if not snd then
		snd = Instance.new("Sound")
		snd.Name               = "_AI_SND_"..soundType
		snd.SoundId            = soundId
		snd.RollOffMaxDistance = 50
		snd.Parent             = root
	end
	if not snd.IsPlaying then snd:Play() end

	local hRange = rec.cfg.HearingRange
	for _, om in ipairs(self:_getNearbyModels(root.Position, hRange)) do
		if om == rec.model then continue end
		local other = self._registry[om]
		if not other or not other.alive then continue end
		local or2 = Root(om)
		if not or2 then continue end
		local dist = (or2.Position - root.Position).Magnitude
		if dist <= hRange then
			local vol = clamp(1 - dist/hRange, 0, 1)
			other.percep.lastHeardPos  = root.Position
			other.percep.lastHeardTime = now()
			if vol > 0.3 then
				self:_addThreatRaw(other, rec.model, vol*8, "sound_"..soundType)
			end
		end
	end
	fireList(self._callbacks.OnSoundEmitted, rec, soundType, root.Position)
end

function AIFrame:CreateSquad(commanderModel, memberModels, formation)
	local id  = guid()
	local cmd = self._registry[commanderModel]
	assert(cmd, "[AIFrame] commander must be registered")
	cmd.squad.squadId = id
	cmd.squad.role    = "Commander"

	local members = {}
	local roles   = { "Soldier","Scout","Support","Heavy","Flanker" }
	for i, m in ipairs(memberModels or {}) do
		local mr = self._registry[m]
		if mr then
			mr.squad.squadId  = id
			mr.squad.role     = roles[((i-1) % #roles) + 1]
			mr.squad.formSlot = i
			members[#members+1] = mr
		end
	end

	local sq = {
		id            = id,
		commander     = cmd,
		members       = members,
		formation     = formation or "Line",
		lastOrderTs   = 0,
		sharedThreat  = {},
		alive         = true,
		tacticalPhase = "Engage",
	}
	self._squads[id] = sq
	fireList(self._callbacks.OnSquadEvent, sq, "Created", nil)
	return id
end

function AIFrame:DisbandSquad(squadId)
	local sq = self._squads[squadId]
	if not sq then return end
	if sq.commander then sq.commander.squad.squadId=nil; sq.commander.squad.role="Soldier" end
	for _, mr in ipairs(sq.members) do
		mr.squad.squadId=nil; mr.squad.role="Soldier"; mr.squad.formSlot=0
	end
	self._squads[squadId] = nil
	fireList(self._callbacks.OnSquadEvent, sq, "Disbanded", nil)
end

function AIFrame:GetSquad(squadId) return self._squads[squadId] end

function AIFrame:_updateSquadCommanders(dt)
	for _, sq in pairs(self._squads) do
		self:_tickSquadCommander(sq, dt)
	end
end

function AIFrame:_tickSquadCommander(sq, dt)
	local cmd = sq.commander
	if not cmd or not cmd.alive then self:_electNewCommander(sq); return end
	if (now() - sq.lastOrderTs) < SQUAD_ORDER_INTERVAL then return end
	sq.lastOrderTs = now()

	local allMembers = { cmd }
	for _, mr in ipairs(sq.members) do if mr.alive then allMembers[#allMembers+1]=mr end end
	if #allMembers == 0 then return end

	local avgHP = 0
	for _, mr in ipairs(allMembers) do avgHP += HPRatio(mr.model) end
	avgHP = avgHP / #allMembers

	local threats       = self:GetTopThreats(cmd.model, 1)
	local primaryThreat = threats[1] and threats[1].source or nil

	self:_squadShareThreat(sq, allMembers)

	local order
	if avgHP < 0.25 then
		order = "Fallback"; sq.tacticalPhase = "Retreat"
	elseif #allMembers < 2 then
		order = "HoldLine"; sq.tacticalPhase = "Defend"
	elseif #allMembers >= 3 and primaryThreat then
		local hasFlanker = false
		for _, mr in ipairs(sq.members) do
			if mr.squad.role=="Flanker" and mr.alive then hasFlanker=true; break end
		end
		if hasFlanker then
			order="Flank"; sq.tacticalPhase="Flank"
		else
			order="Attack"; sq.tacticalPhase="Engage"
		end
	elseif avgHP > 0.7 and primaryThreat then
		order="Attack"; sq.tacticalPhase="Engage"
	else
		order = "HoldLine"
	end

	self:_executeSquadOrder(sq, order, primaryThreat)
end

function AIFrame:_squadShareThreat(sq, allMembers)
	local combined = {}
	for _, mr in ipairs(allMembers) do
		for src, t in pairs(mr.threat) do
			if typeof(src)=="Instance" and Alive(src) then
				combined[src] = (combined[src] or 0) + t.amount
			end
		end
	end
	for _, mr in ipairs(allMembers) do
		for src, amt in pairs(combined) do
			self:_addThreatRaw(mr, src, amt*0.12, "squad_share")
		end
	end
end

function AIFrame:_executeSquadOrder(sq, order, target)
	local allMembers = { sq.commander }
	for _, mr in ipairs(sq.members) do if mr.alive then allMembers[#allMembers+1]=mr end end

	if order == "Attack" and target then
		for _, mr in ipairs(allMembers) do
			self:_setTarget(mr, target)
			self:_setState(mr, S.CHASE, "squad_attack")
		end
		if sq.formation ~= "None" then
			self:FormationMove(sq.commander.model, sq.formation, allMembers)
		end

	elseif order == "Fallback" then
		for _, mr in ipairs(allMembers) do self:_setState(mr, S.FLEE, "squad_fallback") end

	elseif order == "Flank" and target then
		local tr   = Root(target)
		local cmdR = Root(sq.commander.model)
		if tr and cmdR then
			local toE  = (tr.Position - cmdR.Position).Unit
			local left  = Vector3.new(-toE.Z, 0, toE.X)
			local right = Vector3.new( toE.Z, 0, -toE.X)
			local fi = 0
			for _, mr in ipairs(allMembers) do
				if mr.squad.role == "Flanker" then
					self:_computePath(mr, tr.Position + (fi%2==0 and left or right)*14)
					self:_setTarget(mr, target); fi += 1
				else
					self:_setTarget(mr, target)
					self:_setState(mr, S.CHASE, "squad_engage")
				end
			end
		end

	elseif order == "HoldLine" then
		local cmdR = Root(sq.commander.model)
		if cmdR then
			for i, mr in ipairs(allMembers) do
				local a = (i/#allMembers)*math.pi*2
				self:_computePath(mr, cmdR.Position + Vector3.new(math.cos(a)*6, 0, math.sin(a)*6))
				self:_setState(mr, S.GUARD, "squad_hold")
			end
		end

	elseif order == "Regroup" then
		local cmdR = Root(sq.commander.model)
		if cmdR then
			for _, mr in ipairs(sq.members) do
				if mr.alive then
					self:_computePath(mr, cmdR.Position + Vector3.new(rngR(-4,4),0,rngR(-4,4)))
					self:_setState(mr, S.REGROUP, "squad_regroup")
				end
			end
		end

	elseif order == "Support" then
		local weakest, lowestHp = nil, math.huge
		for _, mr in ipairs(allMembers) do
			local hp = HPRatio(mr.model)
			if hp < lowestHp then lowestHp=hp; weakest=mr end
		end
		if weakest then
			local wr = Root(weakest.model)
			for _, mr in ipairs(allMembers) do
				if mr.squad.role=="Support" and mr~=weakest and wr then
					self:_computePath(mr, wr.Position)
				end
			end
		end
	end

	fireList(self._callbacks.OnSquadOrder, sq, order, target)
end

function AIFrame:_electNewCommander(sq)
	local best, bestLevel = nil, -1
	for _, mr in ipairs(sq.members) do
		if mr.alive and mr.cfg.Level > bestLevel then best=mr; bestLevel=mr.cfg.Level end
	end
	if best then
		sq.commander=best; best.squad.role="Commander"
		fireList(self._callbacks.OnSquadEvent, sq, "NewCommander", best)
	else
		sq.alive = false
		fireList(self._callbacks.OnSquadEvent, sq, "Wiped", nil)
	end
end

function AIFrame:_tickSquadOrders(rec, dt)
	if not rec.squad.squadId then return end
	local sq = self._squads[rec.squad.squadId]
	if not sq then return end
	rec.squad.pingTimer = (rec.squad.pingTimer or 0) + dt
	if rec.squad.pingTimer >= 3 then
		rec.squad.pingTimer = 0
		if rec.percep.closestModel then
			sq.sharedThreat[rec.percep.closestModel] =
				(sq.sharedThreat[rec.percep.closestModel] or 0) +
				math.max(1, 20 - (rec.percep.closestDist or 0)*0.25)
		end
	end
	if rec.state == S.REGROUP then
		local cmdR = sq.commander and Root(sq.commander.model)
		if cmdR and rec.movement.status=="arrived" then
			self:_setState(rec, S.IDLE, "regrouped")
		end
	end
end

function AIFrame:IssueSquadOrder(squadId, order, payload)
	local sq = self._squads[squadId]
	if sq then self:_executeSquadOrder(sq, order, payload) end
end

function AIFrame:FormationMove(leaderModel, formation, members)
	local rec  = self._registry[leaderModel]
	if not rec then return end
	local root = Root(leaderModel)
	if not root then return end

	if not members then
		local sq = rec.squad.squadId and self._squads[rec.squad.squadId]
		if not sq then return end
		members = { sq.commander }
		for _, mr in ipairs(sq.members) do if mr.alive then members[#members+1]=mr end end
	end

	local n = #members
	for i, mr in ipairs(members) do
		if mr.model == leaderModel then continue end
		local offset = Vector3.zero
		if formation == "Line" then
			offset = root.CFrame.RightVector * ((i-(n+1)*0.5)*4)
		elseif formation == "Wedge" then
			local s = i-(n+1)*0.5
			offset  = root.CFrame.RightVector*(s*3) + root.CFrame.LookVector*(-math.abs(s)*3-4)
		elseif formation == "Circle" then
			local a = (i/n)*math.pi*2
			offset  = Vector3.new(math.cos(a),0,math.sin(a))*7
		elseif formation == "Column" then
			offset = root.CFrame.LookVector*(i*-4.5)
		elseif formation == "Pincer" then
			local side = i%2==0 and 1 or -1
			offset = root.CFrame.RightVector*(side*8) + root.CFrame.LookVector*6
		elseif formation == "Diamond" then
			local angles = {0,math.pi/2,math.pi,3*math.pi/2}
			local a      = angles[((i-1)%4)+1]
			offset       = Vector3.new(math.cos(a),0,math.sin(a))*6
		end
		self:_computePath(mr, root.Position + offset)
	end
end

function AIFrame:CallForHelp(model, radius)
	local rec = self._registry[model]
	if not rec then return 0 end
	local root = Root(model)
	if not root then return 0 end
	local count = 0
	for _, m in ipairs(self:_getNearbyModels(root.Position, radius or 65)) do
		if m == model then continue end
		local ally = self._registry[m]
		if not ally or ally.cfg.Faction ~= rec.cfg.Faction then continue end
		if ally.state == S.IDLE or ally.state == S.PATROL then
			self:_setTarget(ally, rec.target)
			self:_addThreatRaw(ally, rec.target, 30, "help_called")
			self:_setState(ally, S.CHASE, "help_called")
			count += 1
		end
	end
	fireList(self._callbacks.OnSquadEvent, rec, "HelpCalled", count)
	return count
end

function AIFrame:Attack(model, target, damage, element, config)
	local rec = self._registry[model]
	if not rec or not rec.alive then return nil end
	local ce = rec.cfg.CombatEngine or self._ce
	if ce then
		local info = ce:Damage(model, target, damage or rec.cfg.BaseDamage,
			element or rec.cfg.ElementType, config or {IsBlockable=true})
		fireList(self._callbacks.OnAttack, rec, target, info and info.Final or 0, false)
		return info
	else
		local hum = Hum(target)
		local dmg = damage or rec.cfg.BaseDamage or 15
		if hum then hum:TakeDamage(dmg) end
		fireList(self._callbacks.OnAttack, rec, target, dmg, false)
	end
end

function AIFrame:Block(model, duration, absorb)
	local rec = self._registry[model]
	if not rec then return end
	local ce = rec.cfg.CombatEngine or self._ce
	if ce then ce:Block(model, duration, absorb) end
	rec.combat.blocking = true
	task.delay(duration or 0.8, function()
		if rec and rec.combat then rec.combat.blocking = false end
	end)
end

function AIFrame:Dodge(model)
	local rec  = self._registry[model]
	local root = Root(model)
	local hum  = Hum(model)
	if not rec or not root or not hum then return end
	local dirs = { root.CFrame.RightVector, -root.CFrame.RightVector, -root.CFrame.LookVector }
	local dir  = dirs[rngi(1, #dirs)]
	local ce   = rec.cfg.CombatEngine or self._ce
	if ce then
		ce:GiveIFrames(model, 0.38)
		ce:Launch(model, dir*24 + Vector3.new(0,5,0))
	else
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
		applyImpulse(root, dir*24 + Vector3.new(0,5,0), rec.cfg.Tenacity)
	end
	fireList(self._callbacks.OnDodge, rec, dir)
end

function AIFrame:Parry(model, attacker)
	local rec = self._registry[model]
	if not rec then return end
	local ce = rec.cfg.CombatEngine or self._ce
	if ce then
		ce:GiveIFrames(model, 0.55)
		if attacker and ce._registry and ce._registry[attacker] then
			ce:Stun(attacker, 1.8)
			ce:Knockback(model, attacker, 28, 12)
		end
	end
	fireList(self._callbacks.OnParry, rec, attacker)
end

function AIFrame:Stun(model, duration)
	self:ApplyStatus(model, "Stunned", nil, {duration=duration or 1.2})
end

function AIFrame:Knockback(model, from, force, angle, upForce)
	local root  = Root(model)
	local fRoot = from and Root(from)
	if not root then return end
	local dir = fRoot and (root.Position-fRoot.Position) or -root.CFrame.LookVector
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.001 then dir = Vector3.new(1,0,0) end
	dir = dir.Unit
	local rad  = math.rad(angle or 0)
	local fDir = (dir*math.cos(rad) + Vector3.new(0,1,0)*math.sin(rad)).Unit
	local vel  = fDir*(force or 20) + Vector3.new(0, upForce or 0, 0)
	local hum  = Hum(model)
	if hum then hum:ChangeState(Enum.HumanoidStateType.Freefall) end
	local rec  = self._registry[model]
	applyImpulse(root, vel, rec and rec.cfg.Tenacity or 0)
end

function AIFrame:Heal(model, amount)
	local rec = self._registry[model]
	local hum = Hum(model)
	if not rec or not hum then return end
	if rec.statusEffects.Cursed then amount = amount * 0.5 end
	hum.Health = math.min(hum.MaxHealth, hum.Health + amount)
end

function AIFrame:Revive(model, hpPct)
	local rec = self._registry[model]
	local hum = Hum(model)
	if not rec or not hum then return end
	rec.alive=true; rec.statusEffects={}; rec.threat={}; rec.target=nil
	hum.Health = hum.MaxHealth * clamp(hpPct or 1, 0.01, 1)
	self:_setState(rec, S.IDLE, "revived")
end

function AIFrame:MoveTo(model, position)
	local rec = self._registry[model]
	if rec then self:_computePath(rec, position) else
		local h = Hum(model); if h then h:MoveTo(position) end
	end
end

function AIFrame:Chase(model, target)
	local rec = self._registry[model]
	if not rec then return end
	self:_setTarget(rec, target)
	self:_setState(rec, S.CHASE, "api")
end

function AIFrame:Flee(model, fromTarget)
	local rec = self._registry[model]
	if not rec then return end
	if fromTarget then rec.target = fromTarget end
	self:_setState(rec, S.FLEE, "api")
end

function AIFrame:Patrol(model)
	local rec = self._registry[model]
	if rec then self:_setState(rec, S.PATROL, "api") end
end

function AIFrame:Guard(model, position)
	local rec = self._registry[model]
	if not rec then return end
	if position then rec.spawnPos=position; rec.territory.center=position end
	self:_setState(rec, S.GUARD, "api")
end

function AIFrame:Wander(model, radius)
	local rec  = self._registry[model]
	local root = Root(model)
	if not rec or not root then return end
	local r = radius or 22
	self:_computePath(rec, root.Position + Vector3.new(rngR(-r,r),0,rngR(-r,r)))
end

function AIFrame:Stop(model)
	local rec = self._registry[model]
	if not rec then return end
	local mov = rec.movement
	if mov._blockConn then mov._blockConn:Disconnect(); mov._blockConn=nil end
	mov.status="idle"; mov.path=nil
	local h = Hum(model); local r = Root(model)
	if h and r then h:MoveTo(r.Position) end
end

function AIFrame:Escort(model, targetModel)
	local rec = self._registry[model]
	if not rec then return end
	rec.escortTarget = targetModel
	self:SetGoal(model, "Escort", targetModel)
end

function AIFrame:Hunt(model, targetModel)
	local rec = self._registry[model]
	if not rec then return end
	if targetModel then self:_setTarget(rec, targetModel) end
	self:SetGoal(model, "HuntEnemy")
end

function AIFrame:AddModifier(model, name, overrides)
	local rec = self._registry[model]
	if not rec then return end
	local preset = deepCopy(MODIFIERS[name] or {})
	if overrides then mergeInto(preset, overrides) end
	rec.modifiers[name] = preset
	for k, v in pairs(preset) do
		if k == "_p" then for pk,pv in pairs(v) do rec.cfg.Personality[pk]=pv end
		elseif type(v) == "number" then rec.cfg[k]=v end
	end
end

function AIFrame:RemoveModifier(model, name)
	local rec = self._registry[model]
	if not rec or not rec.modifiers[name] then return end
	rec.modifiers[name] = nil
	local preset = PRESETS[rec.cfg.BehaviourPreset]
	if preset then
		if preset.Personality then
			for pk,pv in pairs(preset.Personality) do rec.cfg.Personality[pk]=pv end
		end
		for k,v in pairs(preset) do if k ~= "Personality" then rec.cfg[k]=v end end
	end
end

function AIFrame:HasModifier(model, name)
	local rec = self._registry[model]
	return rec ~= nil and rec.modifiers[name] ~= nil
end

function AIFrame:SetDayNight(factor)
	self._dayNight = clamp(factor, 0.1, 1.0)
end

function AIFrame:SetRayBudget(perFrame)
	self._rayBudget.perFrame = math.max(1, perFrame)
end

function AIFrame:EvaluateTarget(model, strategy)
	local rec = self._registry[model]
	if not rec then return end
	local visible = rec.percep.visible
	if #visible == 0 then return end
	strategy = strategy or "HighestThreat"
	local best = nil

	if strategy == "NearestFirst" then
		local bd = math.huge
		for _, e in ipairs(visible) do if e.dist < bd then bd=e.dist; best=e.model end end

	elseif strategy == "LowestHP" then
		local minH = math.huge
		for _, e in ipairs(visible) do
			local h = Hum(e.model); if h and h.Health < minH then minH=h.Health; best=e.model end
		end

	elseif strategy == "HighestThreat" then
		local maxT = -1
		for _, e in ipairs(visible) do
			local t = rec.threat[e.model] and rec.threat[e.model].amount or 0
			if t > maxT then maxT=t; best=e.model end
		end
		if not best then
			local bd = math.huge
			for _, e in ipairs(visible) do if e.dist < bd then bd=e.dist; best=e.model end end
		end

	elseif strategy == "MostDangerous" then
		local maxS = -1
		for _, e in ipairs(visible) do
			local t   = rec.threat[e.model] and rec.threat[e.model].amount or 1
			local h   = Hum(e.model)
			local hpr = (h and h.MaxHealth>0) and (h.Health/h.MaxHealth) or 1
			local s   = t*(1+hpr)+rng()*0.1
			if s > maxS then maxS=s; best=e.model end
		end

	elseif strategy == "LowestDefense" then
		local ce   = self._ce
		local minD = math.huge
		for _, e in ipairs(visible) do
			local armor = (ce and ce._registry and ce._registry[e.model] and
				ce._resolveStatValue and ce:_resolveStatValue(e.model,"Armor")) or 0
			if armor < minD then minD=armor; best=e.model end
		end

	elseif strategy == "WeakestStatus" then
		local maxS = -1
		for _, e in ipairs(visible) do
			local other = self._registry[e.model]
			local count = 0
			if other then for _ in pairs(other.statusEffects) do count+=1 end end
			if count > maxS then maxS=count; best=e.model end
		end
	end

	if best then self:_setTarget(rec, best) end
end

function AIFrame:GetTargetRecord(model, target)
	local rec = self._registry[model]
	if not rec then return 0,0 end
	for _, e in ipairs(rec.learning.targetHist) do
		if e.model == target then return e.w, e.l end
	end
	return 0, 0
end

function AIFrame:_learningOnKill(rec, target)
	rec.learning.wins        += 1
	rec.learning.combatCount += 1
	rec.cfg.Personality.Aggression = math.min(1, rec.cfg.Personality.Aggression + 0.012)
	rec.cfg.Personality.Courage    = math.min(1, rec.cfg.Personality.Courage    + 0.008)
	rec.emotion.Rage   = math.max(0, rec.emotion.Rage   - 0.2)
	rec.emotion.Morale = math.min(1, rec.emotion.Morale + 0.15)
	local l = rec.learning.targetHist
	for _, e in ipairs(l) do
		if e.model == target then e.w+=1; return end
	end
	table.insert(l, 1, {model=target, w=1, l=0})
	while #l > 14 do table.remove(l) end
end

function AIFrame:_onDeath(rec)
	if not rec.alive then return end
	rec.alive=false; rec.target=nil

	local root = Root(rec.model)
	if root then
		self:AddDangerZone(rec.model, root.Position, 14, 3)
		rec.learning.losses      += 1
		rec.learning.combatCount += 1
		rec.cfg.Personality.Aggression = math.max(0, rec.cfg.Personality.Aggression - 0.025)
		rec.cfg.Personality.Courage    = math.max(0, rec.cfg.Personality.Courage    - 0.020)
		self:BroadcastWorldEvent("AllyDeath", root.Position, 80, rec.model)
	end

	if rec.movement._blockConn then
		rec.movement._blockConn:Disconnect(); rec.movement._blockConn=nil
	end

	self._rayPool[rec.model] = nil

	if rec._gridKey then
		local cell = self._spatialGrid[rec._gridKey]
		if cell then
			for i=#cell,1,-1 do if cell[i]==rec.model then table.remove(cell,i); break end end
		end
	end

	self:_emitSound(rec, "Death")
	self:_setState(rec, S.DEAD, "died")
	fireList(self._callbacks.OnNPCDied, rec)
	task.delay(2.5, function() self:UnregisterNPC(rec.model) end)
end

function AIFrame:Serialize(model)
	local rec = self._registry[model]
	if not rec then return nil end
	local function v3(v) return v and {v.X,v.Y,v.Z} end
	local mods, statuses = {}, {}
	for name in pairs(rec.modifiers)     do mods[#mods+1]=name end
	for name, e in pairs(rec.statusEffects) do
		statuses[#statuses+1]={name=name,remaining=e.remaining,stacks=e.stacks}
	end
	return {
		state       = rec.state,
		spawnPos    = v3(rec.spawnPos),
		territory   = {center=v3(rec.territory.center),radius=rec.territory.radius},
		memory      = {LastEnemyPos=v3(rec.memory.LastEnemyPos),LastEnemyTime=rec.memory.LastEnemyTime},
		learning    = {wins=rec.learning.wins,losses=rec.learning.losses,combatCount=rec.learning.combatCount},
		emotion     = deepCopy(rec.emotion),
		personality = deepCopy(rec.cfg.Personality),
		shield      = {current=rec.shield.current,max=rec.shield.max},
		mana        = rec.ability.mana,
		stateAge    = rec.stateAge,
		modifiers   = mods,
		statuses    = statuses,
		goal        = rec.goal.current,
		custom      = deepCopy(rec.custom),
		replay      = deepCopy(rec.memory.ReplayLog),
	}
end

function AIFrame:Deserialize(model, data)
	local rec = self._registry[model]
	if not rec or not data then return end
	local function v3(t) return t and Vector3.new(t[1],t[2],t[3]) end
	rec.state    = data.state    or S.IDLE
	rec.stateAge = data.stateAge or 0
	rec.spawnPos = v3(data.spawnPos) or rec.spawnPos
	if data.territory then
		rec.territory.center = v3(data.territory.center) or rec.territory.center
		rec.territory.radius = data.territory.radius or rec.territory.radius
	end
	if data.memory then
		rec.memory.LastEnemyPos  = v3(data.memory.LastEnemyPos)
		rec.memory.LastEnemyTime = data.memory.LastEnemyTime or 0
	end
	if data.learning then
		rec.learning.wins        = data.learning.wins        or 0
		rec.learning.losses      = data.learning.losses      or 0
		rec.learning.combatCount = data.learning.combatCount or 0
	end
	if data.emotion     then mergeInto(rec.emotion, data.emotion) end
	if data.personality then for k,v in pairs(data.personality) do rec.cfg.Personality[k]=v end end
	if data.shield then rec.shield.current=data.shield.current or 0; rec.shield.max=data.shield.max or 0 end
	if data.mana   then rec.ability.mana=data.mana end
	if data.custom then rec.custom=deepCopy(data.custom) end
	if data.modifiers then for _,name in ipairs(data.modifiers) do self:AddModifier(model,name) end end
	if data.statuses  then for _,s in ipairs(data.statuses) do self:ApplyStatus(model,s.name,nil,{duration=s.remaining}) end end
	if data.goal      then self:SetGoal(model, data.goal) end
	if data.replay    then rec.memory.ReplayLog=deepCopy(data.replay) end
end

function AIFrame:GetReplayLog(model)
	local rec = self._registry[model]
	return rec and deepCopy(rec.memory.ReplayLog) or {}
end

function AIFrame:ExportReplay(model)
	local log = self:GetReplayLog(model)
	if #log == 0 then return "-- empty" end
	local lines = { ("-- AIFrame Replay: %s"):format(model.Name) }
	for _, e in ipairs(log) do
		lines[#lines+1] = ("t=%.3f  %-14s -> %-14s  [%s]"):format(e.t, e.from, e.to, e.reason)
	end
	return table.concat(lines, "\n")
end

local STATE_COLOR = {
	[S.IDLE]    = Color3.fromRGB(155,155,155), [S.PATROL]  = Color3.fromRGB(70,200,70),
	[S.ALERT]   = Color3.fromRGB(255,210,0),   [S.CHASE]   = Color3.fromRGB(255,135,0),
	[S.COMBAT]  = Color3.fromRGB(255,40,40),   [S.FLEE]    = Color3.fromRGB(200,0,255),
	[S.SEARCH]  = Color3.fromRGB(0,185,255),   [S.GUARD]   = Color3.fromRGB(0,95,255),
	[S.STUNNED] = Color3.fromRGB(255,0,200),   [S.DEAD]    = Color3.fromRGB(65,65,65),
	[S.CHANNEL] = Color3.fromRGB(255,230,100), [S.REGROUP] = Color3.fromRGB(100,255,200),
	[S.AMBUSH]  = Color3.fromRGB(120,0,255),   [S.ESCORT]  = Color3.fromRGB(0,255,180),
	[S.HUNT]    = Color3.fromRGB(255,80,0),
}

local function barStr(v, mx, len)
	len = len or 8
	local f = math.floor(clamp(v/math.max(mx,0.001),0,1)*len)
	return string.rep("█",f)..string.rep("░",len-f)
end

local function ensureLabel(model)
	local bb = model:FindFirstChild("_AI_DBG")
	if bb then return bb:FindFirstChild("L") end
	bb = Instance.new("BillboardGui")
	bb.Name="_ AI_DBG"; bb.AlwaysOnTop=true
	bb.Size=UDim2.new(0,240,0,98); bb.StudsOffset=Vector3.new(0,4.8,0)
	bb.LightInfluence=0; bb.Parent=model
	local lbl = Instance.new("TextLabel")
	lbl.Name="L"; lbl.BackgroundColor3=Color3.fromRGB(4,4,8)
	lbl.BackgroundTransparency=0.25; lbl.TextColor3=Color3.new(1,1,1)
	lbl.TextSize=9; lbl.Font=Enum.Font.Code
	lbl.Size=UDim2.new(1,0,1,0); lbl.TextWrapped=true
	lbl.RichText=true; lbl.Parent=bb
	return lbl
end

function AIFrame:_updateDebugLabel(rec)
	local lbl = ensureLabel(rec.model)
	if not lbl then return end
	local hum  = Hum(rec.model)
	local hp   = hum and hum.Health    or 0
	local maxH = hum and hum.MaxHealth or 100
	local col  = STATE_COLOR[rec.state] or Color3.new(1,1,1)
	local r    = math.floor(col.R*255)
	local g    = math.floor(col.G*255)
	local b_   = math.floor(col.B*255)

	local statuses = {}
	for k in pairs(rec.statusEffects) do statuses[#statuses+1]=k:sub(1,3) end
	local mods = {}
	for k in pairs(rec.modifiers)     do mods[#mods+1]=k:sub(1,3) end

	local topT = self:GetTopThreats(rec.model, 2)
	local tStr = ""
	for _, t in ipairs(topT) do
		tStr = tStr..(" %s=%.0f"):format(
			typeof(t.source)=="Instance" and t.source.Name:sub(1,5) or "?", t.amount)
	end

	local em = rec.emotion
	local emStr = ("F%.0f%%R%.0f%%St%.0f%%Mo%.0f%%"):format(
		em.Fear*100, em.Rage*100, em.Stress*100, em.Morale*100)

	local goalStr  = rec.goal.current and (" G:"..rec.goal.current:sub(1,4)) or ""
	local squadStr = rec.squad.squadId and (" ["..rec.squad.role:sub(1,4).."]") or ""
	local covStr   = rec.tactical.coverPos and " ◆" or ""
	local lodStr   = ("B%d|LOD%d"):format(rec.bucket, rec.lod)

	lbl.Text = ("<font color=\"rgb(%d,%d,%d)\">[%s]%s L%d%s%s%s</font>\nHP %s %.0f%%  MP %s\n%s|%s|%s\n%s%s\nT→%s%s"):format(
		r,g,b_,
		rec.cfg.Type, rec.state, rec.cfg.Level, squadStr, goalStr, covStr,
		barStr(hp,maxH,8), (hp/math.max(maxH,1))*100,
		barStr(rec.ability.mana, rec.cfg.MaxMana, 5),
		rec.movement.status, rec.tactical.mode, lodStr,
		emStr,
		(#statuses>0 and " ["..table.concat(statuses,",").."]" or "")
			..(#mods>0 and " {"..table.concat(mods,",").."}" or ""),
		rec.target and rec.target.Name or "nil", tStr)
end

function AIFrame:EnableDebug()  self._debug = true  end
function AIFrame:DisableDebug()
	self._debug = false
	for _, m in ipairs(self._list) do
		local bb = m:FindFirstChild("_AI_DBG")
		if bb then bb:Destroy() end
	end
end

function AIFrame:DrawVisionCone(model, dur)
	local rec  = self._registry[model]
	local root = Root(model)
	if not rec or not root then return end
	local pos   = root.Position + Vector3.new(0,1.6,0)
	local cf    = root.CFrame
	local range = rec.cfg.VisionRange * self._dayNight
	local halfA = math.rad(rec.cfg.VisionAngle*0.5)
	dur = dur or 0.06
	for i = 0, 16 do
		local t   = (i/16)*2-1
		local dir = CFrame.fromEulerAnglesYXZ(0,t*halfA,0)*cf.LookVector
		local p   = Instance.new("Part")
		p.Anchored=true; p.CanCollide=false; p.CanQuery=false
		p.Transparency=0.80; p.Color=Color3.fromRGB(255,230,0)
		p.Size=Vector3.new(0.06,0.06,range)
		p.CFrame=CFrame.lookAt(pos+dir*range*0.5, pos+dir*range)
		p.Parent=workspace; Debris:AddItem(p, dur)
	end
end

function AIFrame:DrawThreatLines(model, dur)
	local rec  = self._registry[model]
	local root = Root(model)
	if not rec or not root then return end
	dur = dur or 0.10
	for src, t in pairs(rec.threat) do
		if typeof(src) ~= "Instance" then continue end
		local sr = Root(src); if not sr then continue end
		local from = root.Position + Vector3.new(0,2,0)
		local to   = sr.Position   + Vector3.new(0,2,0)
		local mid  = (from+to)*0.5
		local len  = (to-from).Magnitude
		local intensity = clamp(t.amount/100,0,1)
		local p = Instance.new("Part")
		p.Anchored=true; p.CanCollide=false; p.CanQuery=false
		p.Color=Color3.fromRGB(math.floor(intensity*255),math.floor((1-intensity)*200),0)
		p.Transparency=0.55
		p.Size=Vector3.new(0.12,0.12,len)
		p.CFrame=CFrame.lookAt(mid,to)*CFrame.new(0,0,-len/2)
		p.Parent=workspace; Debris:AddItem(p, dur)
	end
end

function AIFrame:DrawCoverPoint(model, dur)
	local rec = self._registry[model]
	if not rec or not rec.tactical.coverPos then return end
	local p = Instance.new("Part")
	p.Anchored=true; p.CanCollide=false; p.CanQuery=false
	p.Transparency=0.50; p.Color=Color3.fromRGB(0,120,255)
	p.Shape=Enum.PartType.Ball; p.Size=Vector3.new(1.5,1.5,1.5)
	p.Position=rec.tactical.coverPos+Vector3.new(0,1,0)
	p.Parent=workspace; Debris:AddItem(p, dur or 0.5)
end

function AIFrame:DrawSquadLinks(squadId, dur)
	local sq = self._squads[squadId]
	if not sq then return end
	local cmdRoot = sq.commander and Root(sq.commander.model)
	if not cmdRoot then return end
	dur = dur or 0.12
	for _, mr in ipairs(sq.members) do
		if not mr.alive then continue end
		local mr2 = Root(mr.model); if not mr2 then continue end
		local from = cmdRoot.Position+Vector3.new(0,3,0)
		local to   = mr2.Position+Vector3.new(0,3,0)
		local mid  = (from+to)*0.5
		local len  = (to-from).Magnitude
		local p = Instance.new("Part")
		p.Anchored=true; p.CanCollide=false; p.CanQuery=false
		p.Color=Color3.fromRGB(0,220,255); p.Transparency=0.55
		p.Size=Vector3.new(0.10,0.10,len)
		p.CFrame=CFrame.lookAt(mid,to)*CFrame.new(0,0,-len/2)
		p.Parent=workspace; Debris:AddItem(p, dur)
	end
end

function AIFrame:DrawPrediction(model, dur)
	local rec = self._registry[model]
	if not rec or not rec.prediction.predictedPos then return end
	local p = Instance.new("Part")
	p.Anchored=true; p.CanCollide=false; p.CanQuery=false
	p.Transparency=0.45; p.Color=Color3.fromRGB(255,255,0)
	p.Shape=Enum.PartType.Ball; p.Size=Vector3.new(1,1,1)
	p.Position=rec.prediction.predictedPos+Vector3.new(0,1,0)
	p.Parent=workspace; Debris:AddItem(p, dur or 0.3)
end

function AIFrame:DrawEmotionBars(model, dur)
	local rec  = self._registry[model]
	local root = Root(model)
	if not rec or not root then return end
	dur = dur or 0.2
	local base = root.Position + Vector3.new(0,5,0)
	local em   = rec.emotion
	local bars = {
		{val=em.Fear,   color=Color3.fromRGB(200,0,255)},
		{val=em.Rage,   color=Color3.fromRGB(255,40,0) },
		{val=em.Stress, color=Color3.fromRGB(255,200,0)},
		{val=em.Morale, color=Color3.fromRGB(0,200,80) },
	}
	for i, bar in ipairs(bars) do
		local len = bar.val * 4
		if len < 0.05 then continue end
		local p = Instance.new("Part")
		p.Anchored=true; p.CanCollide=false; p.CanQuery=false
		p.Transparency=0.30; p.Color=bar.color
		p.Size=Vector3.new(0.8,len,0.2)
		p.Position=base+Vector3.new((i-2.5)*1.2,len*0.5,0)
		p.Parent=workspace; Debris:AddItem(p, dur)
	end
end

function AIFrame:DrawSpatialGrid(center, radius, dur)
	local g     = self._gridSize
	local cells = math.ceil(radius/g)
	local cx    = math.floor(center.X/g)
	local cz    = math.floor(center.Z/g)
	dur = dur or 0.5
	for dx = -cells, cells do
		for dz = -cells, cells do
			local key   = (cx+dx).."|"..(cz+dz)
			local cell  = self._spatialGrid[key]
			local count = cell and #cell or 0
			if count > 0 then
				local wp = Vector3.new((cx+dx)*g+g/2, center.Y+0.5, (cz+dz)*g+g/2)
				local p  = Instance.new("Part")
				p.Anchored=true; p.CanCollide=false; p.CanQuery=false
				p.Transparency=0.60
				p.Color=Color3.fromRGB(0,math.min(255,count*60),180)
				p.Size=Vector3.new(g*0.95,0.3,g*0.95)
				p.Position=wp; p.Parent=workspace
				Debris:AddItem(p, dur)
			end
		end
	end
end

function AIFrame:DrawSchedulerBuckets()
	local sch = self._scheduler
	for i = 1, sch.bucketCount do
		local n = #sch.buckets[i]
		print(("Bucket %d: %d NPCs%s"):format(i, n, i==sch.currentBucket and " ← active" or ""))
	end
end

function AIFrame:PrintDebug(model)
	local rec = self._registry[model]
	if not rec then print("[AIFrame] NPC not found"); return end
	local hum  = Hum(model)
	local hp   = hum and hum.Health or 0
	local maxH = hum and hum.MaxHealth or 0
	local mods, statuses = {}, {}
	for k in pairs(rec.modifiers)     do mods[#mods+1]=k end
	for k in pairs(rec.statusEffects) do statuses[#statuses+1]=k end
	local topT = self:GetTopThreats(model, 3)
	local em   = rec.emotion
	local function threatCount() local n=0; for _ in pairs(rec.threat) do n+=1 end; return n end
	print(("┌─ AIFrame v6: %s [%s] ───────────────"):format(model.Name, rec.id:sub(1,8)))
	print(("│ State:       %s → %s  (%.2fs)"):format(rec.prevState or "nil", rec.state, rec.stateAge))
	print(("│ Bucket:      %d / %d"):format(rec.bucket, self._scheduler.bucketCount))
	print(("│ Target:      %s"):format(rec.target and rec.target.Name or "nil"))
	print(("│ HP/Shield:   %.0f/%.0f (%.0f%%)  SH:%.0f/%.0f"):format(
		hp,maxH,(hp/math.max(maxH,1))*100,rec.shield.current,rec.shield.max))
	print(("│ Mana:        %.0f/%.0f  LOD:%d  Alive:%s"):format(
		rec.ability.mana,rec.cfg.MaxMana,rec.lod,tostring(rec.alive)))
	print(("│ Percep:      %d vis  %d aud  alert=%d  RayBudget:%d/%d"):format(
		#rec.percep.visible,#rec.percep.audible,rec.percep.alertLevel,
		self._rayBudget.used, self._rayBudget.perFrame))
	print(("│ Memory:      enemy=%s  pos=%s  (%.0fs ago)"):format(
		rec.memory.LastEnemy and rec.memory.LastEnemy.Name or "nil",
		tostring(rec.memory.LastEnemyPos),
		rec.memory.LastEnemyTime>0 and (now()-rec.memory.LastEnemyTime) or 0))
	print(("│ Threat (%d):"):format(threatCount()))
	for i, t in ipairs(topT) do
		local age = rec.threat[t.source] and (now()-rec.threat[t.source].lastHit) or 0
		print(("│   #%d  %-12s  %.1f  locked:%s  age:%.0fs"):format(
			i,typeof(t.source)=="Instance" and t.source.Name or "?",
			t.amount,tostring(t.locked),age))
	end
	print(("│ Path:        %s  wp:%d/%d"):format(rec.movement.status,rec.movement.wpIdx,#rec.movement.waypoints))
	print(("│ Tactical:    %s  cover=%s(%.1f)  hitRun:%s"):format(
		rec.tactical.mode,rec.tactical.coverPos and "YES" or "NO",
		rec.tactical.coverScore, rec.tactical.hitRunPhase))
	print(("│ Prediction:  acc=%.0f%%  pos=%s"):format(
		rec.prediction.accuracy*100,tostring(rec.prediction.predictedPos)))
	print(("│ Emotion:     Fear=%.2f Rage=%.2f Stress=%.2f Morale=%.2f"):format(
		em.Fear,em.Rage,em.Stress,em.Morale))
	print(("│ Combat:      dealt=%.0f  taken=%.0f  H:%d/%d"):format(
		rec.combat.dmgDealt,rec.combat.dmgTaken,rec.combat.hitsDealt,rec.combat.hitsTaken))
	print(("│ Squad:       %s  role=%s"):format(
		rec.squad.squadId and rec.squad.squadId:sub(1,8) or "nil",rec.squad.role))
	print(("│ Goal:        %s"):format(rec.goal.current or "nil"))
	print(("│ BTree:       %s  last=%s"):format(
		rec.btree.root and "active" or "none",tostring(rec.btree.lastResult)))
	print(("│ Style:       %s"):format(rec.cfg.CombatStyle))
	print(("│ Personality: Agg=%.2f Cou=%.2f Int=%.2f Pat=%.2f Loy=%.2f"):format(
		rec.cfg.Personality.Aggression,rec.cfg.Personality.Courage,
		rec.cfg.Personality.Intelligence,rec.cfg.Personality.Patience,rec.cfg.Personality.Loyalty))
	print(("│ Learning:    W:%d L:%d combats:%d"):format(
		rec.learning.wins,rec.learning.losses,rec.learning.combatCount))
	print(("│ Modifiers:   [%s]"):format(table.concat(mods,", ")))
	print(("│ Statuses:    [%s]"):format(table.concat(statuses,", ")))
	print("└──────────────────────────────────────────")
end

function AIFrame:GetProfile()
	local p = self._prof
	return {
		npcCount              = p.npc,
		fps                   = p.fps,
		avgFrameMs            = math.floor(p.avgMs  * 1000) / 1000,
		peakFrameMs           = math.floor(p.peakMs * 1000) / 1000,
		perceptionCalls       = p.perceptionCalls,
		pathfindCalls         = p.pathfindCalls,
		decisionCalls         = p.decisionCalls,
		raycastsThisFrame     = p.raycastsThisFrame,
		raycastsTotal         = p.raycastsTotal,
		pathCacheHits         = p.pathCacheHits,
		pathCacheSize         = self._pathCacheN,
		spatialQueries        = p.spatialQueries,
		schedulerBuckets      = self._scheduler.bucketCount,
		activeBucketThisFrame = self._scheduler.currentBucket,
	}
end

function AIFrame:ResetProfile()
	local p = self._prof
	p.peakMs=0; p.avgMs=0; p._acc=0; p._n=0
	p.perceptionCalls=0; p.pathfindCalls=0; p.decisionCalls=0
	p.raycastsThisFrame=0; p.raycastsTotal=0
	p.pathCacheHits=0; p.spatialQueries=0
end

function AIFrame:On(event, cb)
	assert(self._callbacks[event], ("[AIFrame] unknown event '%s'"):format(tostring(event)))
	local list = self._callbacks[event]
	list[#list+1] = cb
	return function()
		for i, fn in ipairs(list) do
			if fn == cb then table.remove(list,i); break end
		end
	end
end

function AIFrame:Pause()  self._paused = true  end
function AIFrame:Resume() self._paused = false end

function AIFrame:Destroy()
	if self._conn then self._conn:Disconnect(); self._conn = nil end
	local models = {}
	for _, m in ipairs(self._list) do models[#models+1] = m end
	for _, m in ipairs(models) do self:UnregisterNPC(m) end
	self._registry    = {}
	self._list        = {}
	self._squads      = {}
	self._callbacks   = {}
	self._pathCache   = {}
	self._spatialGrid = {}
	self._rayPool     = {}
	self._modules     = {}
	self._worldEvents = {}
	setmetatable(self, nil)
end

AIFrame.States        = S
AIFrame.LOD           = LOD
AIFrame.Presets       = PRESETS
AIFrame.Modifiers     = MODIFIERS
AIFrame.StatusDefs    = STATUS_DEFS
AIFrame.CombatStyles  = COMBAT_STYLES
AIFrame.GoalDefs      = GOAL_DEFS
AIFrame.DefaultConfig = DEFAULT_CFG

return AIFrame
