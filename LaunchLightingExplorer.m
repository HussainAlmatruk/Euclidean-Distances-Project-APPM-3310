function LaunchLightingExplorer(params)
% LaunchLightingExplorer  Open the tabbed MATLAB interface for the project.
%
% The UI keeps the physical room views and the matrix explanations in one
% window. Helper functions below redraw the tabs and handle pole selection.

% One-window interface for map selection, solution plots, and pole inspection.

[mapIds, mapLabels] = AvailableMaps();

fig = figure('Name', 'Lighting Coverage Explorer', ...
    'NumberTitle', 'off', ...
    'Color', 'w', ...
    'MenuBar', 'none', ...
    'ToolBar', 'none', ...
    'Position', [60, 60, 1480, 880]);

controlPanel = uipanel('Parent', fig, ...
    'Units', 'normalized', ...
    'Position', [0.02, 0.87, 0.96, 0.11], ...
    'BackgroundColor', 'w', ...
    'BorderType', 'line', ...
    'HighlightColor', [0.82 0.82 0.82]);

infoText = uicontrol(controlPanel, 'Style', 'text', ...
    'String', '', ...
    'Units', 'normalized', ...
    'Position', [0.01, 0.52, 0.98, 0.38], ...
    'BackgroundColor', 'w', ...
    'ForegroundColor', [0.12 0.12 0.12], ...
    'HorizontalAlignment', 'left', ...
    'FontWeight', 'bold', ...
    'FontSize', 11);

buttonWidth = 0.125;
buttonHeight = 0.34;
leftStart = 0.01;
gap = 0.010;

for k = 1:numel(mapIds)
    left = leftStart + (k - 1) * (buttonWidth + gap);
    uicontrol(controlPanel, 'Style', 'pushbutton', ...
        'String', mapLabels{k}, ...
        'Units', 'normalized', ...
        'Position', [left, 0.08, buttonWidth, buttonHeight], ...
        'FontWeight', 'bold', ...
        'Callback', @(~, ~) RunExplorerMap(fig, mapIds{k}));
end

tabGroup = uitabgroup('Parent', fig, ...
    'Units', 'normalized', ...
    'Position', [0.02, 0.03, 0.96, 0.82]);
SetBackgroundIfPossible(tabGroup, [1 1 1]);

tabs.solution = uitab(tabGroup, 'Title', 'Solution');
tabs.overview = uitab(tabGroup, 'Title', 'System overview');
tabs.inspector = uitab(tabGroup, 'Title', 'Pole inspector');
SetBackgroundIfPossible(tabs.solution, [1 1 1]);
SetBackgroundIfPossible(tabs.overview, [1 1 1]);
SetBackgroundIfPossible(tabs.inspector, [1 1 1]);

app.params = params;
app.mapIds = mapIds;
app.mapLabels = mapLabels;
app.infoText = infoText;
app.tabGroup = tabGroup;
app.tabs = tabs;
app.model = [];
app.result = [];
app.selectedCandidate = [];
guidata(fig, app);

RunExplorerMap(fig, params.mapId);

end
function RunExplorerMap(fig, mapId)
% Compute one map and redraw every tab inside the consolidated UI.

app = guidata(fig);
app.params.mapId = mapId;

roomMap = GetMap(mapId);
model = BuildLightingModel(roomMap, app.params);
result = SolveLightingPlacement(model, app.params);

app.model = model;
app.result = result;
if isempty(result.selected)
    app.selectedCandidate = [];
else
    app.selectedCandidate = result.selected(1);
end
guidata(fig, app);

PrintRunSummary(model, result, app.params);
RenderExplorer(fig);

end
function RenderExplorer(fig)
% Redraw all explorer tabs for the current model.

app = guidata(fig);

set(app.infoText, 'String', sprintf(['Map %s | strength %.2f | threshold %.3f | ', ...
    '%d selected / %d candidates | %.1f%% covered | min %.3f | %s'], ...
    FormatMapId(app.params.mapId), app.params.lightStrength, app.params.threshold, ...
    numel(app.result.selected), size(app.model.A, 1), ...
    100 * app.result.coverageFraction, app.result.minIllumination, app.result.optimalityMessage));

RenderSolutionTab(fig);
RenderOverviewTab(fig);
RenderInspectorTab(fig);

end
function RenderSolutionTab(fig)
% Main room-scale output: selected lights, total illumination, and margin.

app = guidata(fig);
tab = app.tabs.solution;
delete(allchild(tab));

roomMap = app.model.roomMap;
model = app.model;
result = app.result;
params = app.params;

illuminationGrid = ValuesOnGrid(roomMap, model.samplePoints, result.sampleIllumination);
marginValues = result.sampleIllumination - params.threshold;
marginGrid = ValuesOnGrid(roomMap, model.samplePoints, marginValues);
selectedPoints = model.candidatePoints(result.selected, :);

axMap = axes('Parent', tab, 'Units', 'normalized', 'Position', [0.04, 0.16, 0.28, 0.74]);
mapImage = imagesc(axMap, roomMap);
set(mapImage, 'ButtonDownFcn', @(~, ~) SelectNearestPoleFromClick(fig, axMap));
axis(axMap, 'image');
axis(axMap, 'ij');
colormap(axMap, [1 1 1; 0.08 0.08 0.08]);
hold(axMap, 'on');
selectedHandle = plot(axMap, selectedPoints(:, 2), selectedPoints(:, 1), 'o', ...
    'MarkerEdgeColor', [0.10 0.10 0.10], ...
    'MarkerFaceColor', [1.00 0.85 0.15], ...
    'MarkerSize', 7, ...
    'ButtonDownFcn', @(~, ~) SelectNearestPoleFromClick(fig, axMap));
set(selectedHandle, 'HitTest', 'on');
HighlightCurrentPole(axMap, model, app.selectedCandidate);
title(axMap, sprintf('Map %s: click a selected pole', FormatMapId(params.mapId)));
xlabel(axMap, 'Column');
ylabel(axMap, 'Row');
StyleCurrentAxes(axMap);
hold(axMap, 'off');

axIllumination = axes('Parent', tab, 'Units', 'normalized', 'Position', [0.37, 0.16, 0.28, 0.74]);
illuminationImage = imagesc(axIllumination, illuminationGrid);
set(illuminationImage, 'AlphaData', ~isnan(illuminationGrid));
axis(axIllumination, 'image');
axis(axIllumination, 'ij');
set(axIllumination, 'Color', [0.08 0.08 0.08]);
colormap(axIllumination, hot(256));
illuminationScale = max(2 * params.threshold, SortedQuantile(result.sampleIllumination, 0.95));
caxis(axIllumination, [0, illuminationScale]);
StyledColorbar(axIllumination);
hold(axIllumination, 'on');
plot(axIllumination, selectedPoints(:, 2), selectedPoints(:, 1), 'co', 'MarkerSize', 6, 'LineWidth', 1.25);
hold(axIllumination, 'off');
title(axIllumination, 'Total illumination A^T x');
xlabel(axIllumination, 'Column');
ylabel(axIllumination, 'Row');
StyleCurrentAxes(axIllumination);

axMargin = axes('Parent', tab, 'Units', 'normalized', 'Position', [0.70, 0.16, 0.28, 0.74]);
marginImage = imagesc(axMargin, marginGrid);
set(marginImage, 'AlphaData', ~isnan(marginGrid));
axis(axMargin, 'image');
axis(axMargin, 'ij');
set(axMargin, 'Color', [0.08 0.08 0.08]);
colormap(axMargin, BlueWhiteRedMap(256));
marginLimit = max(abs(marginValues));
marginLimit = max(marginLimit, params.threshold);
caxis(axMargin, [-marginLimit, marginLimit]);
StyledColorbar(axMargin);
title(axMargin, 'Coverage margin A^T x - tau');
xlabel(axMargin, 'Column');
ylabel(axMargin, 'Row');
StyleCurrentAxes(axMargin);

uicontrol(tab, 'Style', 'text', ...
    'String', sprintf('Coverage %.1f%% | minimum %.3f | selected lights %d', ...
    100 * result.coverageFraction, result.minIllumination, numel(result.selected)), ...
    'Units', 'normalized', ...
    'Position', [0.04, 0.03, 0.92, 0.06], ...
    'BackgroundColor', 'w', ...
    'ForegroundColor', [0.12 0.12 0.12], ...
    'FontWeight', 'bold', ...
    'FontSize', 11);

end
function RenderOverviewTab(fig)
% System-scale views that avoid the unreadable full candidate-by-sample matrix.

app = guidata(fig);
tab = app.tabs.overview;
delete(allchild(tab));

model = app.model;
result = app.result;
params = app.params;
selected = result.selected;

if isempty(selected)
    DrawCenteredMessage(tab, 'No lights were selected for this run.');
    return;
end

selectedPoints = model.candidatePoints(selected, :);
sortedIllumination = sort(result.sampleIllumination);
visibilityOverlap = sum(model.visibility(selected, :), 1);
visibilityOverlapGrid = ValuesOnGrid(model.roomMap, model.samplePoints, visibilityOverlap(:));
bestSingleIntensity = max(model.A(selected, :), [], 1);
bestSingleIntensityGrid = ValuesOnGrid(model.roomMap, model.samplePoints, bestSingleIntensity(:));

uicontrol(tab, 'Style', 'text', ...
    'String', result.optimalityMessage, ...
    'Units', 'normalized', ...
    'Position', [0.04, 0.93, 0.92, 0.04], ...
    'BackgroundColor', 'w', ...
    'ForegroundColor', [0.12 0.12 0.12], ...
    'FontWeight', 'bold', ...
    'HorizontalAlignment', 'left');

axMap = axes('Parent', tab, 'Units', 'normalized', 'Position', [0.04, 0.54, 0.26, 0.34]);
imagesc(axMap, model.roomMap);
axis(axMap, 'image');
axis(axMap, 'ij');
colormap(axMap, [1 1 1; 0.08 0.08 0.08]);
hold(axMap, 'on');
plot(axMap, selectedPoints(:, 2), selectedPoints(:, 1), 'o', ...
    'MarkerEdgeColor', [0.10 0.10 0.10], ...
    'MarkerFaceColor', [1.00 0.85 0.15], ...
    'MarkerSize', 6, ...
    'ButtonDownFcn', @(~, ~) SelectNearestPoleFromClick(fig, axMap));
if result.hasAlternativeOptimum
    alternativeSelected = find(result.alternativeSolutions(1, :) > 0.5);
    alternativePoints = model.candidatePoints(alternativeSelected, :);
    plot(axMap, alternativePoints(:, 2), alternativePoints(:, 1), 's', ...
        'MarkerEdgeColor', [0.80 0.00 0.70], ...
        'MarkerFaceColor', 'none', ...
        'MarkerSize', 7, ...
        'LineWidth', 1.4);
    legend(axMap, {'Current minimum', 'Alternate minimum'}, 'Location', 'southoutside');
end
HighlightCurrentPole(axMap, model, app.selectedCandidate);
hold(axMap, 'off');
if result.hasAlternativeOptimum
    title(axMap, 'Current minimum and one alternate minimum');
else
    title(axMap, 'Selected poles in the room');
end
xlabel(axMap, 'Column');
ylabel(axMap, 'Row');
StyleCurrentAxes(axMap);

axVisibilityOverlap = axes('Parent', tab, 'Units', 'normalized', 'Position', [0.37, 0.54, 0.26, 0.34]);
visibilityImage = imagesc(axVisibilityOverlap, visibilityOverlapGrid);
set(visibilityImage, 'AlphaData', ~isnan(visibilityOverlapGrid));
axis(axVisibilityOverlap, 'image');
axis(axVisibilityOverlap, 'ij');
set(axVisibilityOverlap, 'Color', [0.95 0.95 0.95]);
maxOverlap = max(visibilityOverlap);
colormap(axVisibilityOverlap, IntegerOverlapMap(maxOverlap + 1));
caxis(axVisibilityOverlap, [-0.5, maxOverlap + 0.5]);
overlapColorbar = StyledColorbar(axVisibilityOverlap);
set(overlapColorbar, 'Ticks', 0:maxOverlap);
ylabel(overlapColorbar, 'Selected poles');
title(axVisibilityOverlap, 'Visibility overlap: how many selected poles see each cell');
xlabel(axVisibilityOverlap, 'Column');
ylabel(axVisibilityOverlap, 'Row');
StyleCurrentAxes(axVisibilityOverlap);

axBestIntensity = axes('Parent', tab, 'Units', 'normalized', 'Position', [0.70, 0.54, 0.26, 0.34]);
bestIntensityImage = imagesc(axBestIntensity, bestSingleIntensityGrid);
set(bestIntensityImage, 'AlphaData', ~isnan(bestSingleIntensityGrid));
axis(axBestIntensity, 'image');
axis(axBestIntensity, 'ij');
set(axBestIntensity, 'Color', [0.95 0.95 0.95]);
colormap(axBestIntensity, hot(256));
caxis(axBestIntensity, [0, max(params.threshold, SortedQuantile(bestSingleIntensity, 0.95))]);
StyledColorbar(axBestIntensity);
title(axBestIntensity, 'Strongest single selected pole at each cell');
xlabel(axBestIntensity, 'Column');
ylabel(axBestIntensity, 'Row');
StyleCurrentAxes(axBestIntensity);

axSorted = axes('Parent', tab, 'Units', 'normalized', 'Position', [0.04, 0.10, 0.26, 0.32]);
plot(axSorted, sortedIllumination, 'LineWidth', 1.25);
hold(axSorted, 'on');
plot(axSorted, [1, numel(sortedIllumination)], [params.threshold, params.threshold], 'r--', 'LineWidth', 1.0);
hold(axSorted, 'off');
title(axSorted, 'Sorted total illumination');
xlabel(axSorted, 'Sample points sorted dimmest to brightest');
ylabel(axSorted, 'Intensity');
StyleCurrentAxes(axSorted);

axVisibleCounts = axes('Parent', tab, 'Units', 'normalized', 'Position', [0.37, 0.10, 0.26, 0.32]);
visibleCounts = sum(model.visibility(selected, :), 2);
adequateCounts = sum(model.A(selected, :) >= params.threshold, 2);
bar(axVisibleCounts, [visibleCounts, adequateCounts]);
legend(axVisibleCounts, {'Visible', 'Enough by itself'}, 'Location', 'northwest');
title(axVisibleCounts, 'Cells reached by each selected pole');
xlabel(axVisibleCounts, 'Selected pole number');
ylabel(axVisibleCounts, 'Sample cells');
StyleCurrentAxes(axVisibleCounts);

axHistory = axes('Parent', tab, 'Units', 'normalized', 'Position', [0.70, 0.10, 0.26, 0.32]);
if isempty(result.history)
    bar(axHistory, [numel(result.selected), size(model.A, 1) - numel(result.selected)]);
    set(axHistory, 'XTickLabel', {'Selected', 'Not selected'});
    title(axHistory, 'Exact solver selection count');
    ylabel(axHistory, 'Candidate lights');
else
    plot(axHistory, result.history(:, 1), 100 * result.history(:, 5), '-o', 'LineWidth', 1.25);
    ylim(axHistory, [0, 105]);
    title(axHistory, 'Greedy coverage by step');
    xlabel(axHistory, 'Step');
    ylabel(axHistory, 'Covered samples (%)');
end
StyleCurrentAxes(axHistory);

end
function RenderInspectorTab(fig)
% Single-pole views: what one selected pole can see and how its matrix rows look.

app = guidata(fig);
tab = app.tabs.inspector;
delete(allchild(tab));

model = app.model;
result = app.result;
params = app.params;

if isempty(result.selected)
    DrawCenteredMessage(tab, 'No selected pole is available to inspect.');
    return;
end

if isempty(app.selectedCandidate) || ~any(result.selected == app.selectedCandidate)
    app.selectedCandidate = result.selected(1);
    guidata(fig, app);
end

candidateIndex = app.selectedCandidate;
selectedOrdinal = find(result.selected == candidateIndex, 1);
candidatePoint = model.candidatePoints(candidateIndex, :);

labels = cell(numel(result.selected), 1);
for k = 1:numel(result.selected)
    point = model.candidatePoints(result.selected(k), :);
    labels{k} = sprintf('%02d: candidate %d at [%d,%d]', k, result.selected(k), point(1), point(2));
end

uicontrol(tab, 'Style', 'text', ...
    'String', 'Selected poles', ...
    'Units', 'normalized', ...
    'Position', [0.03, 0.88, 0.17, 0.05], ...
    'BackgroundColor', 'w', ...
    'ForegroundColor', [0.12 0.12 0.12], ...
    'FontWeight', 'bold', ...
    'HorizontalAlignment', 'left');

uicontrol(tab, 'Style', 'listbox', ...
    'String', labels, ...
    'Value', selectedOrdinal, ...
    'Units', 'normalized', ...
    'Position', [0.03, 0.56, 0.18, 0.31], ...
    'BackgroundColor', 'w', ...
    'ForegroundColor', [0.08 0.08 0.08], ...
    'FontSize', 9, ...
    'Callback', @(src, ~) SelectPoleByOrdinal(fig, get(src, 'Value')));

visibilityValues = double(model.visibility(candidateIndex, :));
intensityValues = model.A(candidateIndex, :);
distanceValues = model.D(candidateIndex, :);
adequateValues = double(intensityValues >= params.threshold);

visibleGrid = ValuesOnGrid(model.roomMap, model.samplePoints, visibilityValues);
intensityGrid = ValuesOnGrid(model.roomMap, model.samplePoints, intensityValues);
adequateGrid = ValuesOnGrid(model.roomMap, model.samplePoints, adequateValues);

visibleCount = sum(visibilityValues > 0);
adequateCount = sum(adequateValues > 0);

uicontrol(tab, 'Style', 'text', ...
    'String', sprintf('Pole %02d at row %d, col %d | visible cells %d | cells above threshold by itself %d', ...
    selectedOrdinal, candidatePoint(1), candidatePoint(2), visibleCount, adequateCount), ...
    'Units', 'normalized', ...
    'Position', [0.24, 0.90, 0.72, 0.05], ...
    'BackgroundColor', 'w', ...
    'ForegroundColor', [0.12 0.12 0.12], ...
    'FontWeight', 'bold', ...
    'HorizontalAlignment', 'left');

axVisible = axes('Parent', tab, 'Units', 'normalized', 'Position', [0.24, 0.54, 0.22, 0.32]);
visibleImage = imagesc(axVisible, visibleGrid);
set(visibleImage, 'AlphaData', ~isnan(visibleGrid));
axis(axVisible, 'image');
axis(axVisible, 'ij');
set(axVisible, 'Color', [0.08 0.08 0.08]);
colormap(axVisible, [0.96 0.96 0.96; 0.12 0.62 0.35]);
caxis(axVisible, [0, 1]);
hold(axVisible, 'on');
plot(axVisible, candidatePoint(2), candidatePoint(1), 'o', ...
    'MarkerEdgeColor', [0.05 0.05 0.05], ...
    'MarkerFaceColor', [1.00 0.85 0.15], ...
    'MarkerSize', 8);
hold(axVisible, 'off');
title(axVisible, 'What this pole can see: V_i');
xlabel(axVisible, 'Column');
ylabel(axVisible, 'Row');
StyleCurrentAxes(axVisible);

axIntensity = axes('Parent', tab, 'Units', 'normalized', 'Position', [0.50, 0.54, 0.22, 0.32]);
intensityImage = imagesc(axIntensity, intensityGrid);
set(intensityImage, 'AlphaData', ~isnan(intensityGrid));
axis(axIntensity, 'image');
axis(axIntensity, 'ij');
set(axIntensity, 'Color', [0.08 0.08 0.08]);
colormap(axIntensity, hot(256));
caxis(axIntensity, [0, max(params.threshold, SortedQuantile(intensityValues, 0.95))]);
StyledColorbar(axIntensity);
hold(axIntensity, 'on');
plot(axIntensity, candidatePoint(2), candidatePoint(1), 'co', 'MarkerSize', 7, 'LineWidth', 1.25);
hold(axIntensity, 'off');
title(axIntensity, 'Solo intensity row A_i on the map');
xlabel(axIntensity, 'Column');
ylabel(axIntensity, 'Row');
StyleCurrentAxes(axIntensity);

axEnough = axes('Parent', tab, 'Units', 'normalized', 'Position', [0.76, 0.54, 0.22, 0.32]);
adequateImage = imagesc(axEnough, adequateGrid);
set(adequateImage, 'AlphaData', ~isnan(adequateGrid));
axis(axEnough, 'image');
axis(axEnough, 'ij');
set(axEnough, 'Color', [0.08 0.08 0.08]);
colormap(axEnough, [0.96 0.96 0.96; 1.00 0.75 0.10]);
caxis(axEnough, [0, 1]);
hold(axEnough, 'on');
plot(axEnough, candidatePoint(2), candidatePoint(1), 'ko', 'MarkerSize', 7, 'LineWidth', 1.25);
hold(axEnough, 'off');
title(axEnough, 'Cells this pole lights above tau');
xlabel(axEnough, 'Column');
ylabel(axEnough, 'Row');
StyleCurrentAxes(axEnough);

rowStart = 0.31;
rowHeight = 0.050;
rowGap = 0.120;
DrawMatrixRowStrip(tab, distanceValues, [0.24, rowStart, 0.72, rowHeight], ...
    'D_i row: distance from this pole to each sample point', parula(256), [], false);
DrawMatrixRowStrip(tab, visibilityValues, [0.24, rowStart - rowGap, 0.72, rowHeight], ...
    'V_i row: 1 means line-of-sight is clear', gray(2), [0, 1], false);
DrawMatrixRowStrip(tab, intensityValues, [0.24, rowStart - 2 * rowGap, 0.72, rowHeight], ...
    'A_i row: intensity from this pole after falloff and walls', hot(256), [0, max(params.threshold, SortedQuantile(intensityValues, 0.95))], true);

end
function DrawMatrixRowStrip(parent, values, position, titleText, colorMap, colorLimits, showXLabel)
% Draw one matrix row as a heat strip.

if nargin < 7
    showXLabel = true;
end

ax = axes('Parent', parent, 'Units', 'normalized', 'Position', position);
imagesc(ax, values(:).');
axis(ax, 'tight');
set(ax, 'YTick', []);
colormap(ax, colorMap);
if ~isempty(colorLimits)
    caxis(ax, colorLimits);
end
StyledColorbar(ax);
titleHandle = title(ax, titleText);
set(titleHandle, 'FontSize', 9);
if showXLabel
    xlabel(ax, 'Sample point index j');
else
    set(ax, 'XTickLabel', []);
end
StyleCurrentAxes(ax);

end
function SelectPoleByOrdinal(fig, selectedOrdinal)
% Listbox callback for the selected-pole inspector.

app = guidata(fig);
selectedOrdinal = min(max(round(selectedOrdinal), 1), numel(app.result.selected));
app.selectedCandidate = app.result.selected(selectedOrdinal);
guidata(fig, app);
set(app.tabGroup, 'SelectedTab', app.tabs.inspector);
RenderSolutionTab(fig);
RenderInspectorTab(fig);

end
function SelectNearestPoleFromClick(fig, ax)
% Map callback: choose the selected pole nearest to the click location.

app = guidata(fig);
if isempty(app.result.selected)
    return;
end

point = get(ax, 'CurrentPoint');
clicked = [point(1, 2), point(1, 1)];
selectedPoints = app.model.candidatePoints(app.result.selected, :);
distances = sum((selectedPoints - clicked).^2, 2);
[~, nearestOrdinal] = min(distances);

app.selectedCandidate = app.result.selected(nearestOrdinal);
guidata(fig, app);
set(app.tabGroup, 'SelectedTab', app.tabs.inspector);
RenderSolutionTab(fig);
RenderInspectorTab(fig);

end
function HighlightCurrentPole(ax, model, candidateIndex)
% Add a magenta ring around the pole currently selected in the inspector.

if isempty(candidateIndex)
    return;
end

point = model.candidatePoints(candidateIndex, :);
plot(ax, point(2), point(1), 'o', ...
    'MarkerSize', 13, ...
    'LineWidth', 2.0, ...
    'MarkerEdgeColor', [0.85 0.00 0.70], ...
    'MarkerFaceColor', 'none');

end
function DrawCenteredMessage(parent, message)
% Simple fallback text for empty states.

uicontrol(parent, 'Style', 'text', ...
    'String', message, ...
    'Units', 'normalized', ...
    'Position', [0.05, 0.45, 0.90, 0.10], ...
    'BackgroundColor', 'w', ...
    'ForegroundColor', [0.12 0.12 0.12], ...
    'FontSize', 13, ...
    'FontWeight', 'bold');

end
function indices = PreviewIndices(totalCount, maxCount)
% Return evenly spaced indices so large matrices stay readable in figures.

if totalCount <= maxCount
    indices = 1:totalCount;
else
    indices = unique(round(linspace(1, totalCount, maxCount)));
end

end
function value = SortedQuantile(values, proportion)
% Toolbox-free quantile for plot scaling.

sortedValues = sort(values(:));
index = ceil(proportion * numel(sortedValues));
index = min(max(index, 1), numel(sortedValues));
value = sortedValues(index);

end
function cmap = BlueWhiteRedMap(n)
% Blue for below-threshold cells, white near zero, red for extra margin.

if nargin < 1
    n = 256;
end

lowerCount = floor(n / 2);
upperCount = n - lowerCount;
lower = [linspace(0.10, 1.00, lowerCount).', ...
         linspace(0.30, 1.00, lowerCount).', ...
         ones(lowerCount, 1)];
upper = [ones(upperCount, 1), ...
         linspace(1.00, 0.20, upperCount).', ...
         linspace(1.00, 0.15, upperCount).'];
cmap = [lower; upper];

end
function cmap = IntegerOverlapMap(numLevels)
% Discrete colors for integer visibility-overlap counts.

numLevels = max(1, round(numLevels));

if numLevels == 1
    cmap = [0.94 0.94 0.94];
    return;
end

countColors = parula(numLevels - 1);
cmap = [0.94 0.94 0.94; countColors];

end
function StyleCurrentAxes(ax)
% Keep plot text readable even when MATLAB uses a dark UI theme.

if nargin < 1
    ax = gca;
end

textColor = [0.15 0.15 0.15];
if isempty(findobj(ax, 'Type', 'image'))
    set(ax, 'Color', [1 1 1]);
end
set(ax, 'XColor', textColor, 'YColor', textColor, 'LineWidth', 1.0);
set(get(ax, 'Title'), 'Color', textColor, 'FontWeight', 'bold');
set(get(ax, 'XLabel'), 'Color', textColor);
set(get(ax, 'YLabel'), 'Color', textColor);

end
function cb = StyledColorbar(ax)
% Keep colorbar labels readable on white figures.

if nargin < 1
    ax = gca;
end

cb = colorbar(ax);
set(cb, 'Color', [0.15 0.15 0.15]);

end
function SetBackgroundIfPossible(handleObject, colorValue)
% Some MATLAB graphics objects support BackgroundColor and some do not.

try
    set(handleObject, 'BackgroundColor', colorValue);
catch
end

end
function gridValues = ValuesOnGrid(roomMap, samplePoints, sampleValues)
% Convert a vector over sample points back into a 2D grid for plotting.

gridValues = nan(size(roomMap));
indices = sub2ind(size(roomMap), samplePoints(:, 1), samplePoints(:, 2));
gridValues(indices) = sampleValues;

end
