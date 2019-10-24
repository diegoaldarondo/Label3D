classdef SnailTrail < Chart
    %SNAILTRAIL Chart for displaying excess return against tracking error
    %for a given asset return series relative to a given benchmark return
    %series.
    %
    % Copyright 2018 The MathWorks, Inc.
    
    properties ( Hidden, Constant )
        % Product dependencies.
        Dependencies = {'MATLAB'};
    end % properties ( Hidden, Constant )
    
    % Public interface properties.
    properties ( Dependent )
        % Chart data, comprising a table with three variables: Dates,
        % Benchmark and Asset. The latter two are return series.
        Returns
        % Axes x-label.
        XLabel
        % Axes y-label.
        YLabel
        % Axes title.
        Title
        % Number of points in the trail, including the head.
        TrailLength
        % Index of the snail's current position.
        CurrentIndex
        % Current date.
        CurrentDate
        % Number of observations used for the window size in the rolling
        % excess return and tracking error computation.
        Period
    end % properties ( Dependent )
    
    properties ( Dependent, SetAccess = private )
        % Performance statistics. This is a table comprising a datetime
        % vector of end dates for the rolling periods, and three double 
        % vectors containing the excess return, tracking error and 
        % information ratio for each period.
        PerformanceStatistics
    end % properties ( Dependent, SetAccess = private )
    
    properties ( Access = private )
        % Backing property for the chart data.
        Returns_
        % Backing property for the trail length.
        TrailLength_ = 5;
        % Backing property for the current index.
        CurrentIndex_ = 1;
        % Backing property for the period.
        Period_ = 5;
        % 2D scatter series for the excess return vs. tracking error.
        ScatterSeries
        % Line object for the snail head.
        Head
        % Line object for the trail.
        Trail
        % Line objects for the axes crosshair.
        CrossHair
        % Information ratio colorbar.
        Colorbar
        % Text box for the performance statistics.
        TextBox
    end % properties ( Access = private )
    
    methods
        
        function obj = SnailTrail( varargin )
            
            % Create a temporary figure to act as the chart axes' Parent.
            f = figure( 'Visible', 'off' );
            oc = onCleanup( @() delete( f ) );
            
            % Parent the chart's axes.
            obj.Parent = f;
            
            % Create the chart graphics.
            obj.ScatterSeries = scatter( obj.Axes, [], [], 12, [], ...
                'o', 'filled' );
            % Restore the DeleteFcn (changed by the scatter function).            
            obj.Axes.DeleteFcn = @obj.onAxesDeleted;            
            % Create the trail.
            obj.Trail = line( 'Parent', obj.Axes, ...
                'XData', [], ...
                'YData', [], ...
                'Color', [0.8, 0, 0], ...
                'Marker', '.', ...
                'MarkerSize', 12, ...
                'LineWidth', 1.5 );
            % Create the head.
            obj.Head = line( 'Parent', obj.Axes, ...
                'XData', [], ...
                'YData', [], ...                
                'Marker', 's', ...
                'MarkerEdgeColor', 'k', ...
                'MarkerFaceColor', 'm' );
            % Draw the crosshair to create the appearance of four
            % quadrants.
            obj.CrossHair = gobjects( 2, 1 );
            obj.CrossHair(1) = line( 'Parent', obj.Axes, ...
                'XData', [NaN, NaN], ...
                'YData', [0, 0], ...
                'Color', 'k', ...
                'LineWidth', 2.5 );
            obj.CrossHair(2) = line( 'Parent', obj.Axes, ...
                'XData', [0, 0], ...
                'YData', [NaN, NaN], ...
                'Color', 'k', ...
                'LineWidth', 2.5 );
            % Axes customizations.
            obj.Axes.XGrid = 'on';
            obj.Axes.YGrid = 'on';
            obj.Axes.Color = [0.95, 0.95, 0.95];
            
            % Create the colorbar.
            obj.Colorbar = colorbar( 'Peer', obj.Axes );
            obj.Colorbar.Label.String = 'Information ratio';
            
            % Create the text box.
            obj.TextBox = text( NaN, NaN, '', ...
                'Parent', obj.Axes );      
            
            % Remove the chart axes' temporary Parent.
            obj.Axes.Parent = [];
            
            % Set the chart properties.
            if ~isempty( varargin )
                set( obj, varargin{:} );
            end % if
            
        end % constructor
        
        function d = get.Returns( obj )
            d = obj.Returns_;
        end % get.Returns
        
        function set.Returns( obj, proposedData )
           
            % Validate the given input data. First, we check that we have a
            % table with three columns.
            validateattributes( proposedData, {'table'}, ...
                {'nonempty', 'size', [NaN, 3]}, 'SnailTrail', ...
                'the asset and benchmark data table' )
            if height( proposedData ) < 10
                error( 'SnailTrail:InvalidData', ...
                    'At least 10 observations are required.' )
            end % if
            % Check the table variables.
            d = proposedData.(1);
            validateattributes( d, {'datetime'}, {}, ...
                'SnailTrail', 'the dates' )
            if ~issorted( d )
                error( 'SnailTrail:InvalidDates', ...
                    'Dates must be in increasing order.' )
            end % if
            r = [proposedData.(2), proposedData.(3)];
            validateattributes( r, {'double'}, {'real', 'finite'}, ...
                'SnailTrail', 'the asset and benchmark series' )
            % Assign the data.
            obj.Returns_ = proposedData;
            
            % Update the chart.
            update( obj );
            
            % Reset the trail            
            reset( obj );
            
        end % set.Data
        
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
        
        function tl = get.TrailLength( obj )
            tl = obj.TrailLength_;
        end % get.TrailLength
        
        function set.TrailLength( obj, proposedLength )
            % Check the proposed trail length.
            validateattributes( proposedLength, {'double'}, ...
                {'real', 'finite', 'integer', 'positive', '<=', ...
                height( obj.PerformanceStatistics )}, ...
                'SnailTrail/set.TrailLength', 'the trail length' )
            % Set the internal property.
            obj.TrailLength_ = proposedLength;
            % Update the chart.
            update( obj );
        end % set.TrailLength
        
        function ad = get.CurrentIndex( obj )
            ad = obj.CurrentIndex_;
        end % get.CurrentIndex
        
        function set.CurrentIndex( obj, proposedIndex )
            % Check the proposed index.
            validateattributes( proposedIndex, {'double'}, ...
                {'scalar', 'real', 'finite', 'integer', 'positive', ...
                '<=', height( obj.PerformanceStatistics )}, ...
                'SnailTrail', 'the current index' )
            % Set the internal property.
            obj.CurrentIndex_ = proposedIndex;
            % Update the chart.
            update( obj );
        end % set.CurrentIndex
        
        function d = get.CurrentDate( obj )
            idx = obj.CurrentIndex_;
            d = obj.PerformanceStatistics.PeriodEndDate(idx);            
        end % get.CurrentDate
        
        function set.CurrentDate( obj, proposedDate )
            % Validate the new date.
            validateattributes( proposedDate, {'datetime'}, {'scalar'} )
            [dateInRange, idx] = ismember( proposedDate, ...
                obj.PerformanceStatistics.PeriodEndDate );            
            if ~dateInRange
                error('SnailTrail:InvalidCurrentDate', ...
                    'The current date must be chosen from the available period end dates.')
            end % if
            % Update the current index.
            obj.CurrentIndex = idx;
        end % set.CurrentDate
        
        
        function p = get.Period( obj )
            p = obj.Period_;
        end % get.Period
        
        function set.Period( obj, proposedPeriod )
            % Check the proposed period.
            validateattributes( proposedPeriod, {'double'}, ...
                {'scalar', 'real', 'finite', 'integer', 'positive', ...
                '<=', round( 0.25 * height( obj.Returns_ ) )}, ...
                'SnailTrail/set.Period', 'the period' )
            % Set the internal property.
            obj.Period_ = proposedPeriod;
            % Update the chart.
            update( obj );
        end % set.Period
        
        function ps = get.PerformanceStatistics( obj )
            % Period end dates.
            d = obj.Returns_.(1);
            d = d(obj.Period_:end);
            % Window size.
            n = obj.Period_;
            % Asset and benchmark.
            benchmark = obj.Returns_.(2);
            asset = obj.Returns_.(3);
            % Rolling mean difference.
            for k = height( obj.Returns_ ) : -1 : n
                er(k-n+1, 1) = mean( asset(k-n+1:k) - benchmark(k-n+1:k) );
            end % for
            % Rolling std difference.
            for k = height( obj.Returns_ ) : -1 : n
                te(k-n+1, 1) = std( asset(k-n+1:k) - benchmark(k-n+1:k) );
            end % for
            % Information ratio.
            ir = er ./ te;
            % Tabulate the results.
            ps = table( d, er, te, ir, 'VariableNames', ...
                {'PeriodEndDate', 'ExcessReturn', 'TrackingError', ...
                'InformationRatio'} );
        end % get.PerformanceStatistics
        
        function step( obj, numSteps )
            % Validate the number of steps.
            if nargin < 2
                numSteps = 1;
            else
                narginchk( 2, 2 )
                validateattributes( numSteps, {'double'}, ...
                    {'real', 'finite', 'scalar', 'integer'}, ...                    
                    'step', 'the number of steps' )
            end % if
            % Saturate if the number of steps is too large or too small.
            if numSteps >= 0
                obj.CurrentIndex = min( obj.CurrentIndex_ + numSteps, ...
                    height( obj.PerformanceStatistics ) );
            else
                obj.CurrentIndex = max( 1, obj.CurrentIndex_ + numSteps );
            end % if
        end % step
        
        function reset( obj )            
            obj.CurrentIndex = 1;            
        end % reset
        
        function animate( obj )
            for k = 1 : height( obj.PerformanceStatistics )
                obj.CurrentIndex = k;
                drawnow();
            end % for            
        end % animate
        
    end % methods
    
    methods ( Access = private )
        
        function update( obj )
            % Refresh the chart graphics on construction or in response to
            % data changes.
            
            % Reset the cross hairs.
            set( obj.CrossHair(1), 'XData', [NaN, NaN] )
            set( obj.CrossHair(2), 'YData', [NaN, NaN] )
            
            % Scatter series.
            set( obj.ScatterSeries, ...
                'XData', obj.PerformanceStatistics.TrackingError, ...
                'YData', obj.PerformanceStatistics.ExcessReturn, ...
                'CData', obj.PerformanceStatistics.InformationRatio )
            % Trail.
            p = obj.CurrentIndex_;
            t = obj.TrailLength_;
            if p >= t
                set( obj.Trail, ...
                    'XData', ...
                    obj.PerformanceStatistics.TrackingError(p-t+1:p), ...
                    'YData', ...
                    obj.PerformanceStatistics.ExcessReturn(p-t+1:p) )
            else
                set( obj.Trail, 'XData', ...
                    obj.PerformanceStatistics.TrackingError(1:p), ...
                    'YData', ...
                    obj.PerformanceStatistics.ExcessReturn(1:p) )
            end % if
            % Head.
            set( obj.Head, 'XData', ...
                obj.PerformanceStatistics.TrackingError(p), ...
                'YData', ...
                obj.PerformanceStatistics.ExcessReturn(p) )            
            
            % Update the text box.
            x = obj.Axes.XLim(1) + 0.005;
            y = obj.Axes.YLim(2) - 0.10 * diff( obj.Axes.YLim );
            d = obj.CurrentDate;
            idx = obj.CurrentIndex_;
            er = obj.PerformanceStatistics.ExcessReturn(idx);
            te = obj.PerformanceStatistics.TrackingError(idx);
            ir = obj.PerformanceStatistics.InformationRatio(idx);
            set( obj.TextBox, 'Position', [x, y, 0], ...
                'String', {['Date: ', char( d )], ...
                ['Excess return: ', num2str( er )], ...
                ['Tracking error: ', num2str( te )], ...
                ['Information ratio: ', num2str( ir )] } )
            
            % Update the cross hairs.
            obj.CrossHair(1).XData = obj.Axes.XLim;            
            obj.CrossHair(2).YData = obj.Axes.YLim;
            
        end % update        
        
    end % methods ( Access = private )
    
end % class definition