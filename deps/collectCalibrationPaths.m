function paths = collectCalibrationPaths(basePath, varargin)
    if ~isempty(varargin)
        key = varargin{1};
        fn = dir(fullfile(basePath, 'calibration', key)); 
    else
        fn = dir(fullfile(basePath, 'calibration', '*_params.mat')); 
    end
    paths = cell(numel(fn),1);
    for nFile = 1:numel(fn)
        paths{nFile} = fullfile(fn(nFile).folder, fn(nFile).name);
    end
end