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
clear all
close all;
addpath(genpath('deps'))
addpath(genpath('skeletons'))

%% Load in the calibration parameter data
params3 = load('Y:/Diego/code/DANNCE/demo/calibrd18_black6_mouseone_green/calibration/hires_cam1_params.mat');
params1 = load('Y:/Diego/code/DANNCE/demo/calibrd18_black6_mouseone_green/calibration/hires_cam2_params.mat');
params2 = load('Y:/Diego/code/DANNCE/demo/calibrd18_black6_mouseone_green/calibration/hires_cam3_params.mat');
params = {params1, params2, params3};

%% Load the videos into memory
vid_paths{1} = 'Y:/Diego/code/DANNCE/demo/calibrd18_black6_mouseone_green/videos/CameraLmouse/636975888610580066/7000.mp4';
vid_paths{2} = 'Y:/Diego/code/DANNCE/demo/calibrd18_black6_mouseone_green/videos/CameraRmouse/636975888633320066/7000.mp4';
vid_paths{3} = 'Y:/Diego/code/DANNCE/demo/calibrd18_black6_mouseone_green/videos/CameraSmouse/636975888673340066/7000.mp4';
videos = cell(3,1);
for nVid = 1:numel(vid_paths)
    vid = readFrames(vid_paths{nVid}, 1:100);
    videos{nVid} = vid;
end

%% Get the data in an appropriate format
% Set up data variables
markers = cell(3,1);
nMarkers = 9;
nFrames = size(videos{1},4);

% Set up the skeleton
C = lines(nMarkers - 1);
skeleton = load('skeletons/rat16');

% If you have data from previous sessions, you can initialize data with the
% 'markers' Name Value parameter. 
% init = 1.0e+03 * [1.2122 1.1287 1.1693 1.1048 1.0786 1.1406 1.1860 1.0810 1.1645; 0.8597 0.8340 0.8028 0.8799 0.9461 0.9295 0.8983 1.0030 0.9736]';
% markers{1} = repmat(reshape(init',1,2,[]),nFrames,1,1);
% markers{2} = repmat(reshape(init',1,2,[]),nFrames,1,1);
% markers{3} = repmat(reshape(init',1,2,[]),nFrames,1,1);

%% Start Label3D
close all
labelGui = Label3D(params, videos, skeleton);

%% Check the camera positions
labelGui.plotCameras       

%% If you just wish to view labels, use View 3D
close all
viewGui = View3D(params, videos, skeleton);

%% You can load both in different ways
close all;
View3D()