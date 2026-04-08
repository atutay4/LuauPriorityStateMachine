type StateMachine = {
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

function m:addState(state : State)
function m:removeState(stateName : string) : boolean
function m:hasActiveState(... : string) : boolean
function m:hasState(stateName : string) : State?
function m:getTopState() : State?
function m:clear(dontRunTop : boolean)
function m:removeVariant(variantName : string)
function m:wait(waitingTime : number)
