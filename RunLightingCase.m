function [model, result] = RunLightingCase(params)
% Run the full model for one map and print the numerical summary.

roomMap = GetMap(params.mapId);
model = BuildLightingModel(roomMap, params);
result = SolveLightingPlacement(model, params);

PrintRunSummary(model, result, params);

end
