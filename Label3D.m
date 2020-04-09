classdef Label3D < Animator
    %Label3D - Label3D is a GUI for manual labeling of 3D keypoints in multiple cameras.
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
    %              path = sprintf('%s%sCamera_%d.mat', obj.savePath,...
    %                       datestr(now,'yyyy_mm_dd_HH_MM_SS'), nCam);
    %   verbose - Print saving messages  
    %
    %   Label3D Methods:
    %   Label3D - constructor
    %   loadCamParams - Load in camera parameters
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
        color
        joints
        origNFrames
        initialMarkers
        isKP3Dplotted
        gridColor = [.7 .7 .7]
        mainFigureColor = [0.1412 0.1412 0.1412]
        labelPosition = [0 .5 .9 .5]
        tablePosition = [.9 .5 .1 .5]
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
        hiddenAxesPos = [.99 .99 .01 .01]
        isLabeled = 2
        isInitialized = 1
        counter
    end
    
    properties (Access = public)
        cameraParams
        cameraPoses
        orientations
        markers
        locations
        camPoints
        points3D
        status
        selectedNode
        skeleton
        ImageSize
        nMarkers
        nCams
        jointsPanel
        jointsControl
        savePath = ''
        kp3a
        statusAnimator
        h
        verbose = false
        undistortedImages = false
    end
    
    methods
        function obj = Label3D(camparams, videos, skeleton, varargin)
            %Label3D - constructor for Label3D class.
            %
            %Inputs:
            %   camparams: Cell array of structures denoting camera
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
            %   Syntax: Label3D(camparams, videos, skeleton, varargin);
            % User defined inputs
            [animatorArgs, ~, varargin] = parseClassArgs('Animator', varargin{:});
            obj@Animator(animatorArgs{:},'Visible','off');
            if ~isempty(skeleton)
                obj.skeleton = skeleton;
            end
            
            if ~isempty(varargin)
                set(obj,varargin{:});
            end
            
            % Set up Animator parameters
            obj.nFrames = size(videos{1},4);
            obj.origNFrames = obj.nFrames;
            obj.frameInds = 1:obj.nFrames;
            obj.nMarkers = numel(obj.skeleton.joint_names);
            obj.savePath = sprintf('%s%sCamera_', obj.savePath,...
                datestr(now,'yyyy_mm_dd_HH_MM_SS'));
            
            % Set up the cameras
            obj.nCams = numel(camparams);
            obj.h = cell(1);
            obj.ImageSize = [size(videos{1},1) size(videos{1},2)];
            [obj.cameraParams, obj.orientations, obj.locations] = ...
                obj.loadCamParams(camparams);
            obj.cameraPoses = obj.getCameraPoses();
            
            % Make the VideoAnimators
            for i = 1:obj.nCams
                pos = [(i-1)/obj.nCams 0 1/obj.nCams 1];
                obj.h{i} = VideoAnimator(videos{i}, 'Position', pos);
                ax = obj.h{i}.Axes;
                ax.Toolbar.Visible = 'off';
                set(ax,'XTick',[],'YTick',[]);
                set(obj.h{i}.img,'ButtonDownFcn',@obj.clickImage);
            end
            
            % If there are initialized markers, save them in
            % initialMarkers, otherwise just set the markers to nan.
            if isempty(obj.markers)
                obj.markers = cell(obj.nCams,1);
                for i = 1:numel(obj.markers)
                    obj.markers{i} = nan(obj.origNFrames, 2, obj.nMarkers);
                end
            else
                obj.initialMarkers = obj.markers;
            end
            
            % Make the Draggable Keypoint Animators
            for i = 1:obj.nCams
                obj.h{obj.nCams + i} = ...
                    DraggableKeypoint2DAnimator(obj.markers{i}, obj.skeleton,...
                    'Axes', obj.h{i}.Axes);
                ax = obj.h{obj.nCams + i}.Axes;
                ax.Toolbar.Visible = 'off';
                xlim(ax, [1 obj.ImageSize(2)])
                ylim(ax, [1 obj.ImageSize(1)])
            end
            
            % Initialize data and accounting matrices
            if ~isempty(obj.markers)
                obj.camPoints = nan(obj.nMarkers,obj.nCams,2,obj.nFrames);
            end
            obj.points3D = nan(obj.nMarkers, 3, obj.nFrames);
            obj.status = zeros(obj.nMarkers, obj.nCams, obj.nFrames);
            
            % Make images rescalable
            cellfun(@(X) set(X.Axes,...
                'DataAspectRatioMode', 'auto', 'Color', 'none'), obj.h)
            obj.selectedNode = 1;
            
            % Style the main Figure
            addToolbarExplorationButtons(obj.Parent)
            set(obj.Parent,'Units','Normalized','pos',obj.labelPosition,...
                'Name','Label3D GUI','NumberTitle','off',...
                'color',obj.mainFigureColor)
           
            % Set up the 3d keypoint animator
            obj.setupKeypoint3dAnimator()
            
            % Set up a status table. 
            obj.setUpStatusTable();
            
            % Link all animators
            Animator.linkAll(obj.getAnimators)
            
            % Set the GUI clicked callback to the custom toggle, so that we
            % can toggle with the keyboard without having the figure lose
            % focus.
            zin = findall(obj.Parent,'tag','Exploration.ZoomIn');
            set(zin, 'ClickedCallback', @(~,~) obj.toggleZoomIn);
            
            % Set up the keypoint table figure
            obj.setUpKeypointTable();
        end
        
        function animators = getAnimators(obj)
            animators = [obj.h {obj} {obj.kp3a} {obj.statusAnimator}];
        end
        
%         function linkAnimators(obj)
%             Animator.linkAll(animators)
%         end
        
        function [c, orientations, locations] = loadCamParams(obj, camparams)
            % Helper to load in camera params into cameraParameters objects
            % and save the world positions.
            [c, orientations, locations] = deal(cell(obj.nCams, 1));
            for i = 1:numel(c)
                % Get all parameters into cameraParameters object.
                K = camparams{i}.K;
                RDistort = camparams{i}.RDistort;
                TDistort = camparams{i}.TDistort;
                R = camparams{i}.r;
                rotationVector = rotationMatrixToVector(R);
                translationVector = camparams{i}.t;
                c{i} = cameraParameters('IntrinsicMatrix',K,...
                    'ImageSize',obj.ImageSize,'RadialDistortion',RDistort,...
                    'TangentialDistortion',TDistort,...
                    'RotationVectors',rotationVector,...
                    'TranslationVectors',translationVector);
                
                % Also save world location and orientation
                orientations{i} = R';
                locations{i} = -translationVector*orientations{i};
            end
        end
        
        function cameraPoses = getCameraPoses(obj)
            % Helper function to store the camera poses for triangulation
            varNames = {'ViewId', 'Orientation', 'Location'};
            cameraPoses = [arr2cell(uint32((1:obj.nCams)))' ...
                obj.orientations obj.locations];
            
            % This fixes a silly conversion between cells and tables that
            % dereferences cells with dim 1 in the rows.
            cameraPoses = cell2struct(cameraPoses',varNames);
            for i = 1:obj.nCams
                cameraPoses(i).Location = {cameraPoses(i).Location};
            end
            cameraPoses = struct2table(cameraPoses);
        end
        
        function zoomOut(obj)
            % Zoom all images out to their maximum sizes.
            for i = 1:obj.nCams
                xlim(obj.h{obj.nCams + i}.Axes, [1 obj.ImageSize(2)])
                ylim(obj.h{obj.nCams + i}.Axes, [1 obj.ImageSize(1)])
            end
        end
        
        function [camIds, jointIds] = getLabeledJoints(obj, frame)
            % Look within a frame and return all joints with at least two
            % labeled views, as well as a logical vector denoting which two
            % views.
            s = squeeze(obj.status(:,:,frame));
            labeled = s == obj.isLabeled | s == obj.isInitialized;
            jointIds = find(sum(labeled, 2) >= 2);
            camIds = labeled(jointIds, :);
        end
        
        function xyzPoints = triangulateLabeledPoints(obj, frame)
            % Get the camera intrinsics
            intrinsics = cellfun(@(X) X.Intrinsics, obj.cameraParams,'uni',0);
            intrinsics = [intrinsics{:}];
            
            % Find the labeled joints and corresponding cameras
            [camIds, jointIds] = obj.getLabeledJoints(frame);
            
            % For each labeled joint, triangulate with the right cameras
            xyzPoints = zeros(numel(jointIds), 3);
            for nJoint = 1:numel(jointIds)
                cams = camIds(nJoint,:);
                joint = jointIds(nJoint);
                pointTracks = obj.getPointTrack(frame, joint, cams);
                xyzPoints(nJoint,:) = triangulateMultiview(pointTracks,...
                    obj.cameraPoses(cams,:), intrinsics(cams));
            end
            
            % Save the results to the points3D matrix
            obj.points3D(jointIds, :, frame) = xyzPoints;
        end
        
        function reprojectPoints(obj, frame)
            % Find the labeled joints and corresponding cameras
            [~, jointIds] = obj.getLabeledJoints(frame);
            
            % Reproject the world coordinates for the labeled joints to
            % each camera and store in the camPoints
            for nCam = 1:obj.nCams
                camParam = obj.cameraParams{nCam};
                rotation = obj.orientations{nCam}';
                translation = camParam.TranslationVectors;
                worldPoints = obj.points3D(jointIds, :, frame);
                if ~isempty(worldPoints)
                    if obj.undistortedImages
                        obj.camPoints(jointIds, nCam, :, frame) = ...
                            worldToImage(camParam, rotation, translation,...
                            worldPoints);
                    else
                        obj.camPoints(jointIds, nCam, :, frame) = ...
                            worldToImage(camParam, rotation, translation,...
                            worldPoints, 'ApplyDistortion', true);
                    end
                end
            end
        end
        
        function resetFrame(obj)
            % Reset current frame to the initial unlabeled positions.
            for i = 1:obj.nCams
                obj.h{obj.nCams + i}.resetFrame();
            end
            f = obj.frameInds(obj.frame);
            obj.status(:,:,f) = 0;
            if ~isempty(obj.initialMarkers)
                for nAnimator = 1:obj.nCams
                    obj.initialMarkers{nAnimator}(f,:,:) = nan;
                end
            end
            obj.checkStatus();
            obj.update()
        end
        
        function clickImage(obj, ~, ~)
            % Callback to image clicks (but not on nodes)
            % Pull out clicked point coordinate in image coordinates
            pt = zeros(obj.nCams,2);
            for i = 1:obj.nCams
                pt(i,:) = obj.h{i}.img.Parent.CurrentPoint(1,1:2);
            end
            
            % Pull out clicked point in figure coordinates. 
            fpt = obj.Parent.CurrentPoint;
            [goodX, goodY] = deal(zeros(obj.nCams, 1));
            for nCam = 1:obj.nCams
                pos = obj.h{nCam}.Position;
                goodX(nCam) = pos(1) <= fpt(1) && fpt(1) < (pos(1) + pos(3));
                goodY(nCam) = pos(2) <= fpt(2) && fpt(2) < (pos(2) + pos(4));    
            end
            cam = find(goodX & goodY);
            
            % Throw a warning if there are more than one good camera.
            if numel(cam) > 1
                warning(['Click is in multiple images. ' ...
                    'Please zoom image axes such that they are '...
                    'non-overlapping. To zoom out fully in all images, press "z".'])
                return;
            end
            
            % Update the currently selected node
            index = obj.selectedNode;
            obj.h{cam+obj.nCams}.points.XData(index) = pt(cam,1);
            obj.h{cam+obj.nCams}.points.YData(index) = pt(cam,2);
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
                for nCam = 1:numel(viewIds)
                    params = obj.cameraParams{viewIds(nCam)};
                    imPts(nCam,:) = undistortPoints(imPts(nCam,:), params);
                end
            end
            pt = pointTrack(viewIds, imPts);
        end
        
        function plotCameras(obj)
            % Helper function to check camera positions.
            f = figure('Name','Camera Positions','NumberTitle','off');
            ax = axes(f);
            colors = lines(obj.nCams);
            p = cell(obj.nCams,1);
            for i = 1:obj.nCams
                p{i} = plotCamera('Orientation',obj.orientations{i},...
                    'Location',obj.locations{i},'Size',50,...
                    'Color',colors(i,:),'Label',sprintf('Camera %d',i));
                hold on;
            end
            grid on
            axis equal;
            daspect(ax, [1 1 1]);
%             set(ax,'FontSize',16,'XLim',[-500 500],...
%                 'YLim',[-500 500],'ZLim',[0 500]);
            xlabel('X')
            ylabel('Y')
            zlabel('Z')
        end
        
        function checkStatus(obj)
            % Update the movement status for the current frame, if
            % necessary
            f = obj.frameInds(obj.frame);
            for nKPAnimator = 1:obj.nCams
                kpAnimator = obj.h{obj.nCams+nKPAnimator};
                currentMarker = kpAnimator.getCurrentFramePositions();
                
                % If there were initializations, use those, otherwise
                % just check for non-nans.
                if isempty(obj.initialMarkers)
                    hasMoved = any(~isnan(currentMarker),2);
                    obj.status(~hasMoved, nKPAnimator, f) = 0;
                else
                    iM = squeeze(obj.initialMarkers{nKPAnimator}(f,:,:))';
                    cM = currentMarker;
                    isDeleted = any(isnan(cM),2);
                    iM(isnan(iM)) = 0;
                    cM(isnan(cM)) = 0;
                    hasMoved = any(round(iM,3) ~= round(cM,3),2);
                    hasMoved = hasMoved & ~isDeleted;
                    obj.status(isDeleted, nKPAnimator, f) = 0;
                end
                obj.status(hasMoved, nKPAnimator, f) = obj.isLabeled;
                obj.camPoints(:, nKPAnimator, :, f) = currentMarker;
            end
            obj.saveState()
        end
        
        function keyPressCallback(obj,source,eventdata)
            obj.checkForClickedNodes
            % keyPressCallback - Handle UI
            % Extends Animator callback function
            
            % Extend Animator callback function
            keyPressCallback@Animator(obj,source,eventdata);
            
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
                    obj.triangulateLabeledPoints(obj.frameInds(obj.frame));
                    obj.reprojectPoints(obj.frameInds(obj.frame));
                    update(obj)
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
                case 'z'
                    obj.toggleZoomIn();
                case 'l'
                    obj.setLabeled();
                case 'r'
                    reset(obj);
                case 'pageup'
                    obj.selectNode(1);
                case 'p'
                    if ~obj.isKP3Dplotted
                        obj.add3dPlot();
                    else
                        obj.remove3dPlot();
                    end
            end
        end
        
        function setLabeled(obj)
            obj.status(:,:,obj.frameInds(obj.frame)) = obj.isLabeled;
            obj.update()
        end            
            
        function toggleZoomIn(obj)
            zoomState = zoom(obj.Parent);
            zoomState.Direction = 'in';
            if strcmp(zoomState.Enable,'off')
                % Toggle the zoom state
                zoomState.Enable = 'on';
                
                % This trick disables window listeners that prevent
                % the installation of custom keypresscallback
                % functions in ui default modes.
                % See matlab.uitools.internal.uimode/setCallbackFcn
                hManager = uigetmodemanager(obj.Parent);
                matlab.graphics.internal.setListenerState(hManager.WindowListenerHandles,'off');
                
                % We need to disable normal keypress mode
                % functionality to prevent the command window from
                % taking focus
                obj.Parent.WindowKeyPressFcn = @(src,event) Animator.runAll(obj.getAnimators,src,event);
                obj.Parent.KeyPressFcn = [];
            else
                zoomState.Enable = 'off';
                obj.Parent.WindowKeyPressFcn = @(src,event) Animator.runAll(obj.getAnimators,src,event);
                obj.Parent.KeyPressFcn = [];
            end
        end
        
        function loadFrom3D(obj, pts3d)
            % loadState - Load (triangulated) 3d data and visualize.
            %
            % Syntax: obj.loadFrom3D(files)
            %
            % Inputs: pts3d - NFrames x 3 x nMarkers 3d data.     
            
            % Load the 3d points
            pts3d = reshape(pts3d, size(pts3d,1), 3, []);
            pts3d = permute(pts3d, [3 2 1]);
            
            
            % Update the stauts. Only overwrite non-labeled points
            isInit = ~any(isnan(pts3d),2);
            newStatus = repelem(isInit,1,obj.nCams,1)*obj.isInitialized;
            handLabeled = obj.status == obj.isLabeled;
            obj.status(~handLabeled) = newStatus(~handLabeled);
            ptsHandLabeled = repelem(any(handLabeled,2), 1, 3, 1);
            obj.points3D(~ptsHandLabeled) = pts3d(~ptsHandLabeled);
            
            % Reproject the camera points
            for nFrame = 1:size(obj.points3D,3)
                obj.reprojectPoints(nFrame);
            end
            for nAnimator = 1:obj.nCams
                impts = squeeze(obj.camPoints(:,nAnimator,:,:));
                obj.initialMarkers{nAnimator} = permute(impts, [3 2 1]);
            end
            obj.update()
%             obj.points3D = nan(size(obj.points3D));
        end
        
        function loadState(obj, files)
            % loadState - Load (triangulated) data from previous sessions.
            %
            % Syntax: obj.loadState(files)
            %
            % Inputs: files - cell array of paths to .mat files generated
            %                 by Label3D.saveState()
                         
            % Load the files and store metadata
            data = cellfun(@load, files);      
            obj.status(:,:,1:size(data(1).status,3)) = data(1).status;
            
            % Load the 3d points
            pts3d = data(1).data_3D;
            pts3d = reshape(pts3d, size(pts3d,1), 3, []);
            pts3d = permute(pts3d, [3 2 1]);
            obj.points3D(:,:,1:size(pts3d,3)) = pts3d;
            
            % Load the camera points
            for nFile = 1:numel(files)
                pts = data(nFile).data_2D;
                pts = reshape(pts, size(pts,1), 2, []);
                pts = permute(pts, [3 2 1]);
                obj.camPoints(:,nFile,:,1:size(pts,3)) = pts;
            end
        end
        
        function saveState(obj)
            % saveState - Save data for each camera to the savePath
            %   Saves one .mat file for each camera with the format string 
            %   path = sprintf('%s%sCamera_%d.mat', obj.savePath, datestr(now,'yyyy_mm_dd_HH_MM_SS'), nCam);
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
            labeledFrames = repelem(labeledFrames,1,3,1);
            pts3D = obj.points3D;
            pts3D(~labeledFrames) = nan;
            data_3D = permute(pts3D, [3 2 1]);
            data_3D = reshape(data_3D, size(data_3D, 1), []);
%             data_3D(~any(~isnan(data_3D),2),:) = [];
%             pts3D(any(~any(~isnan(pts3D),2),3),:,:) = [];
            
            for nCam = 1:obj.nCams
                cp = obj.cameraParams{nCam};
                % Reproject points from 3D to 2D, applying distortion if
                % desired.
                pts = permute(obj.points3D, [3 1 2]);
                allpts = reshape(pts, [], 3);
                if ~obj.undistortedImages
                    data_2D = worldToImage(cp, cp.RotationMatrices,...
                        cp.TranslationVectors, allpts, 'ApplyDistortion',true);
                else
                    data_2D = worldToImage(cp, cp.RotationMatrices,...
                        cp.TranslationVectors, allpts);
                end
                data_2D = reshape(data_2D, size(pts,1), [], 2);
                data_2D = permute(data_2D, [1 3 2]);
                data_2D = reshape(data_2D, size(pts,1), []);
                
                % Save the data
                path = sprintf('%s%d.mat', obj.savePath, nCam);
                if obj.verbose
                    fprintf('Saving to %s at %s\n', path, datestr(now,'HH:MM:SS'))
                end
                save(path, 'data_2D', 'data_3D', 'status',...
                    'skeleton', 'imageSize', 'cameraPoses')
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
            for nAnimator = 1:obj.nCams
                pos = [(nAnimator-1)/(obj.nCams) 0 1/(obj.nCams) 1];
                set(obj.h{nAnimator},'Position',pos)
                set(obj.h{nAnimator+obj.nCams},'Position',pos)
            end
            set(obj.kp3a.Axes,'Position', obj.hiddenAxesPos);
            set(obj.kp3a.Axes,'Visible','off')
            arrayfun(@(X) set(X, 'Visible','off'), obj.kp3a.PlotSegments);
            obj.isKP3Dplotted = false;
        end
        
        function add3dPlot(obj)
            % Move the other plots out of the way
            for nAnimator = 1:obj.nCams
                pos = [(nAnimator-1)/(obj.nCams + 1) 0 1/(obj.nCams + 1) 1];
                set(obj.h{nAnimator},'Position',pos)
                set(obj.h{nAnimator+obj.nCams},'Position',pos)
            end
            pad = .05;
            % Add the 3d plot in the right place
            pos = [obj.nCams/(obj.nCams + 1)+pad pad 1/(obj.nCams + 1)-2*pad 1-2*pad];
            lims = [-400 400];
            set(obj.kp3a.Axes,'Position',pos,'Visible','on',...
                'XLim',lims,'YLim',lims,'ZLim',lims)
            arrayfun(@(X) set(X, 'Visible','on'), obj.kp3a.PlotSegments);
            obj.isKP3Dplotted = true;
        end      
        
        function checkForClickedNodes(obj)
            % Delete the selected nodes if they exist
            draggableAnimators = obj.h(obj.nCams+1:2*obj.nCams);
            for nAnimator = 1:numel(draggableAnimators)
                if ~isnan(draggableAnimators{nAnimator}.selectedNode)
                    obj.selectedNode = draggableAnimators{nAnimator}.selectedNode;
                end
            end
            obj.checkStatus()
            obj.update()
        end
        
        function deleteSelectedNode(obj)
            % Delete the selected nodes if they exist
            draggableAnimators = obj.h(obj.nCams+1:2*obj.nCams);
            fr = obj.frameInds(obj.frame);
            for nAnimator = 1:numel(draggableAnimators)
                if ~isnan(draggableAnimators{nAnimator}.selectedNode)
                    obj.status(draggableAnimators{nAnimator}.selectedNode, nAnimator, fr) = 0;
                    draggableAnimators{nAnimator}.deleteSelectedNode
                end
            end
            obj.checkStatus()
            obj.update()
        end
    end
    
    methods (Access = private)
        function reset(obj)
            restrict(obj, 1:obj.origNFrames)
        end
        
        function setupKeypoint3dAnimator(obj)
            m = permute(obj.points3D,[3 2 1]);
            % This hack prevents overlap between zoom callbacks in the kp
            % animator and the VideoAnimators
            pos = obj.hiddenAxesPos;
            obj.kp3a = Keypoint3DAnimator(m, obj.skeleton,'Position',pos);
            obj.kp3a.frameInds = obj.frameInds;
            obj.kp3a.frame = obj.frame;
            ax = obj.kp3a.Axes;
            grid(ax, 'on');
            set(ax,'color',obj.mainFigureColor,...
                'GridColor',obj.gridColor,...
                'Visible','off')
            view(ax, 3);
            arrayfun(@(X) set(X, 'Visible','off'), obj.kp3a.PlotSegments);
            obj.isKP3Dplotted = false;
        end
    end
    
    methods (Access = protected)
        function update(obj)
            % Update all of the other animators with any new data.
            for nKPAnimator = 1:obj.nCams
                kpaId = obj.nCams+nKPAnimator;
                kps = squeeze(obj.camPoints(:,nKPAnimator,:,:));
                kps = permute(kps, [3 2 1]);
                
                obj.h{kpaId}.markers = kps;
                obj.h{kpaId}.markersX = squeeze(kps(:,1,:));
                obj.h{kpaId}.markersY = squeeze(kps(:,2,:));
                
                fr = obj.frameInds(obj.frame);
                obj.h{kpaId}.points.XData = squeeze(kps(fr,1,:));
                obj.h{kpaId}.points.YData = squeeze(kps(fr,2,:));
            end
            
            % Run all of the update functions.
            for nAnimator = 1:numel(obj.h)
                update(obj.h{nAnimator})
            end
            
            % Update the keypoint animator
            pts = permute(obj.points3D, [3 2 1]);
            obj.kp3a.markers = pts;
            obj.kp3a.markersX = pts(:,1,:);
            obj.kp3a.markersY = pts(:,2,:);
            obj.kp3a.markersZ = pts(:,3,:);
            obj.kp3a.update()
            
            % Update the status animator
            obj.updateStatusAnimator()  
        end
        
        function setUpKeypointTable(obj)
            f = figure('Units','Normalized','pos',obj.tablePosition,'Name','Keypoint table',...
                'NumberTitle','off');
            obj.jointsPanel = uix.Panel('Parent', f, 'Title', 'Joints',...
                'Padding', 5,'Units','Normalized');
            obj.jointsControl = uicontrol(obj.jointsPanel, 'Style',...
                'listbox', 'String', obj.skeleton.joint_names,...
                'Units','Normalized','Callback',@(h,~,~) obj.selectNode(h.Value));
            set(obj.Parent.Children(end), 'Visible','off')
        end
        
        function setUpStatusTable(obj)
            f = figure('Units','Normalized','pos', [0 0 .5 .3],...
                'NumberTitle','off');
            ax = gca;
            colormap([0 0 0;.5 .5 .5;1 1 1])
            summary = squeeze(mode(obj.status,2));
            obj.statusAnimator = HeatMapAnimator(summary','Axes', ax);
            obj.statusAnimator.c.Visible = 'off';
            ax = obj.statusAnimator.Axes;
            set(ax, 'YTick',1:obj.nMarkers,'YTickLabels',obj.skeleton.joint_names)
            yyaxis(ax,'right')
            set(ax,'YLim',[1 obj.nMarkers],'YTick',1:obj.nMarkers,'YTickLabels',sum(summary,2))
            set(obj.statusAnimator.img,'CDataMapping','direct')
            obj.counter = title(sprintf('Total: %d',sum(any(summary==obj.isLabeled,1))));
        end
        
        function updateStatusAnimator(obj)
            obj.checkStatus();
            summary = squeeze(mode(obj.status,2));
            obj.statusAnimator.img.CData = summary+1;
            yyaxis(obj.statusAnimator.Axes,'right')
            set(obj.statusAnimator.Axes,'YTickLabels',flip(sum(summary==obj.isLabeled,2)))
            obj.counter.String = sprintf('Total: %d',sum(any(summary==obj.isLabeled,1)));
            obj.statusAnimator.update()
        end
    end
end