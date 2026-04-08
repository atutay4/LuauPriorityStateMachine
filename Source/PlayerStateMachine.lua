--object file for a state holder

--this is a wrapper of a priority queue, where changes in the top state instead run functions

--use for storing player inputs, queuing up actions, and cancelling to unique states
--the state with the highest priority is the one that is run, once that priority changes, the new state is run
--keep an idle state at the bottom of the queue

local PriorityQueue = require(script:WaitForChild("PriorityQueue"))
local RunService = game:GetService("RunService")
local MAX_ID = 10000


--prototype for a state holder
local m = {
	m_stateFolder = nil; --contains state values which are updated
	m_stateChangedEvent = nil;
	
	--the priority queue uses statePriority as a key, and stateName as a value, allowing it to be indexed by strings
	m_priorityQueue = {};
	--a table of stateName : state objects (functions)
	m_stateFunctions = {};
	
	m_topStateName = nil; --STRING
	m_runningCoroutine = nil;
	m_complete = false;
	m_transitionID = 0;
}
m.__index = m

export type StateMachine = {
	m_stateFolder : Folder;
	m_stateChangedEvent : BindableEvent;
	
	--the priority queue uses statePriority as a key, and stateName as a value, allowing it to be indexed by strings
	m_priorityQueue : PriorityQueue;
	--a table of stateName : state objects (functions)
	m_stateFunctions : {[string] : State};
	
	m_topStateName : string;
	m_runningCoroutine : () -> ();
	m_complete : bool;
	m_transitionID : number;
}


--prototype for individual states, passed into addState
--only addState takes in a state, every other function takes in the stateName
m.START_START_TRANSFER_ENUM = {
	END_STATE = 1;
	MOVE_STATE = 2;
}

export type State = {
	stateName 		: string;
	statePriority 	: number;
	stateVariant 	: string?;

	--THIS FUNCTION CAN WAIT, BUT USE self:wait(time)
	stateStartFunc 	: () -> (boolean?, State?); 		--THIS FUNCTION IS CONVERTED INTO A COROUTINE TO RUN
		--this can return flags which let you easily transfer between states
		--END_STATE: ends the current state after ending
		--TRANSFER_STATE: ends the current state, then immediately starts the state given
	
	--functions MUST BE INSTANT, NO WAITS
	--IF THEY MUST WAIT, then CHAIN ANOTHER STATE into it
	stateEndFunc 	: () -> ()?;    	--function that runs after startFunc ends and the state ends
	stateCancelFunc : () -> ()?; 	--optional for if the state is cancelled before the stateStartFunc finishes, like a reload cancel
									--if stateCancelFunc doesn't exist, stateEndFunc will run during a cancel
}



--here's an example state:
--[[
	aiming = {
		stateName = "Aiming";
		stateVariant = "Default";
		statePriority = 10;
		
		stateStartFunc = function()
			animations.AimStance:Play()
			Camera.startAiming()
			Stats.addEffect("Aiming")
			Crosshair.setCrosshair("Empty")
			
			stateHandler:wait(0.4)
			
			aiming.complete = true
			aiming.completedSignal:Fire()
		end,
		stateEndFunc = function()
			animations.AimStance:Stop()
			Camera.stopAiming()
			Stats.removeEffect("Aiming")
		end
	}
	stateHandler:addState(aiming)
]]--


--[[
	INTERFACE FUNCTIONS
]]--


--returns an empty state holder
function m.new(stateFolder : Folder?)
	local self = setmetatable({}, m)
	
	self.m_stateFolder = stateFolder
	self.m_stateChangedEvent = Instance.new("BindableEvent")
	
	self.m_priorityQueue = PriorityQueue.new("max")
	self.m_stateFunctions = {}
	
	self.m_topStateName = nil
	self.m_runningCoroutine = nil
	self.m_complete = false
	self.m_transitionID = 0
	return self
end

--add to queue, if the queue already exists this will silent exit
function m:addState(state : State)
	if not self.m_priorityQueue:contains(state.stateName) then
		self.m_priorityQueue:enqueue(state.stateName, state.statePriority)
		self.m_stateFunctions[state.stateName] = state
		self:checkTopStateChange()
	end
	
end

--removes from queue, returns if the state was found and removed
function m:removeState(stateName : string) : boolean
	local wasRemoved
	if stateName == self.m_priorityQueue:peek() then
		wasRemoved = self.m_priorityQueue:dequeue() --this should be more optimized
	else
		wasRemoved = self.m_priorityQueue:remove(stateName)
	end
	--self.m_stateFunctions[stateName] = nil
	
	self:checkTopStateChange()
	return wasRemoved
	
end

--is this state the top state?
function m:hasActiveState(... : string) : boolean
	if not self then return end
	local states = {...}
	local top = self.m_priorityQueue:peek()
	if not top then return false end
	for _, stateName in pairs(states) do
		if top == stateName then return true end
	end
	return false
end

--is this state inside the queue?, return the active state if so
function m:hasState(stateName : string) : State?
	if self.m_priorityQueue:contains(stateName) then
		return self.m_stateFunctions[stateName]
	else
		return nil
	end
	
end

--returns the top state
function m:getTopState() : State?
	local top = self.m_priorityQueue:peek()
	if top then return self.m_stateFunctions[top] end
end

--empty state list
function m:clear(dontRunTop : boolean)
	--print(self.m_priorityQueue)
	--end the top state without starting new ones
	if not dontRunTop then
		local oldStateName = self.m_topStateName
		if oldStateName then
			local oldState = self.m_stateFunctions[oldStateName]
			if oldState then

				if self.m_complete == false and oldState.stateCancelFunc then
					oldState.stateCancelFunc()
				elseif oldState.stateEndFunc then
					oldState.stateEndFunc()
				end

			end
		end
	end
	
	--garbage collect the old priority queue and function table and make a new one
	self.m_priorityQueue = PriorityQueue.new("max")
	self.m_stateFunctions = {}
	
	--reset other variables
	self.m_topStateName = nil
	self.m_runningCoroutine = nil
	self.m_complete = false
	self.m_transitionID = 0
end

--remove all states of a defined variant
function m:removeVariant(variantName : string)
	--iterate backwards through the queue, call remove if the variant matches
	for i = #self.m_priorityQueue, 1, -1 do
		local stateName = self.m_priorityQueue[i]
		local state = self.m_stateFunctions[stateName]
		local stateVariant = state.stateVariant
		
		if stateVariant == variantName then
			self.m_priorityQueue:remove(stateName)
		end
		
	end
	
	self:checkTopStateChange()
	
end

--this is only called inside the stateStartFunc of a state
--[[
function m:wait(waitingTime : number)
	assert(typeof(self) == "table", "self is not a table")
	assert(typeof(waitingTime) == "number", "waitingTime is not a number")
	--yield the coroutine, then send a signal back to self to resume or close it after the given time
	--the coroutine is assumed to be the top state
	
	--track state changes by using m_transitionID
	local currentID = self.m_transitionID
	--print(self.m_transitionID)
	
	task.delay(waitingTime, function()
		--print(self.m_transitionID)
		if currentID == self.m_transitionID then
			--print(self.m_runningCoroutine)
			--if not self.m_runningCoroutine then return end
			self:resumeCorout()
			
		else
			error()
		end
	end)
	
	coroutine.yield()
	
end
]]--

function m:wait(waitingTime : number)
	assert(typeof(self) == "table", "self is not a table")
	assert(typeof(waitingTime) == "number", "waitingTime is not a number")
	--yield the coroutine, then send a signal back to self to resume or close it after the given time
	--the coroutine is assumed to be the top state

	--track state changes by using m_transitionID
	local currentID = self.m_transitionID
	local currentState = self.m_topStateName
	task.wait(waitingTime)
	
	return currentID ~= self.m_transitionID or currentState ~= self.m_topStateName
end



--[[
	IMPLEMENTATION FUNCTIONS (you shouldn't need to run these)
]]--

--this should trigger after any possible change to the top state
function m:checkTopStateChange()
	
	--did a top state change occur?
	--print(self.m_priorityQueue)
	local oldStateName = self.m_topStateName
	local topStateName = self.m_priorityQueue:peek()
	if oldStateName == topStateName then return end
	
	--run the ending functions of the old state
	--these should be instant
	
	--if it was running a coroutine, the coroutine will halt on it's own
	if oldStateName then
		local oldState = self.m_stateFunctions[oldStateName]
		if oldState then
			
			if self.m_complete == false and oldState.stateCancelFunc then
				oldState.stateCancelFunc()
			elseif oldState.stateEndFunc then
				oldState.stateEndFunc()
			end
			
		end
	end
	
	
	--iterate
	self.m_transitionID = (self.m_transitionID+1) % MAX_ID
	
	--change top state
	self.m_complete = false
	self.m_topStateName = topStateName
	--print(topStateName)
	local newTopState = self.m_stateFunctions[topStateName]
	self:setValues()
	
	--call event
	self.m_stateChangedEvent:Fire(self)
	
	--run top state (if it exists)
	if newTopState and newTopState.stateStartFunc then
		--self.m_runningCoroutine = coroutine.create(newTopState.stateStartFunc)
		self.m_runningCoroutine = newTopState.stateStartFunc
		task.spawn(function()
			self:resumeCorout()
		end)
		

	end
	
	
		
end

--
function m:resumeCorout()
	
	--print(self)
	--local success, ending, nextState = pcall(self.m_runningCoroutine)
	--local successful, ending, nextState = coroutine.resume(self.m_runningCoroutine)
	local ending, nextState = self.m_runningCoroutine()
	
	--print(ending)
	--if not success then end
	
	--all parameters will be nil if the coroutine waits, however if it returns then the parameters are caught here
	if ending ~= 0 or ending == nil then
		--print("killed coroutine")
		
		--if there is a next state, run it!
		local possibleStateChange = false
		if nextState then
			if not self.m_priorityQueue:contains(nextState.stateName) then
				self.m_priorityQueue:enqueue(nextState.stateName, nextState.statePriority)
				self.m_stateFunctions[nextState.stateName] = nextState
				possibleStateChange = true
			end
		end
		--
		
		if ending == true then
			if self.m_topStateName == self.m_priorityQueue:peek() then
				self.m_priorityQueue:dequeue() --this should be more optimized
			else
				self.m_priorityQueue:remove(self.m_topStateName)
			end
			possibleStateChange = true
		end
		
		if possibleStateChange then
			self:checkTopStateChange()
		end
		
		--print('closed')
		--if self.m_runningCoroutine then coroutine.close(self.m_runningCoroutine) end
		self.m_runningCoroutine = nil
		self.m_complete = true
	end
	

end


--replication function, if the state object has a folder to hold values, it'll update them
function m:setValues(state: State?)
	if not self.m_stateFolder then return end
	
	if state then
		local name = state.stateName
		local priority = state.statePriority
		local variant = state.stateVariant

		self.m_stateFolder.StateName = name
		self.m_stateFolder.StatePriority = priority
		self.m_stateFolder.StateVariant = variant
		
	else
		if RunService:IsStudio() then warn("queue emptied", self) end
		self.m_stateFolder.StateName = ""
		self.m_stateFolder.StatePriority = 0
		self.m_stateFolder.StateVariant = ""
		
	end

	--fire an event to update the values on the server
end

return m
