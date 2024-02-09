classdef Label3D < Animator
    %Label3D - Label3D is a GUI for manual labeling of 3D keypoints in multiple cameras.
    %
    %Input format 1: Build from scratch
    %   camParams: Cell array of structures denoting camera
    %              parameters for each camera.
    %           Structure has five fields:
    %               K - Intrinsic Matrix
    %               RDistort - Radial distortion
    %               TDistort - Tangential distortion
    %               r - Rotation matrix
    %               t - Translation vector
    %   videos: Cell array of h x w x c x nFrames videos.
    %   skeleton: Structure with three fields:
    %       skeleton.color: nSegments x 3 matrix of RGB values
    %       skeleton.joints_idx: nSegments x 2 matrix of integers
    %           denoting directed edges between markers.
    %       skeleton.joint_names: cell array of names of each joint
    %   Syntax: Label3D(camParams, videos, skeleton, varargin);
    %
    %Input format 2: Load from state
    %   file: Path to saved Label3D state file (with or without
    %   video)
    %   videos: Cell array of h x w x c x nFrames videos.
    %   Syntax: Label3D(file, videos, varargin);
    %
    %Input format 3: Load from file
    %   file: Path to saved Label3D state file (with video)
    %   Syntax: Label3D(file, varargin);
    %
    %Input format 4: Load and merge multiple files
    %   file: cell array of paths to saved Label3D state files (with video)
    %   Syntax: Label3D(file, varargin);
    %
    %Input format 5: Load GUI file selection
    %   Syntax: Label3D(varargin);
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
    %
    %   Label3D Properties:
    %   cameraParams - Camera Parameters for all cameras
    %   cameraPoses - Camera poses for all cameras
    %   orientations - Orientations of all cameras
    %   locations - Locations of all cameras
    %   camPoints - Positions of all points in camera coordinates
    %   points3D - Positions of all points in world XYZ coordinates
    %   status - Logical matrix denoting whether a node has been modified
    %   selectedNode - Currently selected node for click updating
    %   skeleton - Struct denoting directed graph
    %   ImageSize - Size of the images
    %   nMarkers - Number of markers
    %   nCams - Number of Cameras
    %   jointsPanel - Handle to keypoint panel
    %   jointsControl - Handle to keypoint controller
    %   savePath - Path in which to save data.
    %   h - Cell array of Animator handles.
    %   frameInds - Indices of current subset of frames
    %   frame - Current frame number within subset
    %   frameRate - current frame rate
    %   undistortedImages - If true, treat input images as undistorted
    %                       (Default false)
    %   savePath - Path in which to save output. The output files are of
    %              the form
    %              path = sprintf('%s%sCamera_%d.mat', obj.savePath, ...
    %                       datestr(now, 'yyyy_mm_dd_HH_MM_SS'), nCam);
    %   verbose - Print saving messages
    %
    %   Label3D Methods:
    %   Label3D - constructor
    %   loadcamParams - Load in camera parameters
    %   getCameraPoses - Return table of camera poses
    %   zoomOut - Zoom all images out to full size
    %   getLabeledJoints - Return the indices of labeled joints and
    %       corresponding cameras in a frame.
    %   triangulateLabeledPoints - Return xyz positions of labeled joints.
    %   reprojectPoints - reproject points from world coordinates to the
    %       camera reference frames
    %   resetFrame - reset all labels to the initial positions within a
    %       frame.
    %   clickImage - Assign the position of the selected node with the
    %       position of a mouse click.
    %   getPointTrack - Helper function to return pointTrack object for
    %       current frame.
    %   plotCameras - Plot the positions and orientations of all cameras in
    %       world coordinates.
    %   checkStatus - Check whether points have been moved and update
    %       accordingly
    %   keyPressCallback - handle UI
    %   saveState - save the current labeled data to a mat file.
    %   selectNode - Modify the current selected node.
    %
    %   Written by Diego Aldarondo (2019)
    %   Some code adapted from https://github.com/talmo/leap
    properties (Access = private)
        % color %UNUSED
        % joints %UNUSED
        origNFrames % original # of frames - why needed? does n-frames ever change?
        initialMarkers
        isKP3Dplotted % track status of keypoints 3d plotted (for toggling)
        % NOTE: maybe we can just rely on kp3d.Visible == 1 instead?
        gridColor = [.7 .7 .7]
        mainFigureColor = [0.1412 0.1412 0.1412]
        labelPosition = [0 .3 .9 .5]
        tablePosition = [.9 .3 .1 .5]
        instructions = ['Label3D Guide:\n'...
            'rightarrow: next frame\n' ...
            'leftarrow: previous frame\n' ...
            'uparrow: increase frame rate by 10\n' ...
            'downarrow: decrease frame rate by 10\n' ...
            'space: set frame rate to 1\n' ...
            'control: set frame rate to 50\n' ...
            'shift: set frame rate to 250\n' ...
            'h: help guide\n'];
        statusMsg = 'Label3D:\nFrame: %d\nframeRate: %d\n'
        hiddenAxesPos = [.99 .99 .01 .01] %used to relocate plots offscreen to hide them
        isLabeled = 2 % enum in status matrix representing labeled (by hand or computed)
        isInitialized = 1 % enum in status matrix representing initially provided points
        counter % text object: total # of labeled frames
        sessionDatestr % date string during load: used to set save file name
    end
    
    properties (Access = public)
        autosave = true % if enabled: autosave after every triangulation (keyboard: "t" or "l"")
        clipboard % object for handling copy & paste of labels
        origCamParams % MAYBE UNNECESSARY? used to save original camera parameters to state file
        cameraParams % cam param: intrinsics
        orientations % cam param: rotation
        locations % cam param: translation
        cameraPoses % creates object from obj.orientations & obj.locations. variables: 'ViewId', 'Orientation', 'Location'
        markers % UNUSED? might store initial markers. SHAPE: cell(#cams) of (#frames, 2, #markers).
        camPoints % 2D camera points for each frame. SHAPE: (#markers, #cams, 2, #frames)
        handLabeled2D % 2D hand-labeled points only (subset of camPoints)
        points3D % 3D points for frame. SHAPE: (#markers, 3, #frames)
        status % status of each point in each frame. Unabled = 0, initialized = 1, labeled = 2. SHAPE: (#markers, #cameras, #frames)
        selectedNode % ID of selected joint in joint table (clicking will create joint of this ID)
        skeleton % skeleton object: color, joints_idx, joint_names
        ImageSize % HEIGHT, WIDTH of each camerea. SHAPE: (#cams, 2)
        nMarkers % # of markers/joints (e.g. 23)
        nCams % # of cameras (e.g. 6)
        jointsPanel % "panel" for joints window
        jointsControl % "uicontrol" object for joints window
        savePath = '' % path to save _Label3D.mat state file. NOTE: if provided for "from scratch" constructor, savePath is folder name instead.
        kp3a % "Keypoint3DAnimator" object -- optionally rendered 3d plot of marker positions
        statusAnimator % animator for status heatmap window
        h % cell of animators: {#cams (VideoAnimators) ... #cams (DraggableKeypoint2DAnimators)}
        verbose = true % UNUSED? TBD REMOVE
        undistortedImages = false % boolean. If true, treat images as undistorted (don't apply intrinsics to frame array)
        sync %camera sync object
        framesToLabel % frame #'s to label: [1 x nFrames] (optional)
        videoPositions % x, y, width, height (origin = bottom left?) of videos. SHAPE: (#cams, 4)
        defScale % global scale for images
        pctScale = .2 % scale images by this fraction
        DragPointColor = [1 1 1]; % passed to DraggableKeypoint2DAnimator constructor
        visibleDragPoints=true; %p assed to DraggableKeypoint2DAnimator constructor
        % ===========================
        % Useful Inherited properties
        % ===========================
        % parent: current figure (from `gcf`)
        % frame: frame number of animation (NOT indexed by frameInds)
        % frameInds: frame index mapping (usually f(x) = x, i.e. identity fn)
    end
    
    methods
        function obj = Label3D(varargin)
            % Label3D - constructor for Label3D class.
            %
            % Input format 1: Build from scratch
            %    camParams: Cell array of structures denoting camera
            %               parameters for each camera.
            %            Structure has five fields:
            %                K - Intrinsic Matrix
            %                RDistort - Radial distortion
            %                TDistort - Tangential distortion
            %                r - Rotation matrix
            %                t - Translation vector
            %    videos: Cell array of h x w x c x nFrames videos.
            %    skeleton: Structure with three fields:
            %        skeleton.color: nSegments x 3 matrix of RGB values
            %        skeleton.joints_idx: nSegments x 2 matrix of integers
            %            denoting directed edges between markers.
            %        skeleton.joint_names: cell array of names of each joint
            %    Syntax: Label3D(camParams, videos, skeleton, varargin);
            %
            % Input format 2: Load from state
            %    file: Path to saved Label3D state file (with or without
            %    video)
            %    videos: Cell array of h x w x c x nFrames videos.
            %    Syntax: Label3D(file, videos, varargin);
            %
            % Input format 3: Load from file
            %    file: Path to saved Label3D state file (with video)
            %    Syntax: Label3D(file, varargin);
            %
            % Input format 4: Load and merge multiple files
            %    file: cell array of paths to saved Label3D state files (with video)
            %    Syntax: Label3D(file, varargin);
            %
            % Input format 5: Load GUI file selection
            %    Syntax: Label3D(varargin);
            
            % User defined inputs
            obj@Animator('Visible', 'off');
            
            % Check for build from scratch
            if numel(varargin) >= 3
                if iscell(varargin{1}) && iscell(varargin{2}) && isstruct(varargin{3})
                    obj.buildFromScratch(varargin{:});
                    return;
                end
            end
            
            % Check for loading from state
            if numel(varargin) >= 2
                if (isstring(varargin{1}) || ischar(varargin{1})) && iscell(varargin{2})
                    file = varargin{1};
                    videos = varargin{2};
                    varargin(1 : 2) = [];
                    obj.loadFromState(file, videos, varargin{:})
                    return;
                end
            end
            
            % Ask for files to load, or load in multiple files.
            obj.load(varargin{:})
        end
        
        function buildFromScratch(obj, camParams, videos, skeleton, varargin)
            %buildFromScratch - Helper for Label3D constructor class.
            %
            %Inputs:
            %   camParams: Cell array of structures denoting camera
            %              parameters for each camera.
            %           Structure has five fields:
            %               K - Intrinsic Matrix
            %               RDistort - Radial distortion
            %               TDistort - Tangential distortion
            %               r - Rotation matrix
            %               t - Translation vector
            %   videos: Cell array of videos. Videos are assumed to be
            %           undistorted and frame matched beforehand.
            %   skeleton: Structure with two fields:
            %       skeleton.color: nSegments x 3 matrix of RGB values
            %       skeleton.joints_idx: nSegments x 2 matrix of integers
            %           denoting directed edges between markers.
            %   Syntax: Label3D.buildFromScratch(camParams, videos, skeleton, varargin);
            
            % User defined inputs
            if ~isempty(skeleton)
                obj.skeleton = skeleton;
            end
            if ~isempty(varargin)
                set(obj, varargin{:})
            end
            
            % Set up Animator parameters
            obj.origCamParams = camParams;
            obj.nFrames = size(videos{1}, 4);
            obj.origNFrames = obj.nFrames;
            obj.frameInds = 1 : obj.nFrames;
            obj.nMarkers = numel(obj.skeleton.joint_names);
            obj.sessionDatestr = datestr(now, 'yyyymmdd_HHMMss_');
            filename = [obj.sessionDatestr, 'Label3D'];
            obj.savePath = fullfile(obj.savePath, filename);
            
            % Set up the cameras
            obj.nCams = numel(obj.origCamParams);
            obj.h = cell(1);
            obj.ImageSize = cellfun(@(x) [size(x, 1); size(x, 2)], videos, ...
                'UniformOutput', false);
            obj.ImageSize = [obj.ImageSize{:}]';
            [obj.cameraParams, obj.orientations, obj.locations] = ...
                obj.loadcamParams(obj.origCamParams);
            obj.cameraPoses = obj.getCameraPoses();
            
            % Make the VideoAnimators
            if isempty(obj.videoPositions)
                obj.videoPositions = obj.getPositions(obj.nCams);
            end
            for nCam = 1 : obj.nCams
                pos = obj.videoPositions(nCam, :);
                obj.h{nCam} = VideoAnimator(videos{nCam}, 'Position', pos);
                ax = obj.h{nCam}.Axes;
                ax.Toolbar.Visible = 'off';
                set(ax, 'XTick', [], 'YTick', []);
                set(obj.h{nCam}.img, 'ButtonDownFcn', @obj.clickImage);
            end
            
            % If there are no initialized markers, set the markers to nan.
            % Othewise, save them in initialMarkers.
            if isempty(obj.markers)
                obj.markers = cell(obj.nCams, 1);
                for i = 1 : numel(obj.markers)
                    obj.markers{i} = nan(obj.origNFrames, 2, obj.nMarkers);
                end
            else
                obj.initialMarkers = obj.markers;
            end
            
            % Make the Draggable Keypoint Animators
            for nCam = 1 : obj.nCams
                obj.h{obj.nCams + nCam} = ...
                    DraggableKeypoint2DAnimator(obj.markers{nCam}, ...
                    obj.skeleton, 'Axes', obj.h{nCam}.Axes, ...
                    'visibleDragPoints', obj.visibleDragPoints, ...
                    'DragPointColor', obj.DragPointColor);
                ax = obj.h{obj.nCams + nCam}.Axes;
                ax.Toolbar.Visible = 'off';
                xlim(ax, [1 obj.ImageSize(nCam, 2)])
                ylim(ax, [1 obj.ImageSize(nCam, 1)])
            end
            
            % Initialize data and accounting matrices
            if ~isempty(obj.markers)
                obj.camPoints = nan(obj.nMarkers, obj.nCams, 2, obj.nFrames);
                obj.handLabeled2D = nan(obj.nMarkers, obj.nCams, 2, obj.nFrames);
            end
            obj.points3D = nan(obj.nMarkers, 3, obj.nFrames);
            obj.status = zeros(obj.nMarkers, obj.nCams, obj.nFrames);
            
            % Make images rescalable
            cellfun(@(X) set(X.Axes, ...
                'DataAspectRatioMode', 'auto', 'Color', 'none'), obj.h)
            % select first joint by default
            obj.selectedNode = 1;
            
            % Style the main Figure
            addToolbarExplorationButtons(obj.Parent) % note: this is also done in animator constructor
            set(obj.Parent, 'Units', 'Normalized', 'pos', obj.labelPosition, ...
                'Name', 'Label3D GUI', 'NumberTitle', 'off', ...
                'color', obj.mainFigureColor)
            
            % Set up the 3d keypoint animator
            obj.setupKeypoint3dAnimator()
            
            % Set up a status table.
            obj.setUpStatusTable();
            
            % Link all animators
            Animator.linkAll(obj.getAnimators)
            
            % Set the GUI clicked callback to the custom toggle, so that we
            % can toggle with the keyboard without having the figure lose
            % focus.
            zin = findall(obj.Parent, 'tag', 'Exploration.ZoomIn');
            set(zin, 'ClickedCallback', @(~, ~) obj.toggleZoomIn);
            
            % Set up the keypoint table figure
            obj.setUpKeypointTable();
            
            % Limit the default interactivity to useful interactions
            for nAx = 1 : numel(obj.Parent.Children)
                ax = obj.Parent.Children(nAx);
                disableDefaultInteractivity(ax);
                ax.Interactions = [zoomInteraction regionZoomInteraction rulerPanInteraction];
            end
        end
        
        function pos = positionFromNRows(obj, views, nRows)
            %POSITIONFROMNROWS - Get the axes positions of each camera view
            %given a set number of rows
            %
            %Inputs: views - number of views
            %        nRows - number of rows
            %
            %Syntax: obj.positionFromNRows(views, nRows)
            %
            %See also: GETPOSITIONS
            nViews = numel(views);
            len = ceil(nViews/nRows);
            pos = zeros(numel(views), 4);
            pos(:, 1) = rem(views-1, len)/len;
            pos(:, 2) = (1 - 1/nRows) - 1/nRows*(floor((views-1) / len));
            pos(:, 3) = 1/len;
            pos(:, 4) = 1/nRows;
        end
        
        function pos = getPositions(obj, nViews)
            %GETPOSITIONS - Get the axes positions of each camera view
            %
            %
            %Inputs: nViews - number of views
            %
            %Syntax: obj.getPositions(views, nRows)
            %
            %See also: POSITIONFROMNROWS
            views = 1 : nViews;
            nRows = floor(sqrt(nViews));
            if nViews > 3
                pos = obj.positionFromNRows(views, nRows);
            else
                pos = obj.positionFromNRows(views, 1);
            end
        end
        
        function animators = getAnimators(obj)
            %GETANIMATORS - return cell array of Animators
            animators = [obj.h {obj} {obj.kp3a} {obj.statusAnimator}];
        end
        
        function saveAll(obj)
            %SAVEALL - Save the labeling session and images
            %
            %Syntax: obj.saveAll()
            %
            %See also: SAVESTATE, EXPORTDANNCE
            
            % Params to save
            path = sprintf('%s_videos.mat', obj.savePath);
            camParams = obj.origCamParams;
            skeleton = obj.skeleton;
            status = obj.status;
            savePath = obj.savePath;
            handLabeled2D = obj.handLabeled2D;
            
            % Since we don't store the videos in Label3D we need to extract
            % them from the VideoAnimators
            animators = obj.getAnimators();
            videos = cell(numel(obj.origCamParams), 1);
            nVid = 1;
            for i = 1 : numel(animators)
                if isa(animators{i}, 'VideoAnimator')
                    videos{nVid} = animators{i}.V;
                end
                nVid = nVid + 1;
            end
            
            % Reshape to dannce specifications
            % Only take the labeled frames
            labeledFrames = ~any(obj.status ~= obj.isLabeled, 2);
            labeledFrames = repelem(labeledFrames, 1, 3, 1);
            pts3D = obj.points3D;
            pts3D(~labeledFrames) = nan;
            data_3D = permute(pts3D, [3 2 1]);
            data_3D = reshape(data_3D, size(data_3D, 1), []);
            if ~isempty(obj.framesToLabel) && ~isempty(obj.sync)
                sync = obj.sync;
                framesToLabel = obj.framesToLabel;
                save(path, 'videos', 'camParams', 'handLabeled2D', 'skeleton', 'data_3D', 'status', 'sync', 'framesToLabel', 'savePath', '-v7.3')
            else
                save(path, 'videos', 'camParams', 'handLabeled2D', 'skeleton', 'data_3D', 'status', 'savePath', '-v7.3')
            end
        end
        
        %         function linkAnimators(obj)
        %             Animator.linkAll(animators)
        %         end
        
        function [c, orientations, locations] = loadcamParams(obj, camParams)
            % LOADCAMPARAMS - Helper to load in camera params into cameraParameters objects
            %  and save the world positions.
            %
            %  Inputs: camParams - cell array of camera parameter structs
            %
            %  Syntax: obj.loadcamParams(camParams)
            %
            % See also: GETCAMERAPOSES
            [c, orientations, locations] = deal(cell(obj.nCams, 1));
            for i = 1 : numel(c)
                % Get all parameters into cameraParameters object.
                K = camParams{i}.K;
                RDistort = camParams{i}.RDistort;
                TDistort = camParams{i}.TDistort;
                R = camParams{i}.r;
                rotationVector = rotationMatrixToVector(R);
                translationVector = camParams{i}.t;
                c{i} = cameraParameters( ...
                    'IntrinsicMatrix', K, ...
                    'ImageSize', obj.ImageSize(i, :), ...
                    'RadialDistortion', RDistort, ...
                    'TangentialDistortion', TDistort, ...
                    'RotationVectors', rotationVector, ...
                    'TranslationVectors', translationVector);
                
                % Also save world location and orientation
                orientations{i} = R';
                locations{i} = -translationVector*orientations{i};
            end
        end
        
        function cameraPoses = getCameraPoses(obj)
            %GETCAMERAPOSES - Helper function to store the camera poses
            %for triangulation
            %
            %See also: LOADCAMPARAMS
            varNames = {'ViewId', 'Orientation', 'Location'};
            cameraPoses = [arr2cell(uint32((1 : obj.nCams)))' ...
                obj.orientations obj.locations];
            
            % This fixes a silly conversion between cells and tables that
            % dereferences cells with dim 1 in the rows.
            cameraPoses = cell2struct(cameraPoses', varNames);
            for i = 1 : obj.nCams
                cameraPoses(i).Location = {cameraPoses(i).Location};
            end
            cameraPoses = struct2table(cameraPoses);
        end
        
        function zoomOut(obj)
            %ZOOMOUT - Zoom all images out to their maximum sizes.
            %
            %See also: TRIANGULATEVIEW
            for i = 1 : obj.nCams
                xlim(obj.h{obj.nCams + i}.Axes, [1 obj.ImageSize(i, 2)])
                ylim(obj.h{obj.nCams + i}.Axes, [1 obj.ImageSize(i, 1)])
            end
        end
        
        function triangulateView(obj)
            %TRIANGULATEVIEW - Triangulate labeled points and zoom all
            %images around those points.
            %
            %Syntax: obj.triangulateView()
            %
            %See also: ZOOMOUT
            
            % Make sure there is at least one triangulated point
            frame = obj.frame;
            meanPts = squeeze(nanmean(obj.camPoints(:, :, :, frame), 1));
            if sum(~isnan(meanPts(:, 1))) < 2
                return
            end
            
            intrinsics = cellfun(@(X) X.Intrinsics, obj.cameraParams, 'uni', 0);
            intrinsics = [intrinsics{:}];
            validCam = find(~isnan(meanPts(:, 1)));
            pointTracks = pointTrack(validCam, meanPts(validCam, :));
            xyzPt = triangulateMultiview(pointTracks, ...
                obj.cameraPoses(validCam, :), intrinsics(validCam));
            
            % If a global scale has been defined, use it. Otherwise use a
            % percentage of the image size.
            if ~isempty(obj.defScale)
                % Build a box in 3D to focus views
                xyzEdges = [xyzPt - obj.defScale; xyzPt + obj.defScale];
                xyzNodes = [];
                for i = 1 : 2
                    for j = 1 : 2
                        for k = 1 : 2
                            xyzNodes(end+1, :) = [xyzEdges(i, 1), xyzEdges(j, 2), xyzEdges(k, 3)];
                        end
                    end
                end
                
                % Change all of the axes to fit the box.
                for nCam = 1 : obj.nCams
                    camParam = obj.cameraParams{nCam};
                    rotation = obj.orientations{nCam}';
                    translation = camParam.TranslationVectors;
                    allPts = worldToImage(camParam, rotation, translation, xyzNodes);
                    allLim = [min(allPts); max(allPts)];
                    ax = obj.h{nCam}.Axes;
                    ax.XLim = allLim(:, 1);
                    ax.YLim = allLim(:, 2);
                end
            else
                % Change all of the axes to surround the mean point with a
                % window defined as a percentage of the image dimensions.
                for nCam = 1 : obj.nCams
                    camParam = obj.cameraParams{nCam};
                    rotation = obj.orientations{nCam}';
                    translation = camParam.TranslationVectors;
                    pt = worldToImage(camParam, rotation, translation, xyzPt);
                    ax = obj.h{nCam}.Axes;
                    xPad = obj.pctScale*camParam.Intrinsics.ImageSize(1);
                    yPad = obj.pctScale*camParam.Intrinsics.ImageSize(2);
                    ax.XLim = [pt(1) - xPad, pt(1) + xPad];
                    ax.YLim = [pt(2) - yPad, pt(2) + yPad];
                end
            end
        end
        
        function [camIds, jointIds] = getLabeledJoints(obj, frame)
            % Look within a frame and return all joints with at least two
            % labeled views, as well as a logical vector denoting which two
            % views.
            s = zeros(size(obj.status, 1), size(obj.status, 2));
            s(:) = obj.status(:, :, frame);
            labeled = s == obj.isLabeled | s == obj.isInitialized;
            jointIds = find(sum(labeled, 2) >= 2);
            camIds = labeled(jointIds, :);
        end
        
        function forceTriangulateLabeledPoints(obj, cam1, joint)
            fr = obj.frameInds(obj.frame);
            % Get the camera intrinsics
            intrinsics = cellfun(@(X) X.Intrinsics, obj.cameraParams, 'uni', 0);
            intrinsics = [intrinsics{:}];
            
            % Find the labeled joints and corresponding cameras
            [camIds, jointIds] = obj.getLabeledJoints(fr);
            
            % For each labeled joint, triangulate with the right cameras
            xyzPoints = zeros(1, 3);
            
            cams = camIds(jointIds == joint, :);
            pointTracks = obj.getPointTrack(fr, joint, cams);
            cams = find(cams);
            % Make a bunch of copies of the weighted point, and necessary
            % vectors
            nReps = 100;
            points = pointTracks.Points;
            if size(points, 1) == 0
                return;
            end
            pointTracks.ViewIds = [pointTracks.ViewIds repelem(cam1, 1, nReps)];
            pointTracks.Points = cat(1, points, repmat(points(cams==cam1, :), nReps, 1));
            cams = [cams repelem(cam1, 1, nReps)];
            
            % Do the weighted regression.
            xyzPoints(1, :) = triangulateMultiview(pointTracks, ...
                obj.cameraPoses(cams, :), intrinsics(cams));
            % Save the results to the points3D matrix
            obj.points3D(joint, :, fr) = xyzPoints;
            
            % Update the status of the draggable animator
            for nKPAnimator = 1 : obj.nCams
                kpAnimator = obj.h{obj.nCams + nKPAnimator};
                kpAnimator.dragged(fr, jointIds) = false;
            end
        end
        
        function xyzPoints = triangulateLabeledPoints(obj, frame)
            % Get the camera intrinsics
            intrinsics = cellfun(@(X) X.Intrinsics, obj.cameraParams, 'uni', 0);
            intrinsics = [intrinsics{:}];
            
            % Find the labeled joints and corresponding cameras
            [camIds, jointIds] = obj.getLabeledJoints(frame);
            
            % For each labeled joint, triangulate with the right cameras
            xyzPoints = zeros(numel(jointIds), 3);
            for nJoint = 1 : numel(jointIds)
                cams = camIds(nJoint, :);
                joint = jointIds(nJoint);
                pointTracks = obj.getPointTrack(frame, joint, cams);
                xyzPoints(nJoint, :) = triangulateMultiview(pointTracks, ...
                    obj.cameraPoses(cams, :), intrinsics(cams));
            end
            
            % Save the results to the points3D matrix
            obj.points3D(jointIds, :, frame) = xyzPoints;
        end
        
        function reprojectPoints(obj, frame)
            % Find the labeled joints and corresponding cameras
            [~, jointIds] = obj.getLabeledJoints(frame);
            
            % Reproject the world coordinates for the labeled joints to
            % each camera and store in the camPoints
            for nCam = 1 : obj.nCams
                camParam = obj.cameraParams{nCam};
                rotation = obj.orientations{nCam}';
                translation = camParam.TranslationVectors;
                worldPoints = obj.points3D(jointIds, :, frame);
                if ~isempty(worldPoints)
                    if obj.undistortedImages
                        obj.camPoints(jointIds, nCam, :, frame) = ...
                            worldToImage(camParam, rotation, translation, ...
                            worldPoints);
                    else
                        obj.camPoints(jointIds, nCam, :, frame) = ...
                            worldToImage(camParam, rotation, translation, ...
                            worldPoints, 'ApplyDistortion', true);
                    end
                end
            end
        end
        
        function resetFrame(obj)
            % Reset current frame to the initial unlabeled positions.
            for i = 1 : obj.nCams
                obj.h{obj.nCams + i}.resetFrame();
            end
            f = obj.frameInds(obj.frame);
            obj.status(:, :, f) = 0;
            if ~isempty(obj.initialMarkers)
                for nAnimator = 1 : obj.nCams
                    obj.initialMarkers{nAnimator}(f, :, :) = nan;
                end
            end
            obj.checkStatus();
            obj.update()
        end
        
        function resetMarker(obj)
            % Delete the selected nodes if they exist
            draggableAnimators = obj.h(obj.nCams+1 : 2*obj.nCams);
            fr = obj.frameInds(obj.frame);
            markerInd = obj.selectedNode;
            for nAnimator = 1 : numel(draggableAnimators)
                obj.status(markerInd, nAnimator, fr) = 0;
                keyObj = draggableAnimators{nAnimator};
                keyObj.markers(fr, :, markerInd) = nan;
                keyObj.markersX = keyObj.markers(:, 1, :);
                keyObj.markersY = keyObj.markers(:, 2, :);
                keyObj.points.XData(:) = keyObj.markers(fr, 1, :);
                keyObj.points.YData(:) = keyObj.markers(fr, 2, :);
                keyObj.update();
            end
            obj.checkStatus()
            obj.update()
        end
        
        function clickImage(obj, ~, ~)
            % Callback to image clicks (but not on nodes)
            % Pull out clicked point coordinate in image coordinates
            pt = zeros(obj.nCams, 2);
            for i = 1 : obj.nCams
                pt(i, :) = obj.h{i}.img.Parent.CurrentPoint(1, 1 : 2);
            end
            
            % Pull out clicked point in figure coordinates.
            fpt = obj.Parent.CurrentPoint;
            [goodX, goodY] = deal(zeros(obj.nCams, 1));
            for nCam = 1 : obj.nCams
                pos = obj.h{nCam}.Position;
                goodX(nCam) = pos(1) <= fpt(1) && fpt(1) < (pos(1) + pos(3));
                goodY(nCam) = pos(2) <= fpt(2) && fpt(2) < (pos(2) + pos(4));
            end
            cam = find(goodX & goodY);
            
            % Throw a warning if there are more than one good camera.
            if numel(cam) > 1
                warning(['Click is in multiple images. ' ...
                    'Please zoom image axes such that they are '...
                    'non-overlapping. To zoom out fully in all images, press "o".'])
                return;
            end
            
            % Update the currently selected node
            index = obj.selectedNode;
            obj.h{cam+obj.nCams}.points.XData(index) = pt(cam, 1);
            obj.h{cam+obj.nCams}.points.YData(index) = pt(cam, 2);
            obj.h{cam+obj.nCams}.dragged(obj.frameInds(obj.frame), obj.selectedNode) = true;
            obj.h{cam+obj.nCams}.update();
            obj.checkStatus();
            obj.update();
        end
        
        function pt = getPointTrack(obj, frame, jointId, camIds)
            % Returns the corresponding pointTrack object for particular
            % frames, joint IDs, and cameras.
            viewIds = find(camIds);
            imPts = squeeze(obj.camPoints(jointId, viewIds, :, frame));
            
            % Undistort the points if needed
            if ~obj.undistortedImages
                for nCam = 1 : numel(viewIds)
                    params = obj.cameraParams{viewIds(nCam)};
                    imPts(nCam, :) = undistortPoints(imPts(nCam, :), params);
                end
            end
            pt = pointTrack(viewIds, imPts);
        end
        
        function plotCameras(obj)
            % Helper function to check camera positions.
            f = figure('Name', 'Camera Positions', 'NumberTitle', 'off');
            ax = axes(f);
            colors = lines(obj.nCams);
            p = cell(obj.nCams, 1);
            for i = 1 : obj.nCams
                p{i} = plotCamera('Orientation', obj.orientations{i}, ...
                    'Location', obj.locations{i}, 'Size', 50, ...
                    'Color', colors(i, :), 'Label', sprintf('Camera %d', i));
                hold on;
            end
            grid on
            axis equal;
            daspect(ax, [1 1 1]);
            xlabel('X')
            ylabel('Y')
            zlabel('Z')
        end
        
        function checkStatus(obj)
            % Update the movement status for the current frame, if
            % necessary
            f = obj.frameInds(obj.frame);
            for nKPAnimator = 1 : obj.nCams
                kpAnimator = obj.h{obj.nCams+nKPAnimator};
                currentMarkerCoords = kpAnimator.getCurrentFramePositions();
                
                % If there were initializations, use those, otherwise
                % just check for non-nans.
                if isempty(obj.initialMarkers)
                    % 23x1 logical array = 1 if marker is not default position
                    hasMoved = any(~isnan(currentMarkerCoords), 2);
                    obj.status(~hasMoved, nKPAnimator, f) = 0;
                else
                    cM = currentMarkerCoords;
                    iM = zeros(size(cM));
                    iM(:) = permute(obj.initialMarkers{nKPAnimator}(f, :, :), [1 3 2]);
                    isDeleted = any(isnan(cM), 2);
                    iM(isnan(iM)) = 0;
                    cM(isnan(cM)) = 0;
                    hasMoved = any(round(iM, 3) ~= round(cM, 3), 2);
                    hasMoved = hasMoved & ~isDeleted;
                    obj.status(isDeleted, nKPAnimator, f) = 0;
                end
                obj.status(hasMoved, nKPAnimator, f) = obj.isLabeled;
                obj.camPoints(:, nKPAnimator, :, f) = currentMarkerCoords;
                
                movedByHand = hasMoved & kpAnimator.dragged(f, :)';
                obj.handLabeled2D(movedByHand, nKPAnimator, 1, f) = currentMarkerCoords(movedByHand, 1);
                obj.handLabeled2D(movedByHand, nKPAnimator, 2, f) = currentMarkerCoords(movedByHand, 2);
            end
        end
        
        function keyPressCallback(obj, source, eventdata)
            % keyPressCallback - Handle UI on keypress
            % bound to "WindowKeyPressFcn" event handler in Animator constructor
            % Extends Animator callback function
            
            % update label3d selectedNode if any draggable animators have selected nodes
            % also run checkStatus() & update() functions
            obj.checkForClickedNodes()
            
            % Determine the key that was pressed and any modifiers
            keyPressed = eventdata.Key;
            modifiers = get(gcf, 'CurrentModifier');
            wasShiftPressed = ismember('shift',   modifiers);
            wasCtrlPressed  = ismember('control', modifiers);
            wasAltPressed   = ismember('alt',     modifiers);
            switch keyPressed
                case 'h'
                    message = obj(1).instructions;
                    fprintf(message);
                case 's'
                    if wasShiftPressed
                        obj.saveState()
                        fprintf('Saved state to %s\n', obj.savePath);
                    end
                case 'backspace'
                    obj.deleteSelectedNode();
                case 't'
                    obj.checkStatus();
                    
                    % Check if a node is held for any of the draggable
                    % keypoint animators.
                    nodeIsHeld = false;
                    draggableAnimators = obj.h(obj.nCams + 1 : 2 * obj.nCams);
                    for nAnimator = 1 : numel(draggableAnimators)
                        curAnimator = draggableAnimators{nAnimator};
                        if ~isnan(curAnimator.selectedNode)
                            camInFocus = nAnimator;
                            marker = curAnimator.selectedNode;
                            position = curAnimator.selectedNodePosition;
                            nodeIsHeld = true;
                        end
                    end
                    
                    % If a marker is currently held, weigh it heavily in a
                    % multiview regression, otherwise do normal multiview
                    % regression.
                    if nodeIsHeld
                        obj.camPoints(marker, camInFocus, :, obj.frameInds(obj.frame)) = position;
                        obj.checkStatus();
                        obj.update()
                        obj.forceTriangulateLabeledPoints(camInFocus, marker)
                    else
                        obj.triangulateLabeledPoints(obj.frameInds(obj.frame));
                    end
                    obj.reprojectPoints(obj.frameInds(obj.frame));
                    update(obj)
                    if obj.autosave
                        obj.saveState()
                    end
                case 'tab'
                    if wasShiftPressed
                        obj.selectNode(obj.selectedNode-1)
                    else
                        obj.selectNode(obj.selectedNode+1)
                    end
                case 'u'
                    obj.resetFrame();
                case 'o'
                    obj.zoomOut();
                case 'x'
                    obj.resetMarker();
                case 'a'
                    obj.resetAspectRatio();
                case 'v'
                    if wasCtrlPressed
                        if ~isempty(obj.clipboard)
                            obj.points3D(:, :, obj.frameInds(obj.frame)) = obj.clipboard.points3D;
                            obj.status(:, :, obj.frameInds(obj.frame)) = obj.clipboard.status;
                            disp(obj.clipboard)
                            obj.reprojectPoints(obj.frameInds(obj.frame))
                            obj.update()
                        end
                    else
                        obj.triangulateView();
                        obj.resetAspectRatio();
                    end
                case 'z'
                    if ~wasShiftPressed
                        obj.toggleZoomIn;
                    else
                        obj.togglePan;
                    end
                case 'l'
                    obj.setLabeled();
                    if obj.autosave
                        obj.saveState()
                    end
                case 'r'
                    reset(obj);
                case 'pageup'
                    obj.selectNode(1);
                case 'f'
                    newFrame = inputdlg('Enter frame number:');
                    newFrame = str2double(newFrame);
                    if isnumeric(newFrame) && ~isempty(newFrame) && ~isnan(newFrame)
                        obj.setFrame(newFrame)
                    end
                case 'p'
                    if ~obj.isKP3Dplotted
                        obj.add3dPlot();
                    else
                        obj.remove3dPlot();
                    end
                case 'c'
                    if wasCtrlPressed
                        cb = struct('points3D', [], 'status', []);
                        cb.points3D = obj.points3D(:, :, obj.frameInds(obj.frame));
                        cb.status = obj.status(:, :, obj.frameInds(obj.frame));
                        obj.clipboard = cb;
                    end
            end
            
            % Extend Animator callback function
            % Base animator provides support for the following keys:
            %   navigate frames: leftarrow, rightarrow
            %   increase/decrease navigation speed: uparrow, downarrow
            %   select "animator scope"?: number keys 1-9
            keyPressCallback@Animator(obj, source, eventdata);
        end
        
        function resetAspectRatio(obj)
            % aspect ratio of all images is set to 1 : 1
            for i = 1 : obj.nCams
                thisAx = obj.h{i}.Axes;
                xLim = thisAx.XLim;
                yLim = thisAx.YLim;
                mRange = range(xLim) / 2 + range(yLim) / 2;
                newRange = [-mRange/2, mRange/2];
                thisAx.XLim = mean(thisAx.XLim) + newRange;
                thisAx.YLim = mean(thisAx.YLim) + newRange;
            end
        end
        
        function setFrame(obj, newFrame)
            % setFrame - set the frame of the GUI
            % Input:
            %   newFrame: Frame number (integer)
            %
            % The frame is set to be mod(newFrame, nFrames)
            if isnumeric(newFrame)
                if rem(newFrame, 1) ~= 0
                    error('Frame must be an integer.')
                end
            else
                error('Frame must be an integer.')
            end
            animators = obj.getAnimators();
            for i = 1 : numel(animators)
                animators{i}.frame = newFrame;
            end
            set(obj.Axes.Parent, 'NumberTitle', 'off', ...
                'Name', sprintf('Frame: %d', obj.frameInds(obj.frame(1))));
        end
        
        function setLabeled(obj)
            % set the entire frame's status as labeled
            obj.status(:, :, obj.frameInds(obj.frame)) = obj.isLabeled;
            obj.update()
        end
        
        function toggleUiState(obj, state)
            % toggle Zoom & Pan UI States
            if strcmp(state.Enable, 'off')
                % Toggle the zoom state
                state.Enable = 'on';
                
                % This trick disables window listeners that prevent
                % the installation of custom keypresscallback
                % functions in ui default modes.
                % See matlab.uitools.internal.uimode/setCallbackFcn
                hManager = uigetmodemanager(obj.Parent);
                matlab.graphics.internal.setListenerState(hManager.WindowListenerHandles, 'off');
                
                % We need to disable normal keypress mode
                % functionality to prevent the command window from
                % taking focus
                
                % WindowKeyPressFcn: executed regardless of which component has focus: global execution
                obj.Parent.WindowKeyPressFcn = @(src, event) Animator.runAll(obj.getAnimators, src, event);
                % KeyPressFcn: executes only if the component has focus
                obj.Parent.KeyPressFcn = [];
            else
                state.Enable = 'off';
                obj.Parent.WindowKeyPressFcn = @(src, event) Animator.runAll(obj.getAnimators, src, event);
                obj.Parent.KeyPressFcn = [];
            end
        end
        
        function toggleZoomIn(obj)
            zoomState = zoom(obj.Parent);
            zoomState.Direction = 'in';
            obj.toggleUiState(zoomState);
        end
        
        function togglePan(obj)
            panState = pan(obj.Parent);
            obj.toggleUiState(panState);
        end
        
        function loadFrom3D(obj, pts3d)
            % loadState - Load (triangulated) 3d data and visualize.
            %
            % Syntax: obj.loadFrom3D(files)
            %
            % Inputs: pts3d - NFrames x 3 x nMarkers 3d data.
            
            % Load the 3d points
            pts3d = reshape(pts3d, size(pts3d, 1), 3, []);
            pts3d = permute(pts3d, [3 2 1]);
            if size(pts3d, 3) ~= obj.nFrames
                error('3d points do not have the same number of frames as Label3D instance')
            end
            
            % Update the status. Only overwrite non-labeled points
            isInit = ~any(isnan(pts3d), 2);
            newStatus = repelem(isInit, 1, obj.nCams, 1)*obj.isInitialized;
            handLabeled = obj.status == obj.isLabeled;
            obj.status(~handLabeled) = newStatus(~handLabeled);
            ptsHandLabeled = repelem(any(handLabeled, 2), 1, 3, 1);
            obj.points3D(~ptsHandLabeled) = pts3d(~ptsHandLabeled);
            
            
            % Reproject the camera points
            for nFrame = 1 : size(obj.points3D, 3)
                obj.reprojectPoints(nFrame);
            end
            for nAnimator = 1 : obj.nCams
                impts = zeros(size(obj.camPoints, 1), size(obj.camPoints, 3), size(obj.camPoints, 4));
                impts(:) = obj.camPoints(:, nAnimator, :, :);
                obj.initialMarkers{nAnimator} = permute(impts, [3 2 1]);
            end
            obj.update()
            %             obj.points3D = nan(size(obj.points3D));
        end
        
        function loadState(obj, varargin)
            % loadState - Load (triangulated) data from previous sessions.
            %
            % Syntax: obj.loadState(file)
            %
            % Optional Inputs: file - *.mat file to previous session. Output of
            % Label3D.saveState()
            %
            % If file is not specified, calls uigetfile.
            if isempty(varargin)
                file = uigetfile('*.mat', 'MultiSelect', 'off');
            else
                file = varargin{1};
                if isstring(file) || ischar(file)
                    [~, ~, ext] = fileparts(file);
                    if ~strcmp(ext, '.mat')
                        error('File must be *.mat')
                    end
                else
                    error('File must be *.mat')
                end
            end
            % Load the files and store metadata
            data = load(file);
            % Load the points
            obj.loadFrom3D(data.data_3D)
            obj.handLabeled2D = data.handLabeled2D;
            obj.status = data.status;
            if isfield(data, 'framesToLabel') && isfield(data, 'sync')
                obj.sync = data.sync;
                obj.framesToLabel = data.framesToLabel;
            end
            obj.update()
        end
        
        function saveState(obj)
            % saveState - Save data for each camera to the savePath
            %   Saves one .mat file for each camera with the format string
            %   path = sprintf('%s%sCamera_%d.mat', obj.savePath, datestr(now, 'yyyy_mm_dd_HH_MM_SS'), nCam);
            %   NOTE: does not save video frames.
            %
            % Saved variables include:
            %   status - Logical denoting whether each keypoint has been
            %            moved
            %   skeleton - Digraph denoting animal skeleton
            %   imageSize - Image dimensions
            %   cameraPoses - World poses of each camera
            %   data_2D - Points in image coordinates - if images were
            %             distorted, the points will also be distorted.
            %             If images were undistorted, the points will also
            %             be undistorted.
            %   data_3D - Points in world coordinates.
            % Include some metadata
            disp('saving')
            status = obj.status;
            skeleton = obj.skeleton;
            imageSize = obj.ImageSize;
            cameraPoses = obj.cameraPoses;
            
            % Reshape to dannce specifications
            % Only take the labeled frames
            labeledFrames = ~any(obj.status ~= obj.isLabeled, 2);
            labeledFrames = repelem(labeledFrames, 1, 3, 1);
            pts3D = obj.points3D;
            pts3D(~labeledFrames) = nan;
            data_3D = permute(pts3D, [3 2 1]);
            data_3D = reshape(data_3D, size(data_3D, 1), []);
            %             data_3D(~any(~isnan(data_3D), 2), :) = [];
            %             pts3D(any(~any(~isnan(pts3D), 2), 3), :, :) = [];
            
            camParams = obj.origCamParams;
            path = sprintf('%s.mat', obj.savePath);
            handLabeled2D = obj.handLabeled2D;
            if ~isempty(obj.framesToLabel) && ~isempty(obj.sync)
                sync = obj.sync;
                framesToLabel = obj.framesToLabel;
                save(path, 'data_3D', 'status', ...
                    'skeleton', 'imageSize', 'handLabeled2D', 'cameraPoses', 'camParams', ...
                    'sync', 'framesToLabel')
            else
                save(path, 'data_3D', 'status', ...
                    'skeleton', 'imageSize', 'handLabeled2D', 'cameraPoses', 'camParams')
            end
        end
        
        function selectNode(obj, val)
            % Update the selected node by val positions.
            
            obj.selectedNode = mod(val, obj.nMarkers);
            if obj.selectedNode == 0
                obj.selectedNode = obj.nMarkers;
            end
            obj.jointsControl.Value = obj.selectedNode;
        end
        
        function remove3dPlot(obj)
            % Hide the KeypointAnimator3D plot
            for nAnimator = 1 : obj.nCams
                pos = obj.videoPositions(nAnimator, :);
                set(obj.h{nAnimator}, 'Position', pos)
                set(obj.h{nAnimator+obj.nCams}, 'Position', pos)
            end
            set(obj.kp3a.Axes, 'Position', obj.hiddenAxesPos);
            set(obj.kp3a.Axes, 'Visible', 'off')
            arrayfun(@(X) set(X, 'Visible', 'off'), obj.kp3a.PlotSegments);
            obj.isKP3Dplotted = false;
        end
        
        function add3dPlot(obj)
            % Show the KeypointAnimator3D plot
            
            % Move the other plots out of the way
            pos = obj.getPositions(obj.nCams + 1);
            for nAnimator = 1 : obj.nCams
                set(obj.h{nAnimator}, 'Position', pos(nAnimator, :))
                set(obj.h{nAnimator+obj.nCams}, 'Position', pos(nAnimator, :))
            end
            
            % Add the 3d plot in the right place
            pad = .1*1/(obj.nCams+1);
            pos = pos(end, :) + [pad pad -2*pad -2*pad];
            lims = [-400 400];
            set(obj.kp3a.Axes, 'Position', pos, 'Visible', 'on', ...
                'XLim', lims, 'YLim', lims, 'ZLim', lims)
            arrayfun(@(X) set(X, 'Visible', 'on'), obj.kp3a.PlotSegments);
            obj.isKP3Dplotted = true;
        end
        
        function checkForClickedNodes(obj)
            % update label3d selectedNode if any of the DraggableAnimators have a selectedNode
            draggableAnimators = obj.h(obj.nCams + 1 : 2 * obj.nCams);
            for nAnimator = 1 : numel(draggableAnimators)
                if ~isnan(draggableAnimators{nAnimator}.selectedNode)
                    obj.selectedNode = draggableAnimators{nAnimator}.selectedNode;
                end
            end
            obj.checkStatus()
            obj.update()
        end
        
        function deleteSelectedNode(obj)
            % Delete the selected nodes if they exist
            draggableAnimators = obj.h(obj.nCams + 1 : 2 * obj.nCams);
            fr = obj.frameInds(obj.frame);
            for nAnimator = 1 : numel(draggableAnimators)
                if ~isnan(draggableAnimators{nAnimator}.selectedNode)
                    obj.status(draggableAnimators{nAnimator}.selectedNode, nAnimator, fr) = 0;
                    draggableAnimators{nAnimator}.deleteSelectedNode
                end
            end
            obj.checkStatus()
            obj.update()
        end
        
        function exportDannce(obj, varargin)
            %exportDannce - Export data to dannce format
            %
            % Optional inputs:
            % basePath - Path to Dannce project folder
            % file - Path to .mat Label3D save file (with or without videos)
            % saveFolder - Folder in which to save dannce.mat file
            % cameraNames - cell array of camera names (in order)
            %   Default: {'Camera1', 'Camera2', etc.}
            % framesToLabel - Vector of frame numbers for each video frame.
            % Syntax: labelGui.exportDannce
            %         labelGui.exportDannce('basePath', path)
            %         labelGui.exportDannce('cameraNames', cameraNames)
            %         labelGui.exportDannce('framesToLabel', framesToLabel)
            %         labelGui.exportDannce('saveFolder', saveFolder)
            defaultBasePath = '';
            defaultCameraNames = cell(1, obj.nCams);
            for i = 1 : numel(defaultCameraNames)
                defaultCameraNames{i} = sprintf('Camera%d', i);
            end
            defaultFramesToLabel = obj.framesToLabel;
            validBasePath = @(X) ischar(X) || isstring(X);
            validCameraNames = @(X) iscell(X) && (numel(X) == obj.nCams);
            validFrames = @(X) isnumeric(X) && (numel(X) == obj.nFrames);
            defaultSaveFolder = '';
            p = inputParser;
            addParameter(p, 'basePath', defaultBasePath, validBasePath);
            addParameter(p, 'cameraNames', defaultCameraNames, validCameraNames);
            addParameter(p, 'framesToLabel', defaultFramesToLabel, validFrames);
            addParameter(p, 'saveFolder', defaultSaveFolder, validBasePath);
            
            parse(p, varargin{:});
            p = p.Results;
            if isempty(p.framesToLabel)
                error('exportDannce:FrameNumbersMustBeProvided', [ ...
                    'Frame numbers for each frame in videos must be provided.\n' ...
                    'framesToLabel - Vector of frame numbers for each video frame.\n' ...
                    'labelGui.exportDannce(''''framesToLabel'''', framesToLabel)'])
            end
            
            % Load the matched frames files if necessary
            if isempty(obj.sync)
                if isempty(p.basePath)
                    p.basePath = uigetdir([], 'Select project folder');
                end
                obj.sync = collectSyncPaths(p.basePath);
                obj.sync = cellfun(@(X) {load(X)}, obj.sync);
            end
            
            % Setup the save folder
            if isempty(p.saveFolder)
                outDir = uigetdir([], 'Select output folder.');
            else
                outDir = p.saveFolder;
            end
            
            % Save the state and use the data for export
            obj.saveState();
            p.file = obj.savePath;
            labels = load(p.file);
            
            
            % For each labels file, extract the labeled points and save metadata.
            nCameras = numel(obj.sync);
            labelData = cell(nCameras, 1);
            for nCam = 1 : nCameras
                % Find corresponding sampleIds
                labeled = zeros(size(labels.status, 1), size(labels.status, 3));
                labeled(:) = ~any(labels.status ~= obj.isLabeled, 2);
                labeled = any(labeled, 1);
                data_sampleID = obj.sync{nCam}.data_sampleID(p.framesToLabel);
                data_frame = obj.sync{nCam}.data_frame(p.framesToLabel);
                data_sampleID = data_sampleID(labeled);
                data_frame = data_frame(labeled)';
                
                cp = obj.cameraParams{nCam};
                % Reproject points from 3D to 2D, applying distortion if
                % desired.
                pts = permute(obj.points3D, [3 1 2]);
                allpts = reshape(pts, [], 3);
                if ~obj.undistortedImages
                    data_2D = worldToImage(cp, cp.RotationMatrices, ...
                        cp.TranslationVectors, allpts, 'ApplyDistortion', true);
                else
                    data_2D = worldToImage(cp, cp.RotationMatrices, ...
                        cp.TranslationVectors, allpts);
                end
                data_2D = reshape(data_2D, size(pts, 1), [], 2);
                data_2D = permute(data_2D, [1 3 2]);
                data_2D = reshape(data_2D, size(pts, 1), []);
                
                % Save out the set of labeled images.
                data_2d = data_2D(labeled, :);
                data_3d = labels.data_3D(labeled, :);
                labelData{nCam} = struct('data_2d', data_2d, ...
                    'data_3d', data_3d, ...
                    'data_frame', data_frame, ...
                    'data_sampleID', data_sampleID);
            end
            outPath = fullfile(outDir, sprintf('%sLabel3D_dannce.mat', obj.sessionDatestr));
            params = obj.origCamParams;
            camnames = p.cameraNames;
            handLabeled2D = obj.handLabeled2D;
            
            if ~isempty(obj.sync)
                sync = obj.sync;
                save(outPath, 'labelData', 'handLabeled2D', 'params', 'sync', 'camnames')
            else
                save(outPath, 'labelData', 'handLabeled2D', 'params', 'camnames')
            end
        end
    end
    
    methods (Access = private)
        function reset(obj)
            % reset frameInds to 1 : nFrames
            % also set current frame number to 1
            restrict(obj, 1 : obj.origNFrames)
        end
        
        function setupKeypoint3dAnimator(obj)
            m = permute(obj.points3D, [3 2 1]);
            % This hack prevents overlap between zoom callbacks in the kp
            % animator and the VideoAnimators
            pos = obj.hiddenAxesPos;
            obj.kp3a = Keypoint3DAnimator(m, obj.skeleton, 'Position', pos);
            obj.kp3a.frameInds = obj.frameInds;
            obj.kp3a.frame = obj.frame;
            ax = obj.kp3a.Axes;
            grid(ax, 'on');
            set(ax, 'color', obj.mainFigureColor, ...
                'GridColor', obj.gridColor, ...
                'Visible', 'off')
            view(ax, 3);
            arrayfun(@(X) set(X, 'Visible', 'off'), obj.kp3a.PlotSegments);
            obj.isKP3Dplotted = false;
        end
        
        function loadMerge(obj, files, varargin)
            % loadMerge - Merge multiple session files
            %
            % The session files must be *.mat generated from
            % Label3D.saveAll()
            %
            % Optional Inputs: files - Cell array of file paths.
            %
            % If no files are given, select with uigetfile
            
            tempVideos = cellfun(@(X) load(X, 'videos'), files);
            videos = cell(numel(tempVideos(1).videos), 1);
            for nCam = 1 : numel(tempVideos(1).videos)
                vids = arrayfun(@(X) X.videos{nCam}, tempVideos, 'UniformOutput', false);
                videos{nCam} = cat(4, vids{:});
                vids = [];
                for nFile = 1 : numel(tempVideos)
                    tempVideos(nFile).videos{nCam} = [];
                end
            end
            
            pts3d = cellfun(@(X) load(X, 'data_3D'), files);
            pts3d = cat(1, pts3d.data_3D);
            stats = cellfun(@(X) load(X, 'status'), files);
            stats = cat(3, stats.status);
            
            data = cellfun(@(X) load(X, 'camParams', 'skeleton'), files);
            camParams = data(1).camParams;
            skel = data(1).skeleton;
            
            obj.buildFromScratch(camParams, videos, skel, varargin{:});
            obj.loadFrom3D(pts3d)
            obj.status = stats;
            obj.update()
        end
        
        function loadFromState(obj, file, videos, varargin)
            data = load(file);
            camParams = data.camParams;
            skel = data.skeleton;
            obj.buildFromScratch(camParams, videos, skel, varargin{:});
            obj.loadState(file)
            if isfield(data, 'framesToLabel') && isfield(data, 'sync')
                obj.sync = data.sync;
                obj.framesToLabel = data.framesToLabel;
            end
        end
        
        function loadAll(obj, path, varargin)
            data = load(path);
            obj.buildFromScratch(data.camParams, data.videos, data.skeleton, varargin{:});
            obj.loadFrom3D(data.data_3D);
            if isfield(data, 'framesToLabel') && isfield(data, 'sync')
                obj.sync = data.sync;
                obj.framesToLabel = data.framesToLabel;
            end
            obj.status = data.status;
            obj.checkStatus()
            obj.update()
        end
        
        function load(obj, varargin)
            if ~isempty(varargin)
                files = varargin{1};
                varargin(1) = [];
            else
                files = uigetfile('*.mat', 'MultiSelect', 'on');
            end
            
            if iscell(files)
                obj.loadMerge(files, varargin{:})
            else
                obj.loadAll(files, varargin{:});
            end
        end
        
    end
    
    methods (Access = protected)
        function update(obj)
            % Update all of the other animators with any new data.
            for nKPAnimator = 1 : obj.nCams
                kpaId = obj.nCams + nKPAnimator;
                kps = zeros(obj.nMarkers, size(obj.camPoints, 3), size(obj.camPoints, 4));
                kps(:) = obj.camPoints(:, nKPAnimator, :, :);
                kps = permute(kps, [3 2 1]);
                
                obj.h{kpaId}.markers = kps;
                obj.h{kpaId}.markersX(:) = kps(:, 1, :);
                obj.h{kpaId}.markersY(:) = kps(:, 2, :);
                
                fr = obj.frameInds(obj.frame);
                obj.h{kpaId}.points.XData(:) = kps(fr, 1, :);
                obj.h{kpaId}.points.YData(:) = kps(fr, 2, :);
            end
            
            % Run all of the update functions.
            for nAnimator = 1 : numel(obj.h)
                obj.h{nAnimator}.update()
            end
            
            % Update the keypoint animator data for all frames
            pts = permute(obj.points3D, [3 2 1]);
            obj.kp3a.markers = pts;
            obj.kp3a.markersX = pts(:, 1, :);
            obj.kp3a.markersY = pts(:, 2, :);
            obj.kp3a.markersZ = pts(:, 3, :);
            obj.kp3a.update()
            
            % Update the status animator
            obj.updateStatusAnimator()
        end
        
        function setUpKeypointTable(obj)
            f = figure('Units', 'Normalized', 'pos', obj.tablePosition, 'Name', 'Keypoint table', ...
                'NumberTitle', 'off');
            obj.jointsPanel = uix.Panel('Parent', f, 'Title', 'Joints', ...
                'Padding', 5, 'Units', 'Normalized');
            obj.jointsControl = uicontrol(obj.jointsPanel, 'Style', ...
                'listbox', 'String', obj.skeleton.joint_names, ...
                'Units', 'Normalized', 'Callback', @(h, ~, ~) obj.selectNode(h.Value));
            set(obj.Parent.Children(end), 'Visible', 'off')
        end
        
        function setUpStatusTable(obj)
            f = figure('Units', 'Normalized', 'pos', [0 0 .5 .3], ...
                'NumberTitle', 'off');
            ax = gca;
            colormap([0 0 0;.5 .5 .5;1 1 1])
            summary = zeros(size(obj.status, 1), size(obj.status, 3));
            summary(:) = mode(obj.status, 2);
            obj.statusAnimator = HeatMapAnimator(summary', 'Axes', ax);
            obj.statusAnimator.c.Visible = 'off';
            ax = obj.statusAnimator.Axes;
            set(ax, 'YTick', 1:obj.nMarkers, 'YTickLabels', obj.skeleton.joint_names)
            yyaxis(ax, 'right')
            if obj.nMarkers == 1
                set(ax, 'YLim', [.5 1.5], 'YTick', 1, 'YTickLabels', sum(summary, 2))
            else
                set(ax, 'YLim', [1 obj.nMarkers], 'YTick', 1:obj.nMarkers, 'YTickLabels', sum(summary, 2))
            end
            set(obj.statusAnimator.img, 'CDataMapping', 'direct')
            obj.counter = title(sprintf('Total: %d', sum(any(summary==obj.isLabeled, 1))));
        end
        
        function updateStatusAnimator(obj)
            obj.checkStatus();
            summary = zeros(size(obj.status, 1), size(obj.status, 3));
            summary(:) = mode(obj.status, 2);
            obj.statusAnimator.img.CData = summary+1;
            yyaxis(obj.statusAnimator.Axes, 'right')
            set(obj.statusAnimator.Axes, 'YTickLabels', flip(sum(summary==obj.isLabeled, 2)))
            obj.counter.String = sprintf('Total: %d', sum(any(summary==obj.isLabeled, 1)));
            obj.statusAnimator.update()
        end
    end
end
