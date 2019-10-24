classdef StackedTraceAnimator < Animator
    %StackedTraceAnimator - interactive stacked trace visualization.
    %Subclass of Animator.
    %
    %Syntax: StackedTraceAnimator(raster)
    %
    %StackedTraceAnimator Properties:
    %    X - nSamples x 1 - X axis data
    %    Y - nSamples x nLines - Y axis data
    %
    %StackedTraceAnimator Methods:
    %StackedTraceAnimator - constructor
    %restrict - restrict animation to subset of frames
    %keyPressCalback - handle UI
    properties (Access = private)
        statusMsg = 'StackedTraceAnimator:\nFrame: %d\nframeRate: %d\n';
    end
    
    properties (Access = public)
        raster
        LineWidth = 3
        viewingWindow = -50:50
        X
        Y
        interTraceSpacing = 1
        animal
        lines
        nMarkers
        centerLine
    end
    
    methods
        function obj = StackedTraceAnimator(X, Y, varargin)
            % User defined inputs
            if ~isempty(X)
                obj.X = X;
            end
            if ~isempty(Y)
                obj.Y = Y;
            end
            if ~isempty(varargin)
                set(obj,varargin{:});
            end
            
            % Handle defaults
            if isempty(obj.nFrames)
                obj.nFrames = size(obj.X,1);
            end
            obj.frameInds = 1:obj.nFrames;
            axes(obj.Axes)
            hold(obj.Axes,'on');

            [~, obj.lines] = stackedTraces(X, Y, obj.interTraceSpacing);
            lims = [min(obj.frame+obj.viewingWindow) max(obj.frame+obj.viewingWindow)];
            xlim(obj.Axes,lims)
            ydata = cell2mat(arrayfun(@(X) X.YData, obj.lines,'uni',0));
            ylim([min(min(ydata)) max(max(ydata))])
            
            % Plot the current frame line
            obj.centerLine = line(obj.Axes,[obj.frame obj.frame],...
                get(obj.Axes,'YLim'),'color','k','LineWidth',obj.LineWidth, 'LineStyle','--');
        end
        
        function restrict(obj, newFrames)
            restrict@Animator(obj, newFrames);
        end
        
        function keyPressCallback(obj,source,eventdata)
            % determine the key that was pressed
            keyPressCallback@Animator(obj,source,eventdata);
            keyPressed = eventdata.Key;
            switch keyPressed
                case 's'
                    fprintf(obj.statusMsg,...
                        obj.frameInds(obj.frame),obj.frameRate);
                case 'r'
                    reset(obj);
            end
            update(obj);
        end
    end
    
    methods (Access = private)
        function reset(obj)
            % Set embedMovie and associated MarkerMovies to the orig. size
            restrict(obj,1:size(obj.X,1));
        end
    end
    
    methods (Access = protected)
        function update(obj)
            lims = [min(obj.frameInds(obj.frame)+obj.viewingWindow) max(obj.frameInds(obj.frame)+obj.viewingWindow)];
            set(obj.centerLine,'XData',[obj.frame obj.frame],'YData', get(gca,'YLim'));
            set(obj.Axes, 'XLim', lims)
        end
    end
end