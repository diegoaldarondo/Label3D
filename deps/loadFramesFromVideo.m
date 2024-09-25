
function videos = loadFramesFromVideo(filepaths, framesToLoad, kwargs)
arguments
    filepaths
    framesToLoad (1,:) double
    kwargs.useParallel logical = true
    kwargs.forceLoadOneCamera logical = false
    % kwargs.cacheFile string = ''
    kwargs.progressInterval {mustBeInteger}
end

tic()

useParallel = kwargs.useParallel;
nCameras = length(filepaths);
if nCameras == 1 && not(kwargs.forceLoadOneCamera)
    ME = MException("loadFramesFromVideo:error", strcat("Trying to load one camera. Is it possible you specified your ", ...
        "video list with single quotes instead of double quotes? If this is intentional, ", ...
        "add the argument forceLoadOneCamera=true"));
    throw(ME)
end

nFramesToLoad=size(framesToLoad, 2);

if nFramesToLoad > 1000
    ME = MException("loadFramesFromVideo:error", strcat("Trying to load more ",...
        "than 1000 frames. This is probably an erorr and would take a very long time"));
    throw(ME)
end


vr = VideoReader(filepaths{1});
videoWidth = vr.Width;
videoHeight = vr.Height;

videos = cell(nCameras, 1);
fcn = @loadSingleVideo;

fprintf("Loading %d frames per camera\n", nFramesToLoad)

if useParallel
    delete(gcp('nocreate')); % make sure no parallel pool is currently running
    parpool("Threads", nCameras); % create parallel pool for loading video frames
    % threads is much faster to start up than processes
    parfor videoIdx = 1 : nCameras
        thisPath = filepaths{videoIdx};
        videos{videoIdx} = feval(fcn, thisPath, videoWidth, videoHeight,framesToLoad, nFramesToLoad);
    end
    delete(gcp('nocreate')); % release parallel resources
else
    % DO NOT USE PARALLEL TO LOAD
    for videoIdx = 1 : nCameras
        thisPath = filepaths{videoIdx};
        videos{videoIdx} = feval(fcn, thisPath, videoWidth, videoHeight,framesToLoad, nFramesToLoad);
    end
    
end

sEllapsed = toc();

fprintf("Loaded %d frames in %.2f seconds (%.2f fps)\n\n", ...
    nFramesToLoad*nCameras, sEllapsed, nFramesToLoad*nCameras/sEllapsed);

end

function dest = loadSingleVideo(thisPath, videoWidth,videoHeight, framesToLoad, nFramesToLoad)
vr = VideoReader(thisPath);
dest = zeros(videoHeight, videoWidth, 3, nFramesToLoad, 'uint8');
% Iterate over all framesToLabel
for frameIdx = 1 : nFramesToLoad
    frameNumber = framesToLoad(frameIdx);
    dest(:, :, :, frameIdx) = vr.read(frameNumber);
end
end
