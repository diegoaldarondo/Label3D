classdef Label3D < Animator
    % Label3D - Label3D is a GUI for manual labeling of 3D keypoints in multiple cameras.
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
    % 
    %  Instructions:
    %  right: move forward one frameRate
    %  left: move backward one frameRate
    %  up: increase the frameRate
    %  down: decrease the frameRate
    %  t: triangulate points in current frame that have been labeled in at least two images and reproject into each image
    %  r: reset gui to the first frame and remove Animator restrictions
    %  u: reset the current frame to the initial marker positions
    %  z: Toggle zoom state
    %  p: Show 3d animation plot of the triangulated points.
    %  backspace: reset currently held node (first click and hold, then
    %             backspace to delete)
    %  pageup: Set the selectedNode to the first node
    %  tab: shift the selected node by 1
    %  shift+tab: shift the selected node by -1
    %  h: print help messages for all Animators
    %  shift+s: Save the data to a .mat file
    % 
    %    Label3D Properties:
    %    cameraParams - Camera Parameters for all cameras
    %    cameraPoses - Camera poses for all cameras
    %    orientations - Orientations of all cameras
    %    locations - Locations of all cameras
    %    camPoints - Positions of all points in camera coordinates
    %    points3D - Positions of all points in world XYZ coordinates
    %    status - Logical matrix denoting whether a node has been modified
    %    selectedNode - Currently selected node for click updating
    %    skeleton - Struct denoting directed graph
    %    ImageSize - Size of the images
    %    nMarkers - Number of markers
    %    nCams - Number of Cameras
    %    jointsPanel - Handle to keypoint panel
    %    jointsControl - Handle to keypoint controller
    %    savePath - Path in which to save data.
    %    h - Cell array of Animator handles.
    %    frameInds - Indices of current subset of frames
    %    frame - Current frame number within subset
    %    frameRate - current frame rate
    %    undistortedImages - If true, treat input images as undistorted
    %                        (Default false)
    %    savePath - Path in which to save output. The output files are of
    %               the form
    %               path = sprintf('%s%sCamera_%d.mat', obj.savePath, ...
    %                        datestr(now, 'yyyy_mm_dd_HH_MM_SS'), nCam);
    %    verbose - Print saving messages
    % 
    %    Label3D Methods:
    %    Label3D - constructor
    %    loadcamParams - Load in camera parameters
    %    getCameraPoses - Return table of camera poses
    %    zoomOut - Zoom all images out to full size
    %    getLabeledJoints - Return the indices of labeled joints and
    %        corresponding cameras in a frame.
    %    triangulateLabeledPoints - Return xyz positions of labeled joints.
    %    reprojectPoints - reproject points from world coordinates to the
    %        camera reference frames
    %    resetFrame - reset all labels to the initial positions within a
    %        frame.
    %    clickImage - Assign the position of the selected node with the
    %        position of a mouse click.
    %    getPointTrack - Helper function to return pointTrack object for
    %        current frame.
    %    plotCameras - Plot the positions and orientations of all cameras in
    %        world coordinates.
    %    checkStatus - Check whether points have been moved and update
    %        accordingly
    %    keyPressCallback - handle UI
    %    saveState - save the current labeled data to a mat file.
    %    selectNode - Modify the current selected node.
    % 
    %    Written by Diego Aldarondo (2019)
    %    Some code adapted from https://github.com/talmo/leap
    properties (Access = private)
        % color %UNUSED
        % joints %UNUSED
        origNFrames % original # of frames - why needed? does n-frames ever change?
        initialMarkers
        isKP3Dplotted % track status of keypoints 3d plotted (for toggling)
        % NOTE: maybe we can just rely on kp3d.Visible == 1 instead?
        gridColor = [0.7, 0.7, 0.7]
        mainFigureColor = [0.1412, 0.1412, 0.1412]
        labelPosition = [0, 0.3, 0.9, 0.5]
        tablePosition = [0.9, 0.3, 0.1, 0.5]
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
        hiddenAxesPos = [0.99, 0.99, 0.01, 0.01] %used to relocate plots offscreen to hide them
        isLabeled = 2 % enum in status matrix representing labeled (by hand or computed)
        isInitialized = 1 % enum in status matrix representing initially provided points
        isInvisible = 3 % enum in status matrix representing an invisible keypoint
        counter % text object: total # of labeled frames
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
        cameraNames % Cell array of camera names corresponding to videos/params
        videoPositions % x, y, width, height (origin = bottom left?) of videos. SHAPE: (#cams, 4)
        defScale % global scale for images
        pctScale = 0.2 % scale images by this fraction
        DragPointColor = [1, 1, 1]; % passed to DraggableKeypoint2DAnimator constructor
        visibleDragPoints = true; %p assed to DraggableKeypoint2DAnimator constructor
        sessionDatestr % date string during load: used to set save file name
        camPrefixMap % Map from Cam_XXX name to hardware ID prefix
        nAnimalsInSession % Number of animals being labeled in this session
        flipViewsVertically = false; % If true, display camera views flipped vertically

        % --- Camera View Pagination Properties ---
        camerasPerPage = 2; % Number of camera views to show per page
        currentCameraPage = 1; % Current page number (1-indexed)
        totalPages = 1; % Total number of pages (calculated)
        nextPageButton % Handle to the 'Next Page' button
        prevPageButton % Handle to the 'Previous Page' button
        pageInfoText   % Handle to the text displaying page info

        % ===========================
        % Useful Inherited properties
        % ===========================
        % Parent: current figure (from `gcf`)
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
            %   videos: Cell array of h x w x c x nFrames videos.
            %   skeleton: Structure with three fields:
            %       skeleton.color: nSegments x 3 matrix of RGB values
            %       skeleton.joints_idx: nSegments x 2 matrix of integers
            %           denoting directed edges between markers.
            %       skeleton.joint_names: cell array of names of each joint
            %   Syntax: Label3D(camParams, videos, skeleton, varargin);
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
            % buildFromScratch - Helper for Label3D constructor class.
            %
            % Inputs:
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
            % if ~isempty(varargin) % Original line
            %    set(obj, varargin{:}) % Original line
            % end % Original line
        
            % --- Handle Optional Inputs including 'nAnimals' ---
            obj.camPrefixMap = containers.Map('KeyType', 'char', 'ValueType', 'char'); % Initialize empty
            obj.nAnimalsInSession = 0; % Default, will be set from varargin
            obj.framesToLabel = []; % Initialize framesToLabel
            obj.cameraNames = {}; % Initialize cameraNames
            obj.undistortedImages = false; % Default for undistortedImages (can be overridden by Animator's default)
            % savePath is initialized to '' by default in properties

            nAnimalsVal = []; 
            camPrefixMapVal = [];
            passedFramesToLabel = [];
            passedSavePath = '';
            passedCameraNames = {};
            passedUndistortedImages = []; % Use empty to detect if it was explicitly passed

            otherArgsForSet = {}; 
            i = 1;
            while i <= numel(varargin)
                if (ischar(varargin{i}) || isstring(varargin{i})) && i+1 <= numel(varargin)
                    paramName = varargin{i};
                    paramValue = varargin{i+1};
        
                    switch lower(paramName)
                        case 'nanimals'
                            nAnimalsVal = paramValue;
                        case 'camprefixmap'
                            if isa(paramValue, 'containers.Map')
                                camPrefixMapVal = paramValue;
                                fprintf('DEBUG buildFromScratch: Successfully queued camPrefixMap.\n');
                            else
                                warning('Label3D:buildFromScratch', 'Optional input ''camPrefixMap'' ignored: value is not a containers.Map.');
                            end
                        case 'framestolabel'
                            passedFramesToLabel = paramValue;
                        case 'savepath'
                            passedSavePath = paramValue;
                        case 'cameranames'
                            passedCameraNames = paramValue;
                        case 'undistortedimages'
                            passedUndistortedImages = paramValue; % Store it, could be logical
                        otherwise
                            % Add other valid key-value pairs to otherArgsForSet
                            otherArgsForSet{end+1} = paramName;
                            otherArgsForSet{end+1} = paramValue;
                    end
                    i = i + 2; % Move past key and value
                else
                    % Handle potential malformed varargin or single trailing argument
                    % If it's the last argument and not a pair, it might be a flag for the Animator base class
                    if i == numel(varargin) && (ischar(varargin{i}) || isstring(varargin{i}))
                         otherArgsForSet{end+1} = varargin{i};
                    else
                        warning('Label3D:buildFromScratch', 'Skipping unexpected or incomplete input argument near index %d', i);
                    end
                    i = i + 1;
                end
            end
        
            % Assign parsed critical values
            if ~isempty(nAnimalsVal)
                obj.nAnimalsInSession = nAnimalsVal;
            else
                error('Label3D:buildFromScratch', '''nAnimals'' must be provided as a named argument.');
            end
            
            if ~isempty(camPrefixMapVal)
                obj.camPrefixMap = camPrefixMapVal;
            end

            if ~isempty(passedFramesToLabel)
                obj.framesToLabel = passedFramesToLabel;
            end
            if ~isempty(passedSavePath)
                obj.savePath = passedSavePath; % This will be combined with filename later
            end
            if ~isempty(passedCameraNames)
                obj.cameraNames = passedCameraNames;
            end
            if ~isempty(passedUndistortedImages) % Check if it was explicitly passed
                obj.undistortedImages = passedUndistortedImages;
            end

            % Apply any remaining arguments using set
            if ~isempty(otherArgsForSet)
                 if mod(numel(otherArgsForSet), 2) ~= 0 && ~(numel(otherArgsForSet)==1 && (ischar(otherArgsForSet{1}) || isstring(otherArgsForSet{1}) ))
                     warning('Label3D:buildFromScratch', 'otherArgsForSet has an odd number of elements (and is not a single flag). Skipping set().');
                     disp(otherArgsForSet);
                 else
                     try
                        set(obj, otherArgsForSet{:});
                        fprintf('DEBUG buildFromScratch: set(obj, otherArgsForSet{:}) executed successfully.\n');
                     catch ME_set
                         fprintf('ERROR during set(obj, otherArgsForSet{:}):\n');
                         disp(otherArgsForSet); 
                         rethrow(ME_set);
                     end
                 end
            else
                 fprintf('DEBUG buildFromScratch: No other arguments for set().\n');
            end
            % --- End Handle Optional Inputs ---

            % Basic validation for nAnimalsInSession
            if obj.nAnimalsInSession <= 0
                error('Label3D:buildFromScratch', 'nAnimalsInSession must be greater than 0.');
            end
            % obj.nMarkers will be set later after skeleton.joint_names is known
            
             % Set up Animator parameters
            obj.origCamParams = camParams;
            obj.nFrames = size(videos{1}, 4);
            obj.origNFrames = obj.nFrames;
            
            % If framesToLabel was not passed or is empty, default to all frames of the video
            if isempty(obj.framesToLabel) 
                obj.framesToLabel = 1 : obj.nFrames;
            end
            obj.frameInds = obj.framesToLabel; % Use the potentially subsetted frames for frameInds
            obj.nFrames = numel(obj.frameInds); % Update nFrames to reflect the number of frames to be labeled

            obj.nMarkers = numel(obj.skeleton.joint_names);
        
            % Validate nMarkers against nAnimalsInSession
            if obj.nMarkers > 0 && obj.nAnimalsInSession > 0 && mod(obj.nMarkers, obj.nAnimalsInSession) ~= 0
                warning('Label3D:buildFromScratch', 'Number of markers (%d) is not evenly divisible by nAnimalsInSession (%d). Swap ID functionality might be affected.', obj.nMarkers, obj.nAnimalsInSession);
            end

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
            
            % --- Initialize Pagination ---
            obj.currentCameraPage = 1;
            if obj.nCams > 0 && obj.camerasPerPage > 0
                obj.totalPages = ceil(obj.nCams / obj.camerasPerPage);
            else
                obj.totalPages = 1;
            end
            % --- End Initialization ---

            % Make the VideoAnimators
            if isempty(obj.videoPositions)
                % Pre-calculate all potential positions even if not used immediately
                obj.videoPositions = obj.getPositions(obj.nCams); 
            end
            for nCam = 1 : obj.nCams
                % Create animator but don't set position here, let updateCameraViewLayout handle it
                % pos = obj.videoPositions(nCam, :); % Position will be set later
                obj.h{nCam} = VideoAnimator(videos{nCam}, 'Position', [0 0 0.1 0.1], 'Visible', 'off', 'frameInds', obj.frameInds); % Pass frameInds, start invisible and small
                ax = obj.h{nCam}.Axes;
                ax.Toolbar.Visible = 'off';
                set(ax, 'XTick', [], 'YTick', []);
                set(obj.h{nCam}.img, 'ButtonDownFcn', @obj.clickImage);

                % --- ADD SWAP ID BUTTON for this camera view ---
                btnWidth = 0.04; % Normalized width - MODIFIED (was 0.05)
                btnHeight = 0.02; % Normalized height for button text visibility - MODIFIED (was 0.025)
                % Position button relative to AXES, not figure - Requires modification if axes position changes dynamically.
                % For now, we'll place it relative to the figure's bottom-right, which might not align perfectly with the paged axes.
                % A better approach would be to parent the button to a panel associated with the axes, or update button position in updateCameraViewLayout.
                % Let's stick to figure-relative for simplicity first.
                
                % Estimate button position (this part is now less reliable due to pagination changing axes positions)
                % We might need to adjust this or create buttons dynamically in updateCameraViewLayout
                % estAxPos = obj.videoPositions(nCam, :); % Use pre-calculated pos for estimation % REMOVED
                % btnX = estAxPos(1) + estAxPos(3) - btnWidth - 0.005; % REMOVED
                % btnY = estAxPos(2) + 0.005; % REMOVED
                % btnX = max(0.001, btnX); % REMOVED
                % btnY = max(0.001, btnY); % REMOVED


                uicontrol('Parent', obj.Parent, ... 
                          'Style', 'pushbutton', ...
                          'String', sprintf('Swap Cam%d IDs', nCam), ...
                          'Units', 'normalized', ...
                           'Position', [0 0 0.01 0.01], ... % Initial small, off-screen position
                          'Callback', @(~,~) obj.swapAnimalIDsInView(nCam), ...
                          'Tag', sprintf('SwapButtonCam%d', nCam), ...
                          'TooltipString', sprintf('Swap Animal IDs for camera %d in current frame', nCam), ...
                          'FontSize', 7, ...
                          'Visible', 'off'); % Start hidden, manage visibility in updateCameraViewLayout
            end
            
            % --- Add Camera Name Overlay & Principal Point ---
            if ~isempty(obj.cameraNames) && numel(obj.cameraNames) == obj.nCams
                for nCam = 1 : obj.nCams
                    ax = obj.h{nCam}.Axes;
                    hold(ax, 'on'); % Ensure we are adding to the plot

                    % Add Camera Name Text
                    camName = obj.cameraNames{nCam};
                    text(ax, 0.98, 0.95, strrep(camName, '_', ' '), ... 
                        'Units', 'normalized', ...
                        'Color', 'white', ...
                        'BackgroundColor', [0 0 0 0.5], ... % Semi-transparent black background
                        'Margin', 2, ...
                        'HorizontalAlignment', 'right', ...
                        'VerticalAlignment', 'top', ...
                        'FontSize', 10, ...
                        'FontWeight', 'bold');

                    % --- Add Hardware ID Text (below Cam Name) ---
                    if ~isempty(obj.camPrefixMap) && isKey(obj.camPrefixMap, camName)
                        prefix = obj.camPrefixMap(camName);
                        text(ax, 0.98, 0.90, prefix, ... % Adjust Y position (e.g., 0.90)
                             'Units', 'normalized', ...
                             'Color', 'cyan', ... % Use a different color for distinction
                             'BackgroundColor', [0 0 0 0.5], ...
                             'Margin', 2, ...
                             'HorizontalAlignment', 'right', ...
                             'VerticalAlignment', 'top', ...
                             'FontSize', 8, ... % Slightly smaller font
                             'FontWeight', 'normal');
                    else
                        % Optional: print warning if map exists but key is missing
                        if ~isempty(obj.camPrefixMap)
                            warning('Prefix not found in camPrefixMap for: %s', camName);
                        end
                    end
                    % --------------------------------------------

                    % Add Principal Point Marker
                    try
                        camParam = obj.cameraParams{nCam};
                        % The cameraParameters object holds the K matrix in the 
                        % non-standard format it was given: [[fx,0,0],[0,fy,0],[cx,cy,1]]
                        K_nonstandard = camParam.Intrinsics.IntrinsicMatrix; 
                        % Extract cx, cy from the correct locations for this format
                        cx = K_nonstandard(3, 1);
                        cy = K_nonstandard(3, 2);
                        % Plot the marker
                        plot(ax, cx, cy, 'r*', 'MarkerSize', 8, 'LineWidth', 1.5); 
                        % Add text label with coordinates
                        text(ax, cx + 10, cy + 10, sprintf('(%.1f, %.1f)', cx, cy), ...
                             'Color', 'red', ...
                             'FontSize', 8, ...
                             'Clipping', 'on'); % Clip text if it goes off axes
                    catch ME_pp
                        warning('Could not plot principal point for %s: %s', camName, ME_pp.message);
                    end

                    hold(ax, 'off'); % Release hold
                end
            else
                warning('Camera names not provided or mismatch count; skipping overlay.');
            end
            % --- End Overlay Section ---

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
            newMarkerSize = 4; % Define desired marker size
            for nCam = 1 : obj.nCams
                obj.h{obj.nCams + nCam} = ...
                    DraggableKeypoint2DAnimator(obj.markers{nCam}, ...
                    obj.skeleton, 'Axes', obj.h{nCam}.Axes, ... % Reuse axes from VideoAnimator
                    'visibleDragPoints', obj.visibleDragPoints, ...
                    'DragPointColor', obj.DragPointColor, ...
                    'MarkerSize', newMarkerSize, ...
                    'LineWidth', 1); % <-- Added LineWidth here
                ax = obj.h{obj.nCams + nCam}.Axes; % Axes are already invisible from VideoAnimator setup
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

            % --- Create Pagination Controls ---
            buttonHeight = 0.02; % MODIFIED (was 0.025)
            buttonWidth = 0.05;  % MODIFIED (was 0.06)
            infoWidth = 0.08; % Adjusted to be proportional, was 0.10
            bottomMargin = 0.01;
            spacing = 0.005; % Adjusted spacing slightly
            
            totalWidth = buttonWidth + spacing + infoWidth + spacing + buttonWidth;
            startX = (1 - totalWidth) / 2;

            obj.prevPageButton = uicontrol('Parent', obj.Parent, 'Style', 'pushbutton', ...
                                          'String', '< Prev', 'Units', 'normalized', ...
                                          'Position', [startX, bottomMargin, buttonWidth, buttonHeight], ...
                                          'Callback', @obj.prevPageCallback, 'Tag', 'PrevPageButton');
            
            obj.pageInfoText = uicontrol('Parent', obj.Parent, 'Style', 'text', ...
                                         'String', sprintf('Page %d / %d', obj.currentCameraPage, obj.totalPages), ...
                                         'Units', 'normalized', ...
                                         'Position', [startX + buttonWidth + spacing, bottomMargin, infoWidth, buttonHeight], ...
                                         'Tag', 'PageInfoText');

            obj.nextPageButton = uicontrol('Parent', obj.Parent, 'Style', 'pushbutton', ...
                                          'String', 'Next >', 'Units', 'normalized', ...
                                          'Position', [startX + buttonWidth + spacing + infoWidth + spacing, bottomMargin, buttonWidth, buttonHeight], ...
                                          'Callback', @obj.nextPageCallback, 'Tag', 'NextPageButton');
            % --- End Pagination Controls ---


            % --- Disable Default Data Cursor Mode and Limit Interactions (like original) --- 
            % Remove the explicit disabling of datacursormode, as disableDefaultInteractivity handles it.
            % dcm_obj = datacursormode(obj.Parent); 
            % set(dcm_obj, 'Enable', 'off');

            % Limit the default interactivity to useful interactions
            for nAx = 1 : numel(obj.Parent.Children)
                ax = obj.Parent.Children(nAx);
                try % Wrap in try-catch in case some children are not axes
                    disableDefaultInteractivity(ax);
                    % Only enable zoom and pan - Data cursor should remain disabled
                    ax.Interactions = [zoomInteraction, regionZoomInteraction, rulerPanInteraction]; 
                catch ME_interact
                    % Ignore errors for non-axes children
                    % fprintf('Skipping interaction setting for child %d: %s\n', nAx, ME_interact.message); 
                end
            end
            % --- End Interaction Limiting --- 

            % --- Initial Layout Update ---
            obj.updateCameraViewLayout(); % Call this to set initial visibility and positions
            % --- End Initial Layout Update ---
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
            len = ceil(nViews / nRows);
            pos = zeros(numel(views), 4);
            pos(:, 1) = rem(views - 1, len) / len;
            pos(:, 2) = (1 - 1 / nRows) - 1 / nRows * (floor((views - 1) / len));
            pos(:, 3) = 1 / len;
            pos(:, 4) = 1 / nRows;
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
            animators = [obj.h, {obj}, {obj.kp3a}, {obj.statusAnimator}];
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
            data_3D = permute(pts3D, [3, 2, 1]);
            data_3D = reshape(data_3D, size(data_3D, 1), []);
            if ~isempty(obj.framesToLabel) && ~isempty(obj.sync)
                sync = obj.sync;
                framesToLabel = obj.framesToLabel;
                save(path, 'videos', 'camParams', 'handLabeled2D', 'skeleton', 'data_3D', 'status', ...
                    'sync', 'framesToLabel', ...
                    'savePath', '-v7.3')
            elseif ~isempty(obj.framesToLabel)
                framesToLabel = obj.framesToLabel;
                save(path, 'videos', 'camParams', 'handLabeled2D', 'skeleton', 'data_3D', 'status', ...
                    'framesToLabel', 'savePath', '-v7.3')
            else
                save(path, 'videos', 'camParams', 'handLabeled2D', 'skeleton', 'data_3D', 'status', ...
                    'savePath', '-v7.3')
            end
        end
        
        function [c, orientations, locations] = loadcamParams(obj, camParams) % Restore original input name
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
                % Original logic: Get parameters into cameraParameters object.
                K = camParams{i}.K;
                RDistort = camParams{i}.RDistort;
                TDistort = camParams{i}.TDistort;
                R = camParams{i}.r; % Assumed R_w_c in original? Let's stick to original logic flow.
                rotationVector = rotationMatrixToVector(R);
                translationVector = camParams{i}.t; % Assumed T_c_w in original?

                c{i} = cameraParameters( ... 
                    'IntrinsicMatrix', K, ... % REMOVED TRANSPOSE to match original_label3d.m
                    'ImageSize', obj.ImageSize(i, :), ...
                    'RadialDistortion', RDistort, ...
                    'TangentialDistortion', TDistort, ...
                    'RotationVectors', rotationVector, ... % Use R directly converted
                    'TranslationVectors', translationVector); % Use t directly

                % Original logic for orientations and locations:
                orientations{i} = R'; % Store R' = R_w_c' = R_c_w (Matches original)
                locations{i} = -translationVector * orientations{i}; % Store T_w_c = -T_c_w * R_c_w (Matches original)
            end
        end
        
        function cameraPoses = getCameraPoses(obj)
            % GETCAMERAPOSES - Helper function to store the camera poses
            % for triangulation
            %
            % See also: LOADCAMPARAMS
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
            % ZOOMOUT - Zoom all images out to their maximum sizes.
            %
            % See also: TRIANGULATEVIEW
            for i = 1 : obj.nCams
                xlim(obj.h{obj.nCams + i}.Axes, [1 obj.ImageSize(i, 2)])
                ylim(obj.h{obj.nCams + i}.Axes, [1 obj.ImageSize(i, 1)])
            end
        end
        
        function triangulateView(obj)
            % TRIANGULATEVIEW - Triangulate labeled points and zoom all
            % images around those points.
            %
            % Syntax: obj.triangulateView()
            %
            % See also: ZOOMOUT
            
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
                            xyzNodes(end + 1, :) = [xyzEdges(i, 1), xyzEdges(j, 2), xyzEdges(k, 3)];
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
                    xPad = obj.pctScale * camParam.Intrinsics.ImageSize(1);
                    yPad = obj.pctScale * camParam.Intrinsics.ImageSize(2);
                    ax.XLim = [pt(1) - xPad, pt(1) + xPad];
                    ax.YLim = [pt(2) - yPad, pt(2) + yPad];
                end
            end
        end
        
        function [camIds, jointIds] = getLabeledJoints(obj, frame)
            % Look within a frame and return all joints with at least two
            % labeled views, as well as a logical vector denoting which two
            % views. Excludes points marked as invisible.
            s = zeros(size(obj.status, 1), size(obj.status, 2));
            s(:) = obj.status(:, :, frame);
            % Original: labeled = s == obj.isLabeled | s == obj.isInitialized;
            % New: Exclude points marked as isInvisible
            usable_for_triangulation = (s == obj.isLabeled | s == obj.isInitialized) & (s ~= obj.isInvisible);
            jointIds = find(sum(usable_for_triangulation, 2) >= 2);
            camIds = usable_for_triangulation(jointIds, :);
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
            pointTracks.Points = cat(1, points, repmat(points(cams == cam1, :), nReps, 1));
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
            % xyzPoints = zeros(numel(jointIds), 3); % Remove preallocation
            for nJoint = 1 : numel(jointIds)
                camsLogicalRow = camIds(nJoint, :);
                joint = jointIds(nJoint);
                pointTracks = obj.getPointTrack(frame, joint, camsLogicalRow); % Gets undistorted points

                cameraIndicesUsed = find(camsLogicalRow); % Store indices
                
                % fprintf('--- Inputs to triangulateMultiview for Joint %d ---\n', joint);
                % fprintf('  Undistorted 2D Points (pointTracks.Points):\n');
                % disp(pointTracks.Points);
                
                % fprintf('  Camera Indices Used: %s\n', mat2str(cameraIndicesUsed)); % Use stored indices
                
                % --- Add check for empty indices --- 
                if isempty(cameraIndicesUsed)
                    % fprintf('  WARNING: No valid camera indices found for joint %d in this frame. Skipping triangulation.\n', joint);
                    continue; % Skip to the next joint
                end
                % --- End check ---
                
                poses_to_use = obj.cameraPoses(cameraIndicesUsed,:); % Use stored indices
                % fprintf('  Poses Passed (from obj.cameraPoses):\n');
                % disp(poses_to_use); % Display the relevant rows of the table
                
                intrinsics_to_use = intrinsics(cameraIndicesUsed); % Use stored indices
                % fprintf('  Intrinsics Passed:\n');
                % for intr_idx = 1:numel(intrinsics_to_use)
                %    fprintf('  Camera %d Intrinsics:\n', cameraIndicesUsed(intr_idx)); % Use stored indices
                %    disp(intrinsics_to_use(intr_idx)); % Display the cameraIntrinsics object
                % end

                % The actual triangulation call
                 % obj.cameraPoses(find(camsLogicalRow), :), intrinsics(find(camsLogicalRow)));
                 % Store the single result directly
                 % current_xyzPoint = triangulateMultiview(pointTracks, poses_to_use, intrinsics_to_use); 
                 
                 % --- Call triangulateMultiview within try-catch ---
                 current_xyzPoint = []; % Initialize to empty
                 triangulation_successful = false; 
                 try
                     % fprintf('Attempting triangulation for joint %d...\n', joint); % Log before call
                     current_xyzPoint = triangulateMultiview(pointTracks, poses_to_use, intrinsics_to_use);
                     triangulation_successful = true;
                     % fprintf('Triangulation call completed for joint %d.\n', joint); % Log after call
                 catch ME
                     fprintf('!!! ERROR during triangulateMultiview call for joint %d !!!\n', joint);
                     fprintf('Error Identifier: %s\n', ME.identifier);
                     fprintf('Error Message: %s\n', ME.message);
                     % Optionally display stack trace
                     % disp(ME.stack); 
                     current_xyzPoint = [NaN, NaN, NaN]; % Assign NaN on error
                 end

                % --- START Log Output / Result Inspection ---
                % fprintf('  Result Inspection for Joint %d:\n', joint);
                % fprintf('    Success Flag: %d\n', triangulation_successful);
                % fprintf('    Output Type: %s\n', class(current_xyzPoint));
                % fprintf('    Output Size: %s\n', mat2str(size(current_xyzPoint)));
                % fprintf('    Output Value (current_xyzPoint): ');
                % disp(current_xyzPoint); % Display the result
                % fprintf('----------------------------------------------------');
                % --- END Log Output ---
                
                % --- Assign result inside the loop --- 
                % obj.points3D(joint, :, frame) = current_xyzPoint;
                if triangulation_successful && isnumeric(current_xyzPoint) && isequal(size(current_xyzPoint), [1, 3]) && ~any(isnan(current_xyzPoint)) && ~any(isinf(current_xyzPoint))
                    % fprintf('    Assigning valid result to obj.points3D(%d, :, %d)\n', joint, frame);
                    obj.points3D(joint, :, frame) = current_xyzPoint;
                else
                    % fprintf('    Skipping assignment due to error or invalid result.\n');
                    % Optionally assign NaN if needed, or leave as is
                    % obj.points3D(joint, :, frame) = [NaN, NaN, NaN]; 
                end
                % fprintf('----------------------------------------------------');

            end % End of nJoint loop
            
            % Save the results to the points3D matrix
            % obj.points3D(jointIds, :, frame) = xyzPoints; % Remove assignment outside the loop (THIS LINE WAS THE PROBLEM)
        end % THIS end closes the triangulateLabeledPoints function
        
        function reprojectPoints(obj, frame)
            % Find joints that have valid 3D data in this frame
            valid3D = ~any(isnan(obj.points3D(:, :, frame)), 2);
            jointIdsWith3D = find(valid3D); % Indices of joints with valid 3D points
        
            if isempty(jointIdsWith3D)
                return; % Nothing to reproject
            end
        
            worldPointsToReproject = obj.points3D(jointIdsWith3D, :, frame);
        
            % Reproject the world coordinates for the joints with valid 3D
            % to each camera and selectively store in camPoints, respecting isInvisible status
            for nCam = 1 : obj.nCams
                camParam = obj.cameraParams{nCam};
                rotation = obj.orientations{nCam}';
                translation = camParam.TranslationVectors;
        
                if ~isempty(worldPointsToReproject)
                    applyDistortionFlag = ~obj.undistortedImages; % Set flag based on property
        
                    % Perform reprojection for all valid 3D points at once
                    projectedImagePointsAll = worldToImage(camParam, rotation, translation, ...
                                                        worldPointsToReproject, 'ApplyDistortion', applyDistortionFlag);
        
                    % Now, selectively update camPoints based on status
                    for idx = 1:numel(jointIdsWith3D)
                        currentJointId = jointIdsWith3D(idx);
                        % Check status using the session frame index (obj.frame) if frame argument is actual video frame, 
                        % or just frame if frame argument is already session frame index.
                        % Assuming 'frame' passed to reprojectPoints is the actual video frame index corresponding to obj.frameInds(obj.frame)
                        % We need the session frame index to access obj.status correctly.
                        % Find the session frame index corresponding to the passed 'frame' index
                        sessionFrameIdx = find(obj.frameInds == frame, 1);
                        if isempty(sessionFrameIdx)
                             warning('Label3D:reprojectPoints', 'Could not find session frame index for actual frame %d. Skipping status check.', frame);
                             currentStatus = -1; % Assign a value that won't match isInvisible
                        else
                            currentStatus = obj.status(currentJointId, nCam, sessionFrameIdx);
                        end
                        
                        % Only update camPoints if the status is NOT invisible
                        if currentStatus ~= obj.isInvisible
                            % Ensure projectedImagePointsAll has the expected size
                            if idx <= size(projectedImagePointsAll, 1)
                                 % Assign to the correct sessionFrameIdx in camPoints
                                 obj.camPoints(currentJointId, nCam, :, sessionFrameIdx) = projectedImagePointsAll(idx, :);
                            else
                                % This case indicates an unexpected mismatch, should be investigated if it occurs
                                warning('Label3D:reprojectPoints', 'Mismatch between jointIdsWith3D count and projected points for frame %d, cam %d, joint %d.', frame, nCam, currentJointId);
                            end
                        else
                            % If status IS invisible, ensure camPoints remains NaN 
                            % (it should already be NaN from 'i' key or checkStatus, but set explicitly for safety)
                            obj.camPoints(currentJointId, nCam, :, sessionFrameIdx) = [NaN, NaN]; 
                        end
                    end % End loop through joints for this camera
                end % End check if worldPointsToReproject is not empty
            end % End loop through cameras
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
        % function reprojectPoints(obj, frame)
        %     % Find joints that have valid 3D data in this frame
        %     valid3D = ~any(isnan(obj.points3D(:, :, frame)), 2);
        %     jointIdsWith3D = find(valid3D); % Indices of joints with valid 3D points
        % \n        \n            if isempty(jointIdsWith3D)\n                return; % Nothing to reproject\n            end\n        \n            worldPointsToReproject = obj.points3D(jointIdsWith3D, :, frame);\n        \n            % Reproject the world coordinates for the joints with valid 3D\n            % to each camera and selectively store in camPoints, respecting isInvisible status\n            for nCam = 1 : obj.nCams\n                camParam = obj.cameraParams{nCam};\n                rotation = obj.orientations{nCam}\';\n                translation = camParam.TranslationVectors;\n        \n                if ~isempty(worldPointsToReproject)\n                    applyDistortionFlag = ~obj.undistortedImages; % Set flag based on property\n        \n                    % Perform reprojection for all valid 3D points at once\n                    projectedImagePointsAll = worldToImage(camParam, rotation, translation, ...\n                                                          worldPointsToReproject, \\\'\\\'\\\'ApplyDistortion\\\'\\\'\\\', applyDistortionFlag);\n        \n                    % Now, selectively update camPoints based on status\n                    for idx = 1:numel(jointIdsWith3D)\n                        currentJointId = jointIdsWith3D(idx);\n                        % Check status using the session frame index (obj.frame) if frame argument is actual video frame, \n                        % or just frame if frame argument is already session frame index.\n                        % Assuming \'frame\' passed to reprojectPoints is the actual video frame index corresponding to obj.frameInds(obj.frame)\n                        % We need the session frame index to access obj.status correctly.\n                        % Find the session frame index corresponding to the passed \'frame\' index\n                        sessionFrameIdx = find(obj.frameInds == frame, 1);\ \n                        if isempty(sessionFrameIdx)\n                             warning(\\\'\\\'\\\'Label3D:reprojectPoints\\\'\\\'\\\', \\\'\\\'\\\'Could not find session frame index for actual frame %d. Skipping status check.\\\'\\\'\\\', frame);\n                             currentStatus = -1; % Assign a value that won\\\'\\\'\\\'t match isInvisible\n                        else\n                            currentStatus = obj.status(currentJointId, nCam, sessionFrameIdx);\n                        end\n                        \n                        % Only update camPoints if the status is NOT invisible\n                        if currentStatus ~= obj.isInvisible\n                            % Ensure projectedImagePointsAll has the expected size\n                            if idx <= size(projectedImagePointsAll, 1)\n                                 % Assign to the correct sessionFrameIdx in camPoints\n                                 obj.camPoints(currentJointId, nCam, :, sessionFrameIdx) = projectedImagePointsAll(idx, :);\n                            else\n                                % This case indicates an unexpected mismatch, should be investigated if it occurs\n                                warning(\\\'\\\'\\\'Label3D:reprojectPoints\\\'\\\'\\\', \\\'\\\'\\\'Mismatch between jointIdsWith3D count and projected points for frame %d, cam %d, joint %d.\\\'\\\'\\\', frame, nCam, currentJointId);\n                            end\n                        else\n                            % If status IS invisible, ensure camPoints remains NaN \n                            % (it should already be NaN from \'i\' key or checkStatus, but set explicitly for safety)\n                            obj.camPoints(currentJointId, nCam, :, sessionFrameIdx) = [NaN, NaN]; \n                        end\n                    end % End loop through joints for this camera\n                end % End check if worldPointsToReproject is not empty\n            end % End loop through cameras\n        end\n        \n        function resetFrame(obj)\n            % Reset current frame to the initial unlabeled positions.\n            for i = 1 : obj.nCams\n                obj.h{obj.nCams + i}.resetFrame();\n            end\n            f = obj.frameInds(obj.frame);\n            obj.status(:, :, f) = 0;\n            if ~isempty(obj.initialMarkers)\n                for nAnimator = 1 : obj.nCams\n                    obj.initialMarkers{nAnimator}(f, :, :) = nan;\n                end\n            end\n            obj.checkStatus();\n            obj.update()\n        end
        % 
        % function resetMarker(obj)
            % Delete the selected nodes if they exist
            draggableAnimators = obj.h(obj.nCams + 1 : 2 * obj.nCams);
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
            selectedNodeIndex = obj.selectedNode;
            obj.h{cam + obj.nCams}.points.XData(selectedNodeIndex) = pt(cam, 1);
            obj.h{cam + obj.nCams}.points.YData(selectedNodeIndex) = pt(cam, 2);
            obj.h{cam + obj.nCams}.dragged(obj.frameInds(obj.frame), obj.selectedNode) = true;
            obj.h{cam + obj.nCams}.update();
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
            daspect(ax, [1, 1, 1]);
            xlabel('X')
            ylabel('Y')
            zlabel('Z')
        end
        
        function checkStatus(obj)
            % Update the movement status for the current frame, if
            % necessary. Prioritizes isInvisible status.
            sessionFrameIdx = obj.frame; % GUI frame index (1 to numel(obj.frameInds))
            actualVideoFrameIdx = obj.frameInds(sessionFrameIdx); % actual video frame number

            for nKPAnimator = 1 : obj.nCams
                kpAnimator = obj.h{obj.nCams + nKPAnimator};
                currentMarkerCoords = kpAnimator.getCurrentFramePositions(); % Get current 2D coords

                for marker_idx = 1:obj.nMarkers
                    % --- Check if marker is marked as invisible FIRST ---
                    if obj.status(marker_idx, nKPAnimator, sessionFrameIdx) == obj.isInvisible
                        % If invisible, ensure camPoints are NaN and skip other checks
                        obj.camPoints(marker_idx, nKPAnimator, :, sessionFrameIdx) = nan;
                        obj.handLabeled2D(marker_idx, nKPAnimator, :, sessionFrameIdx) = nan; % Also clear handLabeled
                        continue; % Skip to the next marker for this camera view
                    end
                    % --- End check ---

                    % --- Original logic (now only runs if not invisible) ---
                    hasMoved = false; % Default
                    currentCoord = currentMarkerCoords(marker_idx, :);
                    isDeleted = any(isnan(currentCoord));

                    if isempty(obj.initialMarkers)
                        % Check only for non-NaN
                        hasMoved = ~isDeleted;
                        if ~hasMoved
                            obj.status(marker_idx, nKPAnimator, sessionFrameIdx) = 0; % Unlabeled
                        else
                            obj.status(marker_idx, nKPAnimator, sessionFrameIdx) = obj.isLabeled;
                        end
                    else
                        % Compare to initial markers
                        initialCoord = nan(1, 2); % Default if index out of bounds
                        if actualVideoFrameIdx <= size(obj.initialMarkers{nKPAnimator}, 1) && marker_idx <= size(obj.initialMarkers{nKPAnimator}, 3)
                             temp_iM = permute(obj.initialMarkers{nKPAnimator}(actualVideoFrameIdx, :, marker_idx), [1, 3, 2]);
                             if ~isempty(temp_iM)
                                initialCoord = temp_iM;
                             end
                        end
                        hasInitial = any(~isnan(initialCoord));

                        if isDeleted
                            obj.status(marker_idx, nKPAnimator, sessionFrameIdx) = 0; % Unlabeled
                        elseif ~hasInitial
                            obj.status(marker_idx, nKPAnimator, sessionFrameIdx) = obj.isLabeled;
                        else
                            initialCoordSafe = initialCoord; initialCoordSafe(isnan(initialCoordSafe)) = -inf; % Prevent NaN comparison issues
                            currentCoordSafe = currentCoord; % Not NaN here
                            hasMoved = any(round(initialCoordSafe, 3) ~= round(currentCoordSafe, 3));
                            if hasMoved
                                obj.status(marker_idx, nKPAnimator, sessionFrameIdx) = obj.isLabeled;
                            else
                                obj.status(marker_idx, nKPAnimator, sessionFrameIdx) = obj.isInitialized;
                            end
                        end
                    end % end initialMarkers check

                    % Update camPoints based on current marker coordinates (only if not invisible)
                    obj.camPoints(marker_idx, nKPAnimator, :, sessionFrameIdx) = currentCoord;

                    % Update handLabeled2D status (only if not invisible)
                    % Note: kpAnimator.dragged uses actualVideoFrameIdx
                    isNowConsideredLabeled = obj.status(marker_idx, nKPAnimator, sessionFrameIdx) == obj.isLabeled;
                    wasDraggedInFrame = kpAnimator.dragged(actualVideoFrameIdx, marker_idx);

                    if isNowConsideredLabeled && wasDraggedInFrame
                        obj.handLabeled2D(marker_idx, nKPAnimator, :, sessionFrameIdx) = currentCoord;
                    else
                        obj.handLabeled2D(marker_idx, nKPAnimator, :, sessionFrameIdx) = nan; % Clear if not moved by hand or not labeled
                    end
                     % --- End Original logic ---
                end % End loop over markers
            end % End loop over cameras
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
                        % --- START MODIFICATION ---
                        fr = obj.frameInds(obj.frame);
                        % 1. Get labeled joints/cameras and store original points
                        [camIdsLogical, jointIds] = obj.getLabeledJoints(fr);
                        originalPoints = struct('jointId', {}, 'camIdx', {}, 'coords', {});
                        pointCounter = 1;
                        for j_idx = 1:numel(jointIds)
                            currentJointId = jointIds(j_idx);
                            % Find camera indices for this joint (logical row from camIdsLogical)
                            labeledCamIndicesForJoint = find(camIdsLogical(j_idx, :)); 
                            for c_idx = 1:numel(labeledCamIndicesForJoint)
                                currentCamIdx = labeledCamIndicesForJoint(c_idx);
                                originalPoints(pointCounter).jointId = currentJointId;
                                originalPoints(pointCounter).camIdx = currentCamIdx;
                                % Read coords directly before they get overwritten
                                originalPoints(pointCounter).coords = squeeze(obj.camPoints(currentJointId, currentCamIdx, :, fr));
                                pointCounter = pointCounter + 1;
                            end
                        end

                        % 2. Perform triangulation (updates obj.points3D)
                        obj.triangulateLabeledPoints(fr);
                        
                        % 3. Reproject points (updates obj.camPoints for ALL cams)
                        obj.reprojectPoints(fr);

                        % 4. Restore original points for the views used in triangulation
                        for i = 1:numel(originalPoints)
                            jId = originalPoints(i).jointId;
                            cId = originalPoints(i).camIdx;
                            origCoords = originalPoints(i).coords;
                            % Check if coords are valid before writing back
                            if ~any(isnan(origCoords))
                                obj.camPoints(jId, cId, :, fr) = origCoords;
                            end
                        end
                        % --- END MODIFICATION ---
                    end
                    % Original call to update display remains here
                    update(obj)
                    if obj.autosave
                        obj.saveState()
                    end
                    drawnow; % Force graphics update
                case 'tab'
                    if wasShiftPressed
                        obj.selectNode(obj.selectedNode - 1)
                    else
                        obj.selectNode(obj.selectedNode + 1)
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
                    drawnow; % Force graphics update
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
                case 'i' % --- MODIFIED case for toggling invisibility (View-Specific) ---
                    sessionFrameIdx = obj.frame; % GUI frame index (1 to numel(obj.frameInds))
                    actualVideoFrameIdx = obj.frameInds(sessionFrameIdx); % Actual video frame number, if needed for other logic later
                    selected_node = obj.selectedNode;

                    if isnan(selected_node) || selected_node < 1 || selected_node > obj.nMarkers
                        fprintf('No valid node selected to toggle visibility.\n');
                        return; % Use return instead of continue in a switch-case
                    end

                    % Determine target camera view based on mouse position
                    targetCameraIdx = obj.privaten_determineActiveCameraViewByMouse(); 
                    if isnan(targetCameraIdx)
                        fprintf('Label3D: ''i'' key - Mouse not clearly over a single camera view. No action taken.\n');
                        return;
                    end
                    
                    current_status_val = obj.status(selected_node, targetCameraIdx, sessionFrameIdx);

                    if current_status_val == obj.isInvisible
                        % Toggle from invisible to unlabeled FOR THIS VIEW ONLY
                        obj.status(selected_node, targetCameraIdx, sessionFrameIdx) = 0; % Unlabeled
                        % camPoints and handLabeled2D for this view remain as they are (could be NaN or have previous/initial values)
                        % checkStatus will later update camPoints from the DraggableKeypointAnimator if the point is re-labeled.
                        fprintf('Node %s (%d) in View %d marked as UNLABELED in frame %d (actual video frame %d).\n', ...
                                obj.skeleton.joint_names{selected_node}, selected_node, targetCameraIdx, sessionFrameIdx, actualVideoFrameIdx);
                    else
                        % Toggle from any other state to invisible FOR THIS VIEW ONLY
                        obj.status(selected_node, targetCameraIdx, sessionFrameIdx) = obj.isInvisible;
                        obj.camPoints(selected_node, targetCameraIdx, :, sessionFrameIdx) = nan;
                        obj.handLabeled2D(selected_node, targetCameraIdx, :, sessionFrameIdx) = nan;
                        fprintf('Node %s (%d) in View %d marked as INVISIBLE in frame %d (actual video frame %d).\n', ...
                                obj.skeleton.joint_names{selected_node}, selected_node, targetCameraIdx, sessionFrameIdx, actualVideoFrameIdx);
                    end

                    % Update status for all points/cameras based on current labels/drags/invisibility flags.
                    % This will ensure that if a point becomes visible again in checkStatus,
                    % its camPoints can be repopulated from the draggable animator if it had a position.
                    obj.checkStatus(); 

                    obj.update(); % Update visuals
                    if obj.autosave
                        obj.saveState();
                    end
                    drawnow; % Force graphics update
                    % --- End MODIFIED case ---
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
                newRange = [-mRange / 2, mRange / 2];
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
            pts3d = permute(pts3d, [3, 2, 1]);
            if size(pts3d, 3) ~= obj.nFrames
                error('3d points do not have the same number of frames as Label3D instance')
            end
            
            % Update the status. Only overwrite non-labeled points
            isInit = ~any(isnan(pts3d), 2);
            newStatus = repelem(isInit, 1, obj.nCams, 1) * obj.isInitialized;
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
                obj.initialMarkers{nAnimator} = permute(impts, [3, 2, 1]);
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
            if isfield(data, 'sync')
                obj.sync = data.sync;
            end
            if isfield(data, 'framesToLabel')
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
            data_3D = permute(pts3D, [3, 2, 1]);
            data_3D = reshape(data_3D, size(data_3D, 1), []);
            %             data_3D(~any(~isnan(data_3D), 2), :) = [];
            %             pts3D(any(~any(~isnan(pts3D), 2), 3), :, :) = [];
            
            camParams = obj.origCamParams;
            path = sprintf('%s.mat', obj.savePath);
            handLabeled2D = obj.handLabeled2D;
            % save framesToLabel & sync & rest
            if ~isempty(obj.framesToLabel) && ~isempty(obj.sync)
                disp('saving with framesToLabel & sync')
                sync = obj.sync;
                framesToLabel = obj.framesToLabel;
                save(path, 'data_3D', 'status', ...
                    'skeleton', 'imageSize', 'handLabeled2D', 'cameraPoses', 'camParams', ...
                    'sync', 'framesToLabel')
            % save framesToLabel & rest
            elseif ~isempty(obj.framesToLabel)
                disp('saving with framesToLabel')
                framesToLabel = obj.framesToLabel;
                save(path, 'data_3D', 'status', ...
                    'skeleton', 'imageSize', 'handLabeled2D', 'cameraPoses', 'camParams', ...
                    'framesToLabel')
            % just save rest
            else
                disp('saving')
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
                set(obj.h{nAnimator + obj.nCams}, 'Position', pos)
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
                set(obj.h{nAnimator + obj.nCams}, 'Position', pos(nAnimator, :))
            end
            
            % Add the 3d plot in the right place
            pad = 0.1 * 1 / (obj.nCams + 1);
            pos = pos(end, :) + [pad, pad, -2*pad, -2*pad];
            lims = [-400, 400];
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
            % makeSync - if true, create the sync struct (e.g. frame_data, etc.)
            % Syntax: labelGui.exportDannce
            %         labelGui.exportDannce('basePath', path)
            %         labelGui.exportDannce('cameraNames', cameraNames)
            %         labelGui.exportDannce('framesToLabel', framesToLabel)
            %         labelGui.exportDannce('saveFolder', saveFolder)
            % obj.nCams = 6;
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
            addParameter(p, 'totalFrames', -1);
            addParameter(p, 'makeSync', false);
            addParameter(p, 'saveFilename', "");

            
            parse(p, varargin{:});
            p = p.Results;
            if isempty(p.framesToLabel)
                error('exportDannce:FrameNumbersMustBeProvided', [ ...
                    'Frame numbers for each frame in videos must be provided.\n' ...
                    'framesToLabel - Vector of frame numbers for each video frame.\n' ...
                    'labelGui.exportDannce(''framesToLabel'', framesToLabel)']);
            end
            
            if p.totalFrames == -1
                error(['totalFrames must be provided. This is the total number' ...
                    'of frames in the video to generate a sync variable.' ...
                    'Not just the number of frames being labeled' ...
                    'E.g. 90000']);
            end
            totalFrames = p.totalFrames;

 
            % Load the matched frames files if necessary
            if isempty(obj.sync)
                if isempty(p.basePath)
                    p.basePath = uigetdir([], 'Select project folder');
                end
                obj.sync = collectSyncPaths(p.basePath);
                obj.sync = cellfun(@(X) {load(X)}, obj.sync);
            end

            nKeyPoints = size(obj.points3D, 1);
            
            nCameras = obj.nCams;
            % if loading sync did not work, then create your own sync
            % assuming frames are already synchronized
            if p.makeSync
                % For each labels file, extract the labeled points and save metadata.
                obj.sync = cell(nCameras, 1);
                for i = 1: nCameras
                    obj.sync{i}.data_2d = zeros(totalFrames, nKeyPoints*2);
                    obj.sync{i}.data_3d = zeros(totalFrames, nKeyPoints*3);
                    obj.sync{i}.data_frame = (0:(totalFrames - 1));
                    obj.sync{i}.data_sampleID = (0:(totalFrames - 1));
                end
            else
                disp("makeSync not specified. Sync array could be missing")
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
                pts = permute(obj.points3D, [3, 1, 2]);
                allpts = reshape(pts, [], 3);
                if ~obj.undistortedImages
                    data_2D = worldToImage(cp, cp.RotationMatrices, ...
                        cp.TranslationVectors, allpts, 'ApplyDistortion', true);
                else
                    data_2D = worldToImage(cp, cp.RotationMatrices, ...
                        cp.TranslationVectors, allpts);
                end
                data_2D = reshape(data_2D, size(pts, 1), [], 2);
                data_2D = permute(data_2D, [1, 3, 2]);
                data_2D = reshape(data_2D, size(pts, 1), []);
                
                % Save out the set of labeled images.
                data_2d = data_2D(labeled, :);
                data_3d = labels.data_3D(labeled, :);
                labelData{nCam} = struct('data_2d', data_2d, ...
                    'data_3d', data_3d, ...
                    'data_frame', data_frame, ...
                    'data_sampleID', data_sampleID);
            end

            saveFilename = p.saveFilename;
            if isempty(saveFilename)
                saveFilename = sprintf('%sLabel3D_dannce.mat', obj.sessionDatestr);
            end
            
            outPath = fullfile(outDir, saveFilename);
            params = obj.origCamParams;
            camnames = p.cameraNames;
            handLabeled2D = obj.handLabeled2D;
            
            if ~isempty(obj.sync)
                sync = obj.sync;
                save(outPath, 'labelData', 'handLabeled2D', 'params', 'sync', 'camnames')
            else
                save(outPath, 'labelData', 'handLabeled2D', 'params', 'camnames')
            end
        end % End of exportDannce

    % --- Method for Swapping Animal IDs ---
    function swapAnimalIDsInView(obj, cameraIndex)
        % Swaps the 2D labels of Animal 1 and Animal 2 for the specified
        % cameraIndex in the current frame, then re-triangulates and updates.

        currentFrameGlobalIdx = obj.frame; 

        if obj.nAnimalsInSession == 0
            warning('Label3D:swapAnimalIDsInView', 'nAnimalsInSession is 0. Cannot perform swap.');
            return;
        end
        if obj.nMarkers == 0
            warning('Label3D:swapAnimalIDsInView', 'nMarkers is 0. Cannot perform swap.');
            return;
        end

        if obj.nAnimalsInSession ~= 2
            warning('Label3D:swapAnimalIDsInView', ...
                    'Swap ID logic is currently implemented for 2 animals only. Found %d animals. No action taken.', ...
                    obj.nAnimalsInSession);
            return;
        end

        keypointsPerAnimal = obj.nMarkers / obj.nAnimalsInSession; 
        if ~(keypointsPerAnimal > 0 && rem(keypointsPerAnimal,1)==0)
            warning('Label3D:swapAnimalIDsInView', 'Cannot proceed with swap: Invalid keypointsPerAnimal calculation (nMarkers=%d, nAnimalsInSession=%d).', obj.nMarkers, obj.nAnimalsInSession);
            return;
        end

        animal1_indices = 1:keypointsPerAnimal;
        animal2_indices = (keypointsPerAnimal + 1) : (2 * keypointsPerAnimal);

        % --- Defensive checks for obj.frame and obj.frameInds ---
        if isempty(obj.frameInds)
            warning('Label3D:swapAnimalIDsInView', 'obj.frameInds is empty. Cannot proceed.');
            return;
        end
        if ~isscalar(obj.frame) || obj.frame <= 0 || obj.frame > numel(obj.frameInds)
            warning('Label3D:swapAnimalIDsInView', 'obj.frame (value: %d) is an invalid index for obj.frameInds (size: %d). Cannot proceed.', obj.frame, numel(obj.frameInds));
            return;
        end
        % --- End defensive checks ---

        actualFrameToProcess = obj.frameInds(obj.frame); 

        % Modified fprintf to ensure clean line continuation
        fprintf('Swapping IDs for Camera %d, GUI Frame %d (Actual Video Frame %d).\n', ...
                cameraIndex, obj.frame, actualFrameToProcess);

        targetFrameForArray = obj.frame;

        if isempty(obj.camPoints) || ndims(obj.camPoints) ~= 4
            warning('Label3D:swapAnimalIDsInView', 'obj.camPoints not properly initialized. Aborting swap.');
            return;
        end
        if size(obj.camPoints,1) < max(animal2_indices) || size(obj.camPoints,2) < cameraIndex || size(obj.camPoints,4) < targetFrameForArray
             warning('Label3D:swapAnimalIDsInView', 'Index out of bounds for obj.camPoints. Aborting swap. Size: %s, Indices: m=%d, c=%d, f=%d', mat2str(size(obj.camPoints)), max(animal2_indices), cameraIndex, targetFrameForArray);
            return;
        end
        
        if isempty(obj.status) || ndims(obj.status) ~= 3
            warning('Label3D:swapAnimalIDsInView', 'obj.status not properly initialized. Aborting swap.');
            return;
        end
         if size(obj.status,1) < max(animal2_indices) || size(obj.status,2) < cameraIndex || size(obj.status,3) < targetFrameForArray
             warning('Label3D:swapAnimalIDsInView', 'Index out of bounds for obj.status. Aborting swap. Size: %s, Indices: m=%d, c=%d, f=%d', mat2str(size(obj.status)),max(animal2_indices), cameraIndex, targetFrameForArray);
            return;
        end

        if isempty(obj.handLabeled2D) || ndims(obj.handLabeled2D) ~= 4
             warning('Label3D:swapAnimalIDsInView', 'obj.handLabeled2D not properly initialized. Aborting swap.');
            return;
        end
        if size(obj.handLabeled2D,1) < max(animal2_indices) || size(obj.handLabeled2D,2) < cameraIndex || size(obj.handLabeled2D,4) < targetFrameForArray
             warning('Label3D:swapAnimalIDsInView', 'Index out of bounds for obj.handLabeled2D. Aborting swap. Size: %s, Indices: m=%d, c=%d, f=%d', mat2str(size(obj.handLabeled2D)),max(animal2_indices), cameraIndex, targetFrameForArray);
            return;
        end

        temp_camPoints_animal1 = obj.camPoints(animal1_indices, cameraIndex, :, targetFrameForArray);
        temp_camPoints_animal2 = obj.camPoints(animal2_indices, cameraIndex, :, targetFrameForArray);

        temp_status_animal1    = obj.status(animal1_indices, cameraIndex, targetFrameForArray);
        temp_status_animal2    = obj.status(animal2_indices, cameraIndex, targetFrameForArray);

        temp_handLabeled_animal1 = obj.handLabeled2D(animal1_indices, cameraIndex, :, targetFrameForArray);
        temp_handLabeled_animal2 = obj.handLabeled2D(animal2_indices, cameraIndex, :, targetFrameForArray);

        obj.camPoints(animal1_indices, cameraIndex, :, targetFrameForArray) = temp_camPoints_animal2;
        obj.camPoints(animal2_indices, cameraIndex, :, targetFrameForArray) = temp_camPoints_animal1;

        obj.status(animal1_indices, cameraIndex, targetFrameForArray)    = temp_status_animal2;
        obj.status(animal2_indices, cameraIndex, targetFrameForArray)    = temp_status_animal1;
        
        obj.handLabeled2D(animal1_indices, cameraIndex, :, targetFrameForArray) = temp_handLabeled_animal2;
        obj.handLabeled2D(animal2_indices, cameraIndex, :, targetFrameForArray) = temp_handLabeled_animal1;
        
        fprintf('  Data swapped in camPoints, status, and handLabeled2D for camera %d.\n', cameraIndex);

        % Call update() BEFORE checkStatus() to ensure animators reflect the swap first
        obj.update();
        fprintf('  GUI update() completed.\n');

        obj.checkStatus(); 
        fprintf('  checkStatus() completed.\n');

        if obj.autosave
            obj.saveState(); 
            fprintf('  Session auto-saved after ID swap.\n');
        end
        
        fprintf('ID Swap complete for Camera %d, GUI Frame %d.\n', cameraIndex, obj.frame);
    end % End of swapAnimalIDsInView method

    % --- Camera View Pagination Methods ---
    function updateCameraViewLayout(obj)
        startIndex = (obj.currentCameraPage - 1) * obj.camerasPerPage + 1;
        endIndex = min(obj.currentCameraPage * obj.camerasPerPage, obj.nCams);

        if obj.nCams == 0 % Handle no cameras case first
            % Hide all swap buttons if they exist
            swapButtons = findall(obj.Parent, 'Type', 'uicontrol', 'Tag', 'SwapButtonCam*');
            set(swapButtons, 'Visible', 'off'); % Keep hiding buttons based on visibility logic

            % Update page info text and button states
            if isvalid(obj.pageInfoText), set(obj.pageInfoText, 'String', 'Page 0 / 0'); end
            if isvalid(obj.prevPageButton), set(obj.prevPageButton, 'Enable', 'off'); end
            if isvalid(obj.nextPageButton), set(obj.nextPageButton, 'Enable', 'off'); end
            return;
        end

        pageIndices = startIndex:endIndex;
        numViewsThisPage = numel(pageIndices);
         if numViewsThisPage <= 0 % Should generally not happen if nCams > 0
            pageIndices = []; % Ensure it's empty
         end
        
        % Only calculate positions if there are views on this page
        if numViewsThisPage > 0
            pagePositions = obj.getPositions(numViewsThisPage);
        else
             pagePositions = zeros(0,4); % Empty array if no views
        end

        fprintf('-- updateCameraViewLayout: Page %d -> Indices %s (%d views) --\\n', obj.currentCameraPage, mat2str(pageIndices), numViewsThisPage); % DEBUG

        for nCam = 1 : obj.nCams
            % Get the shared axes
            % Check if the handle exists and is valid before accessing Axes
            if numel(obj.h) >= nCam && isvalid(obj.h{nCam}) && isprop(obj.h{nCam},'Axes') && ishandle(obj.h{nCam}.Axes)
                videoAx = obj.h{nCam}.Axes;
            else
                warning('Label3D:updateCameraViewLayout', 'Could not get valid axes for animator index %d. Skipping.', nCam);
                continue; % Skip this camera if axes are invalid
            end
            
            % Find SwapID button for this camera
            swapButtonTag = sprintf('SwapButtonCam%d', nCam);
            swapButtonHandle = findall(obj.Parent, 'Type', 'uicontrol', 'Tag', swapButtonTag);

            isCamOnCurrentPage = ismember(nCam, pageIndices);

            if isCamOnCurrentPage
                [~, localIndex] = ismember(nCam, pageIndices);
                % Ensure localIndex is valid before accessing pagePositions
                if localIndex > 0 && localIndex <= size(pagePositions, 1)
                    currentPos = pagePositions(localIndex, :);
    
                    fprintf('  Cam %d: Setting Position [%.2f %.2f %.2f %.2f] (Visible ON)\\n', nCam, currentPos); % DEBUG
                    set(videoAx, 'Position', currentPos, 'Visible', 'on'); % Ensure axes are visible
    
                    % --- Apply vertical flip if requested --- 
                    if obj.flipViewsVertically
                        view(videoAx, 180, 90);
                    else
                        view(videoAx, 0, 90); % Default view
                    end
                    % --- End vertical flip ---\n
                    % Ensure VideoAnimator content is visible
                    if isfield(obj.h{nCam}, 'img') && ishandle(obj.h{nCam}.img)
                         set(obj.h{nCam}.img, 'Visible', 'on');
                    end
    
                    % Ensure DraggableKeypoint2DAnimator points & segments are visible
                    kpAnimatorIndex = obj.nCams + nCam;
                    if numel(obj.h) >= kpAnimatorIndex && isvalid(obj.h{kpAnimatorIndex}) && isa(obj.h{kpAnimatorIndex}, 'DraggableKeypoint2DAnimator')
                        dkpa = obj.h{kpAnimatorIndex};
                        if isprop(dkpa, 'points') && ishandle(dkpa.points)
                            set(dkpa.points, 'Visible', 'on');
                        end
                        if isprop(dkpa, 'segments') && all(ishandle(dkpa.segments)) % Check if segments is an array of handles
                             set(dkpa.segments(ishandle(dkpa.segments)), 'Visible', 'on'); % Set only valid handles
                        end
                    end
    
                    % Show and position the Swap ID button for this visible camera
                    if ~isempty(swapButtonHandle) && ishandle(swapButtonHandle)
                        btnWidth_swap = 0.04;  % Use new defined size for swap button
                        btnHeight_swap = 0.02; % Use new defined size for swap button
                        % New position: Bottom-left of the current axes view
                        btnX_new = currentPos(1) + 0.005; % Offset from left edge of axes
                        btnY_new = currentPos(2) + 0.005; % Offset from bottom edge of axes
                        set(swapButtonHandle, 'Position', [btnX_new, btnY_new, btnWidth_swap, btnHeight_swap], 'Visible', 'on');
                    end
                else
                     warning('Label3D:updateCameraViewLayout', 'Invalid localIndex %d for pagePositions (size %d). Skipping positioning for Cam %d.', localIndex, size(pagePositions,1), nCam);
                end
            else
                fprintf('  Cam %d: Setting Position OFF-SCREEN (Visible ON)\\n', nCam); % DEBUG
                % --- MODIFICATION: Move axes off-screen instead of hiding ---
                set(videoAx, 'Position', obj.hiddenAxesPos, 'Visible', 'on'); % Keep Visible 'on'
                % No need to explicitly hide contents if axes are moved.

                % --- Hide Swap ID button ---
                if ~isempty(swapButtonHandle) && ishandle(swapButtonHandle)
                    set(swapButtonHandle, 'Visible', 'off'); % Still hide the button
                end
            end
        end

        % Update page info text
        if isvalid(obj.pageInfoText)
            set(obj.pageInfoText, 'String', sprintf('Page %d / %d', obj.currentCameraPage, obj.totalPages));
        end

        % Update Next/Prev button states
        if isvalid(obj.prevPageButton)
            if obj.currentCameraPage == 1
                set(obj.prevPageButton, 'Enable', 'off');
            else
                set(obj.prevPageButton, 'Enable', 'on');
            end
        end
        if isvalid(obj.nextPageButton)
            if obj.currentCameraPage == obj.totalPages
                set(obj.nextPageButton, 'Enable', 'off');
            else
                set(obj.nextPageButton, 'Enable', 'on');
            end
        end
         % Add a drawnow here to ensure positioning changes take effect
         drawnow;
    end

    function nextPageCallback(obj, ~, ~)
        if obj.currentCameraPage < obj.totalPages
            obj.currentCameraPage = obj.currentCameraPage + 1;
            obj.updateCameraViewLayout();
            obj.update(); % Refresh drawing on newly visible axes
        end
    end

    function prevPageCallback(obj, ~, ~)
        if obj.currentCameraPage > 1
            obj.currentCameraPage = obj.currentCameraPage - 1;
            obj.updateCameraViewLayout(); % This now calls drawnow internally
            % drawnow; % Removed extra drawnow here, as it's in updateCameraViewLayout
            obj.update(); % Refresh drawing on newly visible axes
        end
    end
    % --- End Pagination Methods ---

    end % End of PUBLIC methods block (this end was already here for the main public methods)

    methods (Access = private)
        function reset(obj)
            % reset frameInds to 1 : nFrames
            % also set current frame number to 1
            restrict(obj, 1 : obj.origNFrames)
        end
        
        function setupKeypoint3dAnimator(obj)
            m = permute(obj.points3D, [3, 2, 1]);
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
            % Ensure 'nAnimals' is part of varargin if needed by buildFromScratch
            % Or extract from 'data' if stored there and pass explicitly
            if isfield(data, 'nAnimalsInSession_LABEL3D') % Check for a uniquely named field
                current_nAnimals = data.nAnimalsInSession_LABEL3D;
                 varargin = [varargin, {'nAnimals', current_nAnimals}];
            elseif isfield(data,'skeleton') && isfield(data.skeleton, 'nAnimals') % Check common/expected places
                current_nAnimals = data.skeleton.nAnimals;
                varargin = [varargin, {'nAnimals', current_nAnimals}];
            else
                % Attempt to infer if possible, or default/error
                % This part is tricky without knowing how nAnimals was previously associated with saved state
                % For now, assume it must be passed or an error will occur in buildFromScratch
                warning('Label3D:loadFromState', 'nAnimals not found in saved state, ensure it is passed via varargin if buildFromScratch requires it.');
            end

            obj.buildFromScratch(camParams, videos, skel, varargin{:});
            obj.loadState(file)
            if isfield(data, 'sync')
                obj.sync = data.sync;
            end
            if isfield(data, 'framesToLabel')
                obj.framesToLabel = data.framesToLabel;
            end
        end
        
        function loadAll(obj, path, varargin)
            data = load(path);
            % Similar to loadFromState, ensure 'nAnimals' is handled for buildFromScratch
             if isfield(data, 'nAnimalsInSession_LABEL3D')
                current_nAnimals = data.nAnimalsInSession_LABEL3D;
                varargin = [varargin, {'nAnimals', current_nAnimals}];
            elseif isfield(data,'skeleton') && isfield(data.skeleton, 'nAnimals')
                current_nAnimals = data.skeleton.nAnimals;
                varargin = [varargin, {'nAnimals', current_nAnimals}];
            else
                warning('Label3D:loadAll', 'nAnimals not found in saved data, ensure it is passed via varargin if buildFromScratch requires it.');
            end
            obj.buildFromScratch(data.camParams, data.videos, data.skeleton, varargin{:});
            obj.loadFrom3D(data.data_3D);
            if isfield(data, 'sync')
                obj.sync = data.sync;
            end
            if isfield(data, 'framesToLabel')
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

        function targetCam = privaten_determineActiveCameraViewByMouse(obj)
            targetCam = NaN;
            fpt = obj.Parent.CurrentPoint; % Normalized figure coordinates [x, y]
    
            startIndex = (obj.currentCameraPage - 1) * obj.camerasPerPage + 1;
            endIndex = min(obj.currentCameraPage * obj.camerasPerPage, obj.nCams);
    
            if startIndex > endIndex || obj.nCams == 0
                return; % No cameras visible or available
            end
            
            visibleCamGlobalIndices = startIndex:endIndex;
            
            foundCams = [];
            for i = 1:numel(visibleCamGlobalIndices)
                camIdxGlobal = visibleCamGlobalIndices(i);
                
                % VideoAnimators are in obj.h{1...nCams}
                if camIdxGlobal <= numel(obj.h) && ...
                   isa(obj.h{camIdxGlobal}, 'VideoAnimator') && ...
                   isvalid(obj.h{camIdxGlobal}.Axes)
                    
                    axHandle = obj.h{camIdxGlobal}.Axes;
                    % Ensure Axes Units are normalized for correct comparison with CurrentPoint
                    originalUnits = get(axHandle, 'Units');
                    set(axHandle, 'Units', 'normalized');
                    axPos = get(axHandle, 'Position'); % [left, bottom, width, height]
                    set(axHandle, 'Units', originalUnits); % Restore original units
    
                    if fpt(1) >= axPos(1) && fpt(1) <= (axPos(1) + axPos(3)) && ...
                       fpt(2) >= axPos(2) && fpt(2) <= (axPos(2) + axPos(4))
                        foundCams(end+1) = camIdxGlobal;
                    end
                end
            end
    
            if numel(foundCams) == 1
                targetCam = foundCams(1);
            elseif numel(foundCams) > 1
                % This case (mouse over multiple views) should be rare with proper layout.
                % Could prioritize by z-order or smallest area, but for now, consider ambiguous.
                warning('Label3D:determineActiveCam', 'Mouse over multiple camera views. Ambiguous for "i" key.');
            end
        end
    end % End of methods (Access = private) block
    
    % --- Misplaced function removed from here, it is now correctly placed above ---

    methods (Access = protected)
        function update(obj)
            % Update all of the other animators with any new data.
            for nKPAnimator = 1 : obj.nCams
                kpaId = obj.nCams + nKPAnimator;
                kps = zeros(obj.nMarkers, size(obj.camPoints, 3), size(obj.camPoints, 4));
                kps(:) = obj.camPoints(:, nKPAnimator, :, :);
                kps = permute(kps, [3, 2, 1]);
                
                obj.h{kpaId}.markers = kps;
                obj.h{kpaId}.markersX(:) = kps(:, 1, :);
                obj.h{kpaId}.markersY(:) = kps(:, 2, :);
                
                % fr = obj.frameInds(obj.frame); % fr is the *actual video frame number* - This was the source of the bug for XData/YData
                % obj.h{kpaId}.points.XData and YData should be for the *current GUI frame*
                % The index into 'kps' (which is nFrames_in_session x 2 x nMarkers) should be obj.frame, not fr.
                obj.h{kpaId}.points.XData(:) = squeeze(kps(obj.frame, 1, :));
                obj.h{kpaId}.points.YData(:) = squeeze(kps(obj.frame, 2, :));
            end
            
            % Run all of the update functions.
            for nAnimator = 1 : numel(obj.h)
                obj.h{nAnimator}.update()
            end
            
            % Update the keypoint animator data for all frames
            pts = permute(obj.points3D, [3, 2, 1]);
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
                'NumberTitle', 'off', 'ToolBar', 'none', 'MenuBar', 'none');
            obj.jointsPanel = uix.Panel('Parent', f, 'Title', 'Joints', ...
                'Padding', 5, 'Units', 'Normalized');
            obj.jointsControl = uicontrol(obj.jointsPanel, ...
                'Style', 'listbox', ...
                'String', obj.skeleton.joint_names, ...
                'Units', 'Normalized', ... 
                'Callback', @(uiObj, ~, ~) obj.selectNode(uiObj.Value)); % handle clicks on the Joints Control UI
            set(obj.Parent.Children(end), 'Visible', 'off')
        end
        
        function setUpStatusTable(obj)
            f = figure('Units', 'Normalized', 'pos', [0, 0, 0.5, 0.3], ...
                'NumberTitle', 'off', 'ToolBar', 'none');
            ax = gca;
            % Current: colormap([0, 0, 0; 0.5, 0.5, 0.5; 1, 1, 1])
            % New map: Black (unlabeled=0+1), Gray (initialized=1+1), White (labeled=2+1), Purple (invisible=3+1)
            colormap(ax, [0, 0, 0; 0.5, 0.5, 0.5; 1, 1, 1; 0.7, 0, 0.7]);
            summary = zeros(size(obj.status, 1), size(obj.status, 3));
            summary(:) = mode(obj.status, 2);
            obj.statusAnimator = HeatMapAnimator(summary', 'Axes', ax);
            obj.statusAnimator.c.Visible = 'off';
            ax = obj.statusAnimator.Axes;
            set(ax, 'YTick', 1 : obj.nMarkers, 'YTickLabels', obj.skeleton.joint_names)
            yyaxis(ax, 'right')
            if obj.nMarkers == 1
                set(ax, 'YLim', [0.5, 1.5], 'YTick', 1, 'YTickLabels', sum(summary, 2))
            else
                set(ax, 'YLim', [1, obj.nMarkers], 'YTick', 1:obj.nMarkers, 'YTickLabels', sum(summary, 2))
            end
            set(obj.statusAnimator.img, 'CDataMapping', 'direct')
            obj.counter = title(sprintf('Total: %d', sum(any(summary == obj.isLabeled, 1))));
            f.set('MenuBar','none');
        end
        
        function updateStatusAnimator(obj)
            % obj.checkStatus(); % REMOVED redundant call
            summary = zeros(size(obj.status, 1), size(obj.status, 3));
            summary(:) = mode(obj.status, 2);
            obj.statusAnimator.img.CData = summary + 1;
            yyaxis(obj.statusAnimator.Axes, 'right')
            set(obj.statusAnimator.Axes, 'YTickLabels', flip(sum(summary == obj.isLabeled, 2)))
            obj.counter.String = sprintf('Total: %d', sum(any(summary == obj.isLabeled, 1)));
            obj.statusAnimator.update()
        end
    end
end