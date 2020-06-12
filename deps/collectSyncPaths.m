function paths = collectSyncPaths(basePath, varargin)
    if ~isempty(varargin)
        key = varargin{1};
        fn = dir(fullfile(basePath,'sync',key));
    else
        fn = dir(fullfile(basePath,'sync','*sync.mat'));
    end
    paths = cell(numel(fn),1);
    for nFile = 1:numel(fn)
        paths{nFile} = fullfile(fn(nFile).folder, fn(nFile).name);
    end
end