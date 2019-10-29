%% Example setup for Label3D
% Label3D is a GUI for manual labeling of 3D keypoints in multiple cameras. 
% 
% Its main features include:
% 1. Simultaneous viewing of any number of camera views. 
% 2. Multiview triangulation of 3D keypoints.
% 3. Point-and-click and draggable gestures to label keypoints. 
% 4. Zooming, panning, and other default Matlab gestures
% 5. Integration with Animator classes. 
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

%% Load in the calibration parameter data
params3 = load('/home/diego/cluster/Diego/code/DANNCE/demo/calibrd18_black6_mouseone_green/calibration/hires_cam1_params.mat');
params1 = load('/home/diego/cluster/Diego/code/DANNCE/demo/calibrd18_black6_mouseone_green/calibration/hires_cam2_params.mat');
params2 = load('/home/diego/cluster/Diego/code/DANNCE/demo/calibrd18_black6_mouseone_green/calibration/hires_cam3_params.mat');
params = {params1, params2, params3};

%% Load the videos into memory
vid_paths{1} = '/home/diego/cluster/Diego/code/DANNCE/demo/calibrd18_black6_mouseone_green/videos/CameraLmouse/636975888610580066/7000.mp4';
vid_paths{2} = '/home/diego/cluster/Diego/code/DANNCE/demo/calibrd18_black6_mouseone_green/videos/CameraRmouse/636975888633320066/7000.mp4';
vid_paths{3} = '/home/diego/cluster/Diego/code/DANNCE/demo/calibrd18_black6_mouseone_green/videos/CameraSmouse/636975888673340066/7000.mp4';
videos = cell(3,1);
for nVid = 1:numel(vid_paths)
    vid = VideoReader(vid_paths{nVid});
    V = {};
    count = 1;
    camParams = cameraParameters('IntrinsicMatrix',params{nVid}.K,'ImageSize',[1048 1328], 'RadialDistortion',params{nVid}.RDistort, 'TangentialDistortion',params{nVid}.TDistort);
    while hasFrame(vid)
        V{count} = readFrame(vid);
        count = count+1;
        if count == 101
            break;
        end
    end
    V = cat(4, V{1:100});
    videos{nVid} = V;
end

%% Get the data in an appropriate format
% Set up data variables
markers = cell(3,1);
nMarkers = 9;
nFrames = size(videos{1},4);

% Set up the skeleton
C = othercolor('RdYlBu_11b',nMarkers-1);
skeleton.color = C([1 8 5 5 2 7 3 6],:);
skeleton.joints_idx = [1 2; 1 3; 1 4; 4 5; 4 6 ; 4 7; 5 8; 5 9];
skeleton.joint_names = {'Nose','Ear R', 'Ear L', 'Spine M','Tail','R Forepaw','L Forepaw','R Hindpaw','L Hindpaw'};

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
