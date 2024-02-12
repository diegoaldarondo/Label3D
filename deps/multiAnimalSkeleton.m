function newSkeleton = multiAnimalSkeleton(baseSkeleton, nAnimals)
    % duplicate an animal skeleton n times e.g. for multi-animal labeling
    % Also assigns a unique marker color to each skeleton (skeleton.marker_color)

    % E.g. usage: 
    % rat23 = load('skeletons/rat23')
    % rat23_2 = multiAnimalSkeleton(rat23, 2)
    % pass rat23_2 as skeleton parameter when starting label3d

    % Copy the baseSkeleton struct so we do not modify the original
    newSkeleton = baseSkeleton;

    nMarkers = length(baseSkeleton.joint_names);
    nConnections = size(baseSkeleton.joints_idx, 1);
    
    jointNamesPrefix = repmat(baseSkeleton.joint_names, 1, nAnimals);
    jointNamesPostfix = num2cell(repelem((1:nAnimals)', nMarkers, 1))';
    jointNamesCombined = cellfun(@(x,y) strcat( x, '_', num2str(y) ) , ...
        jointNamesPrefix, jointNamesPostfix, 'UniformOutput', false);


    newSkeleton.joint_names = jointNamesCombined;

    adjMatrixBase = repmat(baseSkeleton.joints_idx, nAnimals, 1);
    adjMatrixModifier = (repelem(repmat((1:nAnimals)', 1, 2), ...
        nConnections, 1) - 1) * nMarkers;
    jointIndex = adjMatrixBase + adjMatrixModifier;

    newSkeleton.joints_idx = jointIndex;

    connectionColors = repmat(baseSkeleton.color, nAnimals, 1);
    newSkeleton.color = connectionColors;

    uniqueColors = customColorMap(nAnimals);
    markerColors = repelem(uniqueColors, nMarkers , 1);
    newSkeleton.marker_colors = markerColors;
end

