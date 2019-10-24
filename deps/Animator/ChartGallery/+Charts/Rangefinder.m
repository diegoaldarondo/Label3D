classdef Rangefinder < Chart
    %RANGEFINDER Create a rangefinder chart for bivariate scattered data.
    %The rangefinder chart creates a 2-D scatter plot overlaid with a
    %marker at the crossover point of the marginal medians and lines
    %indicating the marginal adjacent values.
    %
    % Copyright 2018 The MathWorks, Inc.
    
    properties ( Hidden, Constant )
        % Product dependencies.
        Dependencies = ...
            {'MATLAB', 'Statistics and Machine Learning Toolbox'};
    end % properties ( Hidden, Constant )
    
    % Public interface properties.
    properties ( Dependent )
        % Chart x-data.
        XData
        % Chart y-data.
        YData
        % Axes x-label.
        XLabel
        % Axes y-label.
        YLabel
        % Axes title.
        Title
        % Marker for the discrete plot.
        Marker
        % Size data for the discrete plot.
        MarkerSize
        % Color of the discrete plot.
        Color
    end % properties ( Dependent )
    
    properties ( Access = private )
        % Backing property for the x-data.
        XData_
        % Backing property for the y-data.
        YData_
        % Bivariate discrete plot.
        DiscretePlot
        % Line objects used for the median crossover.
        MedianCrossover
        % Line objects used for the adjacent values.
        AdjacentLines
    end % properties ( Access = private )
    
    methods
        
        function obj = Rangefinder( varargin )
            
            % Create the chart graphics.
            % Start with the discrete plot for the 2-D data.
            color = obj.Axes.ColorOrder(1, :);
            obj.DiscretePlot = line( 'Parent', obj.Axes, ....
                'XData', [], ...
                'YData', [], ...
                'LineStyle', 'none', ...
                'Marker', '.', ...
                'MarkerSize', 6, ...
                'Color', color );
            % Next, create the median crossover. This comprises two
            % perpendicular line segments with markers at their crossover
            % point.
            obj.MedianCrossover = gobjects( 4, 1 );
            c = 'k';
            obj.MedianCrossover(1) = line( 'Parent', obj.Axes, ...
                'XData', [], ...
                'YData', [], ...
                'Color', c, ...
                'LineWidth', 1.5 );
            obj.MedianCrossover(2) = line( 'Parent', obj.Axes, ...
                'XData', [], ...
                'YData', [], ...
                'Color', c, ...
                'LineWidth', 1.5 );
            obj.MedianCrossover(3) = line( 'Parent', obj.Axes, ...
                'XData', [], ...
                'YData', [], ...
                'Color', c, ...
                'Marker', 'o', ...
                'LineWidth', 1.5, ...
                'MarkerSize', 20 );
            obj.MedianCrossover(4) = line( 'Parent', obj.Axes, ...
                'XData', [], ...
                'YData', [], ...
                'Color', c, ...
                'Marker', 'x', ...
                'LineWidth', 1.5, ...
                'MarkerSize', 20 );
            % Next, create the line segments for the adjacent values.
            obj.AdjacentLines = gobjects( 4, 1 );
            c = obj.Axes.ColorOrder(4, :);
            obj.AdjacentLines(1) = line( 'Parent', obj.Axes, ...
                'XData', [], ...
                'YData', [], ...
                'Color', c, ...
                'LineWidth', 1.5 );
            obj.AdjacentLines(2) = line( 'Parent', obj.Axes, ...
                'XData', [], ...
                'YData', [], ...
                'Color', c, ...
                'LineWidth', 1.5 );
            obj.AdjacentLines(3) = line( 'Parent', obj.Axes, ...
                'XData', [], ...
                'YData', [], ...
                'Color', c, ...
                'LineWidth', 1.5 );
            obj.AdjacentLines(4) = line( 'Parent', obj.Axes, ...
                'XData', [], ...
                'YData', [], ...
                'Color', c, ...
                'LineWidth', 1.5 );
            
            % Set the required axes properties.
            obj.Axes.XGrid = 'on';
            obj.Axes.YGrid = 'on';
            
            % Set the chart properties.
            if ~isempty( varargin )
                set( obj, varargin{:} );
            end % if
            
        end % constructor
        
        % Get/set methods.
        function x = get.XData( obj )
            x = obj.XData_;
        end % get.XData
        
        function set.XData( obj, proposedXData )
            
            % Perform basic validation.
            validateattributes( proposedXData, {'double'}, ...
                {'real', 'vector'}, 'Rangefinder/set.XData', 'the x-data' )
            % Replace any infinities with NaNs.
            proposedXData(isinf( proposedXData ) ) = NaN;
            % Error if the data is all NaNs.
            if all( isnan( proposedXData ) )
                error( 'Rangefinder:InvalidXData', ...
                    'Chart x-data cannot be all non-finite.' )
            end % if
            
            % Decide how to modify the chart data.
            nX = numel( proposedXData );
            nY = numel( obj.YData_ );
            
            if nX < nY % If the new x-data is too short ...
                % ... then chop the chart y-data.
                obj.YData_ = obj.YData_(1:nX);
            else
                % Otherwise, if nX >= nY, then pad the y-data.
                obj.YData_(end+1:nX) = NaN;
            end % if
            
            % Set the internal x-data.
            obj.XData_ = proposedXData(:);
            
            % Update the chart graphics.
            update( obj );
            
        end % set.XData
        
        function y = get.YData( obj )
            y = obj.YData_;
        end % get.YData
        
        function set.YData( obj, proposedYData )
            
            % Perform basic validation.
            validateattributes( proposedYData, {'double'}, ...
                {'real', 'vector'}, 'Rangefinder/set.YData', 'the y-data' )
            % Replace any infinities with NaNs.
            proposedYData(isinf( proposedYData ) ) = NaN;
            % Error if the data is all NaNs.
            if all( isnan( proposedYData ) )
                error( 'Rangefinder:InvalidYData', ...
                    'Chart y-data cannot be all non-finite.' )
            end % if
            
            % Decide how to modify the chart data.
            nY = numel( proposedYData );
            nX = numel( obj.XData_ );
            
            if nY < nX % If the new y-data is too short ...
                % ... then chop the chart x-data.
                obj.XData_ = obj.XData_(1:nY);
            else
                % Otherwise, if nY >= nX, then pad the x-data.
                obj.XData_(end+1:nY) = NaN;
            end % if
            
            % Set the internal y-data.
            obj.YData_ = proposedYData(:);
            
            % Update the chart graphics.
            update( obj );
            
        end % set.YData
        
        function xl = get.XLabel( obj )
            xl = obj.Axes.XLabel;
        end % get.XLabel
        
        function set.XLabel( obj, proposedXLabel )
            obj.Axes.XLabel = proposedXLabel;
        end % set.XLabel
        
        function yl = get.YLabel( obj )
            yl = obj.Axes.YLabel;
        end % get.YLabel
        
        function set.YLabel( obj, proposedYLabel )
            obj.Axes.YLabel = proposedYLabel;
        end % set.YLabel
        
        function t = get.Title( obj )
            t = obj.Axes.Title;
        end % get.Title
        
        function set.Title( obj, proposedTitle )
            obj.Axes.Title = proposedTitle;
        end % set.Title
        
        function m = get.Marker( obj )
            m = obj.DiscretePlot.Marker;
        end % get.Marker
        
        function set.Marker( obj, proposedMarker )
            obj.DiscretePlot.Marker = proposedMarker;
        end % set.Marker
        
        function ms = get.MarkerSize( obj )
            ms = obj.DiscretePlot.MarkerSize;
        end % get.MarkerSize
        
        function set.MarkerSize( obj, proposedSize )
            obj.DiscretePlot.MarkerSize = proposedSize;
        end % set.MarkerSize
        
        function c = get.Color( obj )
            c = obj.DiscretePlot.Color;
        end % get.Color
        
        function set.Color( obj, proposedColor )
            obj.DiscretePlot.Color = proposedColor;
        end % set.Color
        
    end % methods
    
    methods ( Access = private )
        
        function update( obj )
            
            % Update the discrete plot.
            set( obj.DiscretePlot, 'XData', obj.XData_, ...
                'YData', obj.YData_ )
            % Compute the marginal quartiles.
            qx = quantile( obj.XData_, [0.25, 0.50, 0.75] );
            qy = quantile( obj.YData_, [0.25, 0.50, 0.75] );
            % Compute the interquartile ranges.
            iqrx = qx(3) - qx(1);
            iqry = qy(3) - qy(1);
            % Update the median crossover graphics.
            set( obj.MedianCrossover(1), ...
                'XData', qx([1, 3]), ...
                'YData', qy([2, 2]) )
            set( obj.MedianCrossover(2), ...
                'XData', qx([2, 2]), ...
                'YData', qy([1, 3]) )
            set( obj.MedianCrossover(3), ...
                'XData', qx(2), ...
                'YData', qy(2) )
            set( obj.MedianCrossover(4), ...
                'XData', qx(2), ...
                'YData', qy(2) )
            % Update the adjacent lines. To do this, we compute the upper
            % and lower limits.
            xLimits = [qx(1)-1.5*iqrx, qx(3)+1.5*iqrx];
            yLimits = [qy(1)-1.5*iqry, qy(3)+1.5*iqry];
            internalxIdx = obj.XData_ > xLimits(1) & ...
                obj.XData_ < xLimits(2);
            internalyIdx = obj.YData_ > yLimits(1) & ...
                obj.YData_ < yLimits(2);
            adjx = [min(obj.XData_(internalxIdx)), ...
                max(obj.XData_(internalxIdx))];
            adjy = [min(obj.YData_(internalyIdx)), ...
                max(obj.YData_(internalyIdx))];
            % Deal with the edge case when no adjacent values exist.
            if isempty( adjx )
                adjx = NaN( 1, 2 );
            end % if
            if isempty( adjy )
                adjy = NaN( 1, 2 );
            end % if
            % Update the adjacent lines.
            set( obj.AdjacentLines(1), ...
                'XData', [adjx(1), adjx(1)], ...
                'YData', qy([1, 3]) )
            set( obj.AdjacentLines(2), ...
                'XData', [adjx(2), adjx(2)], ...
                'YData', qy([1, 3]) )
            set( obj.AdjacentLines(3), ...
                'XData', qx([1, 3]), ...
                'YData', [adjy(1), adjy(1)] )
            set( obj.AdjacentLines(4), ...
                'XData', qx([1, 3]), ...
                'YData', [adjy(2), adjy(2)] )
            
        end % update
        
    end % methods ( Access = private )
    
end % class definition