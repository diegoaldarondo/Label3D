classdef Cylinder < Chart
    %CYLINDER Create a stacked cylinder chart.
    %
    % Copyright 2018 The MathWorks, Inc.
    
    properties ( Hidden, Constant )
        % Product dependencies.
        Dependencies = {'MATLAB'};
    end % properties ( Hidden, Constant )
    
    properties ( Dependent )
        % Chart data.
        Data
        % Axes x-label.
        XLabel
        % Axes z-label.
        ZLabel
        % Axes title.
        Title
        % List of face colors used for the cylinders.
        FaceColors
        % Axes view.
        View
        % Axes x-tick labels.
        XTickLabel
    end % properties ( Dependent )
    
    properties ( Dependent, SetAccess = private )
        % Number of cylindrical stacks.
        NumStacks
        % Number of layers within each cylindrical stack.
        NumLayers
    end % properties ( Dependent, SetAccess = private )
    
    properties ( Access = private )
        % Backing property for the chart data.
        Data_
        % Backing property for the cylindrical face colors.
        FaceColors_
        % Surface graphics objects used for the cylinders.
        CylinderSurfaces
    end % properties ( Access = private )
    
    methods
        
        function obj = Cylinder( varargin )            
            
            % Set the required axes properties.
            obj.Axes.XGrid = 'on';
            obj.Axes.YGrid = 'on';
            obj.Axes.ZGrid = 'on';
            obj.Axes.View = [-16, 12];
            obj.Axes.DataAspectRatio(1:2) = [1, 1];
            obj.Axes.YLim = [-2, 4];
            obj.Axes.YTick = [];
            obj.Axes.ZAxis.TickDirection = 'in';
            obj.Axes.ZAxis.TickLength(2) = ...
                3 * obj.Axes.ZAxis.TickLength(2);
            obj.Axes.Color = [0.7, 0.7, 0.7];           
            
            % Set the chart properties.
            if ~isempty( varargin )
                set( obj, varargin{:} );
            end % if
            
        end % constructor
        
        % Get/set methods.
        
        function d = get.Data( obj )
            d = obj.Data_;
        end % get.Data
        
        function set.Data( obj, d )
            
            % Validate the input, assign the internal data property and
            % update the chart.
            validateattributes( d, {'double'}, ...
                {'real', 'finite', '2d', 'nonnegative'}, ...
                'Cylinder/set.Data', 'the data' )
            obj.Data_ = d;
            update( obj );
            
        end % set.Data
        
        function n = get.NumStacks( obj )
            n = size( obj.Data_, 1 );
        end % get.NumStacks
        
        function n = get.NumLayers( obj )
            n = size( obj.Data_, 2 );
        end % get.NumLayers
        
        function xl = get.XLabel( obj )
            xl = obj.Axes.XLabel;
        end % get.XLabel
        
        function set.XLabel( obj, proposedXLabel )
            obj.Axes.XLabel = proposedXLabel;
        end % set.XLabel
        
        function zl = get.ZLabel( obj )
            zl = obj.Axes.ZLabel;
        end % get.ZLabel
        
        function set.ZLabel( obj, proposedZLabel )
            obj.Axes.ZLabel = proposedZLabel;
        end % set.ZLabel
        
        function t = get.Title( obj )
            t = obj.Axes.Title;
        end % get.Title
        
        function set.Title( obj, proposedTitle )
            obj.Axes.Title = proposedTitle;
        end % set.Title
        
        function c = get.FaceColors( obj )
            c = obj.FaceColors_;
        end % get.FaceColors
        
        function set.FaceColors( obj, proposedColors )
            
            % Check the user-supplied list of colors.
            validateattributes( proposedColors, {'double'}, ...
                {'real', '>=', 0, '<=', 1, 'size', [obj.NumLayers, 3]}, ...
                'Cylinder/set.FaceColors', 'the face colors' )
            % Update the face colors of each layer in each stack.
            for k = 1 : obj.NumLayers
                set( obj.CylinderSurfaces(:, k), 'FaceColor', proposedColors(k, :) );
            end % for
            % Update the internal property.
            obj.FaceColors_ = proposedColors;          
            
        end % set.FaceColors
        
        function v = get.View( obj )
            v = obj.Axes.View;
        end % get.View
        
        function set.View( obj, proposedView )
            obj.Axes.View = proposedView;
        end % set.View
        
        function xtl = get.XTickLabel( obj )
            xtl = obj.Axes.XTickLabel;
        end % get.XTickLabel
        
        function set.XTickLabel( obj, proposedLabels )
            obj.Axes.XTickLabel = proposedLabels;
        end % set.XTickLabel
        
    end % methods
    
    methods ( Access = private )
        
        function update( obj )
            
            % First, record the previous number of layers (this is used to 
            % preserve the existing face colors if possible). 
            oldNumLayers = size( obj.CylinderSurfaces, 2 );
            % Similarly, record the previous number of stacks (this is used
            % to preserve the existing tick labels if possible).
            oldNumStacks = size( obj.CylinderSurfaces, 1 );            
            
            % Update the number of surface objects in accordance with the 
            % data. Start by deleting the existing cylinders if they exist.             
            if ~isempty( obj.CylinderSurfaces )
                delete( obj.CylinderSurfaces )
            end % if
            % Preallocate for the new cylinders.
            obj.CylinderSurfaces = gobjects( obj.NumStacks, obj.NumLayers);
            % Determine the face colors: use the previous colors if
            % possible; otherwise, revert to a default set of colors.
            if obj.NumLayers <= oldNumLayers
                obj.FaceColors_ = obj.FaceColors_(1 : obj.NumLayers, :);
            else
                obj.FaceColors_ = cool( obj.NumLayers );
            end % if
            % Create the new cylinders.
            for k1 = 1 : obj.NumStacks
                for k2 = 1 : obj.NumLayers
                    obj.CylinderSurfaces(k1, k2) = surface( obj.Axes, ...
                        [], [], [], 'FaceColor', obj.FaceColors_(k2, :), ...
                        'EdgeAlpha', 0 );
                end % for k2
            end % for k1
            
            % Compute the cylindrical coordinates.
            % Define the number of points used for the cylinder
            % circumferences and the radius of the cylinders.
            n = 1000;
            r = 2 * [1; 1];
            % Cylinder heights above the (x, y) plane.
            heights = [zeros( obj.NumStacks, 1 ), cumsum( obj.Data_, 2 )];
            % Angles from 0 to 2*pi.
            theta = 2 * pi * ( 0 : n ) / n;
            % Compute sin(theta), ensuring the final value is exactly zero.
            sintheta = sin( theta );
            sintheta(n+1) = 0;
            rsintheta = r * sintheta;
            rcostheta = r * cos( theta );
            % Compute the coordinates of the cylinders, and update the
            % surface objects and rings.
            y = 1 + rsintheta;
            for k1 = 1 : obj.NumStacks
                x = 5*k1 + rcostheta;
                for k2 = 1 : obj.NumLayers
                    z = heights(k1, k2:(k2+1)).' * ones( 1, n + 1 );
                    set( obj.CylinderSurfaces(k1, k2), ...
                        'XData', x, 'YData', y, 'ZData', z )
                end % for k2
            end % for k1
            
            % Update the axes settings.
            obj.Axes.XLim = [1, 5 * obj.NumStacks + 4];
            obj.Axes.XTick = 5 * (1 : obj.NumStacks);
            % Reuse the previous tick labels, if possible.
            if obj.NumStacks <= oldNumStacks
                obj.Axes.XTickLabel = obj.XTickLabel(1 : obj.NumStacks);
            else
                obj.Axes.XTickLabel = 1 : obj.NumStacks;
            end % if
            
        end % update
        
    end % methods ( Access = private )
    
end % class definition