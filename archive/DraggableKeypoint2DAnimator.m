classdef DraggableKeypoint2DAnimator < Animator
    %DraggableKeypoint2DAnimator - Animate multicolor keypoints in 2D with 
    %   draggable nodes. Concrete subclass of Animator.
    %
    %   DraggableKeypoint2DAnimator Properties:
    %   frame - current frame number
    %   frameRate - current frame rate
    %   MarkerSize - size of markers
    %   LineWidth - width of segments
    %   markers - positions of markers to plot
    %   skeleton - skeleton relating markers to one another
    %   PlotSegments - handles to linesegments
    %   points - handles to invisible draggable points.
    %
    %   DraggableKeypoint2DAnimator Methods:
    %   DraggableKeypoint2DAnimator - constructor
    %   restrict - restrict the animation to a subset of the frames
    %   getCurrentFramePositions - Get the positions of markers in the
    %       frame.
    %   dragpoints - Create draggable points
    %   resetFrame - Reset frame to the original position. 
    %   keyPressCallback - handle UI
    properties (Access = private)
        nMarkers
        origMarkers
        color
        joints
        instructions = ['DraggableKeypoint2DAnimator Guide:\n'...
            'rightarrow: next frame\n' ...
            'leftarrow: previous frame\n' ...
            'uparrow: increase frame rate by 10\n' ...
            'downarrow: decrease frame rate by 10\n' ...
            'space: set frame rate to 1\n' ...
            'control: set frame rate to 50\n' ...
            'shift: set frame rate to 250\n' ...
            'h: help guide\n'];
        statusMsg = 'DraggableKeypoint2DAnimator:\nFrame: %d\nframeRate: %d\n'
    end
    
    properties (Access = public)
        xlim
        ylim
        MarkerSize = 20;
        LineWidth = 3;
        markers
        markersX
        markersY
        skeleton
        PlotSegments
        points
        selectedNode
    end
    
    methods
        function obj = DraggableKeypoint2DAnimator(markers, skeleton, varargin)
            %DraggableKeypoint2DAnimator - constructor for DraggableKeypoint2DAnimator class.
            %DraggableKeypoint2DAnimator is a concrete subclass of Animator.
            %
            %Inputs:
            %   markers: Time x nDimension x nMarkers matrix of keypoints.
            %   skeleton: Structure with two fields:
            %       skeleton.color: nSegments x 3 matrix of RGB values
            %       skeleton.joints_idx: nSegments x 2 matrix of integers
            %           denoting directed edges between markers.
            %   Syntax: DraggableKeypoint2DAnimator(markers, skeleton, varargin);
            obj@Animator(varargin{(end-1):end});
      
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
            obj.origMarkers = obj.markers;
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
            obj.PlotSegments = line(obj.Axes,...
                nanedXVec,...
                nanedYVec,...
                'LineStyle','-',...
                'Marker','.',...
                'MarkerSize',obj.MarkerSize,...
                'LineWidth',obj.LineWidth,'HitTest','off');
            set(obj.PlotSegments, {'color'}, mat2cell(colors,ones(size(colors,1),1)));
            
            % This sets up a trick to lock draggable points to multiple
            % colored lines.
            frameX = obj.markersX(obj.frameInds(obj.frame),:);
            frameY = obj.markersY(obj.frameInds(obj.frame),:);
            obj.points = obj.dragpoints(obj.Axes, frameX, frameY,...
                'LineStyle', 'none', 'Marker', '.', 'MarkerSize',...
                20, 'Color', 'w');
        end
        
        function restrict(obj, newFrames)
            %restrict - restricts animation to a subset of frames
            obj.markersX = obj.markers(newFrames,1,:);
            obj.markersY = obj.markers(newFrames,2,:);
            restrict@Animator(obj, newFrames);
        end
        
        function curMarker = getCurrentFramePositions(obj)
            % Get the current position of the draggable nodes.
            x = obj.points.XData;
            y = obj.points.YData;
            curMarker = [x ; y]';
        end
        
        function lines = dragpoints(obj, ax, x, y, varargin)
            % Create invisible draggable plotting points to act as anchors
            % for multicolor lines. 
            % Consider reimplementing with draggable()
            lines = line(ax, x,y,'hittest','on','buttondownfcn',...
                @obj.clickmarker,'PickableParts','all','Visible','off',...
                varargin{:});
        end
        
        function clickmarker(obj, src, ev)
            % Handle clicks on markers by turning on dragging mode. 
            obj.selectedNode = obj.getSelectedNode(src);
            set(ancestor(src,'figure'),'windowbuttonmotionfcn',{@obj.dragmarker,src})
            set(ancestor(src,'figure'),'windowbuttonupfcn',@obj.stopdragging)
        end
        
        function deleteDataTips(obj)
            lines = obj.points;
            for nLine = 1:numel(lines)
                delete(lines(nLine).Children)
            end
        end
        
        function index = getSelectedNode(obj, src)
            % Find the index of the clicked node
            
            % Get current axes and coords
            h1=gca;
            coords=get(h1,'currentpoint');
            
            % Get all x and y data
            x=src.XData;
            y=src.YData;
            
            % Check which data point has the smallest distance to the dragged point
            x_diff = abs(x-coords(1,1,1));
            y_diff = abs(y-coords(1,2,1));
            [~, index] = min(sqrt(x_diff.^2+y_diff.^2));
        end
        
        function dragmarker(obj, fig, ev,src)
            % Create new x and y data and exchange coords for the dragged point
            h1=gca;
            coords=get(h1,'currentpoint');
            x_new=src.XData;
            y_new=src.YData;
            x_new(obj.selectedNode)=coords(1,1,1);
            y_new(obj.selectedNode)=coords(1,2,1);
            %update plot
            set(src,'xdata',x_new,'ydata',y_new);
            obj.update()
        end
        
        function stopdragging(obj,fig,ev)
            % Stop dragging mode
            set(fig,'windowbuttonmotionfcn','')
            set(fig,'windowbuttonupfcn','')
        end
        
        function resetFrame(obj)
            % Reset the frame to the original positions of markers. 
            f = obj.frameInds(obj.frame);
            obj.markers(f,:,:) = obj.origMarkers(f,:,:);
            obj.markersX = obj.markers(:,1,:);
            obj.markersY = obj.markers(:,2,:);
            obj.points.XData = squeeze(obj.markers(f,1,:));
            obj.points.YData = squeeze(obj.markers(f,2,:));
            obj.update();
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
%                 case 's'
%                     fprintf(obj(1).statusMsg,...
%                         obj(1).frameInds(obj(1).frame),obj(1).frameRate);
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
            
            curFrame = obj.getCurrentFramePositions();
            
            % Get the joints for the current frame
            curX = curFrame(:, 1);
            curY = curFrame(:, 2);
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