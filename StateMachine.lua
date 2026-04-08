

local m

-- Core private variables defined here, then combined with function definitions below
-- Exact type is named StateMachine
type __StateMachine = {
	m_stateFolder : Folder;
	m_stateChangedEvent : BindableEvent;
	
	--the priority queue uses statePriority as a key, and stateName as a value, allowing it to be indexed by strings
	m_priorityQueue : PriorityQueue;
	--a table of stateName : state objects (functions)
	m_stateFunctions : {[string] : State};

	-- internal variables, should not need to use these
	m_topStateName : string;
	m_runningCoroutine : () -> ();
	m_complete : bool;
	m_transitionID : number;
}

function m.new() : StateMachine
	local self = setmetatable({}, m)
	
	self.m_priorityQueue = PriorityQueue.new("max")
	self.m_stateFunctions = {}
	
	self.m_topStateName = nil
	self.m_runningCoroutine = nil
	self.m_complete = false
	self.m_transitionID = 0
	return self
end



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



export type StateMachine = __StateMachine&{
	
	--[[
		Adds a state to the StateMachine
	
		States must have unique priorities, if an already existing priority exists, then this function will error.
	]]--
	addState : (StateMachine, State) -> (); 


	--[[
		Removes the state with the given name
	]]--
	removeState : (StateMachine, stateName) -> (boolean);

--[[
	Returns true if the state is currently the highest priority (the active state)

	Can accept multiple strings, will return true if any are highest priority
]]--
function m:hasActiveState(... : string) : boolean

--[[
	Maps an stateName
]]--
function m:hasState(stateName : string) : State?

--[[
	"Peek" function to get the top state of the StateMachine
]]--
function m:getTopState() : State?

--[[
	Removes all states with the assigned variant
]]--
function m:removeVariant(variantName : string)

--[[
	Remove all states from the machine
]]--
function m:clear(dontRunTop : boolean)

function m:wait(waitingTime : number)

								}
