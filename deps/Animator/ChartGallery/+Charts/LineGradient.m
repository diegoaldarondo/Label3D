classdef LineGradient < Chart
    %LINEGRADIENT Chart for managing a variable-color curve plotted against
    %a date/time vector.
    %
    % Copyright 2018 The MathWorks, Inc.
    
    properties ( Hidden, Constant )
        % Product dependencies.
        Dependencies = {'MATLAB'};
    end % properties ( Hidden, Constant )
    
    % Public interface properties.
    properties ( Dependent )
        % Chart x-data.
        XData
        % Chart y-data.
        YData
        % Colormap.
        Colormap
        % Axes x-label.
        XLabel
        % Axes y-label.
        YLabel
        % Axes title.
        Title
        % Grid display.
        Grid
        % Width of the line.
        LineWidth
    end % properties ( Dependent )
    
    properties ( Access = private )
        % Backing property for the x-data.
        XData_ = NaT( 2, 1 );
        % Backing property for the y-data.
        YData_ = NaN( 2, 1 );
        % Backing property for the colormap.
        Colormap_ = cool( 500 );
        % Line with a color gradient, implemented internally as a surface.
        Surface
    end % properties ( Access = private )
    
    methods
        
        function obj = LineGradient( varargin )
            
            % Associate the colormap with the chart's axes.
            obj.Colormap = obj.Colormap_;
            % Create the chart graphics.
            obj.Surface = surface( obj.Axes, NaT, NaN, NaN, NaN, ...
                'EdgeColor', 'interp' );
            % Set the (x, y) view for the axes.
            view( obj.Axes, 2 );
            % Set the chart properties.
            if ~isempty( varargin )
                set( obj, varargin{:} );
            end % if
            
        end % constructor
        
        % Get/set methods.
        function x = get.XData( obj )
            x = obj.XData_(1, :).';
        end % get.XData
        
        function set.XData( obj, proposedXData )
            
            % Perform basic validation.
            validateattributes( proposedXData, {'datetime'}, ...
                {'vector'}, 'LineGradient/set.XData', 'the x-data' )
            if ~issorted( proposedXData )
                error( 'LineGradient:DecreasingData', ...
                    'Chart x-data must be nondecreasing.' )
            end % if
            % Decide how to modify the chart data.
            nX = numel( proposedXData );
            nY = numel( obj.YData );
            
            if nX < nY % If the new x-data is too short ...
                % ... then chop the chart y-data.                
                obj.YData_ = obj.YData_(:, 1:nX);
            else
                % Otherwise, if nX >= nY, then pad the y-data.
                obj.YData_(:, end+1:nX) = NaN;
            end % if
            
            % Set the internal x-data.
            obj.XData_ = [proposedXData(:), proposedXData(:)].';
            
            % Update the chart graphics.
            update( obj );
            
        end % set.XData
        
        function y = get.YData( obj )
            y = obj.YData_(1, :).';
        end % get.YData
        
        function set.YData( obj, proposedYData )
            
            % Perform basic validation.
            validateattributes( proposedYData, {'double'}, ...
                {'real', 'vector'}, 'LineGradient/set.YData', 'the y-data' )            
            
            % Decide how to modify the chart data.
            nY = numel( proposedYData );
            nX = numel( obj.XData );
            
            if nY < nX % If the new y-data is too short ...
                % ... then chop the chart x-data.
                obj.XData_ = obj.XData_(:, 1:nY);
            else
                % Otherwise, if nY >= nX, then pad the x-data.
                obj.XData_(:, end+1:nY) = NaT;
            end % if
            
            % Set the internal y-data.
            obj.YData_ = [proposedYData(:), proposedYData(:)].';
            
            % Update the chart graphics.
            update( obj );
            
        end % set.YData
        
        function cmap = get.Colormap( obj )
            cmap = obj.Colormap_;
        end % get.Colormap
        
        function set.Colormap( obj, proposedMap )
            colormap( obj.Axes, proposedMap );
            obj.Colormap_ = proposedMap;            
        end % set.Colormap
        
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
        
        function gridStatus = get.Grid( obj )
            gridStatus = obj.Axes.XGrid;
        end % get.Grid
        
        function set.Grid( obj, proposedGridStatus )
            set( obj.Axes, 'XGrid', proposedGridStatus, ...
                           'YGrid', proposedGridStatus );
        end % set.Grid
        
        function lw = get.LineWidth( obj )
            lw = obj.Surface.LineWidth;
        end % get.LineWidth
        
        function set.LineWidth( obj, proposedLineWidth )
            obj.Surface.LineWidth = proposedLineWidth;
        end % set.LineWidth
        
    end % methods
    
    methods ( Access = private )
        
        function update( obj )
            
            % Update the surface plot with the new data.
            z = zeros( size( obj.XData_ ) );
            set( obj.Surface, 'XData', obj.XData_, ...
                'YData', obj.YData_, ...
                'ZData', z, ...
                'CData', obj.YData_ );
            
        end % update
        
    end % methods ( Access = private )
    
end % class definition