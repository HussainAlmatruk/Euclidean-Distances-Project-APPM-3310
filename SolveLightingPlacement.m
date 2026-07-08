function result = SolveLightingPlacement(model, params)
% SolveLightingPlacement  Choose lights using an exact solver or greedy fallback.
%
% If intlinprog is installed and the candidate set is small enough, the code
% solves the binary integer program and can certify the minimum light count.
% Otherwise it uses the greedy deficit-reduction heuristic, which gives a
% feasible solution but not a proof of optimality.

% Try the exact binary integer program first, then fall back to a greedy solver.

target = params.threshold * ones(size(model.A, 2), 1);
result = [];

if params.useExactSolver && size(model.A, 1) <= params.exactCandidateLimit && exist('intlinprog', 'file') == 2
    result = TryIntegerProgram(model.A, target, params);
    if ~isempty(result) && isfield(params, 'checkAlternativeOptima') && params.checkAlternativeOptima
        result = CheckAlternativeOptima(result, model.A, target, params);
    end
end

if isempty(result)
    result = GreedyLightPlacement(model.A, target, params.maxGreedyLights);
end

result.selected = find(result.x > 0.5);
result.sampleIllumination = model.A.' * result.x;
result.coverageFraction = mean(result.sampleIllumination >= target - 1.0e-10);
result.minIllumination = min(result.sampleIllumination);
result.meanIllumination = mean(result.sampleIllumination);
result.optimalityMessage = BuildOptimalityMessage(result);

end
function result = TryIntegerProgram(A, target, params)
% Minimize sum(x) subject to A.'*x >= target and x is binary.

numCandidates = size(A, 1);
f = ones(numCandidates, 1);
intcon = 1:numCandidates;
Aineq = -A.';
bineq = -target;
lb = zeros(numCandidates, 1);
ub = ones(numCandidates, 1);

try
    try
        options = BuildIntegerOptions(params);
        [x, objectiveValue, exitflag] = intlinprog(f, intcon, Aineq, bineq, [], [], lb, ub, options);
    catch
        [x, objectiveValue, exitflag] = intlinprog(f, intcon, Aineq, bineq, [], [], lb, ub);
    end

    if exitflag > 0
        result.x = round(x);
        result.method = 'exact binary integer program';
        result.objectiveValue = objectiveValue;
        result.exitflag = exitflag;
        result.history = [];
        result.isCertifiedOptimal = true;
        result.minimumLightCount = round(objectiveValue);
        result.alternativeStatus = 'not checked';
        result.hasAlternativeOptimum = false;
        result.alternativeSolutions = [];
    else
        result = [];
    end
catch
    result = [];
end

end
function options = BuildIntegerOptions(params)
% Build intlinprog options while staying compatible with older MATLAB versions.

options = optimoptions('intlinprog', 'Display', 'off');

if isfield(params, 'exactMaxTime') && ~isempty(params.exactMaxTime)
    try
        options.MaxTime = params.exactMaxTime;
    catch
    end
end

end
function result = CheckAlternativeOptima(result, A, target, params)
% Look for other optimal binary vectors with the same minimum light count.

if ~result.isCertifiedOptimal
    return;
end

minimumLightCount = round(sum(result.x));
knownSolutions = result.x(:).';
alternatives = [];
searchStatus = 'none';

for k = 1:params.maxAlternativeSolutions
    [alternative, searchStatus] = FindAlternativeOptimum(A, target, minimumLightCount, knownSolutions, params);

    if isempty(alternative)
        break;
    end

    alternatives = [alternatives; alternative(:).']; %#ok<AGROW>
    knownSolutions = [knownSolutions; alternative(:).']; %#ok<AGROW>
end

result.alternativeSolutions = alternatives;
result.hasAlternativeOptimum = ~isempty(alternatives);

if result.hasAlternativeOptimum
    result.alternativeStatus = sprintf('found %d alternate minimum solution(s)', size(alternatives, 1));
elseif strcmp(searchStatus, 'infeasible')
    result.alternativeStatus = 'unique minimum among grid candidates';
else
    result.alternativeStatus = 'alternate-minimum check inconclusive';
end

end
function [alternative, searchStatus] = FindAlternativeOptimum(A, target, minimumLightCount, knownSolutions, params)
% Solve a feasibility IP for a different solution with the same light count.

alternative = [];
searchStatus = 'unknown';

numCandidates = size(A, 1);
f = zeros(numCandidates, 1);
intcon = 1:numCandidates;
Aineq = -A.';
bineq = -target;

for row = 1:size(knownSolutions, 1)
    exclusion = zeros(1, numCandidates);
    exclusion(knownSolutions(row, :) > 0.5) = 1;
    Aineq = [Aineq; exclusion]; %#ok<AGROW>
    bineq = [bineq; minimumLightCount - 1]; %#ok<AGROW>
end

Aeq = ones(1, numCandidates);
beq = minimumLightCount;
lb = zeros(numCandidates, 1);
ub = ones(numCandidates, 1);

try
    try
        options = BuildIntegerOptions(params);
        [x, ~, exitflag] = intlinprog(f, intcon, Aineq, bineq, Aeq, beq, lb, ub, options);
    catch
        [x, ~, exitflag] = intlinprog(f, intcon, Aineq, bineq, Aeq, beq, lb, ub);
    end

    if exitflag > 0
        alternative = round(x(:)).';
        searchStatus = 'found';
    elseif exitflag == -2
        searchStatus = 'infeasible';
    else
        searchStatus = 'unknown';
    end
catch
    alternative = [];
    searchStatus = 'unknown';
end

end
function result = GreedyLightPlacement(A, target, maxLights)
% Greedily add the light that reduces the remaining illumination deficit most.

numCandidates = size(A, 1);
numSamples = size(A, 2);
x = zeros(numCandidates, 1);
illumination = zeros(numSamples, 1);
history = zeros(maxLights, 5);
stepCount = 0;

for step = 1:maxLights
    if all(illumination >= target - 1.0e-10)
        break;
    end

    deficit = max(0, target - illumination).';
    clippedContribution = min(A, repmat(deficit, numCandidates, 1));
    gains = sum(clippedContribution, 2);
    gains(x > 0) = -inf;

    [bestGain, bestIndex] = max(gains);
    if bestGain <= 1.0e-12 || isinf(bestGain)
        break;
    end

    x(bestIndex) = 1;
    illumination = illumination + A(bestIndex, :).';
    stepCount = stepCount + 1;
    history(stepCount, :) = [step, bestIndex, bestGain, min(illumination), mean(illumination >= target)];
end

history = history(1:stepCount, :);

result.x = x;
result.method = 'greedy deficit-reduction heuristic';
result.objectiveValue = sum(x);
result.exitflag = double(all(illumination >= target - 1.0e-10));
result.history = history;
result.isCertifiedOptimal = false;
result.minimumLightCount = NaN;
result.alternativeStatus = 'not checked because the solution is heuristic';
result.hasAlternativeOptimum = false;
result.alternativeSolutions = [];

end
function message = BuildOptimalityMessage(result)
% Explain whether the selected arrangement is actually proven minimal.

if result.isCertifiedOptimal
    if result.hasAlternativeOptimum
        message = sprintf('Exact minimum: %d lights; other minimum arrangements exist (%s).', ...
            result.minimumLightCount, result.alternativeStatus);
    else
        message = sprintf('Exact minimum: %d lights; %s.', ...
            result.minimumLightCount, result.alternativeStatus);
    end
else
    message = 'Greedy heuristic: not certified minimum.';
end

end
