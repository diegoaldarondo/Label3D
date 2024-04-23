%% Example setup for Label3D
% Label3D is a GUI for manual labeling of 3D keypoints in multiple cameras.
%
% Its main features include:
% 1. Simultaneous viewing of any number of camera views.
% 2. Multiview triangulation of 3D keypoints.
% 3. Point-and-click and draggable gestures to label keypoints.
% 4. Zooming, panning, and other default Matlab gestures
% 5. Integration with Animator classes.
% 6. Support for editing prelabeled data.
%
% Instructions:
% right: move forward one frameRate
% left: move backward one frameRate
% up: increase the frameRate
% down: decrease the frameRate
% t: triangulate points in current frame that have been labeled in at least two images and reproject into each image
% r: reset gui to the first frame and remove Animator restrictions
% u: reset the current frame to the initial marker positions
% z: Toggle zoom state
% p: Show 3d animation plot of the triangulated points.
% backspace: reset currently held node (first click and hold, then
%            backspace to delete)
% pageup: Set the selectedNode to the first node
% tab: shift the selected node by 1
% shift+tab: shift the selected node by -1
% h: print help messages for all Animators
% shift+s: Save the data to a .mat file

% This example assumes that video files are already synchronized
% I.e. by hardware (arduino). No sync variable used.

clear all;
close all;
addpath(genpath('deps'));
addpath(genpath('skeletons'));


%% Configuration variables -- SET THESE BEFORE RUNNING
% Path to the DANNCE project folder
% This folder should contain at least the following folders: "videos", "calibration"
projectFolder = 'C:\data\F5-F7_openfield_photometry\alone\day1\240116_151948_F7';

% number of frames to label from each video. Suggested 100-200.
nFramesToLabel = 75;

% skeleton file to load (expected in ./skeletons directory)
skeletonFile = "rat23.mat";

% number of animals: will create a skeleton with multiple animals
nAnimals = 1;

% if enabled, will store the video files as a seperate file you can load
% from later (filename= labeling/frameCache_..._.mat)
enableVideoCache = true;

% Recommended: keep this enabled UNLESS you do not have matlab licesnse for 
% the Parallel Processing Toolbox. Speeds up loading frames ~2x if enabled.
useParallel = true;


%% Locate file paths and set up environment
calibrationPaths = collectCalibrationPaths(projectFolder, "hires_cam*_params.mat");
calibrationParams = cellfun(@(X) {load(X)}, calibrationPaths);

videoName = "0.mp4";
videoPaths = collectVideoPaths(projectFolder, videoName);

% create label folder if does not exist
labelingFolder = fullfile(projectFolder, "labeling");
warnState = warning('off', 'MATLAB:MKDIR:DirectoryExists');
mkdir(labelingFolder)
warning(warnState)

% Load the skeleton
skeleton = load(fullfile("skeletons", skeletonFile));

% Optionally dupilcate skeleton for > 1 animals:
if nAnimals > 1
    skeleton = multiAnimalSkeleton(skeleton, nAnimals);
end


%% Get quick stats from first video file

% load one video to determine video dimensions
vr = VideoReader(videoPaths{1});

nVideos = length(videoPaths);

videoWidth = vr.Width;
videoHeight = vr.Height;
nFramesWholeVideo = vr.NumFrames;
nTotalFrames = nFramesToLabel * nVideos;

% load evenly spaced frames across the whole video
framesToLabel = round(linspace(1, nFramesWholeVideo, nFramesToLabel));

% rough estimation for total load time. May vary depending on computer.
% will be faster if parallel processing is enabled
estimatedLoadTime = ceil((0.10 * nTotalFrames + 4 * nVideos) / 15) * 15;


%% Maybe load from cache

frameCacheFilename = strcat('frameCache_','f', ...
    num2str(nFramesToLabel), '.mat');
frameCacheFilePath = fullfile(labelingFolder, frameCacheFilename);

videos = cell(nVideos, 1);
usedCache = 0;

if enableVideoCache
    if isfile(frameCacheFilePath)
        fprintf("trying cache file: %s\n", frameCacheFilename)
        % try to load file from cache instead
        frameCacheMeta = load(frameCacheFilePath, ...
            "framesToLabel", "videoPaths", "videoWidth", "videoHeight");
        % if the cache matches current parameters, use it instead
        if isequaln(framesToLabel, frameCacheMeta.framesToLabel) && ...
            isequaln(videoPaths, frameCacheMeta.videoPaths) && ...
            isequaln(videoWidth, frameCacheMeta.videoWidth) && ...
            isequaln(videoHeight, frameCacheMeta.videoHeight)

            fprintf("Using video files from cache. May take a few seconds...\n")
            frameCacheData = load(frameCacheFilePath, "videos");
            videos = frameCacheData.videos;
            usedCache = 1;
        else
            fprintf("Frames have changed in cache, loading videos normally " + ...
                "and overwriting cache\n")
        end
    end
else
    disp("Cache disabled. Ignoring cache if present.")
end


%% Load video frames into memory (slow)

if ~usedCache
    fprintf(['Reading video frames with the following parameters:\n'...
        '\tnumber of videos: %d\n'...
        '\twidth x height: (%d x %d)\n'...
        '\ttotal number of frames: %d\n'...
        '\tframes to read per video: %d\n'], ...
        nVideos, videoWidth, videoHeight, nFramesWholeVideo, nFramesToLabel)
    
    fprintf("Estimated load time about %d sec\n\n", estimatedLoadTime)
    
    tic;
    
    if useParallel
        delete(gcp('nocreate')); % make sure no parallel pool is currently running
        parpool("Threads"); % create parallel pool for loading video frames
        % threads is much faster to start up than processes
    end
    
    parfor videoIdx = 1 : nVideos
        fprintf("Started video #%d\n", videoIdx);
        thisPath = videoPaths{videoIdx};
        vr = VideoReader(thisPath);
        
        dest = zeros(videoHeight, videoWidth, 3, nFramesToLabel, 'uint8');
        
        % Iterate over all framesToLabel
        for frameIdx = 1 : nFramesToLabel
            frameNumber = framesToLabel(frameIdx);
            dest(:, :, :, frameIdx) = vr.read(frameNumber);
            
            % Print progress every 20 frames (will be jumbled w. parallel)
            if mod(frameIdx, 20) == 0
                fprintf("\tloaded frame #%d of %d. Vid #%d of %d.\n", ...
                    frameIdx, nFramesToLabel, videoIdx, nVideos );
            end
        end
        
        videos{videoIdx} = dest;
        
        fprintf("Finished video #%d\n", videoIdx);
    end
    
    if useParallel
        delete(gcp('nocreate')); % release parallel resources
    end
    
    sEllapsed = toc;
    
    fprintf("Loaded %d frames in %.2f seconds (%.2f fps)\n\n", ...
        nTotalFrames, sEllapsed, nTotalFrames/sEllapsed);
end


%% Optionally cache video files to resume loading later
if enableVideoCache && ~usedCache
    % note preceding "" converts char arrays to string
    frameCacheFilename = strcat('frameCache_','f', ...
        num2str(nFramesToLabel), '.mat');
    frameCacheFilePath = fullfile(labelingFolder, frameCacheFilename);

    if isfile(frameCacheFilePath)
        fprintf("cache exists, using file: %s\n", frameCacheFilename)
    else
        fprintf("Saving video cache in labeling folder: %s\n", ...
        frameCacheFilename);
        disp('May take a few seconds...\n')
        cacheTime=datetime("now");
        save(frameCacheFilePath, "videos", "framesToLabel",  ...
            "videoPaths", "videoWidth","videoHeight", "nFramesWholeVideo", ...
            "cacheTime", "-v7.3")
    end
end


%% Start Label3D
close all;
fprintf("Launching Label3D. May take a few seconds...\n")
labelGui = Label3D(calibrationParams, videos, skeleton, ...
    'framesToLabel', framesToLabel, ...
    'savePath', labelingFolder);

%% Check the camera positions
% labelGui.plotCameras

%% If you just wish to view labels, use View 3D
% close all
% viewGui = View3D(calibrationParams, videos, skeleton);

%% You can load both in different ways
% close all;
% View3D()
