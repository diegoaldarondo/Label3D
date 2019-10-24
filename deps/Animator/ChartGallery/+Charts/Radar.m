classdef Radar < matlab.mixin.SetGet
    %RADAR Chart displaying a line graph of dependent numeric variables
    %plotted against independent circular data.
    %
    % Copyright 2018 The MathWorks, Inc.
    
    properties ( Hidden, Constant )
        % Product dependencies.
        Dependencies = {'MATLAB'};
    end % properties ( Hidden, Constant )
    
    % Public interface properties.
    properties ( Dependent )
        % Chart parent.
        Parent
        % Chart position.
        Position
        % Chart units.
        Units
        % Chart visibility.
        Visible
        % Chart outer position.
        OuterPosition
        % Chart active position property.
        ActivePositionProperty
        % Chart angular data.
        AngularData
        % Chart radial data.
        RadialData
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
        % Width of the lines.
        LineWidth
        % Angular tick labels.
        AngularTickLabel
        % Radial tick labels.
        RadialTickLabel
        % Marker size.
        MarkerSize
    end % properties ( Dependent )
    
    properties ( Access = private )
        % Backing property for the angular data.
        AngularData_ = double.empty( 0, 1 );
        % Backing property for the radial data.
        RadialData_ = double.empty( 0, 2 );
        % Polar axes.
        Axes
        % Circular line plots.
        Line
        % Chart legend.
        Legend
    end % properties ( Access = private )
    
    methods
        
        function obj = Radar( varargin )
            
            % Create a temporary figure to act as the chart axes' Parent.
            f = figure( 'Visible', 'off' );
            oc = onCleanup( @() delete( f ) );
            
            % Create the polar axes.
            obj.Axes = polaraxes( 'Parent', f );            
            
            % Create the chart graphics.
            obj.Line = polarplot( obj.Axes, NaN, NaN(1, 2), ...
                'Marker', '.', ...
                'MarkerSize', 10, ...
                'LineStyle', '-', ...
                'LineWidth', 1.5 );
            
            % Restore the required axes properties.
            obj.Axes.DeleteFcn = @obj.onAxesDeleted;
            obj.Axes.HandleVisibility = 'on';
            obj.Axes.ThetaZeroLocation = 'top';
            obj.Axes.ThetaAxisUnits = 'radians';
            obj.Axes.ThetaDir = 'clockwise';            
            
            % Create the legend.            
            obj.Legend = legend( obj.Axes, {'', ''} );
            % Remove the chart axes' temporary Parent.
            obj.Parent = [];
                       
            % Set the chart properties.
            if ~isempty( varargin )
                set( obj, varargin{:} );
            end % if
            
        end % constructor
        
        function delete( obj )            
            delete( obj.Axes );            
        end % destructor
        
        % Get/set methods.
        
        function p = get.Parent( obj )
            p = obj.Axes.Parent;
        end % get.Parent
        
        function set.Parent( obj, p )
            obj.Axes.Parent = p;
        end % set.Parent
        
        function pos = get.Position( obj )
            pos = obj.Axes.Position;
        end % get.Position
        
        function set.Position( obj, pos )
            obj.Axes.Position = pos;
        end % set.Position
        
        function u = get.Units( obj )
            u = obj.Axes.Units;
        end % get.Units
        
        function set.Units( obj, u )
            obj.Axes.Units = u;
        end % set.Units
        
        function v = get.Visible( obj )
            v = obj.Axes.Visible;
        end % get.Visible
        
        function set.Visible( obj, v )
            obj.Axes.Visible = v;
            set( obj.Axes.Children, 'Visible', v )
            obj.Axes.Legend.Visible = v;
        end % set.Visible
        
        function opos = get.OuterPosition( obj )
            opos = obj.Axes.OuterPosition;
        end % get.OuterPosition
        
        function set.OuterPosition( obj, pos )
            obj.Axes.OuterPosition = pos;
        end % set.OuterPosition
        
        function a = get.ActivePositionProperty( obj )
            a = obj.Axes.ActivePositionProperty;
        end % get.ActivePositionProperty
        
        function set.ActivePositionProperty( obj, a )
            obj.Axes.ActivePositionProperty = a;
        end % set.ActivePositionProperty            
        
        function theta = get.AngularData( obj )
            theta = obj.AngularData_;
        end % get.AngularData
        
        function set.AngularData( obj, proposedAngularData )
            
            % Validate the input.
            validateattributes( proposedAngularData, {'double'}, ...
                {'real', 'vector', 'nondecreasing'}, ...
                'Radar/set.AngularData', 'the angular data' )
            % Set the internal data property.
            obj.AngularData_ = proposedAngularData;
            % Update the radial data.
            nTheta = numel( proposedAngularData );
            nRadial = size( obj.RadialData_, 1 );
            if nTheta < nRadial
                obj.RadialData_ = obj.RadialData_(1:nTheta, :);
            else
                obj.RadialData_(end+1:nTheta, :) = NaN;
            end % if
            % Update the chart.
            update( obj );
            
        end % set.AngularData
        
        function rho = get.RadialData( obj )
            rho = obj.RadialData_;
        end % get.RadialData
        
        function set.RadialData( obj, proposedRadialData )  
            
            % Validate the input.
            validateattributes( proposedRadialData, {'double'}, ...
                {'real', 'nonempty', '2d', ...
                 'size', [NaN, 2]}, ...
                'Radar/set.RadialData', 'the radial data' )
            % Update the internal data property.
            obj.RadialData_ = proposedRadialData;
            % Update the angular data.
            nTheta = numel( obj.AngularData_ );
            nRadial = size( obj.RadialData_, 1 );
            if nRadial < nTheta
                obj.AngularData_ = obj.AngularData_(1:nRadial);
            else
                obj.AngularData_(end+1:nRadial) = NaN;
            end % if
            % Update the chart.
            update( obj );
            
        end % set.RadialData        
        
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
            assert( iscellstr( proposedLegendText ) && ...
                    numel( proposedLegendText ) == 2, ...
                    'Radar:InvalidLegendText', ...
                    'The legend text must be a 2-element cell array of character vectors.' )
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
        
        function value = get.LegendVisible( obj )
            value = obj.Legend.Visible;
        end % get.LegendVisible
        
        function set.LegendVisible( obj, value )
            obj.Legend.Visible = value;
        end % set.LegendVisible            
        
        function w = get.LineWidth( obj )
            w = obj.Line(1).LineWidth;
        end % get.LineWidth
        
        function set.LineWidth( obj, w )
            set( obj.Line, 'LineWidth', w );
        end % set.LineWidth
        
        function value = get.AngularTickLabel( obj )
            value = obj.Axes.ThetaTickLabel;
        end % get.AngularTickLabel
        
        function set.AngularTickLabel( obj, value )
            obj.Axes.ThetaTickLabel = value;
        end % set.AngularTickLabel
        
        function value = get.RadialTickLabel( obj )
            value = obj.Axes.RTickLabel;
        end % get.RadialTickLabel
        
        function set.RadialTickLabel( obj, value )
            obj.Axes.RTickLabel = value;
        end % set.RadialTickLabel
        
        function value = get.MarkerSize( obj )
            value = obj.Line(1).MarkerSize;
        end % get.MarkerSize
        
        function set.MarkerSize( obj, value )
            set( obj.Line, 'MarkerSize', value );
        end % set.MarkerSize
        
    end % methods
    
    methods ( Access = private )
        
        function update( obj )
            
            % Update the lines.
            x = obj.AngularData_;
            theta = x2theta( x );            
            set( obj.Line(1), 'ThetaData', theta, ...
                'RData', obj.RadialData_(:, 1) );
            set( obj.Line(2), 'ThetaData', theta, ...
                'RData', obj.RadialData_(:, 2) );
            % Update the angular ticks and tick labels.
            nx = numel( x );
            thetaEnd = 2 * pi * (1 - 1 / nx);
            thetaTick = linspace( 0, thetaEnd, nx );            
            thetaTickLabels = min( x ) + (max( x ) - min( x )) * ...
                thetaTick / (2 * pi * (1 - 1 / nx));
            obj.Axes.ThetaTick = thetaTick;
            obj.Axes.ThetaTickLabel = thetaTickLabels;
            
        end % update
        
        function onAxesDeleted( obj, ~, ~ )            
            delete( obj );            
        end % onAxesDeleted
        
    end % methods ( Access = private )
    
    methods ( Static, Access = protected )
        
        function p = extractParent( varargin )
            %EXTRACTPARENT Parses a cell array of name-value pairs to
            %extract the 'Parent' value. If this hasn't been specified,
            %then this function throws an error.
            
            narginchk( 2, Inf );
            names = varargin(1:2:end);
            values = varargin(2:2:end);
            assert( mod( nargin(), 2 ) == 0 && ...
                iscellstr( names ), ...
                'ChartConstructor:NotNameValuePairs', ...
                'You must specify name-value pairs when creating the chart.' )            
            [parentSpecified, parentIdx] = ismember( 'Parent', names );
            assert( parentSpecified, ...
                'ChartConstructor:MissingParent', ...
                'You must specify the chart''s Parent property on construction.' )
            p = values{parentIdx};

        end % extractParent
        
    end % methods ( Static, Access = protected )    
    
end % class definition

function theta = x2theta( x )
%X2THETA Convert an increasing x-data vector to the corresponding angular 
%values in radians.

nx = numel( x );
theta = (2 * pi * (1 - 1 / nx))* (x - min( x )) / (max( x ) - min( x ));

end % x2theta