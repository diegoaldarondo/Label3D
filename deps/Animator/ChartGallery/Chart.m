classdef Chart < matlab.mixin.SetGet
    %CHART Base class for concrete chart implementations.
    %
    % Copyright 2018 The MathWorks, Inc.
    
    properties ( Dependent )
        % Chart parent, interpreted as the parent of the underlying axes 
        % peer object.
        Parent
        % Position.
        Position
        % Units.
        Units
        % Outer position.
        OuterPosition
        % Active position property.
        ActivePositionProperty
        % Visibility.
        Visible        
    end % properties ( Dependent )
    
    properties ( Access = protected )
        % Graphics peer to the chart.
        Axes
    end % properties ( Access = protected )
    
    methods
        
        function obj = Chart()
            
            % Create the chart peer axes.
            obj.Axes = axes( 'Parent', [], ...
                             'DeleteFcn', @obj.onAxesDeleted, ...
                             'HandleVisibility', 'on' );            
            
        end % constructor
        
        function delete( obj )
            
            % Delete the axes if the chart is destroyed.
            delete( obj.Axes );
            
        end % destructor
        
        % Get/set methods.
        
        function p = get.Parent( obj )
            p = obj.Axes.Parent;
        end % get.Parent
        
        function set.Parent( obj, proposedParent )
            obj.Axes.Parent = proposedParent;
        end % set.Parent
        
        function pos = get.Position( obj )
            pos = obj.Axes.Position;
        end % get.Position
        
        function set.Position( obj, proposedPosition )
            obj.Axes.Position = proposedPosition;
        end % set.Position
        
        function u = get.Units( obj )
            u = obj.Axes.Units;
        end % get.Units
        
        function set.Units( obj, proposedUnits )
            obj.Axes.Units = proposedUnits;
        end % set.Units
        
        function outPos = get.OuterPosition( obj )
            outPos = obj.Axes.OuterPosition;
        end % get.OuterPosition
        
        function set.OuterPosition( obj, proposedOuterPosition )
            obj.Axes.OuterPosition = proposedOuterPosition;
        end % set.OuterPosition
        
        function actPos = get.ActivePositionProperty( obj )
            actPos = obj.Axes.ActivePositionProperty;
        end % get.ActivePositionProperty
        
        function set.ActivePositionProperty( obj, proposedActivePositionProperty )
            obj.Axes.ActivePositionProperty = proposedActivePositionProperty;
        end % set.ActivePositionProperty
        
        function v = get.Visible( obj )
            v = obj.Axes.Visible;
        end % get.Visible
        
        function set.Visible( obj, proposedVisibility )
            obj.Axes.Visible = proposedVisibility;
            set( obj.Axes.Children, 'Visible', proposedVisibility )
            set( obj.Axes.Legend, 'Visible', proposedVisibility )
        end % set.Visible
    
    end % methods
    
    methods ( Access = protected )
        
        function onAxesDeleted( obj, ~, ~ )
            
            % Delete the chart if the axes is destroyed.
            delete( obj );
            
        end % onAxesDeleted
        
    end % methods ( Access = protected )
    
end % class definition