function paths = collectCalibrationPaths(basePath)
    fn = dir(fullfile(basePath, 'calibration', 'hires_cam*_params.mat')); 
    paths = cell(numel(fn),1);
    for nFile = 1:numel(fn)
        paths{nFile} = fullfile(fn(nFile).folder, fn(nFile).name);
    end
end