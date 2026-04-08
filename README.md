
Lua priority state machine
==================

This project uses a [Lua priority queue](https://github.com/iskolbin/lpriorityqueue) as a base for a state machine, designed to control player characters in games.

The state machine takes in State objects and places them into a priority queue. Each state has a starting function which has the ability to call wait() to yield the program and an ending or cancel function which is always called after the State leaves the queue in order to clean up the starting function.

This results in a simple implementation for input queuing, inputting a state while another action is ongoing will place it into the priority queue. Once the ongoing state on the top of the queue is popped off, the queued state will be sifted up and be next to run.

State object
==================



State Machine object
==================
