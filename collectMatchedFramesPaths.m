function paths = collectMatchedFramesPaths(basePath)
    fn = dir(fullfile(basePath,'data','*MatchedFrames.mat')); 
    paths = cell(numel(fn),1);
    for nFile = 1:numel(fn)
        paths{nFile} = fullfile(fn(nFile).folder, fn(nFile).name);
    end
end