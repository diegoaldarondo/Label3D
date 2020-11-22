function frames = loadFramesFromFolder(folder, frameIds, maxFrame, varargin)
    p = inputParser;
    addParameter(p,'greyScale',false);
    parse(p, varargin{:});
    p = p.Results;
    
    [frameIds, frameI] = sort(frameIds);
    videos = dir(fullfile(folder, '*.mp4'));
    videoFrames = zeros(numel(videos),1);
    for i = 1:numel(videos)
        [~,name,~] = fileparts(videos(i).name);
        videoFrames(i) = str2double(name);
    end
    [videoFrames, I] = sort(videoFrames);
    videos = videos(I);
    nVideos = numel(videos);
    frames = cell(nVideos,1);
    
    
    for nVid = 1:nVideos
        cur = videoFrames(nVid);
        if nVid == nVideos
            next = maxFrame;
        else
            next = videoFrames(nVid+1);
        end
        framesInVid = (frameIds > cur) & (frameIds <= next);
        if sum(framesInVid) > 0
            framesToLoad = frameIds(framesInVid);
            framesToLoad = framesToLoad - cur;
            vidPath = fullfile(folder, sprintf('%d.mp4', cur));
            disp(sprintf('Loading %s', vidPath))
            frames{nVid} = readFrames(vidPath, framesToLoad, p.greyScale);
        end
    end
    
    
    frames = cat(4, frames{:});
%     frames(:, :, :, frameI) = frames;
end