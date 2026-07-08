function PrintRunSummary(model, result, params)
% Print a compact numerical summary for the experiment log.

fprintf('\nEuclidean distance lighting coverage run\n');
fprintf('Map: %s\n', FormatMapId(params.mapId));
fprintf('Sample points: %d\n', size(model.samplePoints, 1));
fprintf('Candidate light positions: %d\n', size(model.candidatePoints, 1));
fprintf('Matrix sizes: D, V, and A are %d x %d\n', size(model.A, 1), size(model.A, 2));
fprintf('Solver: %s\n', result.method);
fprintf('Selected lights: %d\n', numel(result.selected));
fprintf('Coverage above threshold %.3f: %.1f%%\n', params.threshold, 100 * result.coverageFraction);
fprintf('Minimum illumination: %.3f\n', result.minIllumination);
fprintf('Mean illumination: %.3f\n\n', result.meanIllumination);
fprintf('Optimality: %s\n\n', result.optimalityMessage);

fprintf('Selected candidate cells [row, col]:\n');
disp(model.candidatePoints(result.selected, :));

end
