
Lua priority state machine
==================

This project uses a [Lua priority queue](https://github.com/iskolbin/lpriorityqueue) as a base for a state machine, designed to control player characters in games.

The state machine takes in State objects and places them into a priority queue. Each state has a starting function which has the ability to call wait() to yield the program and an ending or cancel function which is always called after the State leaves the queue in order to clean up the starting function.

This results in a simple implementation for input queuing, inputting a state while another action is ongoing will place it into the priority queue. Once the ongoing state on the top of the queue is popped off, the queued state will be sifted up and be next to run.

State object
==================


```lua
type State = {
  stateName 	: string;
  statePriority : number;
  stateVariant 	: string?;

  stateStartFunc  : () -> (boolean?, State?);
  stateEndFunc 	  : () -> ()?;
  stateCancelFunc : () -> ()?;
}
```

| Member Variable | Type | Description |
| -------- | -------- | -------- |
| stateName | string | Used as an identifier for the state, used so that you can edit states and still be able to access them in the StateMachine. <br> Duplicate stateNames will override the state with the original stateName. |
| statePriority | number | The highest priority state in the stateMachine is set as the active state. <br> Duplicate statePriorities are not allowed. |
| stateVariant | optional string | StateMachine has a function to remove all states of a certain variant. This can be useful for if a tool in a player's hand has changed, or multiple states need to be removed at once. |
| stateStartFunc | function | This function runs once the state becomes the active state. <br> This function is allowed to yield, however this requires use of the StateMachine wait function, as if a higher priority state is added while this function is running the function needs to terminate. <br> - You are not allowed to call StateMachine.insert() within this function, it will result in undetermined behavior. <br> - If the function returns something equal to true, the state will dequeue itself after this function ends. <br> - If the function returns another state object, it will dequeue itself and enqueue the returned state.
| stateEndFunc | optional function | This function runs once the state is no longer the active state. It runs before the next active state runs it's startFunc. This is usually used to clean up the actions done in the stateStartFunc. <br> - This function can **never yield**. |
| stateCancelFunc | optional function | If this state was ended before the stateStartFunc finished running, this function is called instead. If stateCancelState doesn't exist, then it will call stateEndFunc instead. <br> - This function can **never yield**. |



StateMachine:wait(waitingTime : number)
------------------
In order to yield, States need to call the custom wait function within the StateMachine they will be added to.   
Due to the fact that States can be removed at any time by a higher priority State, wait() functions serve as a potential spot for the function to terminate.   
Code between wait() calls are guaranteed to run in sequence, but the function may terminate at a wait().


example code here later

State Machine object
==================


module.new(startingStates : {State}?) : StateMachine
------------------
If an array of States is passed, then the StateMachine will start with all inserted and only run the stateStartFunc of the highest priority State within the array.   
If no State array is given, the StateMachine will be empty.


StateMachine:addState(State : State) : nil
------------------

addState adds a State to the priority queue.   
If the state has a higher priority than the active state (or the StateMachine is empty), then it will remove the active state and run the given state's stateStartFunc.


StateMachine:removeState(stateName : string) : boolean
------------------

removeState dequeues a state using it's stateName, not a State object.   
Similar to addState, this can cause a change in the active state.   
The function returns true if a state was removed, then it will return true. returns false if no State was dequeued.


StateMachine:hasActiveState(... : string) : boolean
------------------

This function checks if any of the given strings matches the active state, and if so, returns true.


StateMachine::hasState(stateName : string) : State?
------------------

Maps a state name to the State within the StateMachine.   
Can also be used to check if a state is anywhere within the StateMachine.


StateMachine:getTopState() : State?
------------------
"Peek" function to get the top state of the StateMachine.   
Returns nil if StateMachine is empty.


StateMachine:clear(dontRunTop : boolean?)
------------------
Empties all states from the StateMachine.   
If the boolean flag is toggled, the stateEndFunc or stateCancelFunc of the top state is not ran.


StateMachine:removeVariant(variantName : string)
------------------
Removes all States with the assigned variantName.   
Running removeState sequentially can result in intermediate startFuncs being ran if States are removed from highest to lowest priority.   
Using this function to remove multiple states is preferred to bypass this issue.   




