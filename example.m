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
projectFolder = '~/olveczky/dannce_data/example_dannce_project_folder';
% number of frames to label from each video. Suggested 100-200.
nFramesToLabel = 10;


%% Locate file paths and set up environment
calibrationPaths = collectCalibrationPaths(projectFolder, 'hires_cam*_params.mat');
calibrationParams = cellfun(@(X) {load(X)}, calibrationPaths);

videoName = '0.mp4';
videoPaths = collectVideoPaths(projectFolder, videoName);

% create label folder if does not exist
labelingFolder = fullfile(projectFolder, "labeling");
warnState = warning('off','MATLAB:MKDIR:DirectoryExists');
mkdir(labelingFolder)
warning(warnState)

%% Load video frames into memory (slow)

% load one video to determine video dimensions
vr = VideoReader(videoPaths{1});

nVideos = length(videoPaths);

videoWidth = vr.Width;
videoHeight = vr.Height;
nFramesWholeVideo = vr.NumFrames;
nTotalFrames = nFramesToLabel * nVideos;

% rough estimation for total load time. May vary depending on computer.
% will be faster if parallel processing is enabled
estimatedLoadTime = ceil((0.10 * nTotalFrames + 4 * nVideos) / 15) * 15;

% load evenly spaced frames across the whole video
framesToLabel = round(linspace(1, nFramesWholeVideo, nFramesToLabel));

fprintf(['Reading video frames with the following parameters:\n'...
    '\tnumber of videos: %d\n'...
    '\twidth x height: (%d x %d)\n'...
    '\ttotal number of frames: %d\n'...
    '\tframes to read per video: %d\n'], ...
    nVideos, videoWidth, videoHeight, nFramesWholeVideo, nFramesToLabel)

fprintf("Estimated load time about %d sec\n\n", estimatedLoadTime)

videos = cell(nVideos, 1);

tic;

delete(gcp('nocreate')); % make sure no parallel pool is currently running
parpool("Threads"); % create parallel pool for loading video frames
% threads is much faster to load than processes

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

delete(gcp('nocreate')); % release parallel resources

sEllapsed = toc;

fprintf("Loaded %d frames in %.2f seconds (%.2f fps)\n\n", ...
    nTotalFrames, sEllapsed, nTotalFrames/sEllapsed);

%% Load the skeleton
skeleton = load('skeletons/rat23.mat');

%% Start Label3D
close all;
fprintf("Launching Label3D. May take a few seconds...\n")
labelGui = Label3D(calibrationParams, videos, skeleton, ...
    'savePath', labelingFolder);

%% Check the camera positions
% labelGui.plotCameras

%% If you just wish to view labels, use View 3D
% close all
% viewGui = View3D(calibrationParams, videos, skeleton);

%% You can load both in different ways
% close all;
% View3D()
