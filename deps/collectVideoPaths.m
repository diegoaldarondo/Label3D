function paths = collectVideoPaths(basePath, vidName, varargin)
%% Collect .mp4 video paths
%  Syntax: paths = collectVideoPaths(PathToBaseFolder, '0.mp4');
%     fn = dir(fullfile(basePath,'videos','*mouseOG','*',vidName)); 
    if ~isempty(varargin)
       key = varargin{1}; 
       fn = dir(fullfile(basePath,key,vidName)); 
    else
       fn = dir(fullfile(basePath,'videos','*mouse','*',vidName)); 
    end
    paths = cell(numel(fn),1);
    for nFile = 1:numel(fn)
        paths{nFile} = fullfile(fn(nFile).folder, fn(nFile).name);
    end
end