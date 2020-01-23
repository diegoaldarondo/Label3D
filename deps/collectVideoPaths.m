function paths = collectVideoPaths(basePath, vidName)
%% Collect .mp4 video paths
%  Syntax: paths = collectVideoPaths(PathToBaseFolder, '0.mp4');
    fn = dir(fullfile(basePath,'videos','*','*',vidName)); 
    paths = cell(numel(fn),1);
    for nFile = 1:numel(fn)
        paths{nFile} = fullfile(fn(nFile).folder, fn(nFile).name);
    end
end