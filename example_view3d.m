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
projectFolder = '/Users/caxon/olveczky/dannce_data/240116_151948_F7';
dannceOutputDataFile = '/Users/caxon/olveczky/dannce_data/240116_151948_F7/save_data_AVG0.mat';

% % number of frames to label from each video. Suggested 100-200.
nFramesToLoad = 500;

% skeleton file to load (expected in ./skeletons directory)
skeletonFile = "rat23.mat";

% number of animals: will create a skeleton with multiple animals
nAnimals = 1;

% if enabled, will store the video files as a seperate file you can load
% from later (filename= labeling/frameCache_..._.mat)
% enableVideoCache = true;

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
nTotalFrames = nFramesToLoad * nVideos;

% load first n frames
framesToLoad = 1:nFramesToLoad;

%% Load video frames into memory (slow)

fprintf(['Reading video frames with the following parameters:\n'...
    '\tnumber of videos: %d\n'...
    '\twidth x height: (%d x %d)\n'...
    '\ttotal number of frames: %d\n'...
    '\tframes to read per video: %d\n'], ...
    nVideos, videoWidth, videoHeight, nFramesWholeVideo, nFramesToLoad)

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
    
    dest = zeros(videoHeight, videoWidth, 3, nFramesToLoad, 'uint8');
    
    % Iterate over all framesToLoad
    for frameIdx = 1 : nFramesToLoad
        frameNumber = framesToLoad(frameIdx);
        dest(:, :, :, frameIdx) = vr.read(frameNumber);
        
        % Print progress every 20 frames (will be jumbled w. parallel)
        if mod(frameIdx, 20) == 0
            fprintf("\tloaded frame #%d of %d. Vid #%d of %d.\n", ...
                frameIdx, nFramesToLoad, videoIdx, nVideos );
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


% %% Start View3D 

viewGui = View3D(calibrationParams, videos, skeleton);

dannce_output_data=load(dannceOutputDataFile);

pts3d = reshape(dannce_output_data.pred, nFramesToLoad, 3, 23);
viewGui.loadFrom3D(pts3d)
