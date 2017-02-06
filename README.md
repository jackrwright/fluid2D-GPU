# fluid2D-GPU
This was an experiment to implement a GPU based fluid simulation on iOS. It's written Objective-C using the older GLKit API.

Initially it was working flawlessly, but with the advent of newer GPU hardware the simulation starts to break down after a short period of time. Possibly due to an arithmetic overflow in a shader. The flaw is most obvious if you view the pressure distribution by selecting the "Pres" Display, so it's probably in the "jacobi" shader. In fact, I may never bother and instead code this for Metal.

Because of the bug, I temporarily disabled the "ink" mode and set the initial fluid characteristic to "Smoke". "Fire" works as well, since it also has a brief life.

Disclaimer: This is not an example of good iOS app, but that wasn't the point :)
