function paths = collectVideoPaths(basePath, vidName, varargin)
%% Collect .mp4 video paths
%  Syntax: paths = collectVideoPaths(PathToBaseFolder, '0.mp4');
%     fn = dir(fullfile(basePath,'videos','*mouseOG','*',vidName)); 
    if ~isempty(varargin)
       key = varargin{1}; 
       fn = dir(fullfile(basePath,'videos',key,vidName));
       if isempty(fn)
          fn = dir(fullfile(basePath,'videos',key,'*',vidName));
       end
    else
       fn = dir(fullfile(basePath,'videos','Camera*','*',vidName)); 
       if isempty(fn)
           fn = dir(fullfile(basePath,'videos','Camera*',vidName));
       end
    end
    paths = cell(numel(fn),1);
    for nFile = 1:numel(fn)
        paths{nFile} = fullfile(fn(nFile).folder, fn(nFile).name);
    end
end