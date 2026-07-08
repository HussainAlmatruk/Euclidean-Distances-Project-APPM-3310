function Euclidean_Main()
% Euclidean_Main  Entry point for the APPM 3310 lighting coverage explorer.
%
% This file intentionally stays small. The project is organized into:
%   LaunchLightingExplorer.m   one-window interactive UI
%   BuildLightingModel.m       room -> D, V, falloff, A matrices
%   SolveLightingPlacement.m   exact BIP solver and greedy fallback
%   GetMap.m                   built-in gallery maps
%   RunLightingCase.m          non-UI experiment runner

clc; close all;

params.mapId = 'D';
params.lightStrength = 12.0;
params.height = 1.25;
params.threshold = 0.2;
params.candidateStride = 1;
params.maxGreedyLights = 40;
params.useExactSolver = true;
params.exactCandidateLimit = 300;
params.exactMaxTime = 45;
params.checkAlternativeOptima = true;
params.maxAlternativeSolutions = 3;
params.launchMapSelector = true;
params.matrixPreviewLimit = 90;

if params.launchMapSelector
    LaunchLightingExplorer(params);
else
    RunLightingCase(params);
end

end
