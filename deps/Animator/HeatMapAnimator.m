classdef HeatMapAnimator < Animator
    %HeatMapAnimator - interactive heatmap visualization.
    %Subclass of Animator.
    %
    %Syntax: HeatmapAnimator(X)
    %
    %HeatmapAnimator Properties:
    %   X - nSamples x nDimensions image to animate.
    %   I - order of indices for the second dimension of X
    %   c - handle to colorbar
    %   means - means of the dimensions of X
    %   stds - stds of the dimensions of X
    %   img - Handle to imagesc of X
    %   centerLine - Handle to line denoting current frame in heatmap
    %   zIm - Logical denoting whether the heatmap is currently zscored by
    %         dimensions.
    %         Default behavior is to automatically zscore dimensions. 
    %   origCLims - limits of [2.5 97.5] data percentiles for switching 
    %               between z-scored representations and standard ones. 
    %   seqSortWin - window to look in for sequential sorting. 
    % 
    %HeatmapAnimator Methods:
    %   Animator - constructor
    %   restrict - restrict animation to subset of frames
    %   keyPressCalback - handle UI
    %   reorder - Change the order of dimensions to some set.
    %   seqSort - Sort the dimensions according to the argmax 
    %             relative to a window surrounding points. Most useful for
    %             finding sequential activity in restricted sets of data.
    %   averageAligned - find average activity in window surrounding
    %             restricted points
    %   rankVariables - rank dimensions as a function of magnitude of
    %                   average activity in a window surrounding 
    %                   restricted points. 
    %   zImage - Flip between zscored image and regular image. 
    %
    %Tips: Press 'z' to flip between zscored and non zscored image.  
    properties (Access = private)
        statusMsg = 'HeatMapAnimator:\nFrame: %d\nframeRate: %d\n';
        viewingWindow = -30:30
        LineWidth = 3
    end
    
    properties (Access = public)
        X
        I
        c
        means
        stds
        img
        centerLine
        zIm=false;
        origCLims
        seqSortWin = -5:5
    end
    
    methods
        function obj = HeatMapAnimator(X, varargin)
            % User defined inputs
            if ~isempty(X)
                obj.X = X;
            end
            
            if ~isempty(varargin)
                set(obj,varargin{:});
            end
            % Handle defaults
            if isempty(obj.nFrames)
                obj.nFrames = size(obj.X, 1);
            end
            if isempty(obj.I)
                obj.I = 1:size(obj.X, 2);
            end
            obj.frameInds = 1:obj.nFrames;
            
            % Plot the first image
            hold(obj.Axes,'off')
            obj.img = imagesc(obj.Axes, obj.X');
            colormap(parula)
            obj.origCLims = prctile(obj.X(:), [2.5 97.5]);
            obj.means = nanmean(obj.X);
            obj.stds = nanstd(obj.X);
            obj.zImage()
            obj.c = colorbar(obj.Axes);
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
                case 'z'
                    obj.zImage();
                case 't'
                    obj.seqSort();
            end
            update(obj);
        end
        
        function reorder(obj, inds) 
            obj.img.CData = obj.img.CData(inds,:);
        end
        
        function seqSort(obj)
            [avg, ~] = obj.averageAligned(true,obj.seqSortWin);
            if ~isequal(obj.I, 1:size(obj.X,2))
                [~, inds] = sort(obj.I);
                obj.I = 1:size(obj.X,2);
                obj.reorder(inds)
            end
            [~, inds] = max(abs(avg),[],1);
            [~, obj.I] = sort(inds);
            obj.reorder(obj.I);
        end
        
        function [avg, tot] = averageAligned(obj, z_score_values, varargin)
            if ~isempty(varargin)
                window = varargin{1};
            else
                window = -10:10;
            end
            ids = obj.frameInds;
            starts = ids(diffpad(ids) ~= 1);
            ids = starts + window;
            if z_score_values
                tot = indpad2(zscore(obj.X), ids);
            else
                tot = indpad2(obj.X, ids);
            end
            avg = squeeze(nanmean(tot,1));
        end
        
        function [metric, ranked, ids] = rankVariables(obj, varargin)
            % Rank variables by the average of abs activity in a window
            % surrounding the starts of the current frameInds
            if ~isempty(varargin)
                window = varargin{1};
            else
                window = 0:10;
            end
            
            [avg, ~] = obj.averageAligned(true, window);
            metric = nanmean(abs(avg));
            [ranked, ids] = sort(metric, 'descend');
        end
        
        function zImage(obj)
            if obj.zIm 
                obj.img.CData = obj.img.CData.*obj.stds' + obj.means';
                caxis(obj.Axes, obj.origCLims)
                obj.zIm = false;
            else
%                 obj.img.CData = abs((obj.img.CData - obj.means') ./ obj.stds');
%                 caxis(obj.Axes, [0 3])
%                 obj.zIm = true;
                
                obj.img.CData = (obj.img.CData - obj.means') ./ obj.stds';
                caxis(obj.Axes, [-3 3])
                obj.zIm = true;
            end
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
            set(obj.centerLine,'XData',[obj.frameInds(obj.frame) obj.frameInds(obj.frame)],'YData', get(obj.Axes,'YLim'));
            set(obj.Axes, 'XLim', lims)
        end
    end
end