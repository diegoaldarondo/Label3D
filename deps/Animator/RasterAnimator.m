classdef RasterAnimator < Animator
    %RasterAnimator - interactive raster visualization.
    %Subclass of Animator.
    %
    %Syntax: RasterAnimator(raster)
    %
    %RasterAnimator Properties:
    %    raster - Nx1 raster to animate.
    %
    %RasterAnimator Methods:
    %RasterAnimator - constructor
    %restrict - restrict animation to subset of frames
    %keyPressCalback - handle UI
    properties (Access = private)
        statusMsg = 'RasterAnimator:\nFrame: %d\nframeRate: %d\n';
    end
    
    properties (Access = public)
        viewingWindow = -50:50
        LineWidth = 3
        raster
        img
        animal
        nMarkers
        centerLine
    end
    
    methods
        function obj = RasterAnimator(raster, varargin)
            % User defined inputs
            if ~isempty(raster)
                obj.raster = raster;
            end
            if ~isempty(varargin)
                set(obj,varargin{:});
            end
            
            % Handle defaults
            if isempty(obj.nFrames)
                obj.nFrames = size(obj.raster,1);
            end
            obj.frameInds = 1:obj.nFrames;
            
            % Plot the first image
            hold(obj.Axes,'off')
            obj.img = imagesc(obj.Axes, obj.raster(:,obj.frame)');
            colormap('jet')
            lims = [min(obj.frame+obj.viewingWindow) max(obj.frame+obj.viewingWindow)];
            xlim(obj.Axes,lims)
            hold(obj.Axes,'on');
            
            % Plot the current frame line
            obj.centerLine = line(obj.Axes,[obj.frame obj.frame],...
                get(obj.Axes,'YLim'),'color','w','LineWidth',obj.LineWidth);
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
            restrict(obj,1:size(obj.raster,1));
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