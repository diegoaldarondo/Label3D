function frames = loadFramesFromFolder(folder, frameIds, chunkSize, varargin)
    p = inputParser;
    addParameter(p,'greyScale',false);
    parse(p, varargin{:});
    p = p.Results;
    
    [frameIds, I] = sort(frameIds);
    videos = dir(fullfile(folder, '*.mp4'));
    nVideos = numel(videos);
    frames = cell(nVideos,1);
    for nVid = 1:nVideos
        cur = (nVid-1)*chunkSize;
        next = (nVid)*chunkSize;
        framesInVid = frameIds >= cur & frameIds < next;
        if sum(framesInVid) > 0
            framesToLoad = frameIds(framesInVid);
            framesToLoad = framesToLoad - (nVid-1)*chunkSize + 1;
            vidPath = fullfile(folder, sprintf('%d.mp4', cur));
            disp(sprintf('Loading %s', vidPath))
            frames{nVid} = readFrames(vidPath, framesToLoad, p.greyScale);
        end
    end
    frames = cat(4, frames{:});
    frames(:, :, :, I) = frames;
end