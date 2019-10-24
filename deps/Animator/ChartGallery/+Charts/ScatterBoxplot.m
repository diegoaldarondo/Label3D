classdef ScatterBoxplot < matlab.mixin.SetGet
    %SCATTERBOXPLOT Chart managing a bivariate scatter plot and its
    %marginal boxplots.
    %
    % Copyright 2018 The MathWorks, Inc.
    
    properties ( Hidden, Constant )
        % Product dependencies.
        Dependencies = {'MATLAB', ...
            'Statistics and Machine Learning Toolbox'};        
    end % properties ( Hidden, Constant )
    
    properties ( Dependent )
        % Chart parent.
        Parent
        % Chart position.
        Position
        % Chart units.
        Units
        % Chart visibility.
        Visible
        % Chart x-data.
        XData
        % Chart y-data.
        YData
        % Main axes x-label.
        XLabel
        % Main axes y-label.
        YLabel
        % Main axes title.
        Title
        % Scatter series marker.
        Marker
        % Scatter series marker face color.
        MarkerFaceColor
        % Scatter series marker edge color.
        MarkerEdgeColor
        % Scatter series size.
        SizeData
        % Scatter series color.
        CData
        % Background color of the chart.
        BackgroundColor
        % Width of the boxplot lines.
        BoxplotLineWidth
    end % properties ( Dependent )
    
    properties ( Access = private )
        % Backing property for the chart x-data.
        XData_
        % Backing property for the chart y-data.
        YData_
        % Graphics container.
        Container
        % Main axes, for the scatter series.
        ScatterAxes
        % Left-hand axes, for the marginal y-data boxplot.
        YBoxPlotAxes
        % Bottom axes, for the marginal x-data boxplot.
        XBoxPlotAxes
        % Discrete data points, plotted as a scatter series.
        ScatterSeries
        % Marginal y-data boxplot graphics.
        YBoxPlotGraphics
        % Marginal x-data boxplot graphics.
        XBoxPlotGraphics
        % Listener for changes in the main axes x-limits.
        XLimChangedListener
        % Listener for changes in the main axes y-limits.
        YLimChangedListener
    end % properties ( Access = private )
   
    methods
        
        function obj = ScatterBoxplot( varargin )
            
            % Create the chart's graphical peer: in this case, a container.
            obj.Container = uipanel( 'Parent', [], ... 
                'BorderType', 'none', ...
                'DeleteFcn', @obj.onContainerDeleted );
            
            % Create the internal graphics objects. First, create the three
            % axes.
            mainAxesPosition = [0.30, 0.275, 0.65, 0.65];
            obj.ScatterAxes = axes( 'Parent', obj.Container, ... 
                'Units', 'Normalized', ...
                'Position', mainAxesPosition );
            outPos = [0.20, 0.175, 0.80, 0.80]; 
            obj.YBoxPlotAxes = axes( 'Parent', obj.Container, ... 
                'Units', 'Normalized', ...
                'Position', [0.05, mainAxesPosition(2), ...
                outPos(1)-0.01, mainAxesPosition(4)] );
            obj.XBoxPlotAxes = axes( 'Parent', obj.Container, ...                
                'Units', 'Normalized', ...
                'Position', [mainAxesPosition(1), 0.01, ...
                mainAxesPosition(3), outPos(2)-0.03] );            
            
            % Scatter series.
            c = obj.ScatterAxes.ColorOrder(1, :);
            obj.ScatterSeries = scatter( obj.ScatterAxes, [], [], 6, c, ...
                '.' );            
            
            % Add the grid.
            obj.ScatterAxes.XGrid = 'on';
            obj.ScatterAxes.YGrid = 'on';
            
            % Create the listeners for changes in the main axes' limits.
            axesInfo = ?matlab.graphics.axis.Axes;
            axesProps = axesInfo.PropertyList;
            propNames = {axesProps.Name};
            xlimIdx = strcmp( propNames, 'XLim' );
            ylimIdx = strcmp( propNames, 'YLim' );
            obj.XLimChangedListener = event.proplistener( ...
                obj.ScatterAxes, axesProps(xlimIdx), ...
                'PostSet', @obj.onXLimChanged );                                
            obj.YLimChangedListener = event.proplistener( ...
                obj.ScatterAxes, axesProps(ylimIdx), ...
                'PostSet', @obj.onYLimChanged );
            
            % Set the chart properties.
            if ~isempty( varargin )
                set( obj, varargin{:} );
            end % if            
            
        end % constructor
        
        function delete( obj )
            delete( obj.Container );
        end % delete
        
        % Get/set methods.
        function p = get.Parent( obj )
            p = obj.Container.Parent;
        end % get.Parent
        
        function set.Parent( obj, proposedParent )
            obj.Container.Parent = proposedParent;
        end % set.Parent
        
        function pos = get.Position( obj )
            pos = obj.Container.Position;
        end % get.Position
        
        function set.Position( obj, proposedPosition )
            obj.Container.Position = proposedPosition;
        end % set.Position
        
        function u = get.Units( obj )
            u = obj.Container.Units;
        end % get.Units
        
        function set.Units( obj, proposedUnits )
            obj.Container.Units = proposedUnits;
        end % set.Units
        
        function v = get.Visible( obj )
            v = obj.Container.Visible;
        end % get.Visible
        
        function set.Visible( obj, proposedVisibility )
            obj.Container.Visible = proposedVisibility;
        end % set.Visible
        
        function x = get.XData( obj )
            x = obj.XData_;
        end % get.XData
        
        function set.XData( obj, proposedXData )
            
            % Check the given input.
            validateattributes( proposedXData, {'double'}, ...
                {'real', 'vector'}, 'ScatterBoxPlot/set.XData', ...
                'the x-data' )
            nX = numel( proposedXData );
            nY = numel( obj.YData_ );
            if nX >= nY
                % Pad.
                obj.YData_(end+1:nX) = NaN;
            else
                % Truncate.
                obj.YData_(nX+1:end) = [];
            end % if
            % Set the internal data property.
            obj.XData_ = proposedXData(:);
            
            % Adjust the size and color data if necessary.
            nC = size( obj.CData, 1 );
            if nC > 1 && nX ~= nC
                obj.CData = obj.ScatterAxes.ColorOrder(1, :);                
            end % if
            nS = numel( obj.SizeData );
            if nS > 1 && nX ~= nS
                obj.SizeData = 36;
            end % if
            
            % Update the chart.
            update( obj );
            
        end % set.XData
        
        function y = get.YData( obj )
            y = obj.YData_;
        end % get.YData
        
        function set.YData( obj, proposedYData )
            
            % Check the given input.
            validateattributes( proposedYData, {'double'}, ...
                {'real', 'vector'}, 'ScatterBoxPlot/set.YData', ...
                'the y-data' )
            nX = numel( obj.XData_ );
            nY = numel( proposedYData );
            if nY >= nX
                % Pad.
                obj.XData_(end+1:nY) = NaN;
            else
                % Truncate.
                obj.XData_(nY+1:end) = [];
            end % if
            % Set the internal data property.
            obj.YData_ = proposedYData(:);
            
            % Adjust the size and color data if necessary.
            nC = size( obj.CData, 1 );
            if nC > 1 && nY ~= nC
                obj.CData = obj.ScatterAxes.ColorOrder(1, :);                
            end % if
            nS = numel( obj.SizeData );
            if nS > 1 && nY ~= nS
                obj.SizeData = 36;
            end % if
            
            % Update the chart.
            update( obj );
            
        end % set.YData
        
        function xl = get.XLabel( obj )
            xl = obj.ScatterAxes.XLabel;
        end % get.XLabel
        
        function set.XLabel( obj, proposedXLabel )
            obj.ScatterAxes.XLabel = proposedXLabel;
        end % set.XLabel
        
        function yl = get.YLabel( obj )
            yl = obj.ScatterAxes.YLabel;
        end % get.YLabel
        
        function set.YLabel( obj, proposedYLabel )
            obj.ScatterAxes.YLabel = proposedYLabel;
        end % set.YLabel
        
        function t = get.Title( obj )
            t = obj.ScatterAxes.Title;
        end % get.Title
        
        function set.Title( obj, proposedTitle )
            obj.ScatterAxes.Title = proposedTitle;
        end % set.Title
        
        function m = get.Marker( obj )
            m = obj.ScatterSeries.Marker;
        end % get.Marker
        
        function set.Marker( obj, proposedMarker )
            obj.ScatterSeries.Marker = proposedMarker;
        end % set.Marker
        
        function mfc = get.MarkerFaceColor( obj )
            mfc = obj.ScatterSeries.MarkerFaceColor;
        end % get.MarkerFaceColor
        
        function set.MarkerFaceColor( obj, proposedColor )
            obj.ScatterSeries.MarkerFaceColor = proposedColor;
        end % set.MarkerFaceColor
        
        function mec = get.MarkerEdgeColor( obj )
            mec = obj.ScatterSeries.MarkerEdgeColor;
        end % get.MarkerEdgeColor
        
        function set.MarkerEdgeColor( obj, proposedColor )
            obj.ScatterSeries.MarkerEdgeColor = proposedColor;
        end % set.MarkerEdgeColor
        
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
        
        function c = get.BackgroundColor( obj )
            c = obj.Container.BackgroundColor;
        end % get.BackgroundColor
        
        function set.BackgroundColor( obj, proposedColor )
            obj.Container.BackgroundColor = proposedColor;
        end % set.BackgroundColor
        
        function w = get.BoxplotLineWidth( obj )
            if isempty( obj.XBoxPlotGraphics )
                w = 1.5;
            else
                w = get( obj.XBoxPlotGraphics(1), 'LineWidth' );
            end % if
        end % get.BoxplotLineWidth
        
        function set.BoxplotLineWidth( obj, proposedWidth )
            set( obj.XBoxPlotGraphics, 'LineWidth', proposedWidth )
            set( obj.YBoxPlotGraphics, 'LineWidth', proposedWidth )
        end % set.BoxplotLineWidth
        
    end % methods
    
    methods ( Access = private )
        
        function update( obj )
            
            % Update the scatter series.
            set( obj.ScatterSeries, 'XData', obj.XData_, ...
                'YData', obj.YData_ )                
            
            % Redraw the boxplots, deleting the old ones if necessary.
            if ~isempty( obj.XBoxPlotGraphics )
                delete( obj.XBoxPlotGraphics )
            end % if
            obj.XBoxPlotGraphics = boxplot( obj.XBoxPlotAxes, ...
                obj.XData_, 'Orientation', 'horizontal' );
            
            if ~isempty( obj.YBoxPlotGraphics )
                delete( obj.YBoxPlotGraphics )
            end % if            
            obj.YBoxPlotGraphics = boxplot( obj.YBoxPlotAxes, ...
                obj.YData_ );            
            
            % Refresh the newly-created graphics. First, switch off both
            % sets of boxplot axes and disable mouse clicks.
            set( obj.YBoxPlotAxes, 'Visible', 'off', ...                
                'HitTest', 'off' )
            set( obj.XBoxPlotAxes, 'Visible', 'off', ...                
                'HitTest', 'off' )
            
            % Increase the line width of the boxplot graphics, and increase
            % the length of the boxes and adjacent value lines.
            w = 1.5;
            
            % Whiskers.
            set( obj.YBoxPlotGraphics(1:2), 'LineWidth', w )
            set( obj.XBoxPlotGraphics(1:2), 'LineWidth', w )
            
            % Adjacent value lines.
            x = get( obj.YBoxPlotGraphics(3), 'XData' );
            d = diff( x );
            set( obj.YBoxPlotGraphics(3:4), ...
                'XData', [x(1)-2*d, x(2)+2*d], ...
                'LineWidth', w )
            
            y = get( obj.XBoxPlotGraphics(3), 'YData');
            d = diff(y);
            set( obj.XBoxPlotGraphics(3:4), ...
                'YData', [y(1)-2*d, y(2)+2*d], ...
                'LineWidth', w)
            
            % Boxes.
            x = get( obj.YBoxPlotGraphics(5), 'XData' );
            d = x(3) - x(2);
            set( obj.YBoxPlotGraphics(5), ...
                'XData', [x(1:2)-2*d, x(3:4)+2*d, x(5)-2*d], ...
                'LineWidth', w )
            y = get( obj.XBoxPlotGraphics(5), 'YData' );
            d = y(3)-y(2);
            set( obj.XBoxPlotGraphics(5), ...
                'YData', [y(1:2)-2*d, y(3:4)+2*d, y(5)-2*d], ...
                'LineWidth', w )
            
            % Median lines.
            x = get( obj.YBoxPlotGraphics(6), 'XData' );
            d = diff( x );
            set( obj.YBoxPlotGraphics(6), ...
                'XData', [x(1)-2*d, x(2)+2*d], ...
                'LineWidth', w )
            y = get( obj.XBoxPlotGraphics(6), 'YData' );
            d = diff( y );
            set( obj.XBoxPlotGraphics(6), ...
                'YData', [y(1)-2*d, y(2)+2*d], ...
                'LineWidth', w )
            
        end % update
        
        function onContainerDeleted( obj, ~, ~ )
            
            delete( obj );
            
        end % onContainerDeleted
        
        function onXLimChanged( obj, ~, ~ )
            
            obj.XBoxPlotAxes.XLim = obj.ScatterAxes.XLim;
            
        end % onXLimChanged
        
        function onYLimChanged( obj, ~, ~ )
            
            obj.YBoxPlotAxes.YLim = obj.ScatterAxes.YLim;
            
        end % onYLimChanged
        
    end % methods ( Access = private )
    
end % class definition