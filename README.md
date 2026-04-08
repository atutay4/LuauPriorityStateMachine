
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

example code here later

State Machine object
==================






