classdef GalleryLauncher < handle
    %GALLERYLAUNCHER Application launcher for the chart gallery.
    %
    % Copyright 2018 The MathWorks, Inc.
    
    properties ( Access = private ) 
        % Main application figure window.
        Figure
        % List of charts available to the user.
        ChartList
        % Web browser handles maintained by the launcher.
        Browsers = {};       
        % Progress bar for the launch process.
        Waitbar
        % Flag for user cancellation of the launch process.
        WaitbarCancelled = false;
    end % properties (Access = private)
    
    methods
        % Constructor.
        function obj = GalleryLauncher()
            
            %% Check software dependencies.
            v = ver( 'layout' );
            if isempty( v )
                obj.Figure = errordlg( 'This application requires GUI Layout Toolbox.', ...
                    'Missing software component.' );
                return
            end % if           
            
            %% Create the main figure.
            obj.Figure = figure( 'Name', 'Chart Gallery', ...
                'NumberTitle', 'off', ...
                'Menubar', 'none', ...
                'Units', 'Normalized', ...
                'Position', [0.225, 0.225, 0.550, 0.550], ...
                'Visible', 'off', ...
                'Resize', 'off', ...
                'CloseRequestFcn', @obj.onFigureClosed );
            
            %% Create a scrolling panel.
            scrollPanel = uix.ScrollingPanel( 'Parent', obj.Figure );
            
            %% Create a grid layout.
            chartGrid = uix.Grid( 'Parent', scrollPanel, ...
                'Padding', 5, ...
                'Spacing', 5, ...
                'BackgroundColor', 'w' );            
           
            %% Load the chart imagery.
            S = load( fullfile( galleryRoot(), '+Data', 'Tiles.mat' ) );
            
            %% Prepare a list of charts available to the user.
            userAccessibleCharts = GalleryLauncher.listAvailableCharts();
            allChartNames = {S.ChartTiles.Name}.';
            obj.ChartList = intersect( userAccessibleCharts, ...
                allChartNames );
            nCharts = numel( obj.ChartList );            
            
            %% Create a series of box panels for the gallery.
            galleryPanels = gobjects( nCharts, 1 );
            ax = gobjects( nCharts, 1 );
            im = gobjects( nCharts, 1 );
            obj.Waitbar = waitbar( 0, 'Preparing available charts ...', ...
                'CreateCancelBtn', @obj.onWaitbarClosed, ... 
                'Name', 'Launching the Chart Gallery' );
            oc = onCleanup( @() removeWaitbar( obj ) );
            for k = 1 : nCharts
                % Check if the user has requested cancellation.
                if obj.WaitbarCancelled
                    return
                end % if
                % Transpose the linear indexing so that the charts appear row-by-row in
                % the grid.
                gridSize = [ceil( nCharts/4 ), 4];
                [kt1, kt2] = ind2sub( gridSize, k );
                kt = sub2ind( flip( gridSize ), kt2, kt1 );
                currentName = obj.ChartList{kt};
                galleryPanels(kt, 1) = uix.BoxPanel(...
                    'Padding', 5, ...
                    'Parent', chartGrid, ...
                    'Title', currentName, ...
                    'FontName', 'Monospaced', ...
                    'TitleColor', [0, 0.447, 0.741], ...
                    'BorderType', 'beveledout', ...
                    'BorderWidth', 5, ...
                    'ShadowColor', [0.6, 0.6, 0.6], ...
                    'HighlightColor', [0.9, 0.9, 0.9], ...
                    'FontSize', 14, ...
                    'FontWeight', 'bold', ...
                    'HelpFcn', {@obj.onHelpIconClicked, kt} );
                ax(kt, 1) = axes( 'Parent', galleryPanels(kt, 1), ...
                    'ActivePositionProperty', 'Position', ...
                    'Position', [0, 0, 1, 1] );
                im(kt, 1) = image( ax(kt, 1), ...
                    'CData', S.ChartTiles(kt).Tile );
                ax(kt, 1).Visible = 'off';
                ax(kt, 1).YDir = 'reverse';
                axis( ax(kt, 1), 'image' )
                % Update the waitbar.
                waitbar( k/nCharts, obj.Waitbar, ...
                    ['Preparing ', currentName] );                
            end % for      
            
            % Close the waitbar.
            removeWaitbar( obj );           
            
            %% Adjust the component sizes.     
            % Ensure that the grid has four columns.
            chartGrid.Widths = [-1, -1, -1, -1]; 
            % Allow 200 pixels per row.
            scrollPanel.Heights = 200 * ceil( nCharts/4 );
            % Give the scroll panel a small margin relative to the figure.
            figPos = getpixelposition( obj.Figure );
            scrollPanel.Widths = figPos(3) - 20;
            
            %% Show the figure and switch off its handle visibility.
            obj.Figure.HandleVisibility = 'off';
            obj.Figure.Visible = 'on';
            
        end % GalleryLauncher
        
    end % methods
    
    methods ( Access = private )        
        
        function onFigureClosed( obj, ~, ~ )
            % Main figure close request function. Close any browsers
            % opened by users interacting with the gallery.
            
            for k = 1:numel( obj.Browsers )
                close( obj.Browsers{k} );
            end % for
            
            % Close the main figure.
            delete(obj.Figure);
            
        end % onFigureClosed     
        
        function removeWaitbar( obj )
            if isvalid( obj.Waitbar )
                delete( obj.Waitbar )
            end % if
        end % removeWaitbar
        
        function onWaitbarClosed( obj, ~, ~ )
            % If the user closes the waitbar, set the object's Cancelled
            % property to true.
            obj.WaitbarCancelled = true;
        end % onWaitbarClosed
        
        function onHelpIconClicked( obj, ~, ~, panelIdx )
            % Chart panel help function. Open the corresponding
            % documentation example file when the help icon is clicked.
            
            exampleFile = fullfile( galleryRoot(), '+Examples', ...
                [obj.ChartList{panelIdx}, '.html'] );
            [~, obj.Browsers{end+1}] = web( exampleFile, '-new' );
            
        end % onHelpIconClicked
        
    end % methods ( Access = private )
    
    methods ( Static, Access = private )
        
        function userAccessibleCharts = listAvailableCharts()
            %LISTAVAILABLECHARTS Prepare a list of charts available to the user.
            %Each chart has a set of MATLAB product dependencies. The chart gallery is
            %populated with the subset of charts accessible via the user's installed
            %products.
            
            % Start with a list of all the charts.
            allCharts = dir( fullfile( galleryRoot(), '+Charts', '*.m' ) );
            % Remove the file extension.
            chartNames = strrep( {allCharts.name}.', '.m', '' );
            % Read off the chart dependencies.
            nCharts = numel( chartNames );
            chartDependencies = cell( nCharts, 1 );
            for k = 1:nCharts
                chartDependencies{k, 1} = Charts.(chartNames{k}).Dependencies;
            end % for
            
            % Decide which charts the user can see, based on their installation.
            v = ver();
            toolboxNames = {v.Name}.';
            userVisible = false( nCharts, 1 );
            for k = 1:nCharts
                userVisible(k) = all( ismember( chartDependencies{k}, toolboxNames ) );
            end % for
            userAccessibleCharts = chartNames(userVisible);
            
        end % listAvailableCharts
        
    end % methods ( Static, Access = private )
    
end % class definition