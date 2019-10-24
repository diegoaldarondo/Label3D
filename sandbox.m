%% Get the camera parameters
clear all
addpath(genpath('/home/diego/code/matlab_toolbox'))
params3 = load('/home/diego/cluster/Diego/code/DANNCE/demo/calibrd18_black6_mouseone_green/calibration/hires_cam1_params.mat');
params1 = load('/home/diego/cluster/Diego/code/DANNCE/demo/calibrd18_black6_mouseone_green/calibration/hires_cam2_params.mat');
params2 = load('/home/diego/cluster/Diego/code/DANNCE/demo/calibrd18_black6_mouseone_green/calibration/hires_cam3_params.mat');
params = {params1, params2, params3};

%% Get the videos
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
%         V{count} = undistortImage(V{count},camParams);
        count = count+1;
    end
    V = cat(4, V{:});
    videos{nVid} = V;
end

%% Plot all three videos in the same figure
close all;
scale = 1000;
markers = cell(3,1);
nMarkers = 9;
nFrames = size(videos{1},4);
C = othercolor('RdYlBu_11b',nMarkers-1);
markers{1} = rand(nFrames , 2, nMarkers)*scale;
markers{2} = rand(nFrames , 2, nMarkers)*scale;
markers{3} = rand(nFrames , 2, nMarkers)*scale;

skeleton.color = lines(nMarkers-1);
% skeleton.color = [1 0 0; 0 0 1; 1 1 1; 1 1 1; 1 .2 .2 ; .2 .2 1];
skeleton.color = C([1 8 5 5 2 7 3 6],:);
skeleton.joints_idx = [1 2; 1 3; 1 4; 4 5; 4 6 ; 4 7; 5 8; 5 9];
skeleton.joint_names = {'Nose','Ear R', 'Ear L', 'Spine M','Tail','R Forepaw','L Forepaw','R Hindpaw','L Hindpaw'};
init = [800.5458  659.2448  800.5458  430.3013  242.4962  426.7241  464.2851 425 485; 392.7989  327.7736  243.4164  327.7736  327.7736  515.8197  127.4253 425 485]';
markers{1} = repmat(reshape(init',1,2,[]),nFrames,1,1);
markers{2} = repmat(reshape(init',1,2,[]),nFrames,1,1);
markers{3} = repmat(reshape(init',1,2,[]),nFrames,1,1);

%%
h = cell(1);
h{1} = VideoAnimator(videos{1}, 'Position', [0 0 1/3 1]);
h{2} = VideoAnimator(videos{2}, 'Position', [1/3 0 1/3 1]);
h{3} = VideoAnimator(videos{3}, 'Position', [2/3 0 1/3 1]);
h{4} = DraggableKeypoint2DAnimator(markers{1}, skeleton, 'Position', [0 0 1/3 1]);
h{5} = DraggableKeypoint2DAnimator(markers{2}, skeleton, 'Position', [1/3 0 1/3 1]);
h{6} = DraggableKeypoint2DAnimator(markers{3}, skeleton, 'Position', [2/3 0 1/3 1]);


cellfun(@(X) set(X.getAxes(), 'DataAspectRatioMode', 'auto', 'Color', 'none'), h)
% cellfun(@(X) axis(X.getAxes(), 'off'), h)
Animator.linkAll(h)
set(gcf,'pos',[103 354 1667 569])
%%
close all;
figure('pos',[2120 103 1072 790]); 
subplot(121)
imshow(videos{1}(:,:,:,1))
subplot(122)
imshow(videos{2}(:,:,:,1))

%%
I1 = videos{1}(:,:,:,1);
I2 = videos{2}(:,:,:,1);

points1 = detectSURFFeatures(rgb2gray(I1));
points2 = detectSURFFeatures(rgb2gray(I2));
% Extract the features.

[f1,vpts1] = extractFeatures(rgb2gray(I1),points1);
[f2,vpts2] = extractFeatures(rgb2gray(I2),points2);
% Retrieve the locations of matched points.

indexPairs = matchFeatures(f1,f2) ;
matchedPoints1 = vpts1(indexPairs(:,1));
matchedPoints2 = vpts2(indexPairs(:,2));

figure('pos',[2120 103 1072 790]); showMatchedFeatures(I1,I2,matchedPoints1,matchedPoints2);
legend('matched points 1','matched points 2');
%%
matchedPoints1 = [378 349; 960 408; 927 401; 547 379;415 520;389 525; 420 492; 996 591; 1123 540];
matchedPoints2 = [867 328; 782 917; 829 872 ; 1071 589; 837 494; 838 483; 865 489; 415 717; 284 877];
[fLMedS,inliers] = estimateFundamentalMatrix(matchedPoints1,...
    matchedPoints2,'Method','Norm8Point');
%% Try to compute the epipolar lines
close all
KL = params{1}.K;
KR = params{2}.K;
Rlr = params{1}.r'*params{2}.r;
Tlr = -params{1}.t+params{2}.t;
F = computeFundamental(KL, KR, Rlr, Tlr);
disp(F)

%%
points = rand(100,2)*500;
% epiLines = epipolarLine(fLMedS, matchedPoints1);
epiLines = epipolarLine(F, matchedPoints1);

I =  squeeze(videos{2}(:,:,:,1));


borderPoints = lineToBorderPoints(epiLines,size(I));
figure('pos',[2120 103 1072 790]); 
imshow(I);
hold on;
plot(matchedPoints2(:,1), matchedPoints2(:,2),'go')
line(borderPoints(:,[1,3])',borderPoints(:,[2,4])','LineWidth',4);

%%
figure; 
colors = lines(numel(params));
for i = 1:numel(params)
    orientation = params{i}.r';
    plotCamera('Orientation',orientation,'Location',-params{i}.t*orientation,'Size',50,'Color',colors(i,:)); hold on;
end
axis equal
%%
close all
load stereoPointPairs
inliers = 1:10;
I1 = imread('viprectification_deskLeft.png');
figure;
subplot(121);
imshow(I1); 
title('Inliers and Epipolar Lines in First Image'); hold on;
plot(matchedPoints1(inliers,1),matchedPoints1(inliers,2),'go')
epiLines = epipolarLine(F,matchedPoints2(inliers,:));
points = lineToBorderPoints(epiLines,size(I1));
line(points(:,[1,3])',points(:,[2,4])');

I2 = imread('viprectification_deskRight.png');
subplot(122); 
imshow(I2);
title('Inliers and Epipolar Lines in Second Image'); hold on;
plot(matchedPoints2(inliers,1),matchedPoints2(inliers,2),'go')
epiLines = epipolarLine(fLMedS,matchedPoints1(inliers,:));
points = lineToBorderPoints(epiLines,size(I2));
line(points(:,[1,3])',points(:,[2,4])');
truesize;
