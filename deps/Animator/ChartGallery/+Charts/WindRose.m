classdef WindRose < Chart
    %WINDROSE Chart for displaying speed and direction data on an angular
    %(polar) histogram.
    %
    % Copyright 2018 The MathWorks, Inc.
    
    properties ( Hidden, Constant )
        % Product dependencies.
        Dependencies = {'MATLAB'};
    end % properties ( Hidden, Constant )
    
    % Public interface properties.
    properties ( Dependent )
        % Wind direction and speed data table.
        WindData
        % Chart title.
        Title
        % Color of the concentric circles and angular rays.
        TraceColor
        % Width of the concentric circles and angular rays.
        TraceLineWidth
        % Legend title.
        LegendTitle
        % Legend text font size.
        LegendFontSize
        % Legend units.
        LegendUnits
        % Legend position.
        LegendPosition
        % Direction label font size.
        DirectionLabelFontSize
        % Direction label font weight.
        DirectionLabelFontWeight
        % Speed intensity colormap.
        Colormap
    end % properties ( Dependent )
    
    % Internal chart data properties.
    properties ( Access = private )
        % Backing property for the chart data.
        WindData_ = Charts.WindRose.setInitialWindData();
        % Backing property for the colormap.
        Colormap_ = parula;
    end % properties ( Access = private )
    
    % Internal chart graphics-related properties.
    properties ( Access = private )
        % Patch objects for the angular histogram bars.
        HistogramPatches
        % Concentric circles for the chart backdrop used to indicate speed.
        BackdropCircles
        % Angular rays for the chart backdrop used to indicate direction.
        BackdropRays
        % Axes legend.
        Legend
        % Text labels indicating the wind directions.
        DirectionLabels
        % Text labels indicating the radial percentages.
        RadialLabels
        % Standard angles for the backdrop rays.
        RayAngles = 0 : 22.5 : 360;
        % Lower edges for the direction bins.
        DirectionLowerEdges = [355, 5 : 10 : 345];
        % Upper edges for the direction bins.
        DirectionUpperEdges = [5, 15 : 10 : 355];
        % Direction bin centers.
        DirectionBinCenters = 0 : 10 : 350;
        % Number of concentric circles.
        NumCircles = 10;
        % Direction label text.
        DirectionLabelText = {'E', 'ENE', 'NE', 'NNE', ...
            'N', 'NNW', 'NW', 'WNW', ...
            'W', 'WSW', 'SW', 'SSW', ...
            'S', 'SSE', 'SE', 'ESE'};
    end % properties ( Access = private )
    
    properties ( Dependent, SetAccess = private )
        % Speed and direction observation counts, partitioned by the speed
        % and direction bins.
        ObservationCounts
        % Cumulative counts, computed as percentages.
        CumulativePercentageObservationCounts
        % Minimum backdrop circle radius.
        MinRadius
        % Maximum backdrop circle radius.
        MaxRadius
    end % properties ( Dependent, SetAccess = private )
    
    properties ( Dependent, Access = private )
        % Bin edges for the speed data.
        SpeedBinEdges
    end % properties ( Dependent, Access = private )
    
    methods
        
        % Constructor method for the chart.
        function obj = WindRose( varargin )            
             
            % Create the chart backdrop. This comprises the concentric
            % circles, the angular rays, the radial labels and the
            % direction labels.
            
            % Concentric circles.
            backdropColor = 0.8725 * ones( 1, 3 );
            obj.BackdropCircles = gobjects( obj.NumCircles, 1 );
            for k = 1 : obj.NumCircles
                obj.BackdropCircles(k) = line( 'Parent', obj.Axes, ...
                    'XData', [], ...
                    'YData', [], ...
                    'Color', backdropColor, ...
                    'HandleVisibility', 'off' );
            end % for
            
            % Angular rays.
            nRays = numel( obj.RayAngles );
            obj.BackdropRays = gobjects( nRays, 1 );
            for k = 1 : nRays
                obj.BackdropRays(k, 1) = line( 'Parent', obj.Axes, ...
                    'XData', [], ...
                    'YData', [], ...
                    'Color', backdropColor, ...
                    'HandleVisibility', 'off' );
            end % for
            
            % Create the text boxes containing the radial percentage
            % labels.
            textX = NaN( obj.NumCircles, 1 );
            textY = textX;
            radialText = repmat( {''}, obj.NumCircles, 1 );
            obj.RadialLabels = text( textX, textY, radialText, ...
                'Parent', obj.Axes, ...
                'FontSize', 10, ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle' );
            
            % Create the text boxes containing the direction labels.
            textX = NaN( numel( obj.DirectionLabelText ), 1 );
            textY = textX;
            obj.DirectionLabels = text( textX, textY, ...
                obj.DirectionLabelText, ...
                'Parent', obj.Axes, ...
                'FontSize', 12, ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle' );
            
            % Create the histogram patches comprising the wind rose. Loop
            % over the number of direction bins and the number of speed
            % bins. For each of these, create the patch.
            nDirectionBins = size( obj.ObservationCounts, 1 );
            nSpeedBins = size( obj.ObservationCounts, 2 );
            obj.HistogramPatches = gobjects( nDirectionBins, nSpeedBins );
            for k1 = 1 : nDirectionBins
                for k2 = nSpeedBins : -1 : 1
                    obj.HistogramPatches(k1, k2) = ...
                        patch( 'Parent', obj.Axes, ...
                        'XData', NaN, ...
                        'YData', NaN, ...
                        'EdgeColor', 'k', ...
                        'LineWidth', 1 );
                end % for k2
            end % for k1
            
            % Form legend text entries of the form "a <= v < b" for the
            % appropriate threshold values a and b.
            nSpeed = numel( obj.SpeedBinEdges ) - 1;
            legendText = cell( nSpeed, 1 );
            for k = 1:nSpeed
                s = sprintf( ' %.1f \\leq v < %.1f', ...
                    obj.SpeedBinEdges(k), ...
                    obj.SpeedBinEdges(k+1) );
                legendText{numel( obj.SpeedBinEdges ) - k} = s;
            end % for            
            % Add the legend and set its properties. To do this, we need to
            % temporarily set the chart's Parent.
            f = figure( 'Visible', 'off' );
            oc = onCleanup( @() delete( f ) );
            obj.Parent = f;
            obj.Legend = legend( obj.Axes, legendText, ...
                'FontSize', 12, ...
                'Color', 'none', ...
                'Units', 'Normalized' );                        
            % Set the legend's title.
            obj.Legend.Title.String = 'Wind Speed';
            % Adjust the legend's position.
            legendPos = obj.Legend.Position;
            legendOffset = 0.0005;
            obj.Legend.Position(1:2) = [legendOffset/2, ...
                1-legendOffset-legendPos(4)];            
            % Remove the chart axes' temporary Parent.
            obj.Parent = [];
            
            % Adjust the axes aspect ratio, background color, ticks and
            % rulers.
            set( obj.Axes, 'DataAspectRatio', [1, 1, 1], ...
                'Color', 'none', ...
                'Visible', 'off' );
            % Ensure the title is visible.
            obj.Title.Visible = 'on';            
            
            % Set the chart properties.
            if ~isempty( varargin )
                set( obj, varargin{:} );
            end % if
            
        end % constructor
        
        function obsCounts = get.ObservationCounts( obj )
            % Get method for the speed and direction observation counts. We
            % create a nDir-by-nSpeed matrix, where nDir is the number of
            % direction bins and nSpeed is the number of speed bins. The
            % matrix contains the observation counts partitioned by the
            % wind direction and windspeed. Each row corresponds to an
            % angular direction bin and each column corresponds to a
            % windspeed bin.
            
            % Preallocate.
            nDir = numel( obj.DirectionBinCenters );
            nSpeed = numel( obj.SpeedBinEdges ) - 1;
            obsCounts = zeros( nDir, nSpeed );
            d = obj.WindData_.Direction;
            % Loop over rows to accumulate the observation counts.
            for k = 1:nDir
                if k == 1
                    % The first direction bin is between 355 and 5 degrees,
                    % so requires special logic.
                    dirIdx = (d >= obj.DirectionLowerEdges(k)) | ...
                        (d <  obj.DirectionUpperEdges(k));
                else
                    % Otherwise, we specify direction angles in a
                    % continuous interval.
                    dirIdx = (d >= obj.DirectionLowerEdges(k)) & ...
                        (d < obj.DirectionUpperEdges(k));
                end % if
                % Extract the speeds in the current wind direction
                % interval, count them according to the speed bins, and
                % take the cumulative sum.
                obsCounts(k, :) = ...
                    histcounts( obj.WindData_.Speed(dirIdx), obj.SpeedBinEdges );
            end % for
            
        end % get.ObservationCounts
        
        function cpoc = get.CumulativePercentageObservationCounts( obj )
            cpoc = 100 * cumsum( obj.ObservationCounts, 2 ) / ...
                numel( obj.WindData_.Speed );
        end % get.CumulativePercentageObservationCounts
        
        function r = get.MaxRadius( obj )
            r = ceil( max( ...
                obj.CumulativePercentageObservationCounts(:) ) );
        end % get.MaxRadius
        
        function r = get.MinRadius( obj )
            r = obj.MaxRadius / 50;
        end % get.MinRadius
        
        function speedBinEdges = get.SpeedBinEdges( obj )
            % Create six equally-spaced speed bins.
            upperSpeed = ceil( max( obj.WindData_.Speed ) );
            if isempty( upperSpeed )
                upperSpeed = 0;
            end % if
            speedBinEdges = linspace( 0, upperSpeed, 7 );
        end % get.SpeedBinEdges
        
        function d = get.WindData( obj )
            d = obj.WindData_;
        end % get.WindData
        
        function set.WindData( obj, T )
            % Check the proposed data table.
            validateattributes( T, {'table'}, {'size', [NaN, 2]} )
            vars = T.Properties.VariableNames;
            assert( isequal( sort( vars ), {'Direction', 'Speed'} ), ...
                'WindRose:InvalidWindData', ...
                'The wind data must be specified as a table with two columns (Direction and Speed).' )
            % Check the windspeed and wind direction.
            s = T.Speed;
            d = T.Direction;            
            validateattributes( s, {'double'}, ...
                {'column', 'real', 'finite', 'nonnegative'}, ...                
                'WindRose/set.WindData', 'the windspeed data' )
            validateattributes( d, {'double'}, ...
                {'column', 'real', 'finite', 'nonnegative', ...
                 '<=', 360}, 'WindRose/set.WindData', 'the wind direction data' )
            % Store the new value.
            obj.WindData_ = T;
            % Update the chart.
            update( obj );
        end % set.WindData
        
        function t = get.Title( obj )
            t = obj.Axes.Title;
        end % get.Title
        
        function set.Title( obj, proposedValue )
            obj.Axes.Title = proposedValue;
        end % set.Title
        
        function c = get.TraceColor( obj )
            c = obj.BackdropCircles(1).Color;
        end % get.TraceColor
        
        function set.TraceColor( obj, proposedColor )
            set( obj.BackdropCircles, 'Color', proposedColor )
            set( obj.BackdropRays, 'Color', proposedColor )
        end % set.TraceColor
        
        function w = get.TraceLineWidth( obj )
            w = obj.BackdropCircles(1).LineWidth;
        end % get.TraceWidth
        
        function set.TraceLineWidth( obj, proposedWidth )
            set( obj.BackdropCircles, 'LineWidth', proposedWidth )
            set( obj.BackdropRays, 'Color', proposedWidth )
        end % set.TraceWidth
        
        function t = get.LegendTitle( obj )
            t = obj.Legend.Title;
        end % get.LegendTitle
        
        function set.LegendTitle( obj, proposedTitle )
            obj.Legend.Title = proposedTitle;
        end % set.LegendTitle
        
        function fs = get.LegendFontSize( obj )
            fs = obj.Legend.FontSize;
        end % get.LegendFontSize
        
        function set.LegendFontSize( obj, proposedFontSize )
            obj.Legend.FontSize = proposedFontSize;
        end % set.LegendFontSize
        
        function u = get.LegendUnits( obj )
            u = obj.Legend.Units;
        end % get.LegendLocation
        
        function set.LegendUnits( obj, u )
            obj.Legend.Units = u;
        end % set.LegendUnits
        
        function pos = get.LegendPosition( obj )
            pos = obj.Legend.Position;
        end % get.LegendPosition
        
        function set.LegendPosition( obj, pos )
            obj.Legend.Position = pos;
        end % set.LegendPosition
        
        function fs = get.DirectionLabelFontSize( obj )
            fs = obj.DirectionLabels(1).FontSize;
        end % get.DirectionLabelFontSize
        
        function set.DirectionLabelFontSize( obj, proposedFontSize )
            set( obj.DirectionLabels, 'FontSize', proposedFontSize )
        end % set.DirectionLabelFontSize
        
        function fw = get.DirectionLabelFontWeight( obj )
            fw = obj.DirectionLabels(1).FontWeight;
        end % get.DirectionLabelFontWeight
        
        function set.DirectionLabelFontWeight( obj, proposedFontWeight )
            set( obj.DirectionLabels, 'FontWeight', proposedFontWeight )
        end % set.DirectionLabelFontWeight
        
        function cmap = get.Colormap( obj )
            cmap = obj.Colormap_;
        end % get.Colormap
        
        function set.Colormap( obj, proposedColormap )
            
            % Validate the proposed colormap.
            validateattributes(proposedColormap, {'double'}, ...
                {'real', 'finite', 'size', [NaN, 3], '>=', 0, '<=', 1})
            if size( proposedColormap, 1 ) < numel( obj.SpeedBinEdges )-1
                error('WindRose:InvalidColorMap', ...
                    'Insufficient number of colors specified in colormap.')
            end % if
            % Assign its value.
            obj.Colormap_ = proposedColormap;
            % Extract the colors to be used.
            colorIdx = round( ...
                linspace( 1, size( obj.Colormap, 1 ), ...
                numel( obj.SpeedBinEdges ) - 1 ) );
            patchColors = obj.Colormap(colorIdx, :);
            % Update the patch colors.
            nSpeed = size( obj.HistogramPatches, 2 );
            for k = 1 : nSpeed
                set( obj.HistogramPatches(:, k), ...
                    'FaceColor', patchColors(k, :) );
            end % for k
            
        end % set.Colormap
        
    end % methods
    
    methods ( Access = private )
        
        function update( obj )
            % Update the chart graphics on construction or when the
            % underlying data is changed.
            
            % Update the concentric circles. The radii of the circles are
            % as follows.
            circleRadii = obj.MinRadius + (1 : obj.NumCircles) * ...
                obj.MaxRadius / obj.NumCircles;
            % Create the circle circumferences, using the parametric
            % representation x = r*cos(t), y = r*sin(t) of a circle with
            % radius r centered at the origin (0, 0).
            t = linspace( 0, 2*pi, 500 );
            x = cos( t );
            y = sin( t );
            % Create the matrices of x and y coordinates for all the
            % circles, using matrix multiplication.
            circleX = x.' * circleRadii;
            circleY = y.' * circleRadii;
            % Update the line x and y-data.
            for k = 1 : obj.NumCircles
                set( obj.BackdropCircles(k), 'XData', circleX(:, k), ...
                    'YData', circleY(:, k) );
            end % for
            
            % Update the angular rays. These begin at the inner circle and
            % terminate at the outer border. The order border is the sum of
            % the minimum and maximum radii.
            outerBorder = obj.MaxRadius + obj.MinRadius;
            R = [obj.MinRadius; outerBorder];
            rayX = R * cosd( obj.RayAngles );
            rayY = R * sind( obj.RayAngles );
            for k = 1 : numel( obj.RayAngles )
                set( obj.BackdropRays(k), 'XData', rayX(:, k), ...
                    'YData', rayY(:, k) );
            end % for
            
            % Update the radial text labels. By convention, these are
            % placed on the SE angular ray (315 degrees anticlockwise from
            % the positive horizontal axis).
            [textX, textY] = pol2cart( deg2rad( 315 ), circleRadii );
            radialText = num2str( circleRadii(:), '%.1f%%' );
            for k = 1 : obj.NumCircles
                set( obj.RadialLabels(k), ...
                    'Position', [textX(k), textY(k), 0], ...
                    'String', radialText(k, :) );
            end % for
            
            % Update the direction labels. Their text does not change, but
            % their position may need to change to accommodate new chart
            % data.
            % Define the radius at which to place the direction text.
            textOffset = 0.65;
            textRadius = obj.MaxRadius + textOffset;
            % Cartesian coordinates of the text labels.
            textX = textRadius * cosd( obj.RayAngles(1:end-1) );
            textY = textRadius * sind( obj.RayAngles(1:end-1) );
            for k = 1 : numel( obj.DirectionLabels )
                set( obj.DirectionLabels(k), ...
                    'Position', [textX(k), textY(k), 0] );
            end % for
            
            % Update the patch x and y-data, as well as the face colors
            % used at each speed level.
            % First, obtain equally-spaced indices for the colormap.
            colorIdx = round( ...
                linspace( 1, size( obj.Colormap, 1 ), ...
                numel( obj.SpeedBinEdges ) - 1 ) );
            % Extract the colors to be used.
            patchColors = obj.Colormap(colorIdx, :);
            % Extract the current data counts.
            angularBinSemiWidth = obj.DirectionUpperEdges(1);
            cpoc = obj.CumulativePercentageObservationCounts;
            for k1 = 1 : size( cpoc, 1 )
                for k2 = size( cpoc, 2 ) : -1 : 1
                    % Inner radius.
                    if k2 > 1
                        r(1) = cpoc(k1, k2-1);
                    else
                        r(1) = 0;
                    end % if
                    % Outer radius.
                    r(2) = cpoc(k1, k2);
                    r = r + obj.MinRadius;
                    % Patch x and y coordinates.
                    theta = obj.DirectionBinCenters(k1) + ...
                        linspace( -angularBinSemiWidth, ...
                        angularBinSemiWidth, 200 );
                    patchX = [r(1) * sind( fliplr( theta ) ), ...
                        r(2) * sind( theta )];
                    patchY = [r(1) * cosd( fliplr( theta ) ), ...
                        r(2) * cosd( theta )];
                    set( obj.HistogramPatches(k1, k2), ...
                        'XData', patchX, 'YData', patchY, ...
                        'FaceColor', patchColors(k2, :) )
                end % for k2
            end % for k1            
            
            % Form legend text entries of the form "a <= v < b" for the
            % appropriate threshold values a and b.
            nSpeed = numel( obj.SpeedBinEdges ) - 1;
            legendText = cell( nSpeed, 1 );
            for k = 1:nSpeed
                s = sprintf( ' %.1f \\leq v < %.1f', ...
                    obj.SpeedBinEdges(k), ...
                    obj.SpeedBinEdges(k+1) );
                legendText{numel( obj.SpeedBinEdges ) - k} = s;
            end % for
            % Update the legend text.
            obj.Legend.String = legendText;
            
            % Update the chart axes limits.
            set( obj.Axes, 'XLim', [-outerBorder, outerBorder], ...
                'YLim', [-outerBorder, outerBorder] );
            
        end % update
        
    end % methods ( Access = private )
    
    methods ( Static, Access = private )
        
        function wd = setInitialWindData()
            
            wd = table.empty( 0, 2 );
            wd.Properties.VariableNames = {'Direction', 'Speed'};
            
        end % setInitialWindData           
        
    end % methods ( Static, Access = private )
    
end % classdef