classdef Keypoint2DAnimator < Animator
    %Keypoint2DAnimator - Make a movie of markers tracked over time. Concrete
    %subclass of Animator.
    %
    %   Keypoint2DAnimator Properties:
    %   lim - limits of viewing window
    %   frame - current frame number
    %   frameRate - current frame rate
    %   MarkerSize - size of markers
    %   LineWidth - width of segments
    %   movieTitle - title to display at top of movie
    %   markers - global markerset
    %   skeleton - skeleton relating markers to one another
    %   ScatterMarkers - handle to scatter plot
    %   PlotSegments - handles to linesegments
    %
    %   Keypoint2DAnimator Methods:
    %   Keypoint2DAnimator - constructor
    %   restrict - restrict the animation to a subset of the frames
    %   keyPressCallback - handle UI
    properties (Access = private)
        nMarkers
        markersX
        markersY
        color
        joints
        instructions = ['Keypoint2DAnimator Guide:\n'...
            'rightarrow: next frame\n' ...
            'leftarrow: previous frame\n' ...
            'uparrow: increase frame rate by 10\n' ...
            'downarrow: decrease frame rate by 10\n' ...
            'space: set frame rate to 1\n' ...
            'control: set frame rate to 50\n' ...
            'shift: set frame rate to 250\n' ...
            'h: help guide\n'];
        statusMsg = 'Keypoint2DAnimator:\nFrame: %d\nframeRate: %d\n'
    end
    
    properties (Access = public)
        xlim
        ylim
        MarkerSize = 20;
        LineWidth = 3;
        markers
        skeleton
        ScatterMarkers
        PlotSegments
    end
    
    methods
        function obj = Keypoint2DAnimator(markers, skeleton, varargin)
            %Keypoint2DAnimator - constructor for Keypoint2DAnimator class.
            %Keypoint2DAnimator is a concrete subclass of Animator.
            %
            %Inputs:
            %   markers: Time x nDimension x nMarkers matrix of keypoints.
            %   skeleton: Structure with two fields:
            %       skeleton.color: nSegments x 3 matrix of RGB values
            %       skeleton.joints_idx: nSegments x 2 matrix of integers
            %           denoting directed edges between markers. 
            %   Syntax: Keypoint2DAnimator(markers, skeleton, varargin);
            
            % Check inputs
            validateattributes(markers,{'numeric'},{'3d'})
            validateattributes(skeleton,{'struct'},{})
            obj.markers = markers;
            obj.skeleton = skeleton;
            obj.color = obj.skeleton.color;
            obj.joints = obj.skeleton.joints_idx;
            validateattributes(obj.joints,{'numeric'},{'positive'})
            validateattributes(obj.color,{'numeric'},{'nonnegative'})
            if max(max(obj.joints)) > size(obj.markers,3)
                error('Invalid joints_idx: Idx exceeds number of markers');
            end
            if size(obj.color, 1) ~= size(obj.joints,1)
                error('Number of colors and number of segments do not match');
            end
            
            % User defined inputs
            if ~isempty(varargin)
                set(obj,varargin{:});
            end
            if isempty(obj.xlim)
                obj.xlim = [min(min(obj.markers(:,1,:))) max(max(obj.markers(:,1,:)))];
            end
            if isempty(obj.ylim)
                obj.ylim = [min(min(obj.markers(:,2,:))) max(max(obj.markers(:,2,:)))];
            end 
            set(obj.Axes,'xlim',obj.xlim,'ylim',obj.ylim);
            
            % Private constructions
            obj.nFrames = size(obj.markers,1);
            obj.frameInds = 1:obj.nFrames;
            obj.markersX = obj.markers(:,1,:);
            obj.markersY = obj.markers(:,2,:);
            obj.nMarkers = size(obj.markers,3);
            
            % Get color groups
            [colors,~,cIds] = unique(obj.color,'rows');
            [~, MaxNNodes] = mode(cIds);
            
            % Get the first frames marker positions
            curX = obj.markersX(obj.frameInds(obj.frame),:);
            curY = obj.markersY(obj.frameInds(obj.frame),:);
            curX = curX(obj.joints)';
            curY = curY(obj.joints)';
            
            %%% Very fast updating procedure with low level graphics. 
            % Concatenate with nans between segment ends to represent all 
            % segments with the same color as one single line object
            catnanX = cat(1,curX,nan(1,size(curX,2)));
            catnanY = cat(1,curY,nan(1,size(curY,2)));
            
            % Put into array for vectorized graphics initialization
            nanedXVec = nan(MaxNNodes*2,size(colors,1));
            nanedYVec = nan(MaxNNodes*2,size(colors,1));
            for nColor = 1:size(colors,1)
                nanedXVec(1:numel(catnanX(:,cIds==nColor)),nColor) = reshape(catnanX(:,cIds==nColor),[],1);
                nanedYVec(1:numel(catnanY(:,cIds==nColor)),nColor) = reshape(catnanY(:,cIds==nColor),[],1);
            end
            
            % Build line objects and set final properties
            obj.PlotSegments = line(obj.Axes,...
                nanedXVec,...
                nanedYVec,...
                'LineStyle','-',...
                'Marker','.',...
                'MarkerSize',obj.MarkerSize,...
                'LineWidth',obj.LineWidth);
            set(obj.PlotSegments, {'color'}, mat2cell(colors,ones(size(colors,1),1)));
        end
        
        function restrict(obj, newFrames)
            %restrict - restricts animation to a subset of frames
            obj.markersX = obj.markers(newFrames,1,:);
            obj.markersY = obj.markers(newFrames,2,:);
            restrict@Animator(obj, newFrames);
        end
        
        
        function keyPressCallback(obj,source,eventdata)
            % keyPressCallback - Handle UI
            % Extends Animator callback function
            
            % Extend Animator callback function
            keyPressCallback@Animator(obj,source,eventdata);
            
            % determine the key that was pressed
            keyPressed = eventdata.Key;
            switch keyPressed
                case 'h'
                    message = obj(1).instructions;
                    fprintf(message);
                case 's'
                    fprintf(obj(1).statusMsg,...
                        obj(1).frameInds(obj(1).frame),obj(1).frameRate);
                case 'r'
                    reset(obj);
            end
        end
    end
    
    methods (Access = private)
        function reset(obj)
            restrict(obj, 1:size(obj.markers,1))
        end
    end
    
    
    methods (Access = protected)
        function update(obj)
            % Find color groups
            [colors,~,cIds] = unique(obj.color,'rows');
            
            % Get the joints for the current frame
            curX = obj.markersX(obj.frameInds(obj.frame),:);
            curY = obj.markersY(obj.frameInds(obj.frame),:);
            curX = curX(obj.joints)';
            curY = curY(obj.joints)';
            
            %%% Very fast updating procedure with low level graphics. 
            % Concatenate with nans between segment ends to represent all 
            % segments with the same color as one single line object
            catnanX = cat(1,curX,nan(1,size(curX,2)));
            catnanY = cat(1,curY,nan(1,size(curY,2)));
            
            % Put into cell for vectorized graphics update
            nanedXVec = cell(size(colors,1),1);
            nanedYVec = cell(size(colors,1),1);
            for i = 1:size(colors,1)
                nanedXVec{i} = reshape(catnanX(:,cIds==i),[],1);
                nanedYVec{i} = reshape(catnanY(:,cIds==i),[],1);
            end
            
            % Update the values
            valueArray = cat(2, nanedXVec, nanedYVec);
            nameArray = {'XData','YData'};
            segments = obj.PlotSegments;
            set(segments,nameArray,valueArray)
        end
    end
end