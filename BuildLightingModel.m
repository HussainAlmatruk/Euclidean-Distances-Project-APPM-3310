function model = BuildLightingModel(roomMap, params)
% BuildLightingModel  Convert a wall map into the matrices used by the solver.
%
% Output fields:
%   samplePoints     open cells that must be illuminated
%   candidatePoints  possible light-pole locations
%   D                Euclidean distance matrix
%   visibility       line-of-sight matrix V
%   falloff          raw inverse-square-style falloff matrix F
%   A                usable intensity matrix, A = F .* V

% Build the distance, visibility, and intensity matrices for a map.

[sampleRows, sampleCols] = find(roomMap == 0);
samplePoints = [sampleRows, sampleCols];

if isempty(samplePoints)
    error('Selected map has no open cells to illuminate.');
end

candidateKeep = true(size(sampleRows));
if params.candidateStride > 1
    candidateKeep = mod(sampleRows - 2, params.candidateStride) == 0 & ...
                    mod(sampleCols - 2, params.candidateStride) == 0;
    if ~any(candidateKeep)
        candidateKeep = true(size(sampleRows));
    end
end

candidatePoints = samplePoints(candidateKeep, :);
D = ComputeDistanceMatrix(candidatePoints, samplePoints);
V = BuildVisibilityMatrix(roomMap, candidatePoints, samplePoints);

strengths = params.lightStrength * ones(size(candidatePoints, 1), 1);
falloff = bsxfun(@rdivide, strengths, D.^2 + params.height^2);
A = falloff .* double(V);

model.roomMap = roomMap;
model.samplePoints = samplePoints;
model.candidatePoints = candidatePoints;
model.D = D;
model.visibility = V;
model.falloff = falloff;
model.A = A;

end
function D = ComputeDistanceMatrix(candidatePoints, samplePoints)
% D(i,j) is the Euclidean distance from candidate light i to sample point j.

candidateRows = candidatePoints(:, 1);
candidateCols = candidatePoints(:, 2);
sampleRows = samplePoints(:, 1).';
sampleCols = samplePoints(:, 2).';

rowDiff = bsxfun(@minus, candidateRows, sampleRows);
colDiff = bsxfun(@minus, candidateCols, sampleCols);
D = sqrt(rowDiff.^2 + colDiff.^2);

end
function V = BuildVisibilityMatrix(roomMap, candidatePoints, samplePoints)
% V(i,j) = 1 when candidate light i has line-of-sight to sample point j.

numCandidates = size(candidatePoints, 1);
numSamples = size(samplePoints, 1);
V = false(numCandidates, numSamples);

for i = 1:numCandidates
    for j = 1:numSamples
        V(i, j) = HasLineOfSight(roomMap, candidatePoints(i, :), samplePoints(j, :));
    end
end

end
function isVisible = HasLineOfSight(roomMap, sourcePoint, targetPoint)
% Grid-sampling approximation to line-of-sight through the room.

if all(sourcePoint == targetPoint)
    isVisible = true;
    return;
end

delta = targetPoint - sourcePoint;
steps = 4 * max(abs(delta)) + 1;
rows = round(linspace(sourcePoint(1), targetPoint(1), steps));
cols = round(linspace(sourcePoint(2), targetPoint(2), steps));

rows = min(max(rows, 1), size(roomMap, 1));
cols = min(max(cols, 1), size(roomMap, 2));
indices = sub2ind(size(roomMap), rows, cols);
isVisible = all(roomMap(indices) == 0);

end
