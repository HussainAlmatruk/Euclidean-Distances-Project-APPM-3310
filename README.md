# Euclidean Distance Matrices for Illumination Coverage

APPM 3310 Matrix Methods project for modeling gallery lighting with matrices.

The code converts a room map into sample points, candidate light-pole positions,
a Euclidean distance matrix `D`, a wall visibility matrix `V`, and an intensity
matrix `A`. It then selects lights with either an exact binary integer program
or a greedy fallback and visualizes the result.

## Run

Run `Euclidean_Main.m` in MATLAB to open the interactive lighting explorer:

```matlab
Euclidean_Main
```

## File Layout

* `Euclidean_Main.m` sets default parameters and starts the program.
* `LaunchLightingExplorer.m` contains the tabbed user interface and plots.
* `BuildLightingModel.m` builds the matrices `D`, `V`, falloff, and `A`.
* `SolveLightingPlacement.m` solves the exact or greedy placement problem.
* `GetMap.m` stores the built-in room maps.
* `RunLightingCase.m` runs one map without the UI.
* `PrintRunSummary.m`, `AvailableMaps.m`, and `FormatMapId.m` are small helpers.

## Solver Note

If MATLAB has `intlinprog`, the solver can certify the minimum number of
selected grid lights. Without `intlinprog`, the code uses a greedy
deficit-reduction heuristic. The greedy solution can cover the room, but it is
not a mathematical proof of minimality.

## Authors

* Hussain Almatruk
* Caleb Farr
* Andrew Gonzalez

APPM 3310: Matrix Methods
Section 300
University of Colorado Boulder
