classdef CircularNetFlow < Chart
    %CIRCULARNETFLOW Illustrates the directed to/from relationships between
    %pairs of categories.
    %
    % Copyright 2018 The MathWorks, Inc.
    
    properties ( Hidden, Constant )
        % Product dependencies.
        Dependencies = {'MATLAB'};
    end % properties ( Hidden, Constant )
    
    % Public interface properties.
    properties ( Dependent )
        % Chart data table.
        LinkData
        % Axes title.
        Title
        % Transparency of the link patches.
        FaceAlpha
        % Offset for the outer labels.
        OuterLabelOffset
    end % properties ( Dependent )
    
    properties ( Dependent, SetAccess = private )
        % Derived net flow, presented as a table.
        NetFlow
        % Net amounts sent.
        NetSent
        % Net amounts received.
        NetReceived
        % Chart data labels.
        Labels
    end % properties ( Dependent, SetAccess = private )
    
    % Internal data properties.
    properties ( Dependent, Access = private )
        % Number of sources/sinks.
        NumSources
        % Row/column indices and values of the positive net flow.
        PositiveNetFlow
        % List of colors used for the various graphics objects.
        Colors
        % Colormap used for the patch objects.
        PatchColormap
        % Angular positions of the arc endpoints, measured in radians
        % anticlockwise from the easterly direction.
        AngularPositions
        % Sizes of the interior, receiving nodes. These are proportional to
        % the total amount received by each node.
        NodeSizes
        % Angular positions of the nodes.
        NodePositions
    end % properties ( Dependent, Access = private )
    
    % Internal graphics and data properties.
    properties ( Access = private )
        % Backing property for the chart data table.
        LinkData_  = table.empty( [0, 0] );
        % Outer radius.
        OuterRadius = 100;
        % Inner radius.
        InnerRadius = 30;
        % Scale factor for the inner node sizes.
        NodeScaleFactor = 200;
        % Number of transition points for interpolated patch shading.
        NumTransitionPoints = 100;
        % Angular gap size between the outer circular arcs.
        AngularGap = pi / 400;
        % Offset for the circumferential patch labels.
        PatchLabelOffset = 10;
        % Patch label font size.
        PatchLabelFontSize = 0.03;
        % Backing property for the outer label offset.
        OuterLabelOffset_ = 35;
        % Outer label font size.
        OuterLabelFontSize = 0.04;
        % Circumferential arcs.
        Arcs
        % Receiving nodes in the interior of the disk.
        ReceivingNodes
        % Link patches.
        LinkPatches
        % Link patch text labels.
        PatchLabels
        % Outer labels for each source.
        OuterLabels
        % Inner labels for each node.
        NodeLabels
    end % properties ( Access = private )
    
    methods
        
        function obj = CircularNetFlow( varargin )            
            
            % Set the chart properties.
            if ~isempty( varargin )
                set( obj, varargin{:} );
            end % if
            
        end % constructor
        
        function d = get.LinkData( obj )
            d = obj.LinkData_;
        end % get.LinkData
        
        function set.LinkData( obj, linkdata )
            
            % Check the proposed chart data.
            validateattributes( linkdata, {'table'}, {'square', 'nonempty'}, ...
                'CircularNetFlow', 'the link data table', 2 )
            try
                A = linkdata{:, :};
            catch MExc
                M = MException( MExc.identifier, ...
                    'Table data cannot be concatenated into a matrix.' );
                throw( M );
            end % try/catch
            
            validateattributes( A, {'double'}, ...
                {'real', 'square', 'finite', 'nonnegative'}, ...
                'CircularNetFlow', 'the link data matrix' )
            d = diag( A );
            if any( d )
                error( 'CircularNetFlow:InvalidLinkData', ...
                    'Diagonal elements of the link data must be zero.' )
            end % if
            
            % Set the internal data property.
            obj.LinkData_ = linkdata;
            
            % Update the chart.
            update( obj );
            
        end % set.LinkData
        
        function labels = get.Labels( obj )
            labels = obj.LinkData_.Properties.VariableNames;
        end % get.Labels        
        
        function t = get.Title( obj )
            t = obj.Axes.Title;
        end % get.Title
        
        function set.Title( obj, proposedTitle )
            obj.Axes.Title = proposedTitle;
        end % set.Title
        
        function fa = get.FaceAlpha( obj )
            fa = obj.LinkPatches(1).FaceAlpha;
        end % get.FaceAlpha
        
        function set.FaceAlpha( obj, proposedAlpha )
            set( obj.LinkPatches, 'FaceAlpha', proposedAlpha )
        end % set.FaceAlpha
        
        function offset = get.OuterLabelOffset( obj )
            offset = obj.OuterLabelOffset_;
        end % get.OuterLabelOffset
        
        function set.OuterLabelOffset( obj, proposedOffset )
            
            % Check the proposed value.
            validateattributes( proposedOffset, {'double'}, ...
                {'scalar', 'real', 'finite', 'positive', 'scalar'}, ...
                'CircularNetFlow/set.OuterLabelOffset', ...
                'the outer label offset' )
            % Update the internal property.
            obj.OuterLabelOffset_ = proposedOffset;
            % Reposition the outer labels.
            [outerLabelX, outerLabelY] = pol2cart( obj.NodePositions, ...
                obj.OuterRadius + obj.OuterLabelOffset );
            for k = 1 : obj.NumSources
                set( obj.OuterLabels(k), 'Position', ...
                    [outerLabelX(k), outerLabelY(k), 0] )
            end % for
            
        end % set.OuterLabelOffset
        
        function nf = get.NetFlow( obj )
            
            % Compute the net flow from each source (row) to every sink
            % (column). The set of sources is the same as the set of sinks.
            d = obj.LinkData{:, :};
            flowFromSource = tril( d );
            flowFromSink = triu( d );
            % Compute the net flow, as an upper triangular matrix.
            netflow = flowFromSink - flowFromSource.';
            % Ensure the net flow matrix is skew-symmetric, i.e., populate
            % the lower triangular part.
            netflow = netflow - triu( netflow ).';
            % Tabulate the result.
            nf = array2table( netflow, 'VariableNames', obj.Labels, ...
                'RowNames', obj.Labels );
            
        end % get.NetFlow
        
        function ns = get.NetSent( obj )
            
            % Sum the positive values in each row.
            nf = obj.NetFlow{:, :};
            nf(nf < 0) = 0;
            ns = sum( nf, 2 );
            
        end % get.NetSent
        
        function nr = get.NetReceived( obj )
            
            % Sum the positive values in each column, returning the results
            % as a column vector.
            nf = obj.NetFlow{:, :};
            nf(nf < 0) = 0;
            nr = sum( nf ).';
            
        end % get.NetReceived
        
        function n = get.NumSources( obj )
            
            n = size( obj.LinkData, 1 );
            
        end % get.NumSources
        
        function pnf = get.PositiveNetFlow( obj )
            
            % Return a three-column matrix containing the row and column
            % indices of the positive net flow values (1st and 2nd
            % columns), together with the positive net flow values.
            nf = obj.NetFlow{:, :};
            posIdx = nf > 0;
            [pnf(:, 1), pnf(:, 2)] = find( posIdx );
            pnf(:, 3) = nf(posIdx);
            
        end % get.PositiveNetFlow
        
        function c = get.Colors( obj )
            
            % Default list of colors used for plotting.
            c = obj.Axes.ColorOrder;
            % Interpolate this list to produce the required number of
            % colors.
            colIdx = 1 : size(c, 1);
            colQueryIdx = linspace( 1, colIdx(end), obj.NumSources );
            c = interp1( colIdx, c, colQueryIdx );
            
        end % get.Colors
        
        function cmap = get.PatchColormap( obj )
            
            % Preallocate for the patch colormap. The number of patches is
            % equal to the number of positive net flow values. Each patch
            % contributes NumTransitionPoints rows to the overall patch
            % colormap.
            N = obj.NumTransitionPoints;
            numPosFlow = size( obj.PositiveNetFlow, 1 );
            cmap = NaN( N * numPosFlow, 3 );
            for k = 1 : numPosFlow
                % For each patch, create a smooth transition from the
                % source color to the sink color. Vertically concatenate
                % the results in the overall patch colormap.
                sourceColor = obj.Colors( obj.PositiveNetFlow(k, 1), : );
                sinkColor = obj.Colors( obj.PositiveNetFlow(k, 2), : );
                transitionMap = ...
                    [linspace(sourceColor(1), sinkColor(1), N).', ...
                    linspace(sourceColor(2), sinkColor(2), N).', ...
                    linspace(sourceColor(3), sinkColor(3), N).'];
                cmap((N * (k-1) + 1) : N * k, :) = transitionMap;
            end % for
            
        end % get.PatchColormap
        
        function a = get.AngularPositions( obj )
            
            % Convert the cumulative net sent amounts to radians.
            cumulativeSourceFlows = cumsum( [0; obj.NetSent] );
            a = 2 * pi * cumulativeSourceFlows / ...
                cumulativeSourceFlows(end);
            
        end % get.AngularSizes
        
        function s = get.NodeSizes( obj )
            
            % Scale the net amounts received by each sink.
            s = obj.NodeScaleFactor * ...
                obj.NetReceived / sum( obj.NetReceived );
            
        end % get.NodeSizes
        
        function a = get.NodePositions( obj )
            
            % The angular node positions are the midpoints of the angular
            % arc positions.
            a = (obj.AngularPositions(1:end-1) + ...
                obj.AngularPositions(2:end)) / 2;
            
        end % get.NodePositions
        
    end % methods
    
    methods ( Access = private )
        
        function update( obj )
            
            % Create the chart graphics.
            % First, draw the circumferential arcs.
            for k = obj.NumSources : -1 : 1
                theta(:, k) = ...
                    linspace( obj.AngularPositions(k) + obj.AngularGap, ...
                    obj.AngularPositions(k+1) - obj.AngularGap );
            end % for
            rho = obj.OuterRadius * ones( size( theta ) );
            [X, Y] = pol2cart( theta, rho );
            obj.Arcs = gobjects( obj.NumSources, 1 );
            for k = 1 : obj.NumSources
                obj.Arcs(k) = line( 'Parent', obj.Axes, ...
                    'XData', X(:, k), ...
                    'YData', Y(:, k), ...
                    'LineWidth', 10, ...
                    'Color', obj.Colors(k, :) );
            end % for
            
            % Next, draw the receiving nodes in the interior of the disk.
            [nodeX, nodeY] = pol2cart( obj.NodePositions, obj.InnerRadius );
            obj.ReceivingNodes = gobjects( obj.NumSources, 1 );
            for k = 1 : obj.NumSources
                obj.ReceivingNodes(k) = line( 'Parent', obj.Axes, ...
                    'XData', nodeX(k), ...
                    'YData', nodeY(k), ...
                    'Marker', 'o', ...
                    'MarkerEdgeColor', obj.Colors(k, :), ...
                    'MarkerFaceColor', obj.Colors(k, :), ...
                    'MarkerSize', obj.NodeSizes(k) );
            end % for
            
            % Draw the patches and their labels. To create the color
            % transitions for each patch, we need to set the axes colormap.
            colormap( obj.Axes, obj.PatchColormap );
            % Compute the angular differences, including the gap sizes.
            dtheta = diff( obj.AngularPositions ) - 2 * obj.AngularGap;
            % Compute the angular starting positions.
            thetaStart = obj.AngularPositions(1:end-1) + obj.AngularGap;
            % Extract parameters required for the loop.
            pnf = obj.PositiveNetFlow;
            N = obj.NumTransitionPoints;
            numPosFlow = size( pnf, 1 );
            % Preallocate.
            obj.LinkPatches = gobjects( numPosFlow, 1 );
            obj.PatchLabels = gobjects( numPosFlow, 1 );
            for k = 1 : numPosFlow
                % Compute the proportion of each circumferential arc to
                % use as the base of the patch.
                sourceIdx = pnf(k, 1);
                sinkIdx = pnf(k, 2);
                flowValue = obj.NetFlow{sourceIdx, sinkIdx};
                arcProp = flowValue / obj.NetSent(sourceIdx);
                % Starting and finishing angles for the patch base.
                localThetaStart = thetaStart(sourceIdx);
                thetaEnd = localThetaStart + arcProp * dtheta(sourceIdx);
                % Update the starting angle for the current source.
                thetaStart(sourceIdx) = thetaEnd;
                % Compute the patch coordinates.
                thetaPatch = [linspace( localThetaStart, thetaEnd, N ), ...
                    linspace( thetaEnd, obj.NodePositions(sinkIdx), N ), ...
                    linspace( obj.NodePositions(sinkIdx), ...
                    localThetaStart, N )];
                rhoPatch = [obj.OuterRadius * ones( 1, N ), ...
                    linspace( obj.OuterRadius, obj.InnerRadius, N ), ...
                    linspace( obj.InnerRadius, obj.OuterRadius, N )];
                [X, Y] = pol2cart( thetaPatch, rhoPatch );
                % Compute the current patch color indices into the overall
                % axes colormap.
                colorIdx = [(N * (k-1) + 1) * ones( N, 1 ); ...
                    ((N * (k-1) + 1) : N * k).'; ...
                    (N * k : -1 : (N * (k-1) + 1)).'];
                % Draw the patches.
                obj.LinkPatches(k) = patch( 'Parent', obj.Axes, ...
                    'XData', X, ...
                    'YData', Y, ...
                    'CData', colorIdx, ...
                    'FaceColor', 'interp', ...
                    'EdgeColor', 'interp', ...
                    'LineWidth', 1, ...
                    'FaceAlpha', 0.85 );
                % Compute the coordinates for the patch labels.
                [patchLabelX, patchLabelY] = pol2cart( ...
                    (localThetaStart + thetaEnd)/2, ...
                    obj.OuterRadius + obj.PatchLabelOffset );
                % Construct the text for the patch label, using the
                % color of the sink.
                sinkColor = num2cell( obj.Colors(sinkIdx, :) );
                patchLabelText = ['\', ...
                    sprintf( 'color[rgb]{%f,%f,%f}%g', ...
                    sinkColor{:}, pnf(k, 3) )];
                % Create the patch labels.
                obj.PatchLabels(k) = text( obj.Axes, ...
                    patchLabelX, ...
                    patchLabelY, ...
                    patchLabelText, ...
                    'FontUnits', 'Normalized', ...
                    'FontWeight', 'bold', ...
                    'FontSize', obj.PatchLabelFontSize, ...
                    'VerticalAlignment', 'middle', ...
                    'HorizontalAlignment', 'center', ...
                    'FontName', 'monospaced' );
            end % for
            
            % Create the outer labels.
            [outerLabelX, outerLabelY] = pol2cart( obj.NodePositions, ...
                obj.OuterRadius + obj.OuterLabelOffset );
            obj.OuterLabels = gobjects( obj.NumSources, 1 );
            for k = 1 : obj.NumSources
                % Form the outer label text from the user-provided text
                % label and the net sent amounts.
                s = [obj.Labels{k}, ' (', num2str( obj.NetSent(k) ), ')'];
                c = num2cell( obj.Colors(k, :) );
                formattedLabel = ['\', ...
                    sprintf( 'color[rgb]{%f,%f,%f} %s', c{:}, s )];
                obj.OuterLabels(k) = text( obj.Axes, ...
                    outerLabelX(k), ...
                    outerLabelY(k), ...
                    formattedLabel, ...
                    'FontWeight', 'bold', ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle', ...
                    'FontUnits', 'Normalized', ...
                    'FontSize', obj.OuterLabelFontSize, ...
                    'FontName', 'monospaced' );
            end % for
            
            % Draw the node labels.
            netReceivedText = num2str( obj.NetReceived );
            nodeLabelFontSize = 0.03 + 0.02 * ...
                (obj.NodeSizes - min( obj.NodeSizes )) / ...
                (max( obj.NodeSizes ) - min( obj.NodeSizes ));
            obj.NodeLabels = gobjects( obj.NumSources, 1 );
            for k = 1 : obj.NumSources
                obj.NodeLabels(k) = text( obj.Axes, ...
                    nodeX(k), ...
                    nodeY(k), ...
                    netReceivedText(k, :), ...
                    'FontWeight', 'bold', ...
                    'FontName', 'monospaced', ...
                    'Color', 0.1 * ones( 1, 3 ), ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle', ...
                    'FontUnits', 'Normalized', ...
                    'FontSize', nodeLabelFontSize(k) );
            end % for
            
            % Add the title.
            t = title( obj.Axes, 'Net Flow', ...
                'FontUnits', 'Normalized', ...
                'FontSize', 0.05, ...
                'FontName', 'Century Schoolbook', ...
                'Visible', 'on' );
            t.Position(1) = t.Position(1) - obj.OuterRadius;
            
            % Set the required axes properties.
            obj.Axes.Visible = 'off';
            obj.Axes.DataAspectRatio = [1, 1, 1];
            
            % Ensure all graphics objects are visible.
            p = vertcat( obj.OuterLabels.Position );
            p = [p; obj.Title.Position];
            obj.Axes.XLim = [min( p(:, 1) ), max( p(:, 1) )];
            obj.Axes.YLim = [min( p(:, 2) ), max( p(:, 2) )];    
            
        end % update
        
    end % methods ( Access = private )
    
end % class definition