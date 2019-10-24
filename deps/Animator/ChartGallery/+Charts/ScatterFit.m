classdef ScatterFit < Chart
    %SCATTERFIT Chart managing 2D scattered data (x and y) together with a
    %best-fit line.
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
        % Legend text.
        LegendText
        % Legend font size.
        LegendFontSize
        % Legend location.
        LegendLocation
        % Legend visibility.
        LegendVisible
        % Grid display.
        Grid
        % Marker for the scatter series.
        Marker
        % Size data for the scatter series.
        SizeData
        % Color data for the scatter series.
        CData        
        % Style of the best-fit line.
        LineStyle
        % Width of the best-fit line.
        LineWidth
        % Color of the best-fit line.
        LineColor        
    end % properties ( Dependent )
    
    properties ( Access = private )
        % Backing property for the x-data.
        XData_ = NaN;
        % Backing property for the y-data.
        YData_ = NaN;
        % 2D scatter series.
        ScatterSeries
        % Line object for the best-fit line.
        BestFitLine
        % Legend.
        Legend
    end % properties ( Access = private )
    
    methods
        
        function obj = ScatterFit( varargin )
            %SCATTERFIT Constructor for the ScatterFit chart. All inputs
            %are specified using name-value pairs.
            
            % Create a temporary figure to act as the chart axes' Parent.
            f = figure( 'Visible', 'off' );
            oc = onCleanup( @() delete( f ) );
            
            % Parent the chart's axes.
            obj.Parent = f;
            
            % Create the scatter plot.
            obj.ScatterSeries = scatter( obj.Axes, NaN, NaN, '.' );
            % Restore the axes' DeleteFcn (reset by the scatter function).
            obj.Axes.DeleteFcn = @obj.onAxesDeleted;            
            
            % Create the best-fit line graphics object.
            obj.BestFitLine = line( NaN, NaN, ...
                'Parent', obj.Axes, ...
                'Color', [0.8, 0, 0], ...
                'LineWidth', 1.5 );
            % Create the legend.
            obj.Legend = legend( obj.Axes, {'', ''} );
            
            % Remove the chart axes' temporary Parent.
            obj.Parent = [];
            
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
                {'real', 'vector'}, 'ScatterFit/set.XData', 'the x-data' )
            
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
            
            % Adjust the size and color data if necessary.
            nC = size( obj.CData, 1 );
            if nC > 1 && nX ~= nC
                obj.CData = obj.Axes.ColorOrder(1, :);                
            end % if
            nS = numel( obj.SizeData );
            if nS > 1 && nX ~= nS
                obj.SizeData = 36;
            end % if
            
            % Update the chart graphics.
            update( obj );
            
        end % set.XData
        
        function y = get.YData( obj )
            y = obj.YData_;
        end % get.YData
        
        function set.YData( obj, proposedYData )
            
            % Perform basic validation.
            validateattributes( proposedYData, {'double'}, ...
                {'real', 'vector'}, 'ScatterFit/set.YData', 'the y-data' )
            
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
            
            % Adjust the size and color data if necessary.
            nC = size( obj.CData, 1 );
            if nC > 1 && nY ~= nC
                obj.CData = obj.Axes.ColorOrder(1, :);                
            end % if
            nS = numel( obj.SizeData );
            if nS > 1 && nY ~= nS
                obj.SizeData = 36;
            end % if
            
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
        
        function legText = get.LegendText( obj )
            legText = obj.Legend.String;
        end % get.LegendText
        
        function set.LegendText( obj, proposedLegendText )
            % Check the proposed legend text.
            assert( iscellstr( proposedLegendText ) && ...
                numel( proposedLegendText ) == 2, ...
                'Legend text must be a two-element cell array of character vectors.' )
            obj.Legend.String = proposedLegendText;
        end % set.LegendText
        
        function legFontSize = get.LegendFontSize( obj )
            legFontSize = obj.Legend.FontSize;
        end % get.LegendFontSize
        
        function set.LegendFontSize( obj, proposedLegendFontSize )
            obj.Legend.FontSize = proposedLegendFontSize;
        end % set.LegendFontSize
        
        function legLoc = get.LegendLocation( obj )
            legLoc = obj.Legend.Location;
        end % get.LegendLocation
        
        function set.LegendLocation( obj, proposedLegendLocation )
            obj.Legend.Location = proposedLegendLocation;
        end % set.LegendLocation
        
        function v = get.LegendVisible( obj )
            v = obj.Legend.Visible;
        end % get.LegendVisible
        
        function set.LegendVisible( obj, v )
            obj.Legend.Visible = v;
        end % set.LegendVisible
        
        function gridStatus = get.Grid( obj )
            gridStatus = obj.Axes.XGrid;
        end % get.Grid
        
        function set.Grid( obj, proposedGridStatus )
            set( obj.Axes, 'XGrid', proposedGridStatus, ...
                           'YGrid', proposedGridStatus );
        end % set.Grid 
        
        function m = get.Marker( obj )
            m = obj.ScatterSeries.Marker;
        end % get.Marker
        
        function set.Marker( obj, proposedMarker )
            obj.ScatterSeries.Marker = proposedMarker;
        end % set.Marker
        
        function sz = get.SizeData( obj )
            sz = obj.ScatterSeries.SizeData;
        end % get.SizeData
        
        function set.SizeData( obj, proposedSizeData )
            obj.ScatterSeries.SizeData = proposedSizeData;
        end % set.SizeData
        
        function c = get.CData( obj )
            c = obj.ScatterSeries.CData;
        end % get.CData
        
        function set.CData( obj, proposedCData )
            obj.ScatterSeries.CData = proposedCData;
        end % set.CData
        
        function ls = get.LineStyle( obj )
            ls = obj.BestFitLine.LineStyle;
        end % get.LineStyle
        
        function set.LineStyle( obj, proposedLineStyle )
            obj.BestFitLine.LineStyle = proposedLineStyle;
        end % set.LineStyle
        
        function lw = get.LineWidth( obj )
            lw = obj.BestFitLine.LineWidth;
        end % get.LineWidth
        
        function set.LineWidth( obj, proposedLineWidth )
            obj.BestFitLine.LineWidth = proposedLineWidth;
        end % set.LineWidth
        
        function c = get.LineColor( obj )
            c = obj.BestFitLine.Color;
        end % get.LineColor
        
        function set.LineColor( obj, proposedLineColor )
            obj.BestFitLine.Color = proposedLineColor;
        end % set.LineColor
        
    end % methods
    
    methods ( Access = private )
        
        function update( obj )
            
            % Update the scatter series with the new data.
            set( obj.ScatterSeries, 'XData', obj.XData_, ...
                'YData', obj.YData_ );
            % Obtain the new best-fit line. Suppress any rank deficiency
            % warning, if necessary, and restore the user's warning
            % preference.
            w = warning( 'query', 'stats:LinearModel:RankDefDesignMat' );
            warning( 'off', 'stats:LinearModel:RankDefDesignMat' )
            m = fitlm( obj.XData_, obj.YData_ );
            warning( w );
            % Update the best-fit line graphics.
            [~, posMin] = min( obj.XData_ );
            [~, posMax] = max( obj.XData_ );
            set( obj.BestFitLine, 'XData', obj.XData_([posMin, posMax]), ...
                'YData', m.Fitted([posMin, posMax]) );
        
        end % update
        
    end % methods ( Access = private )   
    
end % class definition