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
danncePath = 'Y:/Diego/code/DANNCE';

%% Load in the calibration parameter data
% projectFolder = fullfile(danncePath,'demo/markerless_mouse_1');
projectFolder = 'Y:/Everyone/dannce_rig/dannce_ephys/art/2020_12_23_1';
projectFolder = "./social_videos";
% projectFolder = fullfile(danncePath,'demo/markerless_mouse_1');
calibPaths = collectCalibrationPaths(projectFolder);
params = cellfun(@(X) {load(X)}, calibPaths);

%% Load the videos into memory
vidName = '0.mp4';
vidPaths = collectVideoPaths('./social_videos',vidName);
videos = cell(6,1);
sync = collectSyncPaths(projectFolder, '*.mat');
sync = cellfun(@(X) {load(X)}, sync);

% In case the demo folder uses the dannce.mat data format. 
if isempty(sync)
    dannce_file = dir(fullfile(projectFolder, '*dannce.mat'));
    dannce = load(fullfile(dannce_file(1).folder, dannce_file(1).name));
    sync = dannce.sync;
    params = dannce.params;
end

vidPaths = vidPaths(1:2);
videos = videos(1:2);
sync = sync(1:2);
params = params(1:2);

framesToLabel = 90000:2:92000;
for nVid = 1:numel(vidPaths)
    disp(nVid)
    frameInds = sync{nVid}.data_frame(framesToLabel);
%     vidoes{nVid} = readFrames(vidPaths{nVid}, frameInds);
    vid = VideoReader(vidPaths{nVid});
    for i = 1:numel(frameInds)
        vid.CurrentTime = (frameInds(i)+1)/50;
        frame = readFrame(vid);
        disp(i)
        if i == 1
            videos{nVid} = zeros(size(frame,1), size(frame,2), size(frame,3), numel(frameInds), 'uint8');
        end
        videos{nVid}(:,:,:,i) = frame;
    end
    delete(vid)
end
% parfor nVid = 1%:numel(vidPaths)
%     frameInds = sync{nVid}.data_frame(framesToLabel);
%     videos{nVid} = readFrames(vidPaths{nVid}, frameInds+1);
% end

%% Get the skeleton
% skeleton = load('skeletons/rat16');
skeleton = load('skeletons/rat23');
skeleton.joints_idx = cat(1, skeleton.joints_idx, skeleton.joints_idx + 23 );
skeleton.color = cat(1, skeleton.color, skeleton.color);
skeleton.joint_names = cat(2, skeleton.joint_names, skeleton.joint_names);

% skeleton = load('com');

%% Start Label3D
close all
labelGui = Label3D(params, videos, skeleton);
% labelGui = Label3D(params, videos, skeleton, 'sync', sync, 'framesToLabel', framesToLabel);

pts3d = load('save_data_AVG.mat');
pts3d = pts3d.pred(framesToLabel,:,:);
labelGui.loadFrom3D(pts3d)

%% Check the camera positions
labelGui.plotCameras       

%% If you just wish to view labels, use View 3D
close all
viewGui = View3D(params, videos, skeleton);
pts3d = load('save_data_AVG.mat');
% pts3d
pts3d = permute(pts3d.pred, [1, 3, 4, 2]);
disp(size(pts3d))
pts3d = reshape(pts3d, size(pts3d, 1), 3, []);
pts3d = pts3d(framesToLabel,:,:);
viewGui.loadFrom3D(pts3d)

%% You can load both in different ways
close all;
View3D()