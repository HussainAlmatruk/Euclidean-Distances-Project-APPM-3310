function label = FormatMapId(mapId)
% Format map IDs for console output.

if ischar(mapId)
    label = mapId;
else
    label = num2str(mapId);
end

end
