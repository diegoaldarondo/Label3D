function h = Label3DDannceWrapper(basePath, calibOrder, skeletonPath, varargin)
%Label3DDanceWrapper - Prepare Dannce data for labeling. 
%
%Inputs:
%   basePath - Path to base folder containing dannce data.
%              Looks in basePath/labeling/imdir for images. 
%   calibOrder - Vector denoting the matching of calibration files to video
%       files
%   skeletonPath - Path to skeleton structure. 
    dataPath = fullfile(basePath,'labeling/imdir');
    matchedFramesPath = fullfile(basePath,'data');
    calibrationPath = fullfile(basePath,'calibration');

    % Find images in image directory
    fn = dir([dataPath '/*.png']);
    nImages = numel(fn);
    
    % Extract sampleId from image names
    sampleIds = zeros(numel(fn),1);
    for nFile = 1:nImages
        filename = fn(nFile).name;
        [startInd, endInd] = regexp(filename,'\d*');
        sampleIds(nFile) = str2num(filename(startInd:endInd));
    end
    [sIds, sortinds] = sort(sampleIds);
    fn = fn(sortinds);
    
    % Go through each image and load it into memory
    im = cell(nImages,1);
    for nImage = 1:nImages
        filePath = fullfile(fn(nImage).folder, fn(nImage).name);
        im{nImage} = imread(filePath);
    end
    
    % Find the number of cameras
    nCameras = sum(sIds == sIds(1));
    videos = cell(nCameras, 1);
    
    % Populate the videos for each camera
    for nVideo = 1:numel(videos)
        videos{nVideo} = cat(4, im{nVideo:nCameras:end});
    end
   
    % Load in the calibration data
    calib = dir([calibrationPath '/*.mat']);
    calib = calib(calibOrder);
    cameraParams = cell(numel(calib),1);
    for nCalib = 1:numel(calib)
        calibFile = fullfile(calib(nCalib).folder, calib(nCalib).name);
        disp(calib(nCalib).name)
        cameraParams{nCalib} = load(calibFile);
    end
    
    % Undistort images in each video
    for nCamera = 1:numel(videos)
        params = cameraParams{nCamera};
        camParams = cameraParameters('IntrinsicMatrix', params.K,...
            'RadialDistortion',params.RDistort,'TangentialDistortion', params.TDistort);
        for nImage = 1:size(videos{nCamera},4)
            distIm = videos{nCamera}(:,:,:,nImage);
            videos{nCamera}(:,:,:,nImage) = undistortImage(distIm, camParams);
        end
    end
    
    % Load in the skeleton
    skeleton = load(skeletonPath);
    
    %% Open the GUI using the frames from the base path 
    h = Label3D(cameraParams, videos, skeleton, varargin{:});
end