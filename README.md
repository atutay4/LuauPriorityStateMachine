
Lua priority state machine
==================

This project uses a [Lua priority queue](https://github.com/iskolbin/lpriorityqueue) as a base for a state machine, designed to control player characters in games.

The state machine takes in State objects and places them into a priority queue. Each state has a starting function which has the ability to call wait() to yield the program and an ending or cancel function which is always called after the State leaves the queue in order to clean up the starting function.

This results in a simple implementation for input queuing, inputting a state while another action is ongoing will place it into the priority queue. Once the ongoing state on the top of the queue is popped off, the queued state will be sifted up and be next to run.

State object
==================

States are the "nodes" of this structure.    
A majority of the "character" code, like the player character and their actions should be handled within the stateStartFunc and stateEndFunc of States.   
The "input" code, should interact with the StateMachine. For example, pressing the left mouse button will queue a State into the StateMachine. The State contains information on what the character should do. Once the character is finished doing a higher priority task, the State will be loaded as active and ran.

```lua
type State = {
  stateName 	: string;
  statePriority : number;
  stateVariant 	: string?;
  timeout       : number;

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
| timeout | number | After spending this amount of time in the StateMachine without becoming active, this state will be skipped if it becomes highest priority. <br> Requeuing the state or the state becoming active will reset the internal timer. <br> If timeout is not specified, it will default to no timeout. (infinite time) |
| stateStartFunc | function | This function runs once the state becomes the active state. <br> This function is allowed to yield, however this requires use of the StateMachine wait function, as if a higher priority state is added while this function is running the function needs to terminate. <br> - You are not allowed to call StateMachine.insert() within this function, it will result in undetermined behavior. <br> - If the function returns something equal to true, the state will dequeue itself after this function ends. <br> - If the function returns another state object, it will dequeue itself and enqueue the returned state.
| stateEndFunc | optional function | This function runs once the state is no longer the active state. It runs before the next active state runs it's startFunc. This is usually used to clean up the actions done in the stateStartFunc. <br> - This function can **never yield**. |
| stateCancelFunc | optional function | If this state was ended before the stateStartFunc finished running, this function is called instead. If stateCancelState doesn't exist, then it will call stateEndFunc instead. <br> - This function can **never yield**. |



StateMachine:wait(waitingTime : number)
------------------
In order to yield, States need to call the custom wait function within the StateMachine they will be added to.   
Due to the fact that States can be removed at any time by a higher priority State, wait() functions serve as a potential spot for the function to terminate.   
Code between wait() calls are guaranteed to run in sequence, but the function may terminate at a wait().   
- If stateCancelFunc is specified, then terminating at a wait() will call that function.   
- If stateCancelFunc is not specified, teriminating will call the stateEndFunc function instead.   


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


Code examples
==================

Here is a simple example of the code in action:
```lua
--[[
    State code
]]--

local aiming : PlayerStateMachine.State = {
  stateName = "Aiming";
  stateVariant = Tool.Name;
  statePriority = 10;

  stateStartFunc = function()

    -- Do some stuff, in this case aim down sights and play a sound
    toolObject.characterProperties.addEffect("Aiming")
    PlaySound.playSound(Tool.ToolHandle, Assets.Sweeper.Aim, Randomizer)

    
    local AimingSpeed = toolObject.values.AimingSpeed
    toolObject.characterState:wait(AimingSpeed)

    -- This is a persistent state, 
    return nil

  end,
  stateEndFunc = function() end -- No cleanup needed for this function
}

local firing : PlayerStateMachine.State = {	
  stateName = "Firing";
  stateVariant = Tool.Name;
  statePriority = 10000;

  stateStartFunc = function()

    -- Do some stuff, in this case it calls outside libraries for recoil, spawning bullets, and playing sounds
    toolObject:runAnim("Firing", nil, nil, Enum.AnimationPriority.Action2)
    CameraShake.shakeCameraPreset("Bump")
    ReplicatedEffects.callReplicatedEffect("SweeperShot", {
      toolObject.character,
      barrelStart.WorldPosition + (barrelDirection.WorldPosition-barrelStart.WorldPosition)*100
    })
    toolObject.values.MagazineAmmo -= 1

    -- Wait for the state to finish
    toolObject.characterState:wait(toolObject.values.ShootingEndlag)

    -- This state is a singular action, it will end after the action is done
    return true
  end,
  stateEndFunc = function()
    -- There is some clean up here, because the state runs an animation we want to end it if the state ends early, to prevent animation bleeding
    toolObject.animations.AimRecoil:Stop()
  end
}



--[[
    StateMachine code
]]--

-- Bind the states to inputs, aiming occurs on right mouse click (abstracted using a library in order to allow rebinding)
Input.attachAction("Aim", "Tool", Enum.UserInputState.Begin, function()
    toolObject.characterState:addState(aiming)
end)

-- Because the state doesn't dequeue itself, we have to manually do so when right click is released
Input.attachAction("Aim", "Tool", Enum.UserInputState.End, function()
    toolObject.characterState:removeState("Aiming")
end)

-- Firing occurs on left mouse click, but only if the gun is currently aiming.
-- If the player releases right click during the firing state, the aiming state will be dequeued and will not run again.
-- If right click is held, the aiming state remains in queue and will begin again once the firing state ends.
Input.attachAction("Fire", "Tool", Enum.UserInputState.Begin, function()
    
    if toolObject.characterState:hasActiveState("Aiming") then
      toolObject.characterState:addState(firing)
    end

end)

  
```
