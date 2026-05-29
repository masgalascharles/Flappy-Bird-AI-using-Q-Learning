This initially started as a normal Flappy Bird game to test my Swift knowledge,
but I became interested in ML through YouTube and I wanted to start off easy, so 
I began experimenting with Q Learning.

The states stored in the Q table are just the vertical distances
from the top of the next bottom pipe, then rounded to limit the
number of possible states. This gives us a very simple key value to work
with for the Q table and reward calculation.

The agent's possible moves are either "flap" or "idle" for any given frame.
The action taken is either rewarded or punished, determined by
how close the agent is to the top of the next bottom pipe. If it is
just above the top of the next bottom pipe and flaps, then it is rewarded.
If the agent waits longer than that to flap or it flaps too early, then it is punished.
